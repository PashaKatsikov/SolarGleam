#!/bin/sh
# Builds the math core as a static library for the SDK Xcode is building.
# Called from the "Build Solar Math" run-script phase of the Runner target.
set -eu

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

CRATE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${PLATFORM_NAME:-iphoneos}"
OUT_DIR="$CRATE_DIR/build/$PLATFORM"
mkdir -p "$OUT_DIR"

if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo not found. Install Rust from https://rustup.rs" >&2
  exit 1
fi

case "$PLATFORM" in
  iphoneos)
    TARGETS="aarch64-apple-ios"
    ;;
  iphonesimulator)
    TARGETS=""
    for arch in ${ARCHS:-arm64}; do
      case "$arch" in
        arm64) TARGETS="$TARGETS aarch64-apple-ios-sim" ;;
        x86_64) TARGETS="$TARGETS x86_64-apple-ios" ;;
      esac
    done
    ;;
  *)
    echo "error: unsupported platform $PLATFORM" >&2
    exit 1
    ;;
esac

# Keep Xcode's compiler overrides away from rustc.
unset CC CXX LD LDFLAGS CFLAGS CXXFLAGS SDKROOT || true

# A clean Codemagic machine has rustup but not the iOS targets yet.
if command -v rustup >/dev/null 2>&1; then
  # shellcheck disable=SC2086
  rustup target add $TARGETS
fi

# SG_PROBE=1 adds the test-automation hook. Release archives never set it.
FEATURES=""
if [ "${SG_PROBE:-0}" = "1" ]; then
  FEATURES="--features probe"
fi

LIBS=""
for target in $TARGETS; do
  # shellcheck disable=SC2086
  cargo rustc --manifest-path "$CRATE_DIR/Cargo.toml" --lib --release $FEATURES \
    --crate-type staticlib --target "$target" \
    --target-dir "$CRATE_DIR/target" --quiet
  LIBS="$LIBS $CRATE_DIR/target/$target/release/libsolar_math.a"
done

# shellcheck disable=SC2086
if [ "$(echo $LIBS | wc -w | tr -d ' ')" -eq 1 ]; then
  cp $LIBS "$OUT_DIR/libsolar_math.a"
else
  lipo -create $LIBS -output "$OUT_DIR/libsolar_math.a"
fi
echo "solar_math: built $TARGETS -> $OUT_DIR/libsolar_math.a"
