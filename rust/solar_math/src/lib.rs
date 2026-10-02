//! Solar Gleam math core. The C interface uses short opaque names on purpose.
//!
//! sg_k0  initialise and verify the sealed data      -> 1 on success
//! sg_g1  random grid                                -> cell count or 0
//! sg_e2  evaluate a grid                            -> words written or 0
//! sg_p3  pay for `count` of a kind on one line
//! sg_c4  rule constants

pub mod cipher;
pub mod engine;
pub mod rng;
pub mod vault;

use std::sync::OnceLock;
use vault::{Misc, Vault};

static CORE: OnceLock<Option<Vault>> = OnceLock::new();

pub fn core() -> Option<&'static Vault> {
    CORE.get_or_init(vault::open).as_ref()
}

/// Header words before the per-line records in the `sg_e2` result.
const HEAD: usize = 7;
const PER_LINE: usize = 4;

#[no_mangle]
pub extern "C" fn sg_k0() -> i32 {
    i32::from(core().is_some())
}

/// # Safety
/// `out` must point to at least `cap` writable bytes.
#[no_mangle]
pub unsafe extern "C" fn sg_g1(out: *mut u8, cap: i32) -> i32 {
    let Some(vault) = core() else { return 0 };
    if out.is_null() || cap <= 0 {
        return 0;
    }
    let cells = vault.reels * vault.rows;
    if (cap as usize) < cells {
        return 0;
    }
    let slice = std::slice::from_raw_parts_mut(out, cells);
    if engine::spin(vault, slice) {
        cells as i32
    } else {
        0
    }
}

/// Result layout (i64 words): total win, scatter win, scatter count,
/// free spins awarded, celebration tier, winning-cell mask, line count,
/// then `line, symbol, count, amount` for each winning line.
///
/// # Safety
/// `grid` must point to `len` readable bytes and `out` to `cap` writable words.
#[no_mangle]
pub unsafe extern "C" fn sg_e2(
    grid: *const u8,
    len: i32,
    total_bet: i64,
    free_spin: i32,
    out: *mut i64,
    cap: i32,
) -> i32 {
    let Some(vault) = core() else { return 0 };
    if grid.is_null() || out.is_null() || len <= 0 || cap < HEAD as i32 {
        return 0;
    }
    let grid = std::slice::from_raw_parts(grid, len as usize);
    let Some(outcome) = engine::evaluate(vault, grid, total_bet, free_spin != 0) else {
        return 0;
    };
    let need = HEAD + outcome.hits.len() * PER_LINE;
    if (cap as usize) < need {
        return 0;
    }
    let out = std::slice::from_raw_parts_mut(out, need);
    out[0] = outcome.total_win;
    out[1] = outcome.scatter_win;
    out[2] = outcome.scatter_count as i64;
    out[3] = outcome.free_spins as i64;
    out[4] = outcome.tier as i64;
    out[5] = outcome.cells as i64;
    out[6] = outcome.hits.len() as i64;
    for (i, hit) in outcome.hits.iter().enumerate() {
        let at = HEAD + i * PER_LINE;
        out[at] = hit.line as i64;
        out[at + 1] = hit.symbol as i64;
        out[at + 2] = hit.count as i64;
        out[at + 3] = hit.amount;
    }
    need as i32
}

#[no_mangle]
pub extern "C" fn sg_p3(symbol: i32, count: i32, line_bet: i64) -> i64 {
    let Some(vault) = core() else { return 0 };
    if symbol < 0 || count < 0 {
        return 0;
    }
    engine::line_pay(vault, symbol as usize, count as usize, line_bet)
}

/// 0 paylines, 1 scatter x3 multiplier, 2 scatter x4+ multiplier,
/// 3 free spins for 3, 4 free spins for 4+, 5 free-spin line multiplier.
#[no_mangle]
pub extern "C" fn sg_c4(id: i32) -> i64 {
    let Some(vault) = core() else { return 0 };
    match id {
        0 => vault.line_count as i64,
        1 => vault.misc(Misc::Scatter3) as i64,
        2 => vault.misc(Misc::Scatter4) as i64,
        3 => vault.misc(Misc::FreeSpins3) as i64,
        4 => vault.misc(Misc::FreeSpins4) as i64,
        5 => vault.misc(Misc::FreeSpinMultiplier) as i64,
        _ => 0,
    }
}
