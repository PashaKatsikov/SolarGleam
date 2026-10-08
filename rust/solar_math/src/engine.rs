//! Puzzle generation, sequence checking and rewards.
//!
//! A puzzle is a ring of orbs plus a hidden sequence of taps. The sequence
//! lives here; the app only sees the preview events (what to draw) and sends
//! taps back, one orb at a time.

use crate::rng;
use crate::tables as t;
use crate::vault::{lerp, Vault};

pub const EV_REAL: u8 = 0;
pub const EV_GHOST: u8 = 1;
pub const EV_GLYPH: u8 = 2;

/// Result codes of a tap.
pub const TAP_NONE: u8 = 0;
pub const TAP_RIGHT: u8 = 1;
pub const TAP_WRONG: u8 = 2;
pub const TAP_LOST: u8 = 3;
pub const TAP_WON: u8 = 4;

#[derive(Clone, Copy, Debug)]
pub struct Orb {
    /// Internal orb code.
    pub kind: u8,
    /// Internal glyph code.
    pub glyph: u8,
    /// Starting slot on the board.
    pub slot: u8,
}

#[derive(Clone, Copy, Debug)]
pub struct Event {
    pub kind: u8,
    /// Orb index for real / ghost flashes, internal glyph for glyph tokens.
    pub a: u8,
}

#[derive(Debug)]
pub struct Puzzle {
    pub region: usize,
    pub level: usize,
    pub modes: u32,
    pub orbs: Vec<Orb>,
    pub events: Vec<Event>,
    /// Orb indices in the order the player has to tap them.
    pub expected: Vec<u8>,
    /// New slot of every orb after the shift. Identity without shift.
    pub shift_to: Vec<u8>,
    pub flash_ms: u32,
    pub gap_ms: u32,
    pub attempts: u32,
    pub hints: u32,
    pub replays: u32,
    pos: usize,
    attempts_left: u32,
    hints_left: u32,
    replays_left: u32,
    state: u8,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Tap {
    pub code: u8,
    pub pos: usize,
    pub attempts_left: u32,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Reward {
    pub stars: u32,
    pub energy: u32,
    pub fast: bool,
    pub first_try: bool,
    pub decor: i32,
    pub region_done: bool,
    pub mistakes: u32,
    pub aids: u32,
}

fn shuffle<T>(items: &mut [T]) {
    for i in (1..items.len()).rev() {
        let j = rng::below(i as u32 + 1) as usize;
        items.swap(i, j);
    }
}

/// Number of orbs, sequence length, and mode bits of a level.
pub fn shape(vault: &Vault, region: usize, level: usize) -> Option<(usize, usize, u32)> {
    if region >= t::REGIONS || level >= t::LEVELS {
        return None;
    }
    let modes = vault.modes(region, level);
    let mut orbs = lerp(
        vault.region(t::T_ORBS_FROM, region),
        vault.region(t::T_ORBS_TO, region),
        level,
    ) as usize;
    if modes & t::MODE_GLYPH != 0 {
        orbs = orbs.min(t::GLYPHS);
    }
    let len = lerp(
        vault.region(t::T_LEN_FROM, region),
        vault.region(t::T_LEN_TO, region),
        level,
    ) as usize;
    Some((orbs.max(3), len.max(2), modes))
}

/// Orbs (internal codes) that can appear on a level, and the ones that must.
fn pool(vault: &Vault, global: u32) -> (Vec<u8>, Vec<u8>) {
    let mut all = Vec::new();
    let mut forced = Vec::new();
    for internal in 0..t::ORBS {
        let at = vault.orb_unlock(internal);
        if at <= global {
            all.push(internal as u8);
            if at == global && global > 0 {
                forced.push(internal as u8);
            }
        }
    }
    (all, forced)
}

impl Puzzle {
    pub fn generate(vault: &Vault, region: usize, level: usize) -> Option<Puzzle> {
        let (count, len, mut modes) = shape(vault, region, level)?;
        let glyph_mode = modes & t::MODE_GLYPH != 0;
        let mirror = modes & t::MODE_MIRROR != 0;
        // A glyph level reads glyphs off the core, so colour tricks stay off.
        if glyph_mode {
            modes &= !(t::MODE_GHOST | t::MODE_MIRROR);
        }
        let ghost = modes & t::MODE_GHOST != 0;
        let shift = modes & t::MODE_SHIFT != 0;
        let mirror = mirror && !glyph_mode;

        let global = (region * t::LEVELS + level) as u32;
        let (all, forced) = pool(vault, global);
        if all.len() < count {
            return None;
        }

        // Pick the orbs: forced newcomers first, then random from the pool.
        let mut chosen: Vec<u8> = forced.iter().copied().take(count).collect();
        let mut rest: Vec<u8> = all.iter().copied().filter(|o| !chosen.contains(o)).collect();
        shuffle(&mut rest);
        chosen.extend(rest.into_iter().take(count - chosen.len()));
        shuffle(&mut chosen);

        let mut glyphs: Vec<u8> = (0..t::GLYPHS as u8).collect();
        shuffle(&mut glyphs);
        let mut slots: Vec<u8> = (0..count as u8).collect();
        shuffle(&mut slots);

        let orbs: Vec<Orb> = (0..count)
            .map(|i| Orb {
                kind: chosen[i],
                glyph: glyphs[i % t::GLYPHS],
                slot: slots[i],
            })
            .collect();

        // The hidden sequence, never repeating the same step twice in a row.
        let mut steps: Vec<u8> = Vec::with_capacity(len);
        for _ in 0..len {
            loop {
                let pick = rng::below(count as u32) as u8;
                if steps.last() != Some(&pick) {
                    steps.push(pick);
                    break;
                }
            }
        }

        let mut events: Vec<Event> = Vec::with_capacity(len + 6);
        let mut expected: Vec<u8> = Vec::with_capacity(len);
        if glyph_mode {
            for step in &steps {
                events.push(Event {
                    kind: EV_GLYPH,
                    a: orbs[*step as usize].glyph,
                });
                expected.push(*step);
            }
        } else {
            for step in &steps {
                events.push(Event { kind: EV_REAL, a: *step });
            }
            expected = steps.clone();
            if mirror {
                expected.reverse();
            }
        }

        if ghost {
            let extra = vault.misc(t::MISC_GHOST_BASE) as usize
                + len / vault.misc(t::MISC_GHOST_DIV).max(1) as usize;
            for _ in 0..extra {
                let at = 1 + rng::below(events.len() as u32) as usize;
                let orb = rng::below(count as u32) as u8;
                events.insert(at.min(events.len()), Event { kind: EV_GHOST, a: orb });
            }
        }

        let mut shift_to: Vec<u8> = orbs.iter().map(|o| o.slot).collect();
        if shift {
            // Sattolo's algorithm: one cycle, so every orb really moves.
            let mut perm: Vec<u8> = orbs.iter().map(|o| o.slot).collect();
            for i in (1..perm.len()).rev() {
                let j = rng::below(i as u32) as usize;
                perm.swap(i, j);
            }
            shift_to = perm;
        }

        let attempts = vault.region(t::T_ATTEMPTS, region);
        let hints = vault.region(t::T_HINTS, region);
        let replays = vault.region(t::T_REPLAYS, region);
        let flash_ms = lerp(
            vault.region(t::T_FLASH_FROM, region),
            vault.region(t::T_FLASH_TO, region),
            level,
        );
        let gap_ms = vault.region(t::T_GAP, region);

        Some(Puzzle {
            region,
            level,
            modes,
            orbs,
            events,
            expected,
            shift_to,
            flash_ms,
            gap_ms,
            attempts,
            hints,
            replays,
            pos: 0,
            attempts_left: attempts,
            hints_left: hints,
            replays_left: replays,
            state: 0,
        })
    }

    pub fn expected_len(&self) -> usize {
        self.expected.len()
    }

    /// The orb the player has to tap next, if the puzzle is still running.
    pub fn next_expected(&self) -> Option<u8> {
        if self.state == 0 {
            self.expected.get(self.pos).copied()
        } else {
            None
        }
    }

    pub fn tap(&mut self, orb: u8) -> Tap {
        if self.state != 0 || orb as usize >= self.orbs.len() {
            return self.report(TAP_NONE);
        }
        if self.expected[self.pos] == orb {
            self.pos += 1;
            if self.pos == self.expected.len() {
                self.state = 1;
                return self.report(TAP_WON);
            }
            return self.report(TAP_RIGHT);
        }
        self.attempts_left = self.attempts_left.saturating_sub(1);
        self.pos = 0;
        if self.attempts_left == 0 {
            self.state = 2;
            return self.report(TAP_LOST);
        }
        self.report(TAP_WRONG)
    }

    fn report(&self, code: u8) -> Tap {
        Tap {
            code,
            pos: self.pos,
            attempts_left: self.attempts_left,
        }
    }

    /// Watch the preview again. Restarts the input.
    pub fn replay(&mut self) -> bool {
        if self.state != 0 || self.replays_left == 0 {
            return false;
        }
        self.replays_left -= 1;
        self.pos = 0;
        true
    }

    /// Reveals the next orb to tap.
    pub fn hint(&mut self) -> Option<u8> {
        if self.state != 0 || self.hints_left == 0 {
            return None;
        }
        let next = self.expected.get(self.pos).copied()?;
        self.hints_left -= 1;
        Some(next)
    }

    pub fn replays_left(&self) -> u32 {
        self.replays_left
    }

    pub fn hints_left(&self) -> u32 {
        self.hints_left
    }

    pub fn won(&self) -> bool {
        self.state == 1
    }

    /// Rewards for a solved puzzle. `elapsed_ms` is the time spent entering
    /// the answer; `repeat` marks a level that was already cleared once.
    pub fn reward(&self, vault: &Vault, elapsed_ms: u32, repeat: bool) -> Option<Reward> {
        if !self.won() {
            return None;
        }
        let mistakes = self.attempts - self.attempts_left;
        let aids = (self.hints - self.hints_left) + (self.replays - self.replays_left);
        let score = mistakes * 2 + aids;
        let stars = if score == 0 {
            3
        } else if score <= vault.misc(t::MISC_TWO_STAR_SCORE) {
            2
        } else {
            1
        };

        let par = self.expected.len() as u32 * vault.region(t::T_PAR, self.region)
            + vault.misc(t::MISC_PAR_BASE);
        let fast = elapsed_ms <= par;
        let energy = energy_for(vault, self.region, self.level, stars, fast, repeat);

        let decor = if !repeat && (vault.misc(t::MISC_DECOR_MASK) >> self.level) & 1 == 1 {
            (self.level / 2) as i32
        } else {
            -1
        };
        Some(Reward {
            stars,
            energy,
            fast,
            first_try: mistakes == 0,
            decor,
            region_done: !repeat && self.level == t::LEVELS - 1,
            mistakes,
            aids,
        })
    }
}

/// Energy paid for clearing a level.
pub fn energy_for(
    vault: &Vault,
    region: usize,
    level: usize,
    stars: u32,
    fast: bool,
    repeat: bool,
) -> u32 {
    let base = vault.region(t::T_ENERGY_BASE, region) + vault.region(t::T_ENERGY_STEP, region) * level as u32;
    let mult = if level == t::LEVELS - 1 {
        vault.misc(t::MISC_FINAL_MULT)
    } else {
        1
    };
    let core = base * mult;
    let mut energy = core * vault.star_pct(stars as usize) / 100;
    if fast {
        energy += core * vault.misc(t::MISC_FAST_PCT) / 100;
    }
    if repeat {
        energy = energy * vault.misc(t::MISC_REPEAT_PCT) / 100;
    }
    energy
}

/// What it takes to open a region: the cost when payable, -1 while the
/// previous region is unfinished, -2 when energy is short.
pub fn unlock_cost(vault: &Vault, region: usize, prev_done: u32, energy: u32) -> i32 {
    if region >= t::REGIONS {
        return -1;
    }
    let cost = vault.region(t::T_COST, region);
    if region == 0 {
        return 0;
    }
    if prev_done < t::LEVELS as u32 {
        return -1;
    }
    if energy < cost {
        return -2;
    }
    cost as i32
}
