#!/usr/bin/env bash
# Sync the official OnePlus Ace 5 (SM8650 / Pineapple) source baseline.
set -euo pipefail
ROOT=${OPAIRSHARE_SM8650_BUILD_ROOT:-/mnt/opairshare-sm8650}
export OPAIRSHARE_SM8650_BUILD_ROOT="$ROOT"
SOURCE_BRANCH=${OPAIRSHARE_SM8650_SOURCE_BRANCH:-oneplus/sm8650_b_16.0.0_ace_5}
TOOLS=${OPAIRSHARE_SM8650_HOST_TOOLS_DIR:-$ROOT/tools}
[[ $EUID != 0 ]] || { echo 'Do not sync/build as root.' >&2; exit 1; }
mkdir -p "$ROOT"
[[ $(findmnt -n -o FSTYPE -T "$ROOT") == ext4 ]] || { echo 'Build volume must use ext4.' >&2; exit 1; }
mkdir -p "$ROOT/opairshare" "$ROOT/logs" "$TOOLS/bin"
export PATH="$TOOLS/bin:$PATH"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=http.version
export GIT_CONFIG_VALUE_0=HTTP/1.1
if [[ ! -s $TOOLS/bin/repo ]]; then
    curl --fail --location --retry 3 https://storage.googleapis.com/git-repo-downloads/repo -o "$TOOLS/bin/repo.download"
    mv "$TOOLS/bin/repo.download" "$TOOLS/bin/repo"
    chmod +x "$TOOLS/bin/repo"
fi
cd "$ROOT/opairshare"
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/ace5-source-branch.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <extend-project name="android_kernel_common_oneplus_sm8650" path="kernel_platform/common" revision="$SOURCE_BRANCH"/>
  <extend-project name="android_kernel_oneplus_sm8650" path="kernel_platform/msm-kernel" revision="$SOURCE_BRANCH"/>
  <extend-project name="android_kernel_modules_and_devicetree_oneplus_sm8650" path="." revision="$SOURCE_BRANCH"/>
</manifest>
EOF
repo init -u https://github.com/OnePlusOSS/kernel_manifest \
    -b oneplus/sm8650 -m oneplus_ace5.xml --depth=1 \
    --partial-clone --clone-filter=blob:limit=1m
repo sync -n -c --no-tags -j4 --fail-fast
repo sync -l -j4 --fail-fast
repo manifest -r -o "$ROOT/logs/source-lock.xml"
python3 - <<'PY'
from pathlib import Path
import os
import subprocess
import xml.etree.ElementTree as ET

root = Path.cwd()
lock = Path(os.environ['OPAIRSHARE_SM8650_BUILD_ROOT']) / 'logs/source-lock.xml'
projects = ET.parse(lock).getroot().findall('project')
expected_branch = os.environ.get(
    'OPAIRSHARE_SM8650_SOURCE_BRANCH', 'oneplus/sm8650_b_16.0.0_ace_5')
required_paths = {
    'kernel_platform/common',
    'kernel_platform/msm-kernel',
    '.',
}
device_projects = {project.get('path', project.get('name')): project
                   for project in projects}
missing = required_paths - device_projects.keys()
if missing:
    raise SystemExit(f'Missing Ace 5 source projects in lock: {sorted(missing)}')
for project_path in required_paths:
    project = device_projects[project_path]
    if project.get('upstream') != expected_branch:
        raise SystemExit(f'Wrong SM8650 source branch for {project_path}: '
                         f'{project.get("upstream")} != {expected_branch}')
for project in projects:
    path = root / project.get('path', project.get('name'))
    expected = project.get('revision')
    actual = subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != expected:
        raise SystemExit(f'Checkout differs from locked revision: {path} ({actual} != {expected})')
required = [root / 'kernel_platform/oplus/build/oplus_build_kernel.sh',
            root / 'kernel_platform/prebuilts/build-tools']
for path in required:
    if not path.exists():
        raise SystemExit(f'Missing required entry: {path}')
(lock.parent / 'checkout-ready').write_text(
    f'oneplus ace5 sm8650 pineapple gki validated: {expected_branch}\n')
PY
printf 'ONEPLUS_ACE5_SM8650_SYNC_COMPLETE\n'
