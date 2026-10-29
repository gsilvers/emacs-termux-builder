#!/usr/bin/env bash
# Byte-compile Ghostel's Lisp, generate its autoloads, and pack them
# with the support files its shells read (terminfo, shell integration)
# into a tarball for the Emacs APK.  lisp/site-start.el unpacks it on
# the device.
#
# Usage: pack-ghostel.sh GHOSTEL_SRC_DIR EMACS OUT_TAR
#
# EMACS should be the host Emacs from the same build tree as the APK,
# so that the .elc files come from the same Emacs version.
set -euo pipefail

src=${1:?usage: pack-ghostel.sh GHOSTEL_SRC_DIR EMACS OUT_TAR}
emacs=${2:?usage: pack-ghostel.sh GHOSTEL_SRC_DIR EMACS OUT_TAR}
out=${3:?usage: pack-ghostel.sh GHOSTEL_SRC_DIR EMACS OUT_TAR}

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

# Lay it out like a MELPA install, Lisp files and etc/ side by side,
# which is where Ghostel looks for etc/.  extensions/ (evil, consult)
# is left out, as it needs packages that aren't part of Emacs.
cp "$src"/lisp/*.el "$stage/"
cp -R "$src/etc" "$src/LICENSE" "$stage/"

"$emacs" -Q --batch -L "$stage" -f batch-byte-compile "$stage"/*.el
"$emacs" -Q --batch \
  --eval "(loaddefs-generate \"$stage\" \"$stage/ghostel-autoloads.el\")"

# Emacs's tar-mode, which unpacks this, reads ustar.
tar --format=ustar --owner=0 --group=0 --numeric-owner --sort=name \
  -C "$stage" -cf "$out" .
echo "Packed $out"
