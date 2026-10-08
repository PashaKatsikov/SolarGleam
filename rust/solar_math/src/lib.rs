//! Solar Gleam puzzle core. The C interface uses short opaque names on purpose.
//!
//! sg_k0  initialise and verify the tables                  -> 1 on success
//! sg_n1  start a puzzle for (region, level)                -> words written or 0
//! sg_t2  tap an orb                                         -> packed state
//! sg_h3  spend a replay (0) or a hint (1)
//! sg_f5  finish a solved puzzle and get its rewards         -> words written or 0
//! sg_u7  cost to open a region
//! sg_c4  balance constants

pub mod engine;
pub mod rng;
pub mod tables;
pub mod vault;

use std::sync::{Mutex, OnceLock};

use engine::Puzzle;
use vault::Vault;

static CORE: OnceLock<Option<Vault>> = OnceLock::new();
static SESSION: Mutex<Option<Puzzle>> = Mutex::new(None);

pub fn core() -> Option<&'static Vault> {
    CORE.get_or_init(vault::open).as_ref()
}

fn session() -> std::sync::MutexGuard<'static, Option<Puzzle>> {
    SESSION.lock().unwrap_or_else(|p| p.into_inner())
}

/// Words before the orb list in the `sg_n1` result.
const HEAD: usize = 10;

#[no_mangle]
pub extern "C" fn sg_k0() -> i32 {
    i32::from(core().is_some())
}

/// Result layout (i32 words): orb count, mode bits, attempts, hints, replays,
/// flash ms, gap ms, sequence length, event count, shift flag, then
/// `orb, glyph, slot` for every orb, `kind, value` for every preview event,
/// and the post-shift slot of every orb.
///
/// # Safety
/// `out` must point to `cap` writable words.
#[no_mangle]
pub unsafe extern "C" fn sg_n1(region: i32, level: i32, out: *mut i32, cap: i32) -> i32 {
    let Some(vault) = core() else { return 0 };
    if out.is_null() || region < 0 || level < 0 {
        return 0;
    }
    let Some(puzzle) = Puzzle::generate(vault, region as usize, level as usize) else {
        return 0;
    };
    let n = puzzle.orbs.len();
    let need = HEAD + n * 3 + puzzle.events.len() * 2 + n;
    if cap < need as i32 {
        return 0;
    }
    let out = std::slice::from_raw_parts_mut(out, need);
    out[0] = n as i32;
    out[1] = puzzle.modes as i32;
    out[2] = puzzle.attempts as i32;
    out[3] = puzzle.hints as i32;
    out[4] = puzzle.replays as i32;
    out[5] = puzzle.flash_ms as i32;
    out[6] = puzzle.gap_ms as i32;
    out[7] = puzzle.expected_len() as i32;
    out[8] = puzzle.events.len() as i32;
    out[9] = i32::from(puzzle.modes & tables::MODE_SHIFT != 0);

    let mut at = HEAD;
    for orb in &puzzle.orbs {
        out[at] = vault.to_dart_orb[orb.kind as usize] as i32;
        out[at + 1] = vault.to_dart_glyph[orb.glyph as usize] as i32;
        out[at + 2] = orb.slot as i32;
        at += 3;
    }
    for event in &puzzle.events {
        out[at] = event.kind as i32;
        out[at + 1] = if event.kind == engine::EV_GLYPH {
            vault.to_dart_glyph[event.a as usize] as i32
        } else {
            event.a as i32
        };
        at += 2;
    }
    for slot in &puzzle.shift_to {
        out[at] = *slot as i32;
        at += 1;
    }
    *session() = Some(puzzle);
    need as i32
}

/// Packed: bits 0-7 result (1 right, 2 wrong, 3 lost, 4 solved), 8-15 taps
/// entered so far, 16-23 attempts left, 24-30 sequence length.
#[no_mangle]
pub extern "C" fn sg_t2(orb: i32) -> i32 {
    let mut guard = session();
    let Some(puzzle) = guard.as_mut() else { return 0 };
    if !(0..=255).contains(&orb) {
        return 0;
    }
    let tap = puzzle.tap(orb as u8);
    (tap.code as i32)
        | ((tap.pos as i32 & 0xFF) << 8)
        | ((tap.attempts_left as i32 & 0xFF) << 16)
        | ((puzzle.expected_len() as i32 & 0x7F) << 24)
}

/// `kind` 0: replay the preview, returns 1 when allowed. `kind` 1: reveal the
/// next orb, returns its index or -1.
#[no_mangle]
pub extern "C" fn sg_h3(kind: i32) -> i32 {
    let mut guard = session();
    let Some(puzzle) = guard.as_mut() else { return -1 };
    match kind {
        0 => i32::from(puzzle.replay()),
        1 => puzzle.hint().map_or(-1, i32::from),
        _ => -1,
    }
}

/// Reward words: stars, energy, fast flag, first-try flag, decor index (-1 for
/// none), region-complete flag, mistakes, aids used.
///
/// # Safety
/// `out` must point to `cap` writable words.
#[no_mangle]
pub unsafe extern "C" fn sg_f5(elapsed_ms: i32, repeat: i32, out: *mut i32, cap: i32) -> i32 {
    let Some(vault) = core() else { return 0 };
    if out.is_null() || cap < 8 {
        return 0;
    }
    let guard = session();
    let Some(puzzle) = guard.as_ref() else { return 0 };
    let Some(reward) = puzzle.reward(vault, elapsed_ms.max(0) as u32, repeat != 0) else {
        return 0;
    };
    let out = std::slice::from_raw_parts_mut(out, 8);
    out[0] = reward.stars as i32;
    out[1] = reward.energy as i32;
    out[2] = i32::from(reward.fast);
    out[3] = i32::from(reward.first_try);
    out[4] = reward.decor;
    out[5] = i32::from(reward.region_done);
    out[6] = reward.mistakes as i32;
    out[7] = reward.aids as i32;
    8
}

/// Cost when payable now, -1 while the previous region is unfinished, -2 when
/// energy is short.
#[no_mangle]
pub extern "C" fn sg_u7(region: i32, prev_done: i32, energy: i32) -> i32 {
    let Some(vault) = core() else { return -1 };
    if region < 0 {
        return -1;
    }
    engine::unlock_cost(vault, region as usize, prev_done.max(0) as u32, energy.max(0) as u32)
}

/// 0 regions, 1 levels per region, 2 orb kinds, 3 region cost, 4 orb discovery
/// index (Dart orb id), then per global level index `arg`: 5 mode bits,
/// 6 orb count, 7 sequence length, 8 base energy. 9 attempts for a region.
#[no_mangle]
pub extern "C" fn sg_c4(id: i32, arg: i32) -> i32 {
    let Some(vault) = core() else { return 0 };
    let levels = tables::LEVELS as i32;
    let a = arg.max(0);
    let (region, level) = ((a / levels) as usize, (a % levels) as usize);
    match id {
        0 => tables::REGIONS as i32,
        1 => levels,
        2 => tables::ORBS as i32,
        3 => vault.region(tables::T_COST, (a as usize).min(tables::REGIONS - 1)) as i32,
        4 => {
            let internal = vault.to_internal_orb[(a as usize).min(tables::ORBS - 1)] as usize;
            vault.orb_unlock(internal) as i32
        }
        5 | 6 | 7 => match engine::shape(vault, region, level) {
            Some((orbs, len, modes)) => match id {
                5 => modes as i32,
                6 => orbs as i32,
                _ => len as i32,
            },
            None => 0,
        },
        8 => engine::energy_for(vault, region.min(tables::REGIONS - 1), level, 1, false, false) as i32,
        9 => vault.region(tables::T_ATTEMPTS, (a as usize).min(tables::REGIONS - 1)) as i32,
        _ => 0,
    }
}

/// Test automation only: the orb the running puzzle expects next, or -1.
#[cfg(feature = "probe")]
#[no_mangle]
pub extern "C" fn sg_d9() -> i32 {
    let guard = session();
    guard
        .as_ref()
        .and_then(|p| p.next_expected())
        .map_or(-1, i32::from)
}
