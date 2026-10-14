#!/usr/bin/env bash
# Build-only pipeline. NEVER installs to a router or flashes MTD.
set -Eeuo pipefail

REPO_URL="https://github.com/cjdelisle/EN751221-Linux26.git"
PINNED_COMMIT="aea3a43562e8d3dc0335624202fde08d713a18c2"
WORKDIR="$(pwd -P)"
SRC="$WORKDIR/vendor-src"
OUT="$WORKDIR/build-results"
KERNEL="$SRC/tclinux_phoenix/linux-2.6.36"
D24="$SRC/tclinux_phoenix/modules/private/wifi/MT7603"
D5="$SRC/tclinux_phoenix/modules/private/wifi/MT7612E_LinuxAP_3.0.4.0.P2_DPA"
CROSS="mips-linux-gnu-"

mkdir -p "$OUT"
echo "Source: $REPO_URL" > "$OUT/build-info.txt"
echo "Pinned revision: $PINNED_COMMIT" >> "$OUT/build-info.txt"
echo "Build environment: $(date -u +%FT%TZ)" >> "$OUT/build-info.txt"
"$CROSS"gcc --version | head -1 >> "$OUT/build-info.txt"

echo "::group::Fetch pinned upstream kernel and Wi-Fi driver sources"
git clone --depth=1 --single-branch --branch master --filter=blob:none --sparse "$REPO_URL" "$SRC"
actual="$(git -C "$SRC" rev-parse HEAD)"
if [[ "$actual" != "$PINNED_COMMIT" ]]; then
    echo "Upstream revision changed: expected $PINNED_COMMIT, got $actual" >&2
    exit 2
fi
git -C "$SRC" sparse-checkout set \
    tclinux_phoenix/linux-2.6.36 \
    tclinux_phoenix/modules/private/wifi/MT7603 \
    tclinux_phoenix/modules/private/wifi/MT7612E_LinuxAP_3.0.4.0.P2_DPA
echo "::endgroup::"

echo "::group::Verify toolchain architecture and endianness"
printf '%s\n' 'int apcli_probe(void) { return 0; }' > "$OUT/arch_probe.c"
"$CROSS"gcc -march=mips32r2 -mabi=32 -c "$OUT/arch_probe.c" -o "$OUT/arch_probe.o"
readelf -h "$OUT/arch_probe.o" > "$OUT/toolchain-elf.txt"
grep -q 'Data:.*big endian' "$OUT/toolchain-elf.txt"
grep -q 'Machine:.*MIPS' "$OUT/toolchain-elf.txt"
echo "::endgroup::"

echo "::group::Enable APCLI in both vendor configuration files for each driver"
for driver in "$D24" "$D5"; do
    for cfg in config_BBU.mk config.mk; do
        file="$driver/os/linux/$cfg"
        [[ -f "$file" ]] || { echo "Missing $file" >&2; exit 3; }
        cp "$file" "$OUT/$(basename "$driver")-$cfg.original"
        python3 - "$file" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
s = path.read_text()
s, changed = re.subn(r"(?m)^HAS_APCLI=n[ \t]*$", "HAS_APCLI=y", s, count=1)
if changed != 1:
    raise SystemExit(f"APCLI config not found exactly once: {path}")
path.write_text(s)
print(f"APCLI enabled in {path}")
PY
    done
done
echo "::endgroup::"

# Vendor MT7612 APCLI branch accesses wifi_dev.IEEE8021X unconditionally,
# although that member is compiled only with DOT1X_SUPPORT. Keep WPA2-PSK
# intact and guard the optional 802.1X branch rather than enabling EAP code.
echo "::group::Fix vendor MT7612E APCLI conditional compilation"
cp "$D5/ap/ap_data.c" "$OUT/mt7612-ap_data.c.original"
python3 - "$D5/ap/ap_data.c" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()
pattern = re.compile(r"(?m)^([ \t]*)\(wdev->AuthMode == Ndis802_11AuthModeWPA2PSK\) \|\|[ \t]*\n[ \t]*\(wdev->IEEE8021X == TRUE\)")
def repl(m):
    indent = m.group(1)
    return (indent + "(wdev->AuthMode == Ndis802_11AuthModeWPA2PSK)\n"
            + "#ifdef DOT1X_SUPPORT\n"
            + indent + "|| (wdev->IEEE8021X == TRUE)\n"
            + "#endif")
s, count = pattern.subn(repl, s)
if count != 1:
    raise SystemExit(f"Expected one MT7612 APCLI IEEE8021X conditional, found {count}")
p.write_text(s)
print("Guarded optional 802.1X reference in MT7612 APCLI")
PY
echo "::endgroup::"

# Link-time shims for two functions absent from the H298A kernel.
# alloc_etherdev_mq has a different symbol name than ZTE's alloc_etherdev_mqs.
# skbmgr_alloc_skb4k is a vendor RX allocation fast-path; use kernel dev_alloc_skb.
# Both are unverified semantic substitutions. NEVER install on production hardware
# without verifying the precise signatures / DMA and skb requirements.
echo "::group::Add experimental MT7612E ABI compatibility wrappers"
cat > "$D5/os/linux/apcli_compat.c" <<'EOF'
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/skbuff.h>

struct net_device *alloc_etherdev_mq(int sizeof_priv, unsigned int txqs)
{
    return alloc_etherdev_mqs(sizeof_priv, txqs, 1);
}

struct sk_buff *skbmgr_alloc_skb4k(void)
{
    return dev_alloc_skb(4096);
}
EOF
python3 - "$D5/os/linux/Makefile.6" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
needle = "obj-m := $(MOD_NAME).o"
if s.count(needle) != 1:
    raise SystemExit("Unexpected Wi-Fi makefile layout")
s = s.replace(needle, "obj_cmm += ../../os/linux/apcli_compat.o\n" + needle)
p.write_text(s)
PY
echo "EXPERIMENTAL ABI wrappers: alloc_etherdev_mq -> alloc_etherdev_mqs(rxqs=1), skbmgr_alloc_skb4k -> dev_alloc_skb(4096)" >> "$OUT/build-info.txt"
echo "::endgroup::"

# Match the stock 5 GHz driver's os_alloc_mem call path to __kmalloc.
# The generic GCC 10 sample used kmalloc_caches and crashed in
# kmem_cache_alloc during RtmpOsStatsAlloc on real H298A.
# This is only a source-level mitigation, NOT an ABI compatibility proof.
echo "::group::Use stock-like direct kmalloc path in MT7612E"
python3 - "$D5/os/linux/rt_linux.c" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
for old, new in [
    ("*mem = (PUCHAR) kmalloc(size, GFP_ATOMIC);", "*mem = (PUCHAR) __kmalloc(size, GFP_ATOMIC);"),
    ("*mem = (PUCHAR) kmalloc(size, GFP_KERNEL);", "*mem = (PUCHAR) __kmalloc(size, GFP_KERNEL);"),
]:
    if s.count(old) != 1:
        raise SystemExit(f"Expected one allocation site in {p}: {old}")
    s = s.replace(old, new)
p.write_text(s)
PY
echo "MT7612E os_alloc_mem uses __kmalloc, matching stock allocation call style" >> "$OUT/build-info.txt"
echo "::endgroup::"

echo "::group::Prepare MT7510-family Linux 2.6.36 kernel configuration"
EXACT_CONFIG="$WORKDIR/configs/h298a-zte-20220613.config"
if [[ -f "$EXACT_CONFIG" ]]; then
    echo "bb15933b81a28d722abb979ce14957069a8bb6a1dfe621bafa9060e23dfcb85d  $EXACT_CONFIG" | sha256sum -c -
    cp "$EXACT_CONFIG" "$KERNEL/.config"
    echo "Kernel configuration: firmware-extracted original ZTE config ($EXACT_CONFIG)" >> "$OUT/build-info.txt"
    sha256sum "$EXACT_CONFIG" >> "$OUT/build-info.txt"
else
    # Keeping this generic build path ONLY for comparison; a generic-built
    # module MUST NOT be considered loadable on the user's H298A.
    [[ -f "$KERNEL/mt7510_config" ]] || exit 3
    cp "$KERNEL/mt7510_config" "$KERNEL/.config"
    echo "UNSAFE FOR LIVE TEST: generic MT7510 sample config, not ZTE firmware config" >> "$OUT/build-info.txt"
fi
sed -i 's/^CONFIG_LOCALVERSION_AUTO=y/# CONFIG_LOCALVERSION_AUTO is not set/' "$KERNEL/.config"
: > "$KERNEL/.scmversion"
# Linux 2.6.36 expects version-specific compiler-gccN.h. Its vendor tree
# only knows GCC 4, while Ubuntu 22.04 ships MIPS GCC 10. Use the older
# definitions as a *build compatibility shim*, not an ABI guarantee.
gcc_major="$("$CROSS"gcc -dumpversion | cut -d. -f1)"
if (( gcc_major > 4 )); then
    hdr="$KERNEL/include/linux/compiler-gcc$gcc_major.h"
    cp "$KERNEL/include/linux/compiler-gcc4.h" "$hdr"
    cat >> "$hdr" <<'EOF'
#ifndef __noclone
#define __noclone __attribute__((__noclone__))
#endif
#ifndef unreachable
#define unreachable() __builtin_unreachable()
#endif
#ifndef __compiletime_warning
#define __compiletime_warning(message) __attribute__((warning(message)))
#endif
#ifndef __compiletime_error
#define __compiletime_error(message) __attribute__((error(message)))
#endif
EOF
    echo "GCC $gcc_major compatibility shim: $hdr" >> "$OUT/build-info.txt"
fi
echo "Kernel source headers are still generic vendor BSP, NOT the exact ZTE kernel headers" >> "$OUT/build-info.txt"
# The ZTE firmware Kconfig includes custom symbols absent from this
# different (though related) vendor source tree. Non-interactive
# silentoldconfig aborts upon NEW questions. Feed default answers, then
# record all discrepancies for the ABI investigation.
python3 - "$KERNEL" "$CROSS" "$OUT/kernel-config.log" <<'PY'
import pathlib
import subprocess
import sys
kernel, cross, logfile = sys.argv[1:]
cmd = ["make", "-C", kernel, "ARCH=mips", "CROSS_COMPILE=" + cross, "oldconfig"]
result = subprocess.run(cmd, input="\n" * 16000,
                        capture_output=True, text=True, timeout=240)
pathlib.Path(logfile).write_text(result.stdout + result.stderr)
new_count = result.stdout.count("(NEW)")
print(f"Kernel oldconfig returned {result.returncode}; NEW options: {new_count}")
print("WARNING: ZTE custom config / upstream Kconfig mismatch; no runtime ABI guarantee")
if result.returncode:
    print((result.stdout + result.stderr)[-4500:])
    sys.exit(4)
PY
if ! make -C "$KERNEL" ARCH=mips CROSS_COMPILE="$CROSS" silentoldconfig \
    >> "$OUT/kernel-config.log" 2>&1; then
    echo "Kernel silentoldconfig failed after filling defaults" >&2
    tail -50 "$OUT/kernel-config.log" >&2
    exit 4
fi
if ! make -C "$KERNEL" ARCH=mips CROSS_COMPILE="$CROSS" modules_prepare \
    > "$OUT/kernel-prepare.log" 2>&1; then
    echo "Kernel preparation failed; see build-results/kernel-prepare.log" >&2
    tail -50 "$OUT/kernel-prepare.log" >&2
    exit 4
fi
echo "::endgroup::"

# Original upstream repo contains precompiled .o and .ko files. They MUST be
# removed before a new APCLI build, otherwise the result can be stale.
build_one() {
    local path="$1" chip="$2" expected="$3" label="$4"
    echo "::group::Build $label"
    find "$path" -type f \( -name '*.o' -o -name '*.ko' -o -name '*.mod.c' \
        -o -name '.*.cmd' \) -delete
    local code=0
    make -C "$path" TARGET=LINUX PLATFORM=BB_SOC WIFI_MODE=AP \
        CHIPSET="$chip" KERNEL_DIR="$KERNEL" CROSS_COMPILE="$CROSS" \
        all > "$OUT/$label-build.log" 2>&1 || code=$?
    if [[ "$code" -ne 0 ]]; then
        echo "$label compilation failed (exit $code)" >&2
        tail -35 "$OUT/$label-build.log" >&2
        echo "::endgroup::"
        return 1
    fi
    if [[ ! -s "$path/os/linux/$expected" ]]; then
        echo "No generated module: $expected" >&2
        echo "::endgroup::"
        return 1
    fi
    cp "$path/os/linux/$expected" "$OUT/$expected"
    readelf -h "$OUT/$expected" > "$OUT/$label-elf.txt"
    readelf -p .modinfo "$OUT/$expected" > "$OUT/$label-modinfo.txt"
    readelf -Ws "$OUT/$expected" > "$OUT/$label-symbols.txt"
    sha256sum "$OUT/$expected" >> "$OUT/SHA256SUMS"
    echo "::endgroup::"
    return 0
}
FAILED=0
build_one "$D24" mt7603e mt7603eap.ko mt7603 || FAILED=1
build_one "$D5" mt7612e mt7612e_ap.ko mt7612 || FAILED=1
python3 scripts/check_modules.py "$OUT" | tee "$OUT/verification.txt" || FAILED=1
if [[ "$FAILED" -ne 0 ]]; then
    echo "One or both driver builds or static checks failed. Logs uploaded anyway." >&2
    exit 5
fi
echo "BOTH MODULES BUILT AS EXPERIMENTAL CANDIDATES. DO NOT INSmod OR FLASH."