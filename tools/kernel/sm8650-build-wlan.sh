#!/usr/bin/env bash
# Build the stock SM8650/pineapple WLAN DDK module (kiwi-v2) and its native deps.
# Run inside the OPAirDrop private fork after sm8650-sync-source.sh.
set -eo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=${OPAIRSHARE_SM8650_BUILD_ROOT:-${OPAIRSHARE_BUILD_ROOT:-/mnt/opairshare-sm8650}}
[[ $EUID != 0 ]] || { echo 'Build as the normal user.' >&2; exit 1; }
[[ -s $ROOT/logs/checkout-ready ]] || { echo 'Source checkout is not ready.' >&2; exit 1; }

cd "$ROOT/opairshare/kernel_platform"

# The normal baseline path runs prepare_vendor.sh, which links the vendor
# tree into the Bazel workspace. The WLAN-only path skips that setup.
ln -fs ../vendor vendor

# The normal baseline path runs build_with_bazel.py, which creates these
# symlinks before Bazel loads //msm-kernel. The WLAN-only path skips the
# baseline, so create them here as well.
if [[ ! -e build/msm_kernel_extensions.bzl ]]; then
    rm -f build/msm_kernel_extensions.bzl
    ln -s ../msm-kernel/msm_kernel_extensions.bzl build/msm_kernel_extensions.bzl
fi
if [[ ! -e build/abl_extensions.bzl ]]; then
    rm -f build/abl_extensions.bzl
    ln -s ../bootable/bootloader/edk2/abl_extensions.bzl build/abl_extensions.bzl
fi

# Mirror the baseline script's PATH shim. Kleaf only needs a `python` on PATH.
TOOLS=${OPAIRSHARE_TOOLS_DIR:-$ROOT/tools}
mkdir -p "$TOOLS/bin"
if [[ ! -e $TOOLS/bin/python ]]; then
    ln -sf "$(command -v python3)" "$TOOLS/bin/python"
fi
export PATH="$TOOLS/bin:$PATH"

# Keep the build JVM inside the runner RAM budget.
if [[ ! -e .bazelrc ]]; then
    printf '%s\n' 'startup --host_jvm_args=-Xmx3g' > .bazelrc
fi

JOBS=${WLAN_JOBS:-2}
export KLEAF_MAKE_JOBS=$JOBS
mkdir -p "$ROOT/baseline-wlan"

# pineapple_gki_kiwi-v2_modules_dist -> qca_cld3_kiwi_v2.ko
# The DT for Ace 5 (caihong-23926) uses qcom,cnss-kiwi; the source target is kiwi-v2.
./tools/bazel --output_user_root="$ROOT/opairshare/bazel-cache" run \
    --jobs="$JOBS" --make_jobs="$JOBS" --local_ram_resources=$((JOBS * 3072)) \
    --//msm-kernel:skip_abi=true --//msm-kernel:skip_abl=true \
    --config=stamp --user_kmi_symbol_lists=//msm-kernel:android/abi_gki_aarch64_qcom \
    //vendor/qcom/opensource/wlan/qcacld-3.0:pineapple_gki_kiwi-v2_modules_dist \
    -- --dist_dir="$ROOT/baseline-wlan"

WLAN="$ROOT/baseline-wlan/qca_cld3_kiwi_v2.ko"
[[ -s $WLAN ]] || {
    echo "WLAN module missing: $WLAN" >&2
    ls -la "$ROOT/baseline-wlan" >&2 || true
    exit 1
}

# Optional: strip debug info and match the stock target kernel's vermagic.
if [[ -n ${WLAN_VERMAGIC:-} ]]; then
    bash "$SCRIPT_DIR/patch-wlan-module.sh" "$WLAN" "$WLAN_VERMAGIC"
fi

echo "WLAN_BASELINE_BUILD_COMPLETE: $WLAN"
if command -v modinfo >/dev/null 2>&1; then
    modinfo "$WLAN"
else
    strings "$WLAN" | grep -E '^(name|vermagic|depends|srcversion)='
fi
