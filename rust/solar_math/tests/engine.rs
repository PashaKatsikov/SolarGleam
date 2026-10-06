use solar_math::engine::{evaluate, line_pay, spin};
use solar_math::{core, sg_c4, sg_e2, sg_g1, sg_k0, sg_p3};

// Dart-side symbol ids, in enum order.
const TEN: u8 = 0;
const JACK: u8 = 1;
const QUEEN: u8 = 2;
const ACE: u8 = 4;
const CHEST: u8 = 7;
const CROWN: u8 = 8;
const SOLAR: u8 = 9;
const WILD: u8 = 10;
const BONUS: u8 = 11;

const BET: i64 = 200;

fn board(symbol: u8) -> Vec<u8> {
    vec![symbol; 16]
}

fn set(grid: &mut [u8], reel: usize, row: usize, symbol: u8) {
    grid[reel * 4 + row] = symbol;
}

#[test]
fn core_opens() {
    assert_eq!(sg_k0(), 1);
    let vault = core().expect("vault");
    assert_eq!(vault.line_count, 20);
    assert_eq!((vault.reels, vault.rows), (4, 4));
}

#[test]
fn wild_completes_a_crown_line_from_the_left() {
    let vault = core().unwrap();
    let mut grid = board(TEN);
    set(&mut grid, 0, 0, WILD);
    set(&mut grid, 1, 0, WILD);
    set(&mut grid, 2, 0, CROWN);
    set(&mut grid, 3, 0, CROWN);
    let outcome = evaluate(vault, &grid, BET, false).unwrap();
    let crown = outcome
        .hits
        .iter()
        .find(|h| h.symbol == CROWN && h.count == 4)
        .expect("crown x4");
    assert_eq!(crown.amount, 500 * (BET / 20));
}

#[test]
fn bonus_does_not_substitute_on_a_payline() {
    let vault = core().unwrap();
    let mut grid = board(JACK);
    set(&mut grid, 0, 0, BONUS);
    set(&mut grid, 1, 0, SOLAR);
    set(&mut grid, 2, 0, SOLAR);
    set(&mut grid, 3, 0, SOLAR);
    let outcome = evaluate(vault, &grid, BET, false).unwrap();
    assert!(!outcome
        .hits
        .iter()
        .any(|h| h.line == 1 && h.symbol == SOLAR));
}

#[test]
fn three_bonus_symbols_award_free_spins_and_a_scatter_prize() {
    let vault = core().unwrap();
    let mut grid = board(ACE);
    set(&mut grid, 0, 0, BONUS);
    set(&mut grid, 1, 1, BONUS);
    set(&mut grid, 2, 2, BONUS);
    let outcome = evaluate(vault, &grid, BET, false).unwrap();
    assert_eq!(outcome.scatter_count, 3);
    assert_eq!(outcome.free_spins, 8);
    assert_eq!(outcome.scatter_win, BET * 5);
    assert_ne!(outcome.cells & 1, 0);
}

#[test]
fn four_bonus_symbols_award_the_top_prize() {
    let vault = core().unwrap();
    let mut grid = board(TEN);
    for (reel, row) in [(0, 0), (1, 2), (2, 0), (3, 3)] {
        set(&mut grid, reel, row, BONUS);
    }
    let outcome = evaluate(vault, &grid, BET, false).unwrap();
    assert_eq!(outcome.scatter_count, 4);
    assert_eq!(outcome.free_spins, 12);
    assert_eq!(outcome.scatter_win, BET * 20);
}

#[test]
fn free_spins_double_the_line_win() {
    let vault = core().unwrap();
    let grid = board(QUEEN);
    let base = evaluate(vault, &grid, BET, false).unwrap();
    let free = evaluate(vault, &grid, BET, true).unwrap();
    assert_eq!(free.total_win, base.total_win * 2);
}

#[test]
fn a_full_solar_board_reaches_the_top_tier() {
    let vault = core().unwrap();
    let outcome = evaluate(vault, &board(SOLAR), BET, false).unwrap();
    assert_eq!(outcome.tier, 2);
    assert!(outcome.total_win > BET * 30);
}

#[test]
fn a_chest_line_pays_from_the_table() {
    let vault = core().unwrap();
    let mut grid = vec![TEN; 16];
    for reel in 0..4 {
        set(&mut grid, reel, 1, CHEST);
    }
    // Break neighbouring lines so only line 2 pays chest.
    set(&mut grid, 0, 0, JACK);
    set(&mut grid, 0, 2, QUEEN);
    let outcome = evaluate(vault, &grid, BET, false).unwrap();
    let hit = outcome
        .hits
        .iter()
        .find(|h| h.symbol == CHEST && h.count == 4)
        .expect("chest x4");
    assert_eq!(hit.amount, 300 * (BET / 20));
    assert_eq!(
        line_pay(vault, CHEST as usize, 4, BET / 20),
        300 * (BET / 20)
    );
}

#[test]
fn invalid_input_is_rejected() {
    let vault = core().unwrap();
    assert!(evaluate(vault, &[0u8; 15], BET, false).is_none());
    assert!(evaluate(vault, &[99u8; 16], BET, false).is_none());
    assert!(evaluate(vault, &board(TEN), -1, false).is_none());
}

#[test]
fn spins_stay_inside_the_symbol_range() {
    let vault = core().unwrap();
    let mut out = [0u8; 16];
    for _ in 0..2000 {
        assert!(spin(vault, &mut out));
        assert!(out.iter().all(|s| (*s as usize) < vault.symbols));
    }
}

#[test]
fn the_c_interface_matches_the_engine() {
    let mut grid = [0u8; 16];
    assert_eq!(unsafe { sg_g1(grid.as_mut_ptr(), 16) }, 16);
    assert_eq!(unsafe { sg_g1(grid.as_mut_ptr(), 8) }, 0);

    let solar = board(SOLAR);
    let mut out = [0i64; 128];
    let n = unsafe { sg_e2(solar.as_ptr(), 16, BET, 0, out.as_mut_ptr(), 128) };
    assert_eq!(n, 7 + 20 * 4);
    assert_eq!(out[6], 20);
    assert_eq!(out[4], 2);
    assert_eq!(out[5], 0xFFFF);
    assert_eq!(sg_p3(SOLAR as i32, 3, 10), 2100);
    assert_eq!(sg_p3(BONUS as i32, 3, 10), 0);
    assert_eq!(sg_c4(0), 20);
    assert_eq!(sg_c4(3), 8);
    assert_eq!(sg_c4(4), 12);
    assert_eq!(sg_c4(5), 2);
    assert_eq!(sg_c4(99), 0);
}

/// The port must keep the tuned economy: about 93% return and 38% hit rate.
#[test]
fn simulated_return_matches_the_tuned_economy() {
    let vault = core().unwrap();
    let spins = 600_000u64;
    let mut staked = 0i64;
    let mut won = 0i64;
    let mut hits = 0u64;
    let mut free_left = 0u32;
    let mut grid = [0u8; 16];
    for _ in 0..spins {
        let free = free_left > 0;
        if free {
            free_left -= 1;
        } else {
            staked += BET;
        }
        spin(vault, &mut grid);
        let outcome = evaluate(vault, &grid, BET, free).unwrap();
        won += outcome.total_win;
        free_left += outcome.free_spins;
        if !free && outcome.total_win > 0 {
            hits += 1;
        }
    }
    let rtp = won as f64 / staked as f64;
    let base_spins = (staked / BET) as f64;
    let hit_rate = hits as f64 / base_spins;
    println!("rtp {rtp:.4} hit {hit_rate:.4}");
    assert!((0.85..=1.01).contains(&rtp), "rtp {rtp}");
    assert!((0.30..=0.46).contains(&hit_rate), "hit {hit_rate}");
}
