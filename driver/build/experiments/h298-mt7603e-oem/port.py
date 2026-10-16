#!/usr/bin/env python3
"""H298 2.4GHz MT7603E PCIe/APCLI source port from user-supplied vendor tree.

Modifies a COPY, not original source. Must build against genuine ZTE OEM headers.
"""
from pathlib import Path
import argparse
import re
import shutil

GUARD = """/* H298 MT751020: OEM module RtmpOsStatsAlloc uses 0x70.
 * No padding workaround: compile only against a matching OEM struct layout.
 * This guard is necessary but insufficient for complete ABI equivalence.
 */
#ifndef H298_OEM_ABI_GUARD_H
#define H298_OEM_ABI_GUARD_H
#include <linux/netdevice.h>
typedef char h298_stats_exact_layout[sizeof(struct net_device_stats) == 112 ? 1 : -1];
typedef char h298_pointer_width[sizeof(void *) == 4 ? 1 : -1];
#endif
"""

def replace_one(content, before, after, filename):
    matches = content.count(before)
    if matches != 1:
        raise ValueError("%s: expected exactly one %r, found %d" % (filename, before, matches))
    return content.replace(before, after, 1)

def resolve_source(path):
    path = Path(path)
    for candidate in [path, path / "DPA", path / "MT7603U_DPA_LinuxSTA_3.0.0.4_20140825" / "DPA"]:
        if (candidate / "Makefile").is_file() and (candidate / "os/linux/config.mk").is_file():
            return candidate.resolve()
    raise ValueError("Source must contain the 2014 MT7603 DPA Makefile/config.mk")

def port(src, target):
    src = resolve_source(src)
    target = Path(target).resolve()
    if target.exists():
        raise FileExistsError("Refusing to overwrite existing directory: %s" % target)
    if src in target.parents:
        raise ValueError("Output cannot be inside vendor source tree")
    shutil.copytree(src, target, ignore=shutil.ignore_patterns(
        "*.o", "*.ko", "*.cmd", "*.mod.c", "*.mod.o",
        "*.order", "Module.symvers", ".tmp_versions"))
    makefile = target / "Makefile"
    config = target / "os/linux/config.mk"
    rt_linux = target / "os/linux/rt_linux.c"
    if not (target / "ap/apcli_link_cover.c").is_file() or not (target / "include/ap_apcli.h").is_file():
        raise ValueError("Donor does not include required MT7603 APCLI files")

    m = makefile.read_text(encoding="latin-1")
    m = replace_one(m, "RT28xx_MODE  = STA", "RT28xx_MODE  = AP", makefile)
    m = replace_one(m, "CHIPSET = mt7603u", "CHIPSET = mt7603e", makefile)
    makefile.write_text(m, encoding="latin-1")

    cfg = config.read_text(encoding="latin-1")
    cfg = replace_one(cfg, "HAS_APCLI=n", "HAS_APCLI=y", config)
    start = cfg.index("ifneq ($(findstring mt7603e,$(CHIPSET)),)")
    end = cfg.index("ifneq ($(findstring mt7603u,$(CHIPSET)),)", start)
    block = cfg[start:end]
    block = replace_one(block, "WFLAGS += -DCONFIG_FPGA_MODE",
                        "# H298 PCIe production card: FPGA disabled", config)
    cfg = cfg[:start] + block + cfg[end:]
    config.write_text(cfg, encoding="latin-1")

    c = rt_linux.read_text(encoding="latin-1")
    c = replace_one(c, "#include <linux/rtnetlink.h>",
                    '#include <linux/rtnetlink.h>\n#include "h298_oem_abi_guard.h"',
                    rt_linux)
    # Stock driver imports alloc_etherdev_mqs from its OEM kernel.
    c = replace_one(c, "alloc_etherdev(privDataSize)",
                    "alloc_etherdev_mqs(privDataSize, 1, 1)", rt_linux)
    # Native sizeof() is required; a padded 112-byte buffer is NOT a layout fix.
    if c.count("sizeof (struct net_device_stats)") < 2:
        raise ValueError("StatsAlloc native sizeof() references missing")
    rt_linux.write_text(c, encoding="latin-1")
    (target / "os/linux/h298_oem_abi_guard.h").write_text(GUARD, encoding="utf-8")
    print("Prepared MT7603E PCIe AP+APCLI driver sources:", target)
    print("OEM net_device_stats == 112 enforced at compile time.")
    print("Still needs exact ZTE kernel headers, GCC 4.3.x and OEM driver integration.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--donor", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    port(args.donor, args.output)
