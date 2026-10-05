//! Economy tables: weights, pays, paylines and rule numbers.
//!
//! Every number is XOR-masked with a per-index rotation at compile time, so
//! the binary holds no readable pay table. This is a one-shot const scramble,
//! not a runtime cipher: there is no key schedule and nothing to "unlock".
//!
//! Symbol order is the Dart enum order: ten, jack, queen, king, ace, star,
//! fireball, chest, crown, solar, wild, bonus.

pub const SYMBOLS: usize = 12;
pub const REELS: usize = 4;
pub const ROWS: usize = 4;
pub const LINES: usize = 20;

pub const WILD_DART: usize = 10;
pub const BONUS_DART: usize = 11;

#[inline(always)]
const fn mask(i: u32) -> u32 {
    0xA3C5_9E17u32.rotate_left(i & 31) ^ i.wrapping_mul(0x9E37_79B1)
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

pub const BASE_WEIGHT: u32 = 0;
pub const BASE_PAY3: u32 = 32;
pub const BASE_PAY4: u32 = 64;
pub const BASE_SHUFFLE: u32 = 96;
pub const BASE_LINE: u32 = 128;
pub const BASE_MISC: u32 = 224;

pub static WEIGHT: [u32; SYMBOLS] = enc([22, 18, 16, 14, 12, 7, 6, 4, 3, 2, 3, 2], BASE_WEIGHT);
pub static PAY3: [u32; SYMBOLS] = enc([14, 16, 18, 22, 28, 40, 55, 80, 130, 210, 280, 0], BASE_PAY3);
pub static PAY4: [u32; SYMBOLS] = enc(
    [40, 50, 60, 70, 90, 140, 200, 300, 500, 800, 1000, 0],
    BASE_PAY4,
);

/// Internal code of each Dart symbol. Internal codes are what the engine
/// compares; Dart ids are translated at the boundary.
pub static SHUFFLE: [u32; SYMBOLS] = enc([5, 8, 9, 6, 10, 11, 2, 3, 4, 7, 0, 1], BASE_SHUFFLE);

/// Row per reel for each payline, line-major.
pub static LINE_ROWS: [u32; LINES * REELS] = enc(
    [
        0, 0, 0, 0, //
        1, 1, 1, 1, //
        2, 2, 2, 2, //
        3, 3, 3, 3, //
        0, 1, 2, 3, //
        3, 2, 1, 0, //
        0, 1, 1, 0, //
        3, 2, 2, 3, //
        1, 0, 0, 1, //
        2, 3, 3, 2, //
        1, 2, 2, 1, //
        2, 1, 1, 2, //
        0, 0, 1, 2, //
        3, 3, 2, 1, //
        1, 1, 2, 3, //
        2, 2, 1, 0, //
        0, 1, 0, 1, //
        3, 2, 3, 2, //
        1, 2, 1, 2, //
        2, 1, 2, 1, //
    ],
    BASE_LINE,
);

/// scatter3, scatter4, free spins for 3, free spins for 4+, free-spin
/// multiplier, big-win tier, solar-win tier (both × total bet).
pub static MISC: [u32; 7] = enc([5, 20, 8, 12, 2, 15, 30], BASE_MISC);
