#!/usr/bin/env bash
# Build an arm64 Emacs APK that shares the com.termux user ID.
#
# Usage: build-emacs.sh EMACS_SRC_DIR OUT_DIR
#
# Environment:
#   ANDROID_HOME        Android SDK root (required)
#   ANDROID_NDK_HOME    Android NDK root (required, r27 or later)
#   ANDROID_API         android.jar API level (default 36)
#   BUILD_TOOLS         build-tools version (default 36.0.0)
#   MIN_SDK             minimum Android API level (default 29)
#   EMACS_DEBUG         "true" for a debuggable build (default false)
#   PORTS_DIR           where to unpack dependency ports (default ./ports)
#   GHOSTEL_SRC         Ghostel source tree; when set, its Lisp is bundled
#                       and lisp/site-start.el set up to load it (its native
#                       module is added later by add-ghostel-module.sh)
set -euo pipefail

src=${1:?usage: build-emacs.sh EMACS_SRC_DIR OUT_DIR}
out=${2:?usage: build-emacs.sh EMACS_SRC_DIR OUT_DIR}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$out"
out=$(cd "$out" && pwd)

: "${ANDROID_HOME:?ANDROID_HOME must be set}"
: "${ANDROID_NDK_HOME:?ANDROID_NDK_HOME must be set}"
api=${ANDROID_API:-36}
build_tools=${BUILD_TOOLS:-36.0.0}
min_sdk=${MIN_SDK:-29}
ports_dir=${PORTS_DIR:-$PWD/ports}
ghostel_src=${GHOSTEL_SRC:-}
[ -z "$ghostel_src" ] || ghostel_src=$(cd "$ghostel_src" && pwd)

toolchain="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
android_jar="$ANDROID_HOME/platforms/android-$api/android.jar"
android_cc="$toolchain/bin/aarch64-linux-android$min_sdk-clang"
# HarfBuzz is C++; configure locates libc++_shared.so through this.
android_cxx="$android_cc++"

for f in "$android_jar" "$android_cc" "$android_cxx" \
         "$ANDROID_HOME/build-tools/$build_tools/apksigner"; do
  [ -e "$f" ] || { echo "Missing $f" >&2; exit 1; }
done

ndk_path=$("$here/fetch-ports.sh" "$ports_dir")
echo "Dependency ports: $ndk_path"

debug_flag=--without-android-debug
[ "${EMACS_DEBUG:-false}" = true ] && debug_flag=--with-android-debug

cd "$src"
[ -x configure ] || ./autogen.sh
./configure \
  --with-android="$android_jar" \
  ANDROID_CC="$android_cc" \
  SDK_BUILD_TOOLS="$ANDROID_HOME/build-tools/$build_tools" \
  --with-shared-user-id=com.termux \
  "$debug_flag" \
  --with-ndk-path="$ndk_path" \
  --with-ndk-cxx="$android_cxx"

if [ -n "$ghostel_src" ]; then
  # The version build-ghostel.sh gives the native module.
  ghostel_version=$(sed -n 's/^pub const version = "\(.*\)";$/\1/p' \
                      "$ghostel_src/src/version.zig")
  [ -n "$ghostel_version" ] || { echo "No version in $ghostel_src/src/version.zig" >&2; exit 1; }
  sed "s/@GHOSTEL_VERSION@/$ghostel_version/" "$here/../lisp/site-start.el" \
    > lisp/site-start.el
  # Build the host Emacs and its Lisp first, so that it can compile
  # Ghostel before the APK is packed.
  make -j"$(nproc)" lisp
  "$here/pack-ghostel.sh" "$ghostel_src" "$PWD/src/emacs" "$PWD/etc/ghostel.tar"
fi

make -j"$(nproc)" all

shopt -s nullglob
apks=(java/emacs-*-arm64-v8a.apk)
[ ${#apks[@]} -eq 1 ] || { echo "Expected one APK, found: ${apks[*]:-none}" >&2; exit 1; }
cp "${apks[0]}" "$out/"
echo "Built $out/$(basename "${apks[0]}")"
