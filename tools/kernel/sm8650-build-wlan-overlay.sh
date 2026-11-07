#!/usr/bin/env bash
# Apply the Ace 5 AWDL port scaffold, then build WLAN with PAS/Wonder OFF.
#
# This is a compile smoke test for the overlay, not a bootable build. It runs
# after the stock WLAN baseline has already been built, and writes to a
# separate dist directory so the stock module is not overwritten.
#
# Usage (inside the OPAirDrop private fork, after sm8650-sync-source.sh):
#   tools/kernel/ace5-port/apply.sh is expected at $OPAIRSHARE_PORT_DIR.
set -eo pipefail

ROOT=${OPAIRSHARE_SM8650_BUILD_ROOT:-${OPAIRSHARE_BUILD_ROOT:-/mnt/opairshare-sm8650}}
SRC=$ROOT/opairshare
HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PORT=${OPAIRSHARE_PORT_DIR:-$HERE/ace5-port}
OUT=${OPAIRSHARE_OVERLAY_DIST:-$ROOT/overlay-wlan-feature-off}

[[ $EUID != 0 ]] || { echo 'Build as the normal user.' >&2; exit 1; }
[[ -s $ROOT/logs/checkout-ready ]] || { echo 'Source checkout is not ready.' >&2; exit 1; }
[[ -x $PORT/apply.sh ]] || {
    echo "Port scaffold not found: $PORT" >&2
    echo 'Copy port/ to tools/kernel/ace5-port/ or set OPAIRSHARE_PORT_DIR.' >&2
    exit 1
}

echo "Applying port scaffold from $PORT"
bash "$PORT/apply.sh" "$SRC" --force

# This job is the feature-OFF build. Refuse to run if a defconfig turns the
# new modes on, otherwise the result would not test what it claims.
DEFCONFIG=$SRC/vendor/qcom/opensource/wlan/qcacld-3.0/configs/pineapple_gki_kiwi-v2_defconfig
if grep -qE '^CONFIG_(DRIVER_PASSTHRU_MODE|WONDER_SUPPORT)=y' "$DEFCONFIG"; then
    echo "Feature flags enabled in $DEFCONFIG; expected feature-OFF build." >&2
    exit 1
fi

cd "$SRC/kernel_platform"

# Mirror the baseline script's python shim for Kleaf.
TOOLS=${OPAIRSHARE_TOOLS_DIR:-$ROOT/tools}
mkdir -p "$TOOLS/bin"
if [[ ! -e $TOOLS/bin/python ]]; then
    ln -sf "$(command -v python3)" "$TOOLS/bin/python"
fi
export PATH="$TOOLS/bin:$PATH"

if [[ ! -e .bazelrc ]]; then
    printf '%s\n' 'startup --host_jvm_args=-Xmx3g' > .bazelrc
fi

export KLEAF_MAKE_JOBS=2
rm -rf "$OUT"
mkdir -p "$OUT"

# Same target as the stock baseline: overlay only changes sources, not the
# module name or the Bazel target.
./tools/bazel --output_user_root="$ROOT/opairshare/bazel-cache" run \
    --jobs=2 --make_jobs=2 --local_ram_resources=6144 \
    --//msm-kernel:skip_abi=true --//msm-kernel:skip_abl=true \
    --config=stamp --user_kmi_symbol_lists=//msm-kernel:android/abi_gki_aarch64_qcom \
    //vendor/qcom/opensource/wlan/qcacld-3.0:pineapple_gki_kiwi-v2_modules_dist \
    -- --dist_dir="$OUT"

WLAN="$OUT/qca_cld3_kiwi_v2.ko"
[[ -s $WLAN ]] || {
    echo "Overlay WLAN module missing: $WLAN" >&2
    ls -la "$OUT" >&2 || true
    exit 1
}

echo "OVERLAY_FEATURE_OFF_BUILD_COMPLETE: $WLAN"
if command -v modinfo >/dev/null 2>&1; then
    modinfo "$WLAN"
else
    strings "$WLAN" | grep -E '^(name|vermagic|depends|srcversion)='
fi
