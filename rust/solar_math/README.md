# solar_math

Puzzle core for Solar Gleam. It builds every memory puzzle (orb ring, preview
sequence, rule modes), checks each tap, hands out stars and energy, and prices
the regions. The Flutter app only draws what it is told and sends taps back.

## What is obfuscated

- The difficulty curves, energy economy, mode schedule and orb discovery order
  are XOR-masked per index at compile time (`src/tables.rs`), so the binary
  holds no readable balance sheet. There is no runtime cipher or key.
- Orb and glyph ids are shuffled and translated at the boundary.
- Decoded numbers sit in memory XOR-masked with a key chosen at start-up.
- The hidden answer of a puzzle never leaves the core; the app receives only
  the preview and reports taps.
- The C interface is a handful of short symbols (`sg_k0`, `sg_n1`, `sg_t2`,
  `sg_h3`, `sg_f5`, `sg_u7`, `sg_c4`). Release builds use fat LTO,
  `panic = "abort"` and stripped symbols.

## Layout

- `src/lib.rs` C interface and word layouts
- `src/engine.rs` puzzle generation, tap checking, rewards
- `src/tables.rs` balance tables (edit these to change the math)
- `src/vault.rs` table decoding and masked storage
- `tools/build_ios.sh` static library build, run by the Xcode phase
  "Build Solar Math"

## Commands

```sh
# Rust tests (all 48 levels are generated 200 times each and validated)
cargo test --release --features probe

# Host library for `flutter test`
cargo build --release
```

To change the balance, edit the plain numbers inside the `enc([...])` calls in
`src/tables.rs` and rerun the tests. They also check that every region can be
paid for from the energy earned before it.

Xcode builds the iOS static library automatically. It needs `rustup` with
the targets `aarch64-apple-ios`, `aarch64-apple-ios-sim` and
`x86_64-apple-ios`.

`SG_PROBE=1` adds `sg_d9`, a hook that reveals the next expected tap. It exists
for the simulator integration tests only and is never part of a release build.

## C interface

| Function | Purpose |
| --- | --- |
| `sg_k0()` | Verify the tables, returns 1 on success |
| `sg_n1(region, level, out, cap)` | Start a puzzle, see `src/lib.rs` for the word layout |
| `sg_t2(orb)` | Tap an orb, returns a packed state |
| `sg_h3(kind)` | Spend a replay (0) or a hint (1) |
| `sg_f5(ms, repeat, out, cap)` | Rewards for the solved puzzle |
| `sg_u7(region, prev_done, energy)` | Cost to open a region |
| `sg_c4(id, arg)` | Balance constants for the UI |
