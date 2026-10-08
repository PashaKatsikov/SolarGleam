//! Puzzle tables: difficulty curves, energy economy, mode schedule and the
//! orb discovery order.
//!
//! Every number is XOR-masked with a per-index rotation at compile time, so
//! the binary holds no readable balance sheet. This is a one-shot const
//! scramble, not a runtime cipher: there is no key schedule and nothing to
//! "unlock".
//!
//! Orb order is the Dart discovery order: azure, pink, cyan, white, violet,
//! amber, crimson, prism, crystal, emerald, gold, void.

pub const REGIONS: usize = 6;
pub const LEVELS: usize = 8;
pub const ORBS: usize = 12;
pub const GLYPHS: usize = 4;

#[inline(always)]
const fn mask(i: u32) -> u32 {
    0x5B1D_C7A9u32.rotate_left((i.wrapping_mul(7)) & 31) ^ i.wrapping_mul(0x85EB_CA6B).wrapping_add(0x27D4_EB2F)
}

#[inline(always)]
pub const fn dec(v: u32, i: u32) -> u32 {
    v ^ mask(i)
}

const fn enc<const N: usize>(src: [u32; N], base: u32) -> [u32; N] {
    let mut out = [0u32; N];
    let mut i = 0;
    while i < N {
        out[i] = src[i] ^ mask(base + i as u32);
        i += 1;
    }
    out
}

// Table ids. The vault stores each table in a 64-slot window of its own.
pub const T_ORBS_FROM: usize = 0;
pub const T_ORBS_TO: usize = 1;
pub const T_LEN_FROM: usize = 2;
pub const T_LEN_TO: usize = 3;
pub const T_FLASH_FROM: usize = 4;
pub const T_FLASH_TO: usize = 5;
pub const T_GAP: usize = 6;
pub const T_ATTEMPTS: usize = 7;
pub const T_HINTS: usize = 8;
pub const T_REPLAYS: usize = 9;
pub const T_ENERGY_BASE: usize = 10;
pub const T_ENERGY_STEP: usize = 11;
pub const T_COST: usize = 12;
pub const T_PAR: usize = 13;
pub const T_MODES: usize = 14;
pub const T_ORB_UNLOCK: usize = 15;
pub const T_ORB_SHUFFLE: usize = 16;
pub const T_GLYPH_SHUFFLE: usize = 17;
pub const T_STAR_PCT: usize = 18;
pub const T_MISC: usize = 19;
pub const TABLES: usize = 20;
pub const WINDOW: u32 = 64;

const fn base(table: usize) -> u32 {
    table as u32 * WINDOW
}

// Mode bits used by the schedule.
pub const MODE_ECHO: u32 = 1;
pub const MODE_MIRROR: u32 = 2;
pub const MODE_GLYPH: u32 = 4;
pub const MODE_GHOST: u32 = 8;
pub const MODE_SHIFT: u32 = 16;

// Region rows ---------------------------------------------------------------

pub static ORBS_FROM: [u32; REGIONS] = enc([3, 4, 5, 6, 7, 8], base(T_ORBS_FROM));
pub static ORBS_TO: [u32; REGIONS] = enc([4, 5, 6, 7, 8, 12], base(T_ORBS_TO));
pub static LEN_FROM: [u32; REGIONS] = enc([3, 4, 4, 5, 5, 6], base(T_LEN_FROM));
pub static LEN_TO: [u32; REGIONS] = enc([5, 6, 7, 8, 9, 10], base(T_LEN_TO));
pub static FLASH_FROM: [u32; REGIONS] = enc([720, 700, 680, 660, 640, 620], base(T_FLASH_FROM));
pub static FLASH_TO: [u32; REGIONS] = enc([600, 580, 540, 520, 500, 460], base(T_FLASH_TO));
pub static GAP: [u32; REGIONS] = enc([300, 290, 280, 270, 260, 250], base(T_GAP));
pub static ATTEMPTS: [u32; REGIONS] = enc([3, 3, 3, 3, 3, 4], base(T_ATTEMPTS));
pub static HINTS: [u32; REGIONS] = enc([2, 2, 2, 2, 2, 3], base(T_HINTS));
pub static REPLAYS: [u32; REGIONS] = enc([2, 2, 2, 2, 2, 3], base(T_REPLAYS));
pub static ENERGY_BASE: [u32; REGIONS] = enc([20, 34, 48, 62, 76, 92], base(T_ENERGY_BASE));
pub static ENERGY_STEP: [u32; REGIONS] = enc([2, 3, 4, 5, 6, 7], base(T_ENERGY_STEP));
pub static COST: [u32; REGIONS] = enc([0, 180, 300, 420, 560, 700], base(T_COST));
/// Milliseconds allowed per tap for the "fast solve" bonus.
pub static PAR: [u32; REGIONS] = enc([1900, 1800, 1700, 1650, 1600, 1550], base(T_PAR));

/// Mode bits for every level, region-major.
/// 1 echo, 2 mirror, 4 glyph, 8 ghost, 16 shift.
pub static MODES: [u32; REGIONS * LEVELS] = enc(
    [
        1, 1, 1, 1, 1, 1, 1, 1, // neon district: colour memory only
        1, 1, 4, 1, 4, 1, 4, 4, // crystal forest: inner glyphs
        1, 2, 1, 2, 17, 2, 18, 18, // aurora temple: reversed order, then shifting layout
        9, 2, 4, 10, 25, 4, 10, 26, // cyber ocean: false signals
        17, 18, 20, 25, 26, 20, 26, 25, // quantum desert: several rules at once
        20, 25, 26, 20, 26, 25, 20, 26, // memory core: everything together
    ],
    base(T_MODES),
);

/// Global level index (`region * 8 + level`) at which each orb joins the pool.
pub static ORB_UNLOCK: [u32; ORBS] = enc([0, 0, 0, 4, 8, 12, 16, 24, 28, 32, 36, 40], base(T_ORB_UNLOCK));

/// Internal code of each Dart orb id.
pub static ORB_SHUFFLE: [u32; ORBS] = enc([7, 2, 10, 5, 0, 9, 3, 11, 6, 1, 8, 4], base(T_ORB_SHUFFLE));
/// Internal code of each Dart glyph id.
pub static GLYPH_SHUFFLE: [u32; GLYPHS] = enc([2, 0, 3, 1], base(T_GLYPH_SHUFFLE));

/// Energy share by star count, in percent.
pub static STAR_PCT: [u32; 3] = enc([100, 125, 150], base(T_STAR_PCT));

/// fast-solve bonus %, final-level multiplier, repeat-clear %, par base ms,
/// score ceiling for two stars, base ghost count, ghost divisor, decor levels.
pub static MISC: [u32; 8] = enc([25, 2, 30, 2500, 2, 1, 4, 0b1010_1010], base(T_MISC));

pub const MISC_FAST_PCT: usize = 0;
pub const MISC_FINAL_MULT: usize = 1;
pub const MISC_REPEAT_PCT: usize = 2;
pub const MISC_PAR_BASE: usize = 3;
pub const MISC_TWO_STAR_SCORE: usize = 4;
pub const MISC_GHOST_BASE: usize = 5;
pub const MISC_GHOST_DIV: usize = 6;
pub const MISC_DECOR_MASK: usize = 7;
