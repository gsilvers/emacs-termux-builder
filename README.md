# emacs-termux-builder

GitHub Actions builds of [GNU Emacs for Android][emacs-android] and
[Termux][termux-app], signed with the same key so that Emacs can share
Termux's user ID (`com.termux`) and run Termux programs. Emacs comes
with the [Ghostel][ghostel] terminal emulator built in. Only arm64 is
built, which covers Pixel phones running GrapheneOS.

Each release holds two APKs:

| File                                        | What                                                       |
|---------------------------------------------|------------------------------------------------------------|
| `emacs-<ver>-29-arm64-v8a.apk`              | Emacs stable release, `--with-shared-user-id=com.termux`, Android 10+, with Ghostel |
| `termux-app_<tag>+emacs-termux-builder_arm64-v8a.apk` | Termux app release, apt-android-7 bootstrap      |

Releases are tagged `emacs-<ver>+termux-<ver>+ghostel-<ver>`, e.g.
`emacs-31.1+termux-0.118.3+ghostel-0.60.0`.

## How it works

`.github/workflows/build.yml` runs only when you start it: open
**Actions → Build Emacs + Termux → Run workflow**, or run
`gh workflow run build.yml` from your workstation. Nothing runs on a
schedule or on pushes.

1. **resolve**: finds the newest stable Emacs tag on
   [emacs-mirror][emacs-mirror] (`emacs-MAJOR.MINOR`, skipping pretests
   and release candidates), the latest [Termux release][termux-app] and
   the latest [Ghostel release][ghostel-releases]. If a release for
   that combination already exists, the run stops here, so starting it
   when nothing is new costs a few seconds.
2. **emacs**: builds Emacs with NDK r27 (16 KB page size safe), the
   API 36 `android.jar`, and the ndk-build dependency ports from the
   [Android ports for GNU Emacs][sf] project: GnuTLS (with gmp, nettle,
   libtasn1, p11-kit), libxml2, tree-sitter, HarfBuzz, giflib,
   libjpeg-turbo, libpng and libtiff, plus upstream libwebp (which
   ships its own `Android.mk`). The ports are pinned by SHA-256
   in [`ports.sha256`](ports.sha256). The build is a release
   (non-debuggable) build unless you ask for a debug one. Ghostel's
   Lisp is byte-compiled with the build's own host Emacs and packed,
   with the terminfo entry and shell integration scripts Ghostel gives
   its shells, into the APK as `etc/ghostel.tar`; see
   [Ghostel](#ghostel) below.
3. **termux**: builds Termux's release variant with Gradle, split to
   arm64 only. Gradle downloads the bootstrap packages from
   termux-packages and checks their hashes.
4. **ghostel**: builds Ghostel's native module (libghostty-vt plus
   Ghostel's Emacs glue) for `aarch64-linux-android` with the same NDK
   and the flags Ghostel's own releases use. Ghostel needs the exact
   Zig version its `build.zig.zon` names, which changes between
   releases, so that's the one installed, from a Zig community mirror
   or ziglang.org, after checking its signature against the Zig
   project's minisign key.
5. **package**: adds the Ghostel module to the Emacs APK as
   `lib/arm64-v8a/libghostel-module.so`, re-signs both APKs with
   `apksigner` using `emacs.keystore`, checks that the two certificates
   match, and publishes a GitHub release whose notes link the exact
   upstream commits and port tarballs (which is also how the GPL source
   offer is met).

The run options let you pin an Emacs tag (e.g. `emacs-30.2`), Termux
tag or Ghostel tag (e.g. `v0.59.0`), do a test build that keeps the APKs as a workflow artifact
instead of publishing (untick **publish**), rebuild an existing
release (**force**), or build a debuggable Emacs. From the command
line, e.g.:

```sh
gh workflow run build.yml                          # latest Emacs + Termux + Ghostel
gh workflow run build.yml -f emacs_tag=emacs-30.2  # a specific Emacs
gh workflow run build.yml -f ghostel_tag=v0.59.0   # a specific Ghostel
gh workflow run build.yml -f publish=false         # test build, no release
```

A new Ghostel release is enough to make a new build: Ghostel's Lisp
usually needs the native module from the same release, so the two are
always bundled together.

A full build takes about 15 minutes of runner time. (Actions minutes on
GitHub's standard runners are free for public repositories.)

The scripts in `scripts/` also run outside Actions on an x86-64 Linux
machine with the Android SDK, NDK and a JDK installed; read the
workflow for the exact versions.

## Signing key

Android only lets two apps share a user ID if they're signed with the
same key, and only lets an update install over an app signed with the
same key. Both APKs are signed with the `emacs.keystore` that ships in
the Emacs source tree, the same key the SourceForge Termux builds of
Emacs use. So installs signed with it (including upstream Termux
re-signed with it by hand) upgrade in place, and SourceForge builds can
be mixed in.

The key and its password are public, so in principle anyone could sign
an app that installs over these or joins the `com.termux` user ID and
reads your Termux and Emacs data. Only install APKs from sources you
trust. Every release lists its certificate SHA-256.

Termux plugins (Termux:API, Widget, Boot, …) share the same user ID, so
they also have to be signed with `emacs.keystore`; the F-Droid and
GitHub builds of them won't install alongside these. They aren't built
here yet.

## Installing

If your current Emacs and Termux are already signed with
`emacs.keystore`, just install the new APKs over them.

Otherwise (first install, or apps signed with another key), Android
refuses the update and fixes an app's shared user ID at install time,
so do a clean install:

1. Back up Termux `$HOME` (e.g. `tar` it to shared storage after
   `termux-setup-storage`) and anything under Emacs's `~`.
2. Uninstall Emacs, then Termux.
3. Install **Termux first**, open it once so it unpacks its bootstrap.
4. Install **Emacs second**.
5. Restore your files.

### Updates with Obtainium

[Obtainium][obtainium] installs and updates straight from GitHub
releases. Add this repository twice:

| App    | Source URL                          | "Filter APKs by regular expression" |
|--------|-------------------------------------|-------------------------------------|
| Termux | `https://github.com/<you>/emacs-termux-builder` | `^termux-app_.*\.apk$`  |
| Emacs  | `https://github.com/<you>/emacs-termux-builder` | `^emacs-.*\.apk$`       |

Emacs keeps the same `versionCode` (30) across releases and every
release rebuilds Termux too, so Obtainium can't compare APK versions.
For both entries, leave "Use release tag/name as version"-style
detection on (the default for GitHub sources) and **turn off "Verify
version string extracted from APK"** if Obtainium complains that the
APK version doesn't match the tag.

## After installing

Put this in `early-init.el` so Emacs finds Termux's programs:

```elisp
(setenv "PATH" (format "%s:%s" "/data/data/com.termux/files/usr/bin"
                       (getenv "PATH")))
(push "/data/data/com.termux/files/usr/bin" exec-path)
```

Don't set `LD_LIBRARY_PATH`; the port's FAQ notes that it causes
library conflicts.

## Ghostel

[Ghostel][ghostel] is a terminal emulator for Emacs built on
libghostty-vt, the terminal engine from the Ghostty terminal. It's set
up so that `M-x ghostel` opens a terminal with nothing to install from
MELPA and no module for Ghostel to download or compile.

By default Ghostel runs `$SHELL` or `/bin/sh`, which is Android's
`mksh` and gets no shell integration. To run Termux's bash, with
directory tracking and prompt navigation, add this to your init file:

```elisp
(setq ghostel-shell "/data/data/com.termux/files/usr/bin/bash")
```

How it fits together (see [`lisp/site-start.el`](lisp/site-start.el)):

- The Lisp and the files Ghostel's shells read are in the APK as
  `etc/ghostel.tar`. Only Emacs can read files inside the APK, so the
  first start of each Ghostel and Emacs version unpacks them into
  `~/.emacs.d/ghostel-bundled/` and puts them on `load-path`. Older
  versions there are removed.
- The native module is installed by Android from the APK, read-only,
  into Emacs's library directory (`exec-directory`), and loaded from
  there.
- Android 10 and later don't let apps run programs stored in app data
  directories, Termux's included. Emacs works around that with an exec
  loader, which Ghostel's native PTY code skips, so `site-start.el` sets
  `ghostel-use-native-pty` to nil and Ghostel starts shells through
  Emacs instead. Because Emacs shares Termux's user ID, Ghostel's
  faster native PTY might work anyway; to try it, add
  `(setq ghostel-use-native-pty t)` to your init file.
- Ghostel's evil and consult extensions aren't bundled, as they need
  packages that don't come with Emacs.
- If you install Ghostel with package.el anyway, that copy comes first
  in `load-path` and handles its own native module as usual.

[emacs-android]: https://github.com/emacs-mirror/emacs/blob/master/java/INSTALL
[emacs-mirror]: https://github.com/emacs-mirror/emacs
[termux-app]: https://github.com/termux/termux-app
[sf]: https://sourceforge.net/projects/android-ports-for-gnu-emacs/files/
[obtainium]: https://github.com/ImranR98/Obtainium
[ghostel]: https://github.com/dakra/ghostel
[ghostel-releases]: https://github.com/dakra/ghostel/releases
