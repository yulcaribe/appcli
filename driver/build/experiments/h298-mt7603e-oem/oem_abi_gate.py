#!/usr/bin/env python3
"""Fail-closed ABI compatibility gate for H298 factory MT7603E.

Uses MIPS32 big-endian ELF relocatable code (no GDB or device access).
Expected OEM offsets are measured from the genuine ZTE 2.4GHz .ko,
SHA-256 4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5.
A passing static gate still does not prove a working or safe driver.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import struct
import sys

OEM = {
    "sha256": "4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5",
    "skb_data": 0xC4,
    "skb_len": 0x58,
    "adapter_bytes": 0x11FD58,
    "netdev_stats_bytes": 0x70,
    "vermagic": "2.6.36 SMP mod_unload MIPS32_R2 32BIT MT_SMTC",
}
API = ["wlan_cspkernel_ops", "ffe_receive_skb_locked", "ffe_learn_skb",
       "ra_sw_nat_hook_rx", "alloc_etherdev_mqs"]


def tool(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE)


def inspect(path):
    p=Path(path)
    blob=p.read_bytes()
    hdr=tool("readelf","-h",str(p))
    if ("big endian" not in hdr or "Machine:                           MIPS" not in hdr):
        raise ValueError("Target must be MIPS big-endian")
    sections={}
    for line in tool("readelf","-SW",str(p)).splitlines():
        m=re.search(r"\[\s*(\d+)\]\s+(\S+)\s+\S+\s+[0-9a-f]+\s+([0-9a-f]+)\s+([0-9a-f]+)\b",line)
        if m:sections[int(m.group(1))]={"name":m.group(2),"start":int(m.group(3),16),"bytes":int(m.group(4),16)}
    funcs={}
    imports=set()
    for line in tool("readelf","-Ws",str(p)).splitlines():
        row=line.split()
        if len(row)<8 or not row[0].endswith(":"):continue
        if row[6]=="UND":imports.add(row[7])
        if row[3]=="FUNC" and row[6].isdigit() and int(row[6]) in sections:
            funcs[row[7]]=(int(row[6]),int(row[1],16),int(row[2]))
    def code(name):
        if name not in funcs:return []
        sec,value,size=funcs[name]
        info=sections[sec]
        off=info["start"]+value
        return list(struct.unpack(">"+str(size//4)+"I",blob[off:off+size//4*4]))
    def mips_load_fields(name,reg=4):
        return [w&0xffff for w in code(name) if w>>26==0x23 and (w>>21)&31==reg]
    loads=mips_load_fields("RTMP_QueryPacketInfo",4)
    def adapter_size():
        regs={}
        for w in code("RTMPAllocAdapterBlock")[:96]:
            op=w>>26;rs=(w>>21)&31;rt=(w>>16)&31;imm=w&0xffff
            if op==0x0f:regs[rt]=imm<<16
            elif op in (0x09,0x0d) and rs in regs:
                value=regs[rs]+(imm-(0x10000 if op==0x09 and imm>=0x8000 else 0))
                if rt==6 and value>0x10000:return value
        return None
    ops=code("RtmpOsStatsAlloc")
    nums=[w&0xffff for w in ops if w>>26==0x09 and (w>>21)&31==0]
    vm=re.search(r"vermagic=([^\n]+)",tool("readelf","-p",".modinfo",str(p)))
    comp=re.search(r"GCC:[^\n]+",tool("readelf","-p",".comment",str(p)))
    return {
      "bytes":len(blob),"sha256":hashlib.sha256(blob).hexdigest(),
      "vermagic":vm.group(1).strip() if vm else None,
      "compiler":comp.group(0) if comp else None,
      "skb_data":loads[0] if len(loads)>=2 else None,
      "skb_len":loads[1] if len(loads)>=2 else None,
      "adapter_bytes":adapter_size(),
      "netdev_stats_bytes":0x70 if 0x70 in nums else None,
      "functions":len(funcs),
      "api":{x:x in imports for x in API},
      "apcli_count":sum(1 for x in funcs if x.startswith("ApCli") or x.startswith("Set_ApCli")),
    }


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("candidate")
    parser.add_argument("--stock",help="Optional private OEM module, checked against pinned SHA256")
    parser.add_argument("--output",default=None)
    parser.add_argument("--report-only",action="store_true")
    args=parser.parse_args()
    candidate=inspect(args.candidate)
    if args.stock:
        stock=inspect(args.stock)
        if stock["sha256"]!=OEM["sha256"]:
            raise ValueError("OEM binary digest mismatch; refusing to treat it as trusted reference")
        expected={k:stock[k] for k in ("skb_data","skb_len","adapter_bytes","netdev_stats_bytes","vermagic")}
    else:
        stock=None
        expected={k:OEM[k] for k in ("skb_data","skb_len","adapter_bytes","netdev_stats_bytes","vermagic")}
    failures={key:{"oem":value,"candidate":candidate[key]}
              for key,value in expected.items() if candidate[key]!=value}
    status="BLOCKED" if failures else "STATIC_ABI_FIELDS_MATCHED_REVIEW_REQUIRED"
    report={"status":status,"failures":failures,"candidate":candidate,
            "stock":stock,"caveats":[
              "All other struct offsets, callbacks, kernel custom hooks, firmwares, APCLI and safety remain unverified.",
              "Passing this static gate alone NEVER certifies a live-loadable driver.",
              "Compiler version and OEM ZTE integration differences require review.",
            ]}
    serialized=json.dumps(report,indent=2,ensure_ascii=False)+"\n"
    if args.output:Path(args.output).write_text(serialized)
    print(serialized)
    return 2 if failures and not args.report_only else 0

if __name__=="__main__":
    sys.exit(main())
