#!/usr/bin/env bash
# Strip debug info from a built WLAN module and patch its .modinfo vermagic.
# Usage: patch-wlan-module.sh <module.ko> <target-vermagic-release>
set -euo pipefail

MOD=${1:?usage: patch-wlan-module.sh <module.ko> <target-vermagic-release>}
TARGET=${2:?target vermagic release}
[[ -s $MOD ]] || { echo "module not found: $MOD" >&2; exit 1; }

find_tool() {
    local name=$1 path
    path=$(command -v "$name" 2>/dev/null || true)
    if [[ -z $path ]]; then
        path=$(ls /usr/lib/llvm-*/bin/"$name" 2>/dev/null | head -1 || true)
    fi
    if [[ -z $path ]]; then
        local root=${OPAIRSHARE_SM8650_BUILD_ROOT:-/mnt/opairshare-sm8650}
        path=$(find "$root/opairshare/kernel_platform/prebuilts/clang/host/linux-x86" \
            -type f -path "*/bin/$name" 2>/dev/null | head -1 || true)
    fi
    [[ -n $path && -x $path ]] || {
        echo "cannot find $name (llvm toolchain)" >&2
        return 1
    }
    printf '%s\n' "$path"
}

STRIP=$(find_tool llvm-strip)
OBJCOPY=$(find_tool llvm-objcopy)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

"$STRIP" --strip-debug -o "$TMP/module.stripped.ko" "$MOD"
"$OBJCOPY" --dump-section .modinfo="$TMP/modinfo.bin" "$TMP/module.stripped.ko"

python3 - "$TMP/modinfo.bin" "$TMP/modinfo.patched.bin" "$TARGET" <<'PY'
import sys

src, dst, target = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(src, 'rb').read()
key = b'vermagic='
i = data.find(key)
if i < 0:
    raise SystemExit('no vermagic entry in .modinfo')
j = data.find(b'\0', i)
if j < 0:
    j = len(data)
entry = data[i:j]
rest = entry[len(key):]
release, sep, flags = rest.partition(b' ')
if not release:
    raise SystemExit('empty vermagic entry')
new = key + target.encode('ascii') + (b' ' + flags if sep else b'')
out = data if release == target.encode('ascii') else data[:i] + new + data[j:]
open(dst, 'wb').write(out)
print('vermagic:', new.decode('ascii', 'replace'))
PY

"$OBJCOPY" --update-section .modinfo="$TMP/modinfo.patched.bin" \
    "$TMP/module.stripped.ko" "$TMP/module.patched.ko"
mv "$TMP/module.patched.ko" "$MOD"

echo "WLAN_MODULE_PATCHED: $MOD"
if command -v modinfo >/dev/null 2>&1; then
    modinfo "$MOD" | grep -E '^(filename|vermagic|name|depends):'
else
    strings "$MOD" | grep -E '^(vermagic|name|depends)='
fi
