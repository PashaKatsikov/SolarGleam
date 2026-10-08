//! Decodes the balance tables once at start-up. Every decoded number is held
//! XOR-masked with a key chosen at start-up, and orb / glyph ids are shuffled
//! so the engine never works with the ids Dart sees.

use crate::rng;
use crate::tables::{self as t, dec};

const W: usize = t::WINDOW as usize;

pub struct Vault {
    seed: u32,
    data: Vec<u32>,
    pub to_internal_orb: [u8; t::ORBS],
    pub to_dart_orb: [u8; t::ORBS],
    pub to_internal_glyph: [u8; t::GLYPHS],
    pub to_dart_glyph: [u8; t::GLYPHS],
}

impl Vault {
    fn mask(&self, slot: u32) -> u32 {
        self.seed
            .wrapping_mul(0x9E37_79B1)
            .wrapping_add(slot.wrapping_mul(0xC2B2_AE35))
            .rotate_left((slot ^ (slot >> 3)) & 31)
    }

    fn lock(&self, value: u32, slot: u32) -> u32 {
        value ^ self.mask(slot)
    }

    fn unlock(&self, value: u32, slot: u32) -> u32 {
        value ^ self.mask(slot)
    }

    /// One value of one table. Out-of-range reads return zero.
    pub fn get(&self, table: usize, index: usize) -> u32 {
        if table >= t::TABLES || index >= W {
            return 0;
        }
        let slot = table * W + index;
        self.data.get(slot).map_or(0, |v| self.unlock(*v, slot as u32))
    }

    pub fn misc(&self, which: usize) -> u32 {
        self.get(t::T_MISC, which)
    }

    /// Value of a per-region table.
    pub fn region(&self, table: usize, region: usize) -> u32 {
        self.get(table, region)
    }

    /// Mode bits for a level.
    pub fn modes(&self, region: usize, level: usize) -> u32 {
        self.get(t::T_MODES, region * t::LEVELS + level)
    }

    /// Global level index at which an orb (internal code) joins the pool.
    pub fn orb_unlock(&self, internal: usize) -> u32 {
        self.get(t::T_ORB_UNLOCK, internal)
    }

    pub fn star_pct(&self, stars: usize) -> u32 {
        self.get(t::T_STAR_PCT, stars.saturating_sub(1).min(2))
    }

    fn put(&mut self, table: usize, index: usize, value: u32) {
        let slot = table * W + index;
        self.data[slot] = self.lock(value, slot as u32);
    }
}

/// Linear blend between the first and last level of a region, rounded.
pub fn lerp(from: u32, to: u32, level: usize) -> u32 {
    let last = (t::LEVELS - 1) as i64;
    let (a, b, l) = (from as i64, to as i64, level.min(t::LEVELS - 1) as i64);
    ((a * last * 2 + (b - a) * l * 2 + last) / (last * 2)) as u32
}

fn permutation(
    table: &[u32],
    base: usize,
    n: usize,
) -> Option<([u8; t::ORBS], [u8; t::ORBS])> {
    let mut forward = [0u8; t::ORBS];
    let mut back = [0u8; t::ORBS];
    let mut seen = [false; t::ORBS];
    for i in 0..n {
        let v = dec(table[i], (base * W + i) as u32) as usize;
        if v >= n || seen[v] {
            return None;
        }
        seen[v] = true;
        forward[i] = v as u8;
        back[v] = i as u8;
    }
    Some((forward, back))
}

pub fn open() -> Option<Vault> {
    let (to_internal_orb, to_dart_orb) = permutation(&t::ORB_SHUFFLE, t::T_ORB_SHUFFLE, t::ORBS)?;
    let (gi, gd) = permutation(&t::GLYPH_SHUFFLE, t::T_GLYPH_SHUFFLE, t::GLYPHS)?;
    let mut to_internal_glyph = [0u8; t::GLYPHS];
    let mut to_dart_glyph = [0u8; t::GLYPHS];
    to_internal_glyph.copy_from_slice(&gi[..t::GLYPHS]);
    to_dart_glyph.copy_from_slice(&gd[..t::GLYPHS]);

    let mut vault = Vault {
        seed: rng::word() | 1,
        data: vec![0; t::TABLES * W],
        to_internal_orb,
        to_dart_orb,
        to_internal_glyph,
        to_dart_glyph,
    };

    let rows: [(usize, &[u32]); 14] = [
        (t::T_ORBS_FROM, &t::ORBS_FROM[..]),
        (t::T_ORBS_TO, &t::ORBS_TO[..]),
        (t::T_LEN_FROM, &t::LEN_FROM[..]),
        (t::T_LEN_TO, &t::LEN_TO[..]),
        (t::T_FLASH_FROM, &t::FLASH_FROM[..]),
        (t::T_FLASH_TO, &t::FLASH_TO[..]),
        (t::T_GAP, &t::GAP[..]),
        (t::T_ATTEMPTS, &t::ATTEMPTS[..]),
        (t::T_HINTS, &t::HINTS[..]),
        (t::T_REPLAYS, &t::REPLAYS[..]),
        (t::T_ENERGY_BASE, &t::ENERGY_BASE[..]),
        (t::T_ENERGY_STEP, &t::ENERGY_STEP[..]),
        (t::T_COST, &t::COST[..]),
        (t::T_PAR, &t::PAR[..]),
    ];
    for (table, src) in rows {
        for (i, v) in src.iter().enumerate() {
            let plain = dec(*v, (table * W + i) as u32);
            vault.put(table, i, plain);
        }
    }

    for (i, v) in t::MODES.iter().enumerate() {
        let plain = dec(*v, (t::T_MODES * W + i) as u32);
        if plain == 0 || plain >= 32 {
            return None;
        }
        vault.put(t::T_MODES, i, plain);
    }

    // Unlock order and the shuffles are kept by internal code.
    for dart in 0..t::ORBS {
        let plain = dec(t::ORB_UNLOCK[dart], (t::T_ORB_UNLOCK * W + dart) as u32);
        vault.put(t::T_ORB_UNLOCK, to_internal_orb[dart] as usize, plain);
    }
    for (i, v) in t::STAR_PCT.iter().enumerate() {
        let plain = dec(*v, (t::T_STAR_PCT * W + i) as u32);
        vault.put(t::T_STAR_PCT, i, plain);
    }
    for (i, v) in t::MISC.iter().enumerate() {
        let plain = dec(*v, (t::T_MISC * W + i) as u32);
        vault.put(t::T_MISC, i, plain);
    }

    // Sanity: every region must stay inside the orb pool and the board limits.
    for r in 0..t::REGIONS {
        let max_orbs = vault.region(t::T_ORBS_TO, r) as usize;
        let min_orbs = vault.region(t::T_ORBS_FROM, r) as usize;
        if min_orbs < 3 || max_orbs > t::ORBS || min_orbs > max_orbs {
            return None;
        }
        if vault.region(t::T_ATTEMPTS, r) == 0 {
            return None;
        }
    }
    Some(vault)
}
