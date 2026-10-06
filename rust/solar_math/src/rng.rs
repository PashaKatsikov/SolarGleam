//! Uniform random numbers. Apple platforms use the system CSPRNG.

#[cfg(target_vendor = "apple")]
mod sys {
    extern "C" {
        fn arc4random_uniform(upper: u32) -> u32;
        fn arc4random() -> u32;
    }

    pub fn below(n: u32) -> u32 {
        if n == 0 {
            return 0;
        }
        // SAFETY: both calls take plain integers and have no preconditions.
        unsafe { arc4random_uniform(n) }
    }

    pub fn word() -> u32 {
        // SAFETY: no preconditions.
        unsafe { arc4random() }
    }
}

#[cfg(not(target_vendor = "apple"))]
mod sys {
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::time::{SystemTime, UNIX_EPOCH};

    static STATE: AtomicU64 = AtomicU64::new(0);

    fn seed() -> u64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_nanos() as u64)
            .unwrap_or(0x1234_5678_9ABC_DEF1)
            | 1
    }

    fn next() -> u64 {
        let mut expected = STATE.load(Ordering::Relaxed);
        loop {
            // A zero state means "not seeded yet"; xorshift would stay at zero forever.
            let mut x = if expected == 0 { seed() } else { expected };
            x ^= x << 13;
            x ^= x >> 7;
            x ^= x << 17;
            match STATE.compare_exchange(expected, x, Ordering::Relaxed, Ordering::Relaxed) {
                Ok(_) => return x.wrapping_mul(0x2545_F491_4F6C_DD1D),
                Err(seen) => expected = seen,
            }
        }
    }

    pub fn below(n: u32) -> u32 {
        if n == 0 {
            return 0;
        }
        let zone = u64::MAX - (u64::MAX % n as u64);
        loop {
            let v = next();
            if v < zone {
                return (v % n as u64) as u32;
            }
        }
    }

    pub fn word() -> u32 {
        (next() >> 32) as u32
    }
}

pub use sys::{below, word};
