#!/usr/bin/env python3
"""Compare original ZTE H298 MT7603E module with reverse-engineered candidate."""
import argparse
import hashlib
import re
import subprocess
from pathlib import Path

EXPECTED_STOCK_SHA = "4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5"
IMPORTANT_ZTE_IMPORTS = {"wlan_cspkernel_ops", "ffe_receive_skb_locked",
                         "ffe_learn_skb", "alloc_etherdev_mqs"}

def read_output(*argv):
    return subprocess.check_output(argv, text=True, stderr=subprocess.PIPE)

def summarize(path):
    hdr = read_output("readelf", "-h", str(path))
    sec = read_output("readelf", "-p", ".modinfo", str(path))
    nm = read_output("nm", "-a", str(path))
    keys = {}
    for k in ("Class", "Data", "Machine", "Flags"):
        m = re.search(r"^\s*" + k + r":\s*(.+)$", hdr, re.M)
        keys[k] = m.group(1).strip() if m else "UNKNOWN"
    match = re.search(r"vermagic=([^\n]+)", sec)
    keys["vermagic"] = match.group(1).strip() if match else "UNKNOWN"
    imported = set(re.findall(r"(?m)^\s*(?:[0-9a-fA-F]+\s+)?U\s+(\S+)$", nm))
    defined = set(re.findall(r"(?m)^\s*[0-9a-fA-F]+\s+[Tt]\s+(\S+)$", nm))
    return keys, imported, defined

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("original")
    ap.add_argument("candidate")
    args = ap.parse_args()
    original, candidate = Path(args.original), Path(args.candidate)
    digest = hashlib.sha256(original.read_bytes()).hexdigest()
    if digest != EXPECTED_STOCK_SHA:
        print("WARNING: This is not the known H298 stock module:", digest)
    left, original_imports, _ = summarize(original)
    right, candidate_imports, candidate_defined = summarize(candidate)
    mismatch = [key for key in left if left[key] != right[key]]
    for key in left:
        print("%s: stock=%s candidate=%s" % (key, left[key], right[key]))
    print("Missing stock ZTE imports:", sorted((original_imports & IMPORTANT_ZTE_IMPORTS) - candidate_imports))
    print("Additional candidate imports:", sorted(candidate_imports - original_imports))
    print("APCLI features:", sorted(s for s in candidate_defined if s in {"ApCliIfUp", "ApCliLinkUp", "Set_ApCli_Enable_Proc"}))
    print("Mismatched ELF fields:", mismatch)
    print("ABI NOT PROVEN: C struct offsets, callbacks, compiler codegen, and ZTE hooks remain to be validated.")
    return 2 if digest != EXPECTED_STOCK_SHA or mismatch or ((original_imports & IMPORTANT_ZTE_IMPORTS) - candidate_imports) else 0

if __name__ == "__main__":
    raise SystemExit(main())
