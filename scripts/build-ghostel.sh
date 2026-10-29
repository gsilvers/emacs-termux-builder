#!/usr/bin/env bash
# Build Ghostel's native module for arm64 Android.
#
# Usage: build-ghostel.sh GHOSTEL_SRC_DIR OUT_DIR
#
# Environment:
#   ANDROID_NDK_HOME    Android NDK root (required)
#   ZIG                 zig binary (default: zig); Ghostel needs exactly
#                       the Zig version its build.zig.zon names
#
# Writes OUT_DIR/libghostel-module.so, named like a library Android
# installs from an APK's lib/arm64-v8a/, and OUT_DIR/ghostel-module.version.
set -euo pipefail

src=${1:?usage: build-ghostel.sh GHOSTEL_SRC_DIR OUT_DIR}
out=${2:?usage: build-ghostel.sh GHOSTEL_SRC_DIR OUT_DIR}
: "${ANDROID_NDK_HOME:?ANDROID_NDK_HOME must be set}"
zig=${ZIG:-zig}

mkdir -p "$out"
out=$(cd "$out" && pwd)
prefix=$(mktemp -d)
trap 'rm -rf "$prefix"' EXIT

# The same target and flags as Ghostel's own release builds of its
# aarch64-android module.
cd "$src"
"$zig" build --prefix "$prefix" \
  -Dtarget=aarch64-linux-android.24 -Doptimize=ReleaseFast -Dcpu=baseline

cp "$prefix/ghostel-module.so" "$out/libghostel-module.so"
cp "$prefix/ghostel-module.version" "$out/"
echo "Built $out/libghostel-module.so, version $(cat "$out/ghostel-module.version")"
