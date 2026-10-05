//! Reel generation and win evaluation, driven entirely by the vault tables.

use crate::vault::{Misc, Vault};

pub struct LineHit {
    pub line: u32,
    pub symbol: u8,
    pub count: u32,
    pub amount: i64,
}

pub struct Outcome {
    pub total_win: i64,
    pub scatter_win: i64,
    pub scatter_count: u32,
    pub free_spins: u32,
    pub tier: u32,
    pub cells: u32,
    pub hits: Vec<LineHit>,
}

/// Fills `out` (reel-major, `reels * rows` bytes) with Dart-side symbol ids.
pub fn spin(vault: &Vault, out: &mut [u8]) -> bool {
    let cells = vault.reels * vault.rows;
    if out.len() < cells {
        return false;
    }
    for slot in out.iter_mut().take(cells) {
        let internal = vault.draw_internal();
        *slot = vault.to_dart[internal];
    }
    true
}

fn resolve(vault: &Vault, grid: &[u8], line: usize, wild: u8, bonus: u8) -> Option<(u8, u32)> {
    let mut target: Option<u8> = None;
    let mut count = 0u32;
    for reel in 0..vault.reels {
        let row = vault.line_row(line, reel);
        let symbol = grid[reel * vault.rows + row];
        if symbol == bonus {
            break;
        }
        if symbol == wild {
            count += 1;
            continue;
        }
        match target {
            None => {
                target = Some(symbol);
                count += 1;
            }
            Some(t) if t == symbol => count += 1,
            Some(_) => break,
        }
    }
    if count < 3 {
        return None;
    }
    Some((target.unwrap_or(wild), count))
}

/// `grid` holds Dart-side symbol ids, reel-major.
pub fn evaluate(vault: &Vault, grid: &[u8], total_bet: i64, free_spin: bool) -> Option<Outcome> {
    let cells_len = vault.reels * vault.rows;
    if grid.len() != cells_len || total_bet < 0 {
        return None;
    }
    let mut internal = [0u8; 32];
    for (i, dart) in grid.iter().enumerate() {
        if *dart as usize >= vault.symbols {
            return None;
        }
        internal[i] = vault.to_internal[*dart as usize];
    }
    let grid = &internal[..cells_len];
    let wild = vault.to_internal_misc(Misc::Wild);
    let bonus = vault.to_internal_misc(Misc::Bonus);

    let line_bet = total_bet / vault.line_count as i64;
    let multiplier = if free_spin {
        vault.misc(Misc::FreeSpinMultiplier) as i64
    } else {
        1
    };

    let mut hits = Vec::new();
    let mut cells = 0u32;
    let mut line_total = 0i64;
    for line in 0..vault.line_count {
        let Some((symbol, count)) = resolve(vault, grid, line, wild, bonus) else {
            continue;
        };
        let pay = vault.pay(symbol as usize, count as usize) as i64;
        let amount = pay.saturating_mul(line_bet).saturating_mul(multiplier);
        line_total = line_total.saturating_add(amount);
        hits.push(LineHit {
            line: line as u32 + 1,
            symbol: vault.to_dart[symbol as usize],
            count,
            amount,
        });
        for reel in 0..count as usize {
            let row = vault.line_row(line, reel);
            cells |= 1 << (reel * vault.rows + row);
        }
    }

    let mut scatter_count = 0u32;
    let mut scatter_cells = 0u32;
    for (i, symbol) in grid.iter().enumerate() {
        if *symbol == bonus {
            scatter_count += 1;
            scatter_cells |= 1 << i;
        }
    }
    let mut scatter_win = 0i64;
    let mut free_spins = 0u32;
    if scatter_count >= 3 {
        let top = scatter_count >= 4;
        let factor = vault.misc(if top { Misc::Scatter4 } else { Misc::Scatter3 });
        scatter_win = total_bet.saturating_mul(factor as i64);
        free_spins = vault.misc(if top {
            Misc::FreeSpins4
        } else {
            Misc::FreeSpins3
        });
        cells |= scatter_cells;
    }

    let total_win = line_total.saturating_add(scatter_win);
    let solar = total_bet.saturating_mul(vault.misc(Misc::TierSolar) as i64);
    let big = total_bet.saturating_mul(vault.misc(Misc::TierBig) as i64);
    let tier = if total_win >= solar && total_win > 0 {
        2
    } else if total_win >= big && total_win > 0 {
        1
    } else {
        0
    };

    Some(Outcome {
        total_win,
        scatter_win,
        scatter_count,
        free_spins,
        tier,
        cells,
        hits,
    })
}

/// Pay for `count` of a kind on one line, for a given per-line bet.
pub fn line_pay(vault: &Vault, dart_symbol: usize, count: usize, line_bet: i64) -> i64 {
    if dart_symbol >= vault.symbols {
        return 0;
    }
    let internal = vault.to_internal[dart_symbol] as usize;
    (vault.pay(internal, count) as i64).saturating_mul(line_bet)
}
