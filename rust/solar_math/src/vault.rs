//! Decodes the economy tables once at start-up. Every decoded number is held
//! XOR-masked with a key chosen at start-up, and symbol indices are shuffled
//! so the engine never works with the ids Dart sees.

use crate::rng;
use crate::tables::{self as t, dec};

pub const MAX_SYMBOLS: usize = 32;

const SLOT_WEIGHT: u32 = 0;
const SLOT_PAY3: u32 = 64;
const SLOT_PAY4: u32 = 128;
const SLOT_MISC: u32 = 192;
const SLOT_LINE: u32 = 256;

pub struct Vault {
    seed: u32,
    pub symbols: usize,
    pub reels: usize,
    pub rows: usize,
    pub line_count: usize,
    weight: Vec<u32>,
    pay3: Vec<u32>,
    pay4: Vec<u32>,
    lines: Vec<u32>,
    misc: [u32; 12],
    pub to_internal: [u8; MAX_SYMBOLS],
    pub to_dart: [u8; MAX_SYMBOLS],
    pub total_weight: u32,
}

#[derive(Clone, Copy)]
pub enum Misc {
    Wild = 0,
    Bonus = 1,
    Scatter3 = 2,
    Scatter4 = 3,
    FreeSpins3 = 4,
    FreeSpins4 = 5,
    FreeSpinMultiplier = 6,
    TierBig = 7,
    TierSolar = 8,
}

impl Vault {
    fn mask(&self, slot: u32) -> u32 {
        self.seed
            .wrapping_mul(0x9E37_79B1)
            .wrapping_add(slot.wrapping_mul(0x85EB_CA6B))
            .rotate_left(slot & 31)
    }

    fn lock(&self, value: u32, slot: u32) -> u32 {
        value ^ self.mask(slot)
    }

    fn unlock(&self, value: u32, slot: u32) -> u32 {
        value ^ self.mask(slot)
    }

    pub fn weight(&self, internal: usize) -> u32 {
        self.weight
            .get(internal)
            .map_or(0, |v| self.unlock(*v, SLOT_WEIGHT + internal as u32))
    }

    pub fn pay(&self, internal: usize, count: usize) -> u32 {
        let (table, base) = if count >= 4 {
            (&self.pay4, SLOT_PAY4)
        } else {
            (&self.pay3, SLOT_PAY3)
        };
        table
            .get(internal)
            .map_or(0, |v| self.unlock(*v, base + internal as u32))
    }

    pub fn misc(&self, which: Misc) -> u32 {
        let i = which as usize;
        self.unlock(self.misc[i], SLOT_MISC + i as u32)
    }

    /// Internal code of the wild or bonus symbol.
    pub fn to_internal_misc(&self, which: Misc) -> u8 {
        self.misc(which) as u8
    }

    pub fn line_row(&self, line: usize, reel: usize) -> usize {
        let i = line * self.reels + reel;
        self.lines
            .get(i)
            .map_or(0, |v| self.unlock(*v, SLOT_LINE + i as u32) as usize)
    }

    /// Weighted draw. Returns an internal symbol code.
    pub fn draw_internal(&self) -> usize {
        let mut pick = rng::below(self.total_weight);
        for internal in 0..self.symbols {
            let w = self.weight(internal);
            if pick < w {
                return internal;
            }
            pick -= w;
        }
        0
    }
}

pub fn open() -> Option<Vault> {
    let n = t::SYMBOLS;
    let (reels, rows, line_count) = (t::REELS, t::ROWS, t::LINES);
    if n == 0 || n > MAX_SYMBOLS || reels * rows > 32 {
        return None;
    }

    let mut to_internal = [0u8; MAX_SYMBOLS];
    let mut to_dart = [0u8; MAX_SYMBOLS];
    let mut seen = [false; MAX_SYMBOLS];
    for dart in 0..n {
        let internal = dec(t::SHUFFLE[dart], t::BASE_SHUFFLE + dart as u32) as usize;
        if internal >= n || seen[internal] {
            return None;
        }
        seen[internal] = true;
        to_internal[dart] = internal as u8;
        to_dart[internal] = dart as u8;
    }

    // Tables are listed in Dart order; the vault stores them by internal code.
    let mut weights = vec![0u32; n];
    let mut pays3 = vec![0u32; n];
    let mut pays4 = vec![0u32; n];
    for dart in 0..n {
        let internal = to_internal[dart] as usize;
        weights[internal] = dec(t::WEIGHT[dart], t::BASE_WEIGHT + dart as u32);
        pays3[internal] = dec(t::PAY3[dart], t::BASE_PAY3 + dart as u32);
        pays4[internal] = dec(t::PAY4[dart], t::BASE_PAY4 + dart as u32);
    }

    let mut lines = Vec::with_capacity(line_count * reels);
    for (i, v) in t::LINE_ROWS.iter().enumerate() {
        let row = dec(*v, t::BASE_LINE + i as u32);
        if row as usize >= rows {
            return None;
        }
        lines.push(row);
    }

    let rule = |i: usize| dec(t::MISC[i], t::BASE_MISC + i as u32);
    let misc = [
        to_internal[t::WILD_DART] as u32,
        to_internal[t::BONUS_DART] as u32,
        rule(0),
        rule(1),
        rule(2),
        rule(3),
        rule(4),
        rule(5),
        rule(6),
    ];

    let seed = rng::word() | 1;
    let mut vault = Vault {
        seed,
        symbols: n,
        reels,
        rows,
        line_count,
        weight: Vec::new(),
        pay3: Vec::new(),
        pay4: Vec::new(),
        lines: Vec::new(),
        misc: [0; 12],
        to_internal,
        to_dart,
        total_weight: 0,
    };

    let mut total = 0u32;
    for (i, w) in weights.iter().enumerate() {
        total = total.checked_add(*w)?;
        let locked = vault.lock(*w, SLOT_WEIGHT + i as u32);
        vault.weight.push(locked);
    }
    if total == 0 {
        return None;
    }
    vault.total_weight = total;
    for (i, v) in pays3.iter().enumerate() {
        let locked = vault.lock(*v, SLOT_PAY3 + i as u32);
        vault.pay3.push(locked);
    }
    for (i, v) in pays4.iter().enumerate() {
        let locked = vault.lock(*v, SLOT_PAY4 + i as u32);
        vault.pay4.push(locked);
    }
    for (i, v) in lines.iter().enumerate() {
        let locked = vault.lock(*v, SLOT_LINE + i as u32);
        vault.lines.push(locked);
    }
    for (i, v) in misc.iter().enumerate() {
        vault.misc[i] = vault.lock(*v, SLOT_MISC + i as u32);
    }
    Some(vault)
}
