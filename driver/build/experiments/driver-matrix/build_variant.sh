#!/usr/bin/env bash
# Five isolated source-feature experiments. Never installs any driver.
set -Eeuo pipefail
cd "$(git rev-parse --show-toplevel)"
: "${H298A_PROFILE:?Select a driver feature profile}"
case "$H298A_PROFILE" in
  zte-stocklike) APCLI=n; WDS=y; CLIENT_WDS=n; MAC_REPEATER=n ;;
  apcli-minimal) APCLI=y; WDS=n; CLIENT_WDS=n; MAC_REPEATER=n ;;
  apcli-wds) APCLI=y; WDS=y; CLIENT_WDS=n; MAC_REPEATER=n ;;
  apcli-client-wds) APCLI=y; WDS=y; CLIENT_WDS=y; MAC_REPEATER=n ;;
  apcli-mac-repeater) APCLI=y; WDS=n; CLIENT_WDS=n; MAC_REPEATER=y ;;
  *) printf 'Invalid profile: %s\n' "$H298A_PROFILE" >&2; exit 64 ;;
esac
mkdir -p "experiments/driver-matrix/out/$H298A_PROFILE"
# Modify a temporary COPY of our known-working build script, not the original.
python3 - "$H298A_PROFILE" "$APCLI" "$WDS" "$CLIENT_WDS" "$MAC_REPEATER" <<'PY'
import pathlib, sys
name, apcli, wds, client_wds, mac_repeater = sys.argv[1:]
source = pathlib.Path('scripts/build.sh').read_text()
assert source.count('OUT="$WORKDIR/build-results"') == 1
source = source.replace(
    'OUT="$WORKDIR/build-results"',
    'OUT="$WORKDIR/experiments/driver-matrix/out/${H298A_PROFILE}"'
)
start = source.index('echo "::group::Enable APCLI in both vendor configuration files for each driver"')
end = source.index('# Vendor MT7612 APCLI branch', start)
replacement = """echo "::group::Apply pinned source feature profile"
for driver in "$D24" "$D5"; do
    for cfg in config_BBU.mk config.mk; do
        file="$driver/os/linux/$cfg"
        [[ -f "$file" ]] || exit 3
        cp "$file" "$OUT/$(basename "$driver")-$cfg.original"
        python3 - "$file" "${H298A_APCLI}" "${H298A_WDS}" "${H298A_CLIENT_WDS}" "${H298A_MAC_REPEATER}" <<'PY_FLAGS'
from pathlib import Path
import re, sys
path = Path(sys.argv[1])
features = dict(zip(
    ('APCLI', 'WDS', 'CLIENT_WDS_SUPPORT', 'MAC_REPEATER_SUPPORT'),
    sys.argv[2:]
))
contents = path.read_text()
for key, value in features.items():
    pattern = rf'(?m)^(HAS_{key})=[yn]$'
    contents, count = re.subn(pattern, lambda m: m.group(1) + '=' + value, contents)
    if not count:
        raise SystemExit(f"Missing HAS_{key} in {path}")
    print(f"{path}: HAS_{key}={value}, branches={count}")
path.write_text(contents)
PY_FLAGS
        cp "$file" "$OUT/$(basename "$driver")-$cfg.profile"
    done
done
echo "::endgroup::"

"""
source = source[:start] + replacement + source[end:]
if name == 'apcli-client-wds':
    # The pinned upstream CLIENT_WDS code path has one unmatched '(' in ap_data.c.
    # Correct the two matching C source sites in the TEMPORARY vendor checkout.
    # No production or stock ZTE module is changed.
    fix = """python3 - "$D24/ap/ap_data.c" "$D5/ap/ap_data.c" <<'PY_CLIENT'
from pathlib import Path
import sys
before = 'if ((pEntry && (pEntry->Sst == SST_ASSOC)) {'
after = 'if (pEntry && (pEntry->Sst == SST_ASSOC)) {'
for filename in sys.argv[1:]:
    path = Path(filename)
    source = path.read_text()
    if source.count(before) != 1:
        raise SystemExit(f'Expected exactly one CLIENT_WDS syntax bug in {path}')
    path.write_text(source.replace(before, after))
    print('Patched known CLIENT_WDS syntax in', path)
PY_CLIENT
python3 - "$D24/common/cmm_data.c" "$D5/common/cmm_data.c" <<'PY_CLIENT_BSSID'
from pathlib import Path
import sys
old_fields = (
    'pAd->ApCfg.MBSSID[pMacEntry->func_tb_idx].Bssid',
    'pAd->ApCfg.MBSSID[pMacEntry->apidx].Bssid',
)
new_fields = (
    'pAd->ApCfg.MBSSID[pMacEntry->func_tb_idx].wdev.bssid',
    'pAd->ApCfg.MBSSID[pMacEntry->apidx].wdev.bssid',
)
for filename, before, after in zip(sys.argv[1:], old_fields, new_fields):
    path = Path(filename)
    source = path.read_text()
    if source.count(before) != 1:
        raise SystemExit(f'Expected exactly one old CLIENT_WDS Bssid field in {path}')
    path.write_text(source.replace(before, after))
    print('Adjusted CLIENT_WDS to wifi_dev.bssid in', path)
PY_CLIENT_BSSID
"""
    anchor_client = '# Vendor MT7612 APCLI branch'
    assert source.count(anchor_client) == 1
    source = source.replace(anchor_client, fix + '\n' + anchor_client, 1)
# Keep compilation success distinct from ABI approval. Gate failure is recorded,
# never silently promoted into a 'safe to load' claim.
anchor = 'python3 scripts/check_modules.py "$OUT" | tee "$OUT/verification.txt" || FAILED=1'
assert source.count(anchor) == 1
source = source.replace(anchor, """
audit_code=0
python3 scripts/check_modules.py "$OUT" > "$OUT/verification.txt" 2>&1 || audit_code=$?
cat "$OUT/verification.txt"
printf 'STATIC_ABI_GATE_EXIT=%s\\n' "$audit_code" > "$OUT/UNSAFE_DEVICE_LOAD.txt"
cat >> "$OUT/UNSAFE_DEVICE_LOAD.txt" <<'WARNING'
DO NOT INSMOD/RMMOD/FLASH ON THE H298A.
The H298A's original OEM 2022 Wi-Fi source and patched kernel headers
are not available. This is a related EN751221 BSP, not exact ZTE source.
A previous candidate produced a real H298A kernel Oops.
Compilation is NOT hardware ABI compatibility or WPA2 association proof.
WARNING
""")
source = source.replace(
    'echo "BOTH MODULES BUILT AS EXPERIMENTAL CANDIDATES. DO NOT INSmod OR FLASH."',
    'echo "Compiled two $H298A_PROFILE modules for offline inspection only. DO NOT LOAD."'
)
out = pathlib.Path('experiments/driver-matrix/generated-build.sh')
out.write_text(source)
print('Prepared build for', name, 'feature switches:', apcli, wds, client_wds, mac_repeater)
PY
H298A_APCLI="$APCLI" H298A_WDS="$WDS" \
H298A_CLIENT_WDS="$CLIENT_WDS" H298A_MAC_REPEATER="$MAC_REPEATER" \
  bash experiments/driver-matrix/generated-build.sh
