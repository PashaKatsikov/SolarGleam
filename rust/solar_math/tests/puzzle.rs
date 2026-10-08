use solar_math::engine::{
    energy_for, shape, unlock_cost, Puzzle, EV_GHOST, EV_GLYPH, EV_REAL, TAP_LOST, TAP_RIGHT,
    TAP_WON, TAP_WRONG,
};
use solar_math::tables as t;
use solar_math::{core, sg_c4, sg_f5, sg_h3, sg_k0, sg_n1, sg_t2, sg_u7};

static GLOBAL: std::sync::Mutex<()> = std::sync::Mutex::new(());

fn vault() -> &'static solar_math::vault::Vault {
    core().expect("tables must open")
}

#[test]
fn tables_open() {
    assert_eq!(sg_k0(), 1);
}

#[test]
fn every_level_builds_a_valid_puzzle() {
    let v = vault();
    for region in 0..t::REGIONS {
        for level in 0..t::LEVELS {
            let (count, len, modes) = shape(v, region, level).unwrap();
            let global = (region * t::LEVELS + level) as u32;
            for _ in 0..200 {
                let p = Puzzle::generate(v, region, level).unwrap();
                assert_eq!(p.orbs.len(), count, "orb count r{region} l{level}");
                assert!((3..=12).contains(&count));
                assert_eq!(p.expected_len(), len);

                // distinct orbs, all already discovered by this point
                let mut kinds: Vec<u8> = p.orbs.iter().map(|o| o.kind).collect();
                kinds.sort_unstable();
                kinds.dedup();
                assert_eq!(kinds.len(), count);
                for orb in &p.orbs {
                    assert!(v.orb_unlock(orb.kind as usize) <= global);
                    assert!((orb.slot as usize) < count);
                }
                // the orb introduced on this level is always on the board
                for internal in 0..t::ORBS {
                    if v.orb_unlock(internal) == global && global > 0 {
                        assert!(p.orbs.iter().any(|o| o.kind as usize == internal));
                    }
                }
                // slots form a permutation
                let mut slots: Vec<u8> = p.orbs.iter().map(|o| o.slot).collect();
                slots.sort_unstable();
                assert_eq!(slots, (0..count as u8).collect::<Vec<_>>());

                let glyph = modes & t::MODE_GLYPH != 0;
                let ghost = modes & t::MODE_GHOST != 0 && !glyph;
                let mirror = modes & t::MODE_MIRROR != 0 && !glyph;
                let shift = modes & t::MODE_SHIFT != 0;

                if glyph {
                    assert!(count <= t::GLYPHS);
                    let mut g: Vec<u8> = p.orbs.iter().map(|o| o.glyph).collect();
                    g.sort_unstable();
                    g.dedup();
                    assert_eq!(g.len(), count, "glyphs must be unique");
                    assert!(p.events.iter().all(|e| e.kind == EV_GLYPH));
                    assert_eq!(p.modes & (t::MODE_GHOST | t::MODE_MIRROR), 0);
                    // every token points at exactly one orb
                    for (e, want) in p.events.iter().zip(&p.expected) {
                        assert_eq!(p.orbs[*want as usize].glyph, e.a);
                    }
                } else {
                    let real: Vec<u8> = p
                        .events
                        .iter()
                        .filter(|e| e.kind == EV_REAL)
                        .map(|e| e.a)
                        .collect();
                    assert_eq!(real.len(), len);
                    assert!(real.iter().all(|a| (*a as usize) < count));
                    let want: Vec<u8> = if mirror {
                        real.iter().rev().copied().collect()
                    } else {
                        real.clone()
                    };
                    assert_eq!(p.expected, want);
                    let ghosts = p.events.iter().filter(|e| e.kind == EV_GHOST).count();
                    assert_eq!(ghosts > 0, ghost, "ghost flag r{region} l{level}");
                    assert!(p.events[0].kind == EV_REAL, "first event is never a ghost");
                }
                // no step repeats back to back
                for pair in p.expected.windows(2) {
                    if !mirror && !glyph {
                        assert_ne!(pair[0], pair[1]);
                    }
                }

                // shift moves every orb
                assert_eq!(p.shift_to.len(), count);
                let mut dest = p.shift_to.clone();
                dest.sort_unstable();
                assert_eq!(dest, (0..count as u8).collect::<Vec<_>>());
                for (orb, to) in p.orbs.iter().zip(&p.shift_to) {
                    assert_eq!(orb.slot != *to, shift, "shift moves orbs only when asked");
                }
            }
        }
    }
}

#[test]
fn difficulty_grows_without_jumps() {
    let v = vault();
    // Within a region neither the board nor the sequence ever shrinks, except
    // on glyph levels where the board is capped at four orbs.
    for region in 0..t::REGIONS {
        let mut last_len = 0;
        for level in 0..t::LEVELS {
            let (orbs, len, modes) = shape(v, region, level).unwrap();
            assert!(len >= last_len, "sequence shrank at r{region} l{level}");
            last_len = len;
            if region == 0 {
                assert!(orbs <= 4 && len <= 5, "early levels stay gentle");
            }
            if modes & t::MODE_GLYPH != 0 {
                assert!(orbs <= t::GLYPHS);
            }
        }
    }
    assert_eq!(shape(v, 5, 7).unwrap().0, 12);
}

#[test]
fn solving_wins_and_pays() {
    let v = vault();
    let mut p = Puzzle::generate(v, 1, 3).unwrap();
    let sequence = p.expected.clone();
    for (i, orb) in sequence.iter().enumerate() {
        let tap = p.tap(*orb);
        if i + 1 == sequence.len() {
            assert_eq!(tap.code, TAP_WON);
        } else {
            assert_eq!(tap.code, TAP_RIGHT);
            assert_eq!(tap.pos, i + 1);
        }
    }
    let reward = p.reward(v, 1000, false).unwrap();
    assert_eq!(reward.stars, 3);
    assert!(reward.first_try && reward.fast);
    assert_eq!(reward.energy, energy_for(v, 1, 3, 3, true, false));
    assert_eq!(reward.decor, 1); // level 4 hands out the second decor piece
    assert!(!reward.region_done);
    // taps after the win do nothing
    assert_eq!(p.tap(0).code, 0);
}

#[test]
fn final_level_closes_the_region() {
    let v = vault();
    let mut p = Puzzle::generate(v, 2, 7).unwrap();
    for orb in p.expected.clone() {
        p.tap(orb);
    }
    let reward = p.reward(v, 999_999, false).unwrap();
    assert!(reward.region_done && !reward.fast);
    assert_eq!(reward.decor, 3);
    let repeat = p.reward(v, 999_999, true).unwrap();
    assert!(!repeat.region_done && repeat.decor == -1);
    assert!(repeat.energy < reward.energy);
}

fn wrong_orb(p: &Puzzle) -> u8 {
    let want = p.next_expected().unwrap();
    ((want as usize + 1) % p.orbs.len()) as u8
}

#[test]
fn mistakes_burn_attempts_and_reset_progress() {
    let v = vault();
    let mut p = Puzzle::generate(v, 0, 4).unwrap();
    let first = p.expected[0];
    assert_eq!(p.tap(first).code, TAP_RIGHT);
    let bad = wrong_orb(&p);
    let tap = p.tap(bad);
    assert_eq!(tap.code, TAP_WRONG);
    assert_eq!(tap.pos, 0, "a mistake restarts the entry");
    assert_eq!(tap.attempts_left, p.attempts - 1);
    for _ in 1..p.attempts {
        let bad = wrong_orb(&p);
        let tap = p.tap(bad);
        if tap.attempts_left == 0 {
            assert_eq!(tap.code, TAP_LOST);
        }
    }
    assert!(p.next_expected().is_none());
    assert!(p.reward(v, 0, false).is_none(), "no reward for a lost puzzle");
}

#[test]
fn aids_are_limited_and_cost_stars() {
    let v = vault();
    let mut p = Puzzle::generate(v, 3, 0).unwrap();
    let mut hints = 0;
    while p.hint().is_some() {
        hints += 1;
    }
    assert_eq!(hints, p.hints);
    let mut replays = 0;
    while p.replay() {
        replays += 1;
    }
    assert_eq!(replays, p.replays);
    for orb in p.expected.clone() {
        p.tap(orb);
    }
    let reward = p.reward(v, 0, false).unwrap();
    assert_eq!(reward.aids, hints + replays);
    assert_eq!(reward.stars, 1);
    assert!(!reward.first_try || reward.mistakes == 0);
}

#[test]
fn one_mistake_still_earns_two_stars() {
    let v = vault();
    let mut p = Puzzle::generate(v, 0, 0).unwrap();
    let bad = wrong_orb(&p);
    p.tap(bad);
    for orb in p.expected.clone() {
        p.tap(orb);
    }
    let reward = p.reward(v, 0, false).unwrap();
    assert_eq!(reward.stars, 2);
    assert!(!reward.first_try);
}

/// Playing every level once at one star, with no speed bonus, must always
/// pay for the next region (and leave a margin).
#[test]
fn economy_is_reachable_and_not_free() {
    let v = vault();
    let mut energy: i64 = 0;
    for region in 0..t::REGIONS {
        let cost = unlock_cost(v, region, t::LEVELS as u32, i32::MAX as u32);
        assert!(cost >= 0);
        if region > 0 {
            assert!(
                energy >= cost as i64,
                "region {region}: have {energy}, need {cost}"
            );
            assert!(
                energy < cost as i64 * 3,
                "region {region}: the cost must matter ({energy} vs {cost})"
            );
            energy -= cost as i64;
        }
        for level in 0..t::LEVELS {
            energy += energy_for(v, region, level, 1, false, false) as i64;
        }
    }
    // three stars earn more than one
    assert!(energy_for(v, 3, 2, 3, true, false) > energy_for(v, 3, 2, 1, false, false));
}

#[test]
fn unlock_rules() {
    let v = vault();
    assert_eq!(unlock_cost(v, 0, 0, 0), 0);
    assert_eq!(unlock_cost(v, 1, 7, 10_000), -1, "previous region unfinished");
    assert_eq!(unlock_cost(v, 1, 8, 10), -2, "not enough energy");
    assert_eq!(unlock_cost(v, 1, 8, 180), 180);
    assert_eq!(unlock_cost(v, 9, 8, 180), -1);
}

#[test]
fn orbs_are_discovered_in_order() {
    // The first levels use three starter orbs, the finale all twelve.
    let v = vault();
    let mut seen = [false; t::ORBS];
    for region in 0..t::REGIONS {
        for level in 0..t::LEVELS {
            let global = (region * t::LEVELS + level) as u32;
            let known = (0..t::ORBS).filter(|i| v.orb_unlock(*i) <= global).count();
            let (count, _, _) = shape(v, region, level).unwrap();
            assert!(known >= count, "pool too small at r{region} l{level}");
            for i in 0..t::ORBS {
                if v.orb_unlock(i) <= global {
                    seen[i] = true;
                }
            }
        }
    }
    assert!(seen.iter().all(|s| *s));
    assert_eq!(
        (0..t::ORBS).filter(|i| v.orb_unlock(*i) == 0).count(),
        3,
        "three starter orbs"
    );
}

#[test]
fn c_interface_round_trip() {
    let _lock = GLOBAL.lock().unwrap_or_else(|p| p.into_inner());
    unsafe {
        let mut buf = [0i32; 256];
        let n = sg_n1(1, 2, buf.as_mut_ptr(), 256);
        assert!(n > 10);
        let orbs = buf[0] as usize;
        let events = buf[8] as usize;
        assert_eq!(n as usize, 10 + orbs * 3 + events * 2 + orbs);
        assert!(buf[5] > 400 && buf[6] > 100);

        // too small a buffer is refused
        assert_eq!(sg_n1(1, 2, buf.as_mut_ptr(), 4), 0);
        // out-of-range levels are refused
        assert_eq!(sg_n1(9, 0, buf.as_mut_ptr(), 256), 0);
        assert_eq!(sg_n1(0, 8, buf.as_mut_ptr(), 256), 0);

        // start again and answer from the preview we were given
        let n = sg_n1(0, 0, buf.as_mut_ptr(), 256);
        assert!(n > 0);
        let orbs = buf[0] as usize;
        let events = buf[8] as usize;
        let len = buf[7] as usize;
        let seq: Vec<i32> = (0..events)
            .map(|i| buf[10 + orbs * 3 + i * 2 + 1])
            .collect();
        assert_eq!(seq.len(), len);
        for (i, orb) in seq.iter().enumerate() {
            let packed = sg_t2(*orb);
            let code = packed & 0xFF;
            if i + 1 == len {
                assert_eq!(code, TAP_WON as i32);
            } else {
                assert_eq!(code, TAP_RIGHT as i32);
                assert_eq!((packed >> 8) & 0xFF, i as i32 + 1);
            }
        }
        let mut reward = [0i32; 8];
        assert_eq!(sg_f5(500, 0, reward.as_mut_ptr(), 8), 8);
        assert_eq!(reward[0], 3);
        assert!(reward[1] > 0);
        assert_eq!(reward[4], -1);

        assert_eq!(sg_h3(0), 0, "no replays once solved");
    }
    assert_eq!(sg_c4(0, 0), 6);
    assert_eq!(sg_c4(1, 0), 8);
    assert_eq!(sg_c4(3, 1), 180);
    assert_eq!(sg_c4(6, 0), 3);
    assert_eq!(sg_c4(4, 0), 0);
    assert_eq!(sg_c4(4, 6), 16, "crimson joins with the aurora temple");
    assert_eq!(sg_u7(1, 8, 500), 180);
}

#[cfg(feature = "probe")]
#[test]
fn probe_follows_the_expected_sequence() {
    use solar_math::sg_d9;
    let _lock = GLOBAL.lock().unwrap_or_else(|p| p.into_inner());
    unsafe {
        let mut buf = [0i32; 256];
        assert!(sg_n1(2, 1, buf.as_mut_ptr(), 256) > 0);
        let len = buf[7];
        for i in 0..len {
            let next = sg_d9();
            assert!(next >= 0);
            let packed = sg_t2(next);
            assert_eq!(packed & 0xFF, if i + 1 == len { 4 } else { 1 });
        }
        assert_eq!(sg_d9(), -1);
    }
}
