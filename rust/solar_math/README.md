# solar_math

Sealed math core for Solar Gleam: reel generation, 20 paylines, pay tables,
bonus scatter, free spins and celebration tiers. The Flutter app only draws
the result.

## What is obfuscated

- Weights, pays, paylines and rule numbers ship only as an encrypted blob
  (`src/sealed.bin`). The key is rebuilt at run time from scattered fragments
  and mixed with a per-seal nonce. A keyed tag rejects a tampered blob.
- Symbol ids are shuffled inside the blob and translated at the boundary.
- Decoded numbers sit in memory XOR-masked with a key chosen at start-up.
- The C interface is five short symbols (`sg_k0`, `sg_g1`, `sg_e2`, `sg_p3`,
  `sg_c4`). Release builds use fat LTO, `panic = "abort"` and stripped symbols.

## Layout

- `src/lib.rs` C interface
- `src/engine.rs` spin and evaluation
- `src/vault.rs` blob decoding and masked storage
- `src/cipher.rs` cipher shared with the sealing tool
- `src/bin/seal.rs` sealing tool (feature `seal`)
- `tools/build_ios.sh` static library build, run by the Xcode phase
  "Build Solar Math"
- `spec/economy.spec` plaintext economy, ignored by git

## Commands

```sh
# Rust tests (includes a 600k-spin return simulation)
cargo test --release

# Host library for `flutter test`
cargo build --release

# Change the math: edit spec/economy.spec, then re-seal
cargo run --release --features seal --bin seal -- spec/economy.spec src/sealed.bin
cargo test --release
```

Xcode builds the iOS static library automatically. It needs `rustup` with
the targets `aarch64-apple-ios`, `aarch64-apple-ios-sim` and
`x86_64-apple-ios`.

## C interface

| Function | Purpose |
| --- | --- |
| `sg_k0()` | Verify sealed data, returns 1 on success |
| `sg_g1(out, cap)` | Random grid, reel-major symbol ids |
| `sg_e2(grid, len, bet, free, out, cap)` | Evaluate a grid, see `src/lib.rs` for the word layout |
| `sg_p3(symbol, count, line_bet)` | Pay for one line, used by the paytable |
| `sg_c4(id)` | Rule constants |
