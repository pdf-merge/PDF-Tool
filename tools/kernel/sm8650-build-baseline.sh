#!/usr/bin/env bash
# Official OnePlus Ace 5 SM8650 Pineapple GKI baseline only; no OPAirShare patches or deployment.
set -euo pipefail
ROOT=${OPAIRSHARE_SM8650_BUILD_ROOT:-/mnt/opairshare-sm8650}
SOURCE_BRANCH=${OPAIRSHARE_SM8650_SOURCE_BRANCH:-oneplus/sm8650_b_16.0.0_ace_5}
[[ $EUID != 0 ]] || { echo 'Build as the normal user.' >&2; exit 1; }
[[ $(findmnt -n -o FSTYPE -T "$ROOT") == ext4 ]] || { echo 'Build volume must use ext4.' >&2; exit 1; }
[[ -s $ROOT/logs/checkout-ready ]] || { echo 'SM8650 source checkout is not ready.' >&2; exit 1; }
python3 - "$ROOT/logs/source-lock.xml" "$SOURCE_BRANCH" <<'PY'
import sys
import xml.etree.ElementTree as ET

lock, expected = sys.argv[1:]
projects = {p.get('path', p.get('name')): p for p in ET.parse(lock).getroot().findall('project')}
for path in ('kernel_platform/common', 'kernel_platform/msm-kernel', '.'):
    project = projects.get(path)
    if project is None or project.get('upstream') != expected:
        actual = None if project is None else project.get('upstream')
        raise SystemExit(f'Wrong SM8650 source branch for {path}: {actual!r} != {expected!r}')
PY
HOST_TOOLS="$ROOT/tools/bin"
mkdir -p "$HOST_TOOLS"
if ! command -v python >/dev/null 2>&1; then
    command -v python3 >/dev/null 2>&1 || { echo 'python3 is required.' >&2; exit 1; }
    ln -sf "$(command -v python3)" "$HOST_TOOLS/python"
    export PATH="$HOST_TOOLS:$PATH"
fi
cd "$ROOT/opairshare"
echo "Building official OnePlus Ace 5 SM8650 Pineapple GKI baseline from $SOURCE_BRANCH; no OPAirShare integration."
export KLEAF_MAKE_JOBS=${KLEAF_MAKE_JOBS:-2}
bash kernel_platform/oplus/build/oplus_build_kernel.sh pineapple gki
DIST="$ROOT/opairshare/kernel_platform/out/msm-kernel-pineapple-gki/dist"
[[ -s $DIST/Image ]] || { echo "GKI command ended without producing $DIST/Image." >&2; exit 1; }
echo 'ONEPLUS_ACE5_SM8650_BASELINE_BUILD_COMMAND_COMPLETE; inspect artifacts and device compatibility before any integration.'
