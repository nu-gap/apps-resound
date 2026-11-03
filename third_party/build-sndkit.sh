#!/bin/sh
# Build and install the SndKit framework chain into the GNUstep prefix
# selected by the environment (sourced GNUstep.sh / $GNUSTEP_CONFIG_FILE).
#
# Chain: MKPerformSndMIDI (portaudio backend) -> SndKit
#   Resound needs only these two of the four MusicKit frameworks;
#   MKDSP/MusicKit are the synthesizer half and are not built.
#
# The framework installs into the GNUstep domain root of the configured
# prefix:  <prefix>/lib/GNUstep/Frameworks/{MKPerformSndMIDI,SndKit}.framework
# plus the flat <prefix>/lib/libSndKit.so and <prefix>/include/SndKit/
# headers that the application makefiles use for -lSndKit.
#
# External dependencies (system packages):
#   portaudio (libportaudio.so + portaudio.h)
#   libsndfile (libsndfile.so + sndfile.h, pkg-config sndfile)
#   libportmidi (portmidi.h + porttime.h, for the unused-by-Resound
#                MIDI half of MKPerformSndMIDI)
#   ALSA development files are used by portaudio at its own build time;
#   linking the prebuilt system portaudio does not require them.
#
# Usage:
#   source <prefix>/share/GNUstep/Makefiles/GNUstep.sh
#   export GNUSTEP_CONFIG_FILE=<prefix>/etc/GNUstep/GNUstep.conf
#   third_party/build-sndkit.sh
#
# Idempotent: the port patch uses -N (skip if already applied) and the
# make steps are incremental.

set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC="$ROOT/third_party/MusicKit/MusicKit"

[ -d "$ROOT/third_party/MusicKit" ] || {
  echo "error: third_party/MusicKit not found - run 'git submodule update --init' first" >&2
  exit 1
}

# Port patches against the pinned snapshot.  -N keeps this idempotent on
# re-runs; a failed application (e.g. after a submodule bump) aborts the
# build loudly.
echo "==> applying port patches"
for p in "$ROOT"/patches/*.diff; do
  [ -e "$p" ] || continue
  (
    cd "$ROOT/third_party/MusicKit"
    if git apply --check "$p" 2>/dev/null; then
      git apply "$p"
      echo "    applied $(basename "$p")"
    elif git apply --reverse --check "$p" 2>/dev/null; then
      echo "    $(basename "$p") already applied, skipping"
    else
      echo "error: $(basename "$p") does not apply to the pinned MusicKit snapshot (submodule bumped without re-checking the patch?)" >&2
      exit 1
    fi
  )
done

echo "==> configure"
( cd "$SRC" && ./configure )

NPROC=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)

# The backend must be *installed* (headers + shared library) before
# SndKit is built: SndFormat.h imports <MKPerformSndMIDI/PerformSound.h>
# and SndKit prelinks -lMKPerformSndMIDI into its framework binary.
# On a prefix without a previous install, building everything first and
# installing afterwards (as the upstream Frameworks aggregate does)
# fails at the SndKit compile; the install-in-between order is the one
# that works from a clean state.

echo "==> building MKPerformSndMIDI (portaudio backend)"
( cd "$SRC" && make -C Frameworks/PlatformDependent/MKPerformSndMIDI_portaudio -j"$NPROC" )

echo "==> installing MKPerformSndMIDI"
( cd "$SRC" && make -C Frameworks/PlatformDependent/MKPerformSndMIDI_portaudio install )

echo "==> building SndKit"
( cd "$SRC" && make -C Frameworks/SndKit -j"$NPROC" )

echo "==> installing SndKit"
( cd "$SRC" && make -C Frameworks/SndKit install )

echo "==> done"
