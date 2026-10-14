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

echo "::group::Prepare MT7510-family Linux 2.6.36 kernel (NOT original ZTE kernel)"
[[ -f "$KERNEL/mt7510_config" ]] || exit 3
cp "$KERNEL/mt7510_config" "$KERNEL/.config"
sed -i 's/^CONFIG_LOCALVERSION_AUTO=y/# CONFIG_LOCALVERSION_AUTO is not set/' "$KERNEL/.config"
: > "$KERNEL/.scmversion"
echo "Using vendor sample mt7510_config, not a verified H298A .config" >> "$OUT/build-info.txt"
if ! make -C "$KERNEL" ARCH=mips CROSS_COMPILE="$CROSS" silentoldconfig \
    > "$OUT/kernel-config.log" 2>&1; then
    echo "Kernel configuration failed; see build-results/kernel-config.log" >&2
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