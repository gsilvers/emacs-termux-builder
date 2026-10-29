#!/usr/bin/env bash
# Download Zig for x86-64 Linux, check its minisign signature against
# the Zig project's key, and unpack it.  Tries the community mirrors
# ziglang.org lists first, as the Zig project asks of CI, then
# ziglang.org itself.
#
# Usage: install-zig.sh VERSION DEST_DIR
#
# Needs minisign.  Prints the directory holding the zig binary.
set -euo pipefail

version=${1:?usage: install-zig.sh VERSION DEST_DIR}
dest=${2:?usage: install-zig.sh VERSION DEST_DIR}
# From https://ziglang.org/download/
key=RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U
name=zig-x86_64-linux-$version
tarball=$name.tar.xz

mkdir -p "$dest"
cd "$dest"

urls=()
for mirror in $(curl -fsSL https://ziglang.org/download/community-mirrors.txt | shuf); do
  urls+=("$mirror/$tarball")
done
urls+=("https://ziglang.org/download/$version/$tarball")

for url in "${urls[@]}"; do
  echo "Trying $url" >&2
  rm -f "$tarball" "$tarball.minisig"
  curl -fsSL --retry 2 -o "$tarball" "$url?source=emacs-termux-builder" &&
    curl -fsSL --retry 2 -o "$tarball.minisig" "$url.minisig?source=emacs-termux-builder" &&
    comment=$(minisign -V -P "$key" -m "$tarball" -Q) || continue
  # The signed comment names the file, so a validly signed tarball of
  # another version can't stand in for this one.
  if [[ $comment =~ ^timestamp:[0-9]+[[:space:]]+file:([^[:space:]]+)[[:space:]]+hashed$ ]] &&
     [ "${BASH_REMATCH[1]}" = "$tarball" ]; then
    tar xJf "$tarball"
    rm -f "$tarball" "$tarball.minisig"
    echo "Installed Zig $version from $url" >&2
    echo "$PWD/$name"
    exit 0
  fi
  echo "Signed for another file: $comment" >&2
done

echo "Could not download a verified $tarball" >&2
exit 1
