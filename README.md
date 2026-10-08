# Solar Gleam

Solar Gleam is a memory-puzzle adventure set in a drowned digital world. Watch
glowing orbs flash on a holographic platform, repeat the pattern from memory
and bring forgotten districts back to life, one restored landmark at a time.

## Game

- Six regions with eight restorations each: Neon District, Crystal Data
  Forest, Aurora Sky Temple, Cyber Ocean, Quantum Desert and Memory Core.
- Five rules that combine as you go: **Echo** (repeat the order), **Mirror**
  (repeat it backwards), **Glyph** (read symbols off the core), **Ghost**
  (ignore false flickers) and **Shift** (follow orbs that swap places).
- Earn stars and energy, open new regions, discover twelve orbs, unlock
  memory fragments and decor relics, and rebuild each region diorama.
- Portrait only, tuned for iPhone and iPad.

## Project layout

- `lib/` - Flutter app (screens, widgets, audio, progress storage).
- `rust/solar_math/` - the puzzle core: pattern generation, answer checking,
  rewards and the economy. It is compiled into the app as a static library
  (`tools/build_ios.sh`, run by the "Build Solar Math" Xcode phase) and read
  from Dart over FFI (`lib/game/native_math.dart`).
- `tools/` - asset pipeline used to slice and optimise the artwork.
- `test/` - unit and widget tests (`cargo build --release` in
  `rust/solar_math` first, so the host library exists).
- `integration_test/` - plays the game on a simulator (`SG_PROBE=1`).

## Build

```sh
cd rust/solar_math && cargo test && cargo build --release && cd ../..
flutter test
flutter run
```

Rust targets needed for iOS: `aarch64-apple-ios`, `aarch64-apple-ios-sim`,
`x86_64-apple-ios` (`rustup target add ...`).
