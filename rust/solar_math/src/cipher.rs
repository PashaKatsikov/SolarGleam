//! Stream cipher and keyed tag shared by the library and the sealing tool.
//! The master key is never stored as one constant. It is rebuilt at run time
//! from scattered fragments, then mixed with a per-seal nonce.

use core::hint::black_box;

#[inline(never)]
pub fn master() -> [u64; 4] {
    let p = black_box([
        0x9E37_79B9_7F4A_7C15u64,
        0xC2B2_AE3D_27D4_EB4F,
        0x1656_67B1_9E37_79F9,
        0x27D4_EB2F_1656_67C5,
    ]);
    let q = black_box([
        0x5851_F42D_4C95_7F2Du64,
        0x1405_7B7E_F767_814F,
        0xD6E8_FEB8_6659_FD93,
        0xA076_1D64_78BD_642F,
    ]);
    let r = black_box(0x1B87_3593u32);
    let mut out = [0u64; 4];
    let mut i = 0usize;
    while i < 4 {
        let shift = 13 + 11 * i as u32;
        let mixed = p[i] ^ q[(i + 1) & 3].rotate_left(shift);
        out[i] = mixed
            .wrapping_mul(0x2545_F491_4F6C_DD1D)
            .rotate_right((r >> (i as u32 * 3)) & 31)
            ^ q[i].rotate_left(7);
        i += 1;
    }
    out
}

pub fn splitmix(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9E37_79B9_7F4A_7C15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

pub struct Stream {
    s: [u64; 4],
}

impl Stream {
    pub fn new(key: &[u64; 4], nonce: &[u8; 16]) -> Self {
        let mut a = [0u8; 8];
        let mut b = [0u8; 8];
        a.copy_from_slice(&nonce[0..8]);
        b.copy_from_slice(&nonce[8..16]);
        let n0 = u64::from_le_bytes(a);
        let n1 = u64::from_le_bytes(b);
        let mut seed = key[0] ^ n0;
        let mut s = [0u64; 4];
        s[0] = splitmix(&mut seed) ^ key[1];
        s[1] = splitmix(&mut seed) ^ key[2] ^ n1;
        s[2] = splitmix(&mut seed) ^ key[3];
        s[3] = splitmix(&mut seed) ^ n0.rotate_left(21);
        if s == [0; 4] {
            s[0] = 1;
        }
        Stream { s }
    }

    pub fn next(&mut self) -> u64 {
        let s = &mut self.s;
        let result = s[0].wrapping_add(s[3]).rotate_left(23).wrapping_add(s[0]);
        let t = s[1] << 17;
        s[2] ^= s[0];
        s[3] ^= s[1];
        s[1] ^= s[2];
        s[0] ^= s[3];
        s[2] ^= t;
        s[3] = s[3].rotate_left(45);
        result
    }

    pub fn apply(&mut self, data: &mut [u8]) {
        for chunk in data.chunks_mut(8) {
            let pad = self.next().to_le_bytes();
            for (byte, mask) in chunk.iter_mut().zip(pad) {
                *byte ^= mask;
            }
        }
    }
}

pub fn tag(data: &[u8], key: &[u64; 4]) -> u64 {
    let mut h = key[0] ^ 0xCBF2_9CE4_8422_2325;
    for &byte in data {
        h ^= byte as u64;
        h = h.wrapping_mul(0x0000_0100_0000_01B3);
        h = h.rotate_left(5) ^ key[(byte as usize) & 3];
    }
    h ^ (h >> 29) ^ key[3].rotate_left(11)
}
