//! Seals the plaintext economy spec into `src/sealed.bin`.
//!
//!   cargo run --release --features seal --bin seal -- spec/economy.spec src/sealed.bin
//!
//! The spec stays out of version control. Only the sealed blob ships.

#![allow(dead_code)]

#[path = "../cipher.rs"]
mod cipher;

use std::collections::HashMap;
use std::fs::{self, File};
use std::io::Read;

const ORDER: [&str; 12] = [
    "ten", "jack", "queen", "king", "ace", "star", "fireball", "chest", "crown", "solar", "wild",
    "bonus",
];

fn fail(message: &str) -> ! {
    eprintln!("seal: {message}");
    std::process::exit(1);
}

fn number(token: Option<&str>, what: &str) -> u32 {
    token
        .and_then(|t| t.parse::<u32>().ok())
        .unwrap_or_else(|| fail(&format!("bad number for {what}")))
}

fn main() {
    let mut args = std::env::args().skip(1);
    let spec_path = args
        .next()
        .unwrap_or_else(|| fail("usage: seal <spec> <out>"));
    let out_path = args
        .next()
        .unwrap_or_else(|| fail("usage: seal <spec> <out>"));
    let text = fs::read_to_string(&spec_path).unwrap_or_else(|_| fail("cannot read spec"));

    // (weight, pay3, pay4) by Dart symbol order.
    let mut symbols: HashMap<String, (u32, u32, u32)> = HashMap::new();
    let mut lines: Vec<Vec<u32>> = Vec::new();
    let mut scalars: HashMap<String, u32> = HashMap::new();

    for raw in text.lines() {
        let line = raw.split('#').next().unwrap_or("").trim();
        if line.is_empty() {
            continue;
        }
        let mut parts = line.split_whitespace();
        let head = parts.next().unwrap_or("");
        match head {
            "symbol" => {
                let name = parts.next().unwrap_or_else(|| fail("symbol needs a name"));
                let w = number(parts.next(), "weight");
                let p3 = number(parts.next(), "pay3");
                let p4 = number(parts.next(), "pay4");
                symbols.insert(name.to_string(), (w, p3, p4));
            }
            "line" => lines.push(parts.map(|t| number(Some(t), "line row")).collect()),
            other => {
                let value = number(parts.next(), other);
                scalars.insert(other.to_string(), value);
            }
        }
    }

    let n = ORDER.len();
    let reels = lines.first().map_or(0, |l| l.len());
    if reels == 0 || lines.iter().any(|l| l.len() != reels) {
        fail("every line needs the same reel count");
    }
    let rows = scalars
        .get("rows")
        .copied()
        .unwrap_or_else(|| fail("missing rows"));
    let need = |key: &str| -> u32 {
        scalars
            .get(key)
            .copied()
            .unwrap_or_else(|| fail(&format!("missing {key}")))
    };

    let mut nonce = [0u8; 16];
    File::open("/dev/urandom")
        .and_then(|mut f| f.read_exact(&mut nonce))
        .unwrap_or_else(|_| fail("cannot read /dev/urandom"));
    let key = cipher::master();

    // Secret shuffle: internal code of each Dart symbol.
    let mut shuffle_nonce = nonce;
    for b in shuffle_nonce.iter_mut() {
        *b = b.rotate_left(3) ^ 0xA5;
    }
    let mut stream = cipher::Stream::new(&key, &shuffle_nonce);
    let mut to_internal: Vec<u32> = (0..n as u32).collect();
    for i in (1..n).rev() {
        let j = (stream.next() % (i as u64 + 1)) as usize;
        to_internal.swap(i, j);
    }
    let mut to_dart = vec![0usize; n];
    for (dart, internal) in to_internal.iter().enumerate() {
        to_dart[*internal as usize] = dart;
    }

    let mut words: Vec<u32> = Vec::new();
    words.push(n as u32);
    for internal in 0..n {
        let name = ORDER[to_dart[internal]];
        let (w, p3, p4) = symbols
            .get(name)
            .copied()
            .unwrap_or_else(|| fail(&format!("missing symbol {name}")));
        words.extend([w, p3, p4]);
    }
    words.extend(to_internal.iter().copied());
    let wild = ORDER.iter().position(|s| *s == "wild").unwrap();
    let bonus = ORDER.iter().position(|s| *s == "bonus").unwrap();
    words.push(to_internal[wild]);
    words.push(to_internal[bonus]);
    words.push(lines.len() as u32);
    words.push(reels as u32);
    words.push(rows);
    for line in &lines {
        words.extend(line.iter().copied());
    }
    for key_name in [
        "scatter3",
        "scatter4",
        "fs3",
        "fs4",
        "fsmult",
        "tier_big",
        "tier_solar",
    ] {
        words.push(need(key_name));
    }

    let mut payload: Vec<u8> = words.iter().flat_map(|w| w.to_le_bytes()).collect();
    let tag = cipher::tag(&payload, &key);
    payload.extend(tag.to_le_bytes());
    cipher::Stream::new(&key, &nonce).apply(&mut payload);

    let mut blob = nonce.to_vec();
    blob.extend(payload);
    fs::write(&out_path, &blob).unwrap_or_else(|_| fail("cannot write output"));
    println!("sealed {} bytes -> {}", blob.len(), out_path);
}
