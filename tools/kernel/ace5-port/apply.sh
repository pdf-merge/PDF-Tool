#!/usr/bin/env bash
# Apply the Ace 5 WLAN port scaffold to an OPAirDrop source tree.
# Usage: ./apply.sh <opairshare-root> [--force]
# The root is the directory that contains kernel_platform/ and vendor/.
#
# Steps:
#   1. apply patches/0001-stage2a-enums-buildchain-6.1.patch (enums + Kbuild)
#   2. copy new/ (18 new files), clean/ (18 clean merges), resolved/ (6 files)
#
# This is still a textual port: it is not expected to boot, and a feature-ON
# build still needs the HDD/DP integration patches (0005-0007 upstream).
set -euo pipefail

ROOT=${1:?usage: $0 <opairshare-root> [--force]}
FORCE=${2:-}
HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PATCH=$HERE/patches/0001-stage2a-enums-buildchain-6.1.patch
WLAN=$ROOT/vendor/qcom/opensource/wlan

[[ -d "$WLAN" ]] || {
    echo "Not an OPAirDrop source root: $ROOT" >&2
    exit 1
}

if [[ $FORCE != --force ]]; then
    echo "This overwrites WLAN sources under:"
    echo "  $WLAN"
    echo "Back up the tree first, then re-run with --force."
    exit 2
fi

if git -C "$ROOT" apply --check "$PATCH" 2>/dev/null; then
    git -C "$ROOT" apply "$PATCH"
    echo "Applied $(basename "$PATCH")"
elif grep -q 'QDF_PASSTHRU_MODE' \
        "$WLAN/qca-wifi-host-cmn/qdf/inc/qdf_types.h"; then
    echo "Patch already applied (QDF_PASSTHRU_MODE present)"
else
    echo "Patch does not apply and the tree is not patched: $PATCH" >&2
    echo "Resolve this before copying the overlay files." >&2
    exit 3
fi

cp -a "$HERE/new/." "$ROOT/"
cp -a "$HERE/clean/." "$ROOT/"
cp -a "$HERE/resolved/." "$ROOT/"

echo "Copied: new/ + clean/ + resolved/"
echo "Reference only: $(find "$HERE/conflicted" -type f | wc -l) pre-resolution files in conflicted/"
echo "See $HERE/RESOLUTIONS.md for what was changed and what is still 6.6-only."
