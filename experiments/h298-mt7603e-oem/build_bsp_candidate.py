#!/usr/bin/env python3
"""Build a 2.4GHz APCLI research candidate using the proven EN751221 BSP.

The 2014 DPA source lacks PCIe AP ring type definitions. This is an
ALTERNATIVE source port, not an OEM-compatible reconstructed driver.
"""
from pathlib import Path

out = Path("experiments/h298-mt7603e-oem/mtk-v2-bsp-build.sh")
template = Path("scripts/build.sh").read_text()
template = template.replace(
    'OUT="$WORKDIR/build-results"',
    'OUT="$WORKDIR/experiments/h298-mt7603e-oem/out/mtk-v2-bsp"'
)
anchor = 'echo "::group::Prepare MT7510-family Linux 2.6.36 kernel configuration"'
patch = """echo "::group::Apply MT7603E OEM allocation experiments"
python3 - "$D24/os/linux/rt_linux.c" <<'PY_FIX'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
for old, new in (
    ('*mem = (PUCHAR) kmalloc(size, GFP_ATOMIC);',
     '*mem = (PUCHAR) __kmalloc(size, GFP_ATOMIC);'),
    ('*mem = (PUCHAR) kmalloc(size, GFP_KERNEL);',
     '*mem = (PUCHAR) __kmalloc(size, GFP_KERNEL);'),
):
    if s.count(old) != 1:
        raise SystemExit(f'Missing allocation site: {old!r}')
    s = s.replace(old, new)
# The original 2.4GHz ZTE module requests 0x70 for net_device_stats.
# This changes the allocation *length*, NOT the kernel structure layout.
old = 'sizeof (struct net_device_stats)'
if s.count(old) != 2:
    raise SystemExit(f'Expected 2 stats allocations, found {s.count(old)}')
s = s.replace(old, '112')
p.write_text(s)
print('MT7603E uses OEM-like __kmalloc and 112-byte stats buffers')
PY_FIX
cat > "$D24/os/linux/apcli_compat.c" <<'EOF'
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
python3 - "$D24/os/linux/Makefile.6" <<'PY_MK'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
needle = 'obj-m := $(MOD_NAME).o'
if s.count(needle) != 1:
    raise SystemExit('Unexpected BSP Makefile.6 structure')
p.write_text(s.replace(needle, 'obj_cmm += ../../os/linux/apcli_compat.o\\n'+needle, 1))
PY_MK
echo "::group::Disable stray BBU proc dependency in 2.4GHz MT7603E"
python3 - "$D24/os/linux/pci_main_dev.c" <<'PY_BBU'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
# H298 ZTE module has no pAd_save import. The donor always compiles BBU's
# tc3162/sta_info proc feature with BB_SOC but does not compile the matching
# pAd_save storage (conditionally compiled in bb_soc.c).
# Exclude ONLY this optional proc diagnostic from 2.4 GHz driver build.
sites = [
    '#ifdef BB_SOC\\nextern RTMP_ADAPTER *pAd_save;',
    '#ifdef BB_SOC\\n        struct proc_dir_entry *wifi_proc;',
    '#ifdef BB_SOC\\n        wifi_proc=create_proc_entry("tc3162/sta_info", 0, NULL);',
    '#ifdef BB_SOC\\n    remove_proc_entry("tc3162/sta_info",0);',
    '#ifdef BB_SOC\\nunsigned int BBUWlanStaInfo(void)'
]
for old in sites:
    if s.count(old) != 1:
        raise SystemExit('Unexpected source: ' + repr(old))
    new = old.replace('#ifdef BB_SOC',
                      '#if defined(BB_SOC) && defined(H298_ENABLE_BBU_STAINFO_PROC)', 1)
    s = s.replace(old, new, 1)
p.write_text(s)
print('Disabled unused BBU proc sta_info while keeping PCIe probe/remove.')
PY_BBU
echo "pAd_save: removed optional tc3162/sta_info path (2.4GHz only)" >> "$OUT/build-info.txt"
python3 experiments/h298-mt7603e-oem/patch_netdev_abi_v3.py "$D24/os/linux/rt_linux.c"
echo "V3 net_device OEM field offset adaptation in rt_linux.c only" >> "$OUT/build-info.txt"
echo "::endgroup::"
echo "2.4GHz allocation and symbol experimental patch applied; full OEM ABI still unknown." >> "$OUT/build-info.txt"
echo "::endgroup::"

"""
if template.count(anchor) != 1:
    raise SystemExit("Cannot find kernel-preparation anchor")
template = template.replace(anchor, patch + anchor)
# Compile 2.4 GHz only. The kernel and the common BSP are prepared by the
# pinned original pipeline, but the 5 GHz module is not rebuilt or published.
single_band = 'build_one "$D5" mt7612e mt7612e_ap.ko mt7612 || FAILED=1'
if template.count(single_band) != 1:
    raise SystemExit('Expected one 5GHz build line')
template = template.replace(single_band,
                            'echo "Skipping MT7612E in 2.4GHz-only experiment"')
check_call = 'python3 scripts/check_modules.py "$OUT" | tee "$OUT/verification.txt" || FAILED=1'
if template.count(check_call) != 1:
    raise SystemExit('Expected one old two-band check invocation')
verification = """python3 - "$OUT/mt7603eap.ko" "$OUT/verification.txt" <<'PY_VERIFY' || FAILED=1
from pathlib import Path
import subprocess
import sys
mod, report = map(Path, sys.argv[1:])
if not mod.is_file():
    raise SystemExit("2.4GHz module absent")
def call(*args):
    return subprocess.check_output(args, text=True)
undefined = call("mips-linux-gnu-nm", "-u", str(mod))
all_symbols = call("mips-linux-gnu-nm", "-a", str(mod))
elf = call("readelf", "-h", str(mod))
modinfo = call("readelf", "-p", ".modinfo", str(mod))
pad = any(line.strip().split()[-1] == "pAd_save" for line in undefined.splitlines() if line.strip())
arch = "MIPS" in elf and "big endian" in elf
magic = "2.6.36 SMP mod_unload MIPS32_R2 32BIT MT_SMTC" in modinfo
apcli = "ApCli" in all_symbols
summary = "\\n".join([
    "MT7603E 2.4 GHz ONLY",
    "UNDEFINED pAd_save: " + str(pad),
    "MIPS BE: " + str(arch),
    "H298 vermagic: " + str(magic),
    "APCLI symbols: " + str(apcli),
    "Undefined symbols (note: OEM kernel may provide some):",
    undefined,
    "WARNING: Symbol check does not prove full ZTE kernel ABI compatibility.",
    "WARNING: RTMP_ADAPTER layout differs from OEM binary.",
])
report.write_text(summary)
print(summary)
if pad or not (arch and magic and apcli):
    raise SystemExit(5)
PY_VERIFY"""
template = template.replace(check_call, verification)

out.write_text(template)
print(out)
