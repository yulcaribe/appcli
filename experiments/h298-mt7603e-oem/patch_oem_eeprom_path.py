#!/usr/bin/env python3
"""OEM MT7603E EEPROM source path, read-only factory file, 2.4GHz only.

ZTE H298 factory filesystem:
  /etc/Wireless/MT7603e/MT7603E_EEPROM.bin (512 bytes)
Original generic donor falls back to /etc/RT30xxEEPROM.bin (not present).
No writes to EEPROM, flash or OEM rootfs are performed here.
"""
import sys
from pathlib import Path

FACTORY="/etc/Wireless/MT7603e/MT7603E_EEPROM.bin"

def patch(name):
    p=Path(name)
    s=p.read_text(encoding="latin-1")
    needle='"/etc/RT30xxEEPROM.bin"'
    count=s.count(needle)
    if count!=2:
        raise SystemExit("Unexpected donor EEPROM header (expected 2 BIN_FILE_PATH references, got %d)" % count)
    s=s.replace(needle,'"'+FACTORY+'"')
    p.write_text(s, encoding="latin-1")
    print("EEPROM BIN_FILE_PATH redirected to factory 512-byte file:",FACTORY)

if __name__=="__main__":
    if len(sys.argv)!=2:
        raise SystemExit("usage: patch_oem_eeprom_path.py <MT7603/include/eeprom.h>")
    patch(sys.argv[1])
