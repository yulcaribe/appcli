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
echo "2.4GHz allocation and symbol experimental patch applied; full OEM ABI still unknown." >> "$OUT/build-info.txt"
echo "::endgroup::"

"""
if template.count(anchor) != 1:
    raise SystemExit("Cannot find kernel-preparation anchor")
template = template.replace(anchor, patch + anchor)
out.write_text(template)
print(out)
