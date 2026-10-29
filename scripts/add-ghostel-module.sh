#!/usr/bin/env bash
# Add Ghostel's native module to the Emacs APK as
# lib/arm64-v8a/libghostel-module.so, so Android installs it next to
# Emacs's own libraries.  Emacs's build signs the APK; that signature
# is removed here, and sign-apks.sh signs the result again.
#
# Usage: add-ghostel-module.sh APK MODULE
#
# Environment:
#   ZIPALIGN   path to zipalign (required)
set -euo pipefail

apk=${1:?usage: add-ghostel-module.sh APK MODULE}
module=${2:?usage: add-ghostel-module.sh APK MODULE}
: "${ZIPALIGN:?}"
apk=$(cd "$(dirname "$apk")" && pwd)/$(basename "$apk")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/lib/arm64-v8a"
cp "$module" "$work/lib/arm64-v8a/libghostel-module.so"
cp "$apk" "$work/emacs.apk"
cd "$work"
# Drop the old v1 (JAR) signature, which doesn't cover the new file.
# It's all that Emacs's APK keeps in META-INF.
zip -q -d emacs.apk 'META-INF/*'
zip -q emacs.apk lib/arm64-v8a/libghostel-module.so
"$ZIPALIGN" -f 4 emacs.apk "$apk"
echo "Added libghostel-module.so to $apk"
