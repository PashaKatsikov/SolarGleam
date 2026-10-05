# solar_math

Math core for Solar Gleam: reel generation, 20 paylines, pay tables, bonus
scatter, free spins and celebration tiers. The Flutter app only draws the
result.

## What is obfuscated

- Weights, pays, paylines and rule numbers are XOR-masked per index at
  compile time (`src/tables.rs`), so the binary holds no readable pay table.
  There is no runtime cipher or key.
- Symbol ids are shuffled and translated at the boundary.
- Decoded numbers sit in memory XOR-masked with a key chosen at start-up.
- The C interface is five short symbols (`sg_k0`, `sg_g1`, `sg_e2`, `sg_p3`,
  `sg_c4`). Release builds use fat LTO, `panic = "abort"` and stripped symbols.

## Layout

- `src/lib.rs` C interface
- `src/engine.rs` spin and evaluation
- `src/tables.rs` economy tables (edit these to change the math)
- `src/vault.rs` table decoding and masked storage
- `tools/build_ios.sh` static library build, run by the Xcode phase
  "Build Solar Math"

## Commands

```sh
# Rust tests (includes a 600k-spin return simulation)
cargo test --release

# Host library for `flutter test`
cargo build --release
```

To change the math, edit the plain numbers inside the `enc([...])` calls in
`src/tables.rs` and rerun `cargo test --release`.

Xcode builds the iOS static library automatically. It needs `rustup` with
the targets `aarch64-apple-ios`, `aarch64-apple-ios-sim` and
`x86_64-apple-ios`.

## C interface

| Function | Purpose |
| --- | --- |
| `sg_k0()` | Verify the tables, returns 1 on success |
| `sg_g1(out, cap)` | Random grid, reel-major symbol ids |
| `sg_e2(grid, len, bet, free, out, cap)` | Evaluate a grid, see `src/lib.rs` for the word layout |
| `sg_p3(symbol, count, line_bet)` | Pay for one line, used by the paytable |
| `sg_c4(id)` | Rule constants |
