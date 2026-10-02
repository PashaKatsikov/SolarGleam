//! Opens the sealed economy blob. Nothing readable is stored in the binary:
//! the blob is encrypted, symbol indices are shuffled inside it, and every
//! decoded number is held XOR-masked with a key chosen at start-up.

use crate::cipher::{self, Stream};
use crate::rng;

static SEALED: &[u8] = include_bytes!("sealed.bin");

pub const MAX_SYMBOLS: usize = 32;
pub const MAX_LINES: usize = 40;
pub const MAX_REELS: usize = 8;

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

struct Reader<'a> {
    data: &'a [u8],
    at: usize,
}

impl Reader<'_> {
    fn word(&mut self) -> Option<u32> {
        let end = self.at.checked_add(4)?;
        let chunk = self.data.get(self.at..end)?;
        self.at = end;
        Some(u32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]))
    }
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
    if SEALED.len() < 16 + 8 {
        return None;
    }
    let mut nonce = [0u8; 16];
    nonce.copy_from_slice(&SEALED[..16]);
    let key = cipher::master();
    let mut body = SEALED[16..].to_vec();
    Stream::new(&key, &nonce).apply(&mut body);

    let split = body.len().checked_sub(8)?;
    let (payload, stored) = body.split_at(split);
    let mut raw = [0u8; 8];
    raw.copy_from_slice(stored);
    if cipher::tag(payload, &key) != u64::from_le_bytes(raw) {
        return None;
    }

    let mut rd = Reader {
        data: payload,
        at: 0,
    };
    let n = rd.word()? as usize;
    if n == 0 || n > MAX_SYMBOLS {
        return None;
    }
    let mut weights = Vec::with_capacity(n);
    let mut pays3 = Vec::with_capacity(n);
    let mut pays4 = Vec::with_capacity(n);
    for _ in 0..n {
        weights.push(rd.word()?);
        pays3.push(rd.word()?);
        pays4.push(rd.word()?);
    }
    let mut to_internal = [0u8; MAX_SYMBOLS];
    let mut to_dart = [0u8; MAX_SYMBOLS];
    for dart in 0..n {
        let internal = rd.word()? as usize;
        if internal >= n {
            return None;
        }
        to_internal[dart] = internal as u8;
        to_dart[internal] = dart as u8;
    }
    let wild = rd.word()?;
    let bonus = rd.word()?;
    let line_count = rd.word()? as usize;
    let reels = rd.word()? as usize;
    let rows = rd.word()? as usize;
    if line_count == 0
        || line_count > MAX_LINES
        || reels == 0
        || reels > MAX_REELS
        || rows == 0
        || reels * rows > 32
    {
        return None;
    }
    let mut lines = Vec::with_capacity(line_count * reels);
    for _ in 0..line_count * reels {
        let row = rd.word()?;
        if row as usize >= rows {
            return None;
        }
        lines.push(row);
    }
    let scatter3 = rd.word()?;
    let scatter4 = rd.word()?;
    let fs3 = rd.word()?;
    let fs4 = rd.word()?;
    let fs_mult = rd.word()?;
    let tier_big = rd.word()?;
    let tier_solar = rd.word()?;

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
    let misc = [
        wild, bonus, scatter3, scatter4, fs3, fs4, fs_mult, tier_big, tier_solar,
    ];
    for (i, v) in misc.iter().enumerate() {
        vault.misc[i] = vault.lock(*v, SLOT_MISC + i as u32);
    }
    Some(vault)
}
