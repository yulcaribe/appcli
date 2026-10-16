#!/usr/bin/env python3
"""V7: adapt MT7603E profile path to the REAL H298 factory readonly filesystem.

Observed on device:
  /etc/Wireless/MT7603e/RT2860AP.dat (2100 bytes)
  /etc/Wireless/MT7603e/MT7603E_EEPROM.bin (512 bytes)
The upstream generic BSP tries /etc/Wireless/RT2860AP/RT2860AP.dat.
This patch affects ONLY MT7603E/os/linux/rt_profile.c.
It does not copy profile secrets or write to the H298 filesystem.
"""
from pathlib import Path
import sys

TARGET="/etc/Wireless/MT7603e/RT2860AP.dat"

def patch(path):
    p=Path(path)
    data=p.read_text(encoding="latin-1")
    old="src = get_dev_profile(pAd);"
    if data.count(old) != 1:
        raise SystemExit("Unexpected donor RTMPReadParametersHook profile assignment")
    # Force H298-specific path after the existing upstream decision logic.
    # No profile data, password or SSID is embedded into the .ko file.
    new='src = get_dev_profile(pAd);\n' \
        '\tsrc = "' + TARGET + '";\n' \
        '\tprintk(KERN_ERR "H298V7: profile path %s\\n", src);'
    data=data.replace(old,new,1)
    p.write_text(data,encoding="latin-1")
    print("MT7603E profile path rewritten:",TARGET)

if __name__=="__main__":
    if len(sys.argv)!=2:
        raise SystemExit("usage: patch_profile_path_v7.py <MT7603E/os/linux/rt_profile.c>")
    patch(sys.argv[1])
