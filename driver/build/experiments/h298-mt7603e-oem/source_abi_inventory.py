#!/usr/bin/env python3
"""Whole-tree *inventory*, not a code safety proof.

Read EVERY donor source/header under MT7603, list kernel-facing API and
layout-sensitive operations. Meant to accompany binary OEM ABI gate.
Do NOT conflate lexical coverage with matching OEM ABI.
"""
from collections import defaultdict
from pathlib import Path
import argparse
import json
import re
import sys

PATTERNS={
  "skb_direct_members":r"\b(?:skb|pkt|pPacket|pRxPacket|net_pkt)\s*->\s*(?:data|len|head|tail|end|cb|dev|next|prev|truesize|users)\b",
  "skb_inline_ops":r"\b(?:skb_push|skb_pull|skb_put|skb_reserve|skb_clone|skb_copy|skb_shinfo|skb_headroom|skb_tailroom|skb_headlen|skb_trim)\s*\(",
  "rt_os_packet_macros":r"\b(?:GET_OS_PKT_\w+|SET_OS_PKT_\w+|OS_PKT_\w+|RTMP_QueryPacketInfo)\s*\(",
  "netdevice_fields":r"\b(?:dev|net_dev|pNetDev)\s*->\s*(?:netdev_ops|ethtool_ops|dev_addr|_tx|priv_flags|stats|features|flags|ml_priv)\b",
  "netdevice_queue":r"\b(?:netif_start_queue|netif_stop_queue|netif_wake_queue|netif_carrier_on|netif_carrier_off|netdev_priv)\s*\(",
  "dma_api":r"\b(?:PCI_MAP_SINGLE|PCI_MAP_SINGLE_DEV|pci_map_single|dma_map_single|pci_unmap_single|dma_unmap_single|RtmpDrvPciMapSingle|RTMP_DCACHE_FLUSH)\s*\(",
  "pci_irq_api":r"\b(?:pci_|RtmpOSIRQRequest|RTMP_OS_IRQ_REQUEST|request_irq|free_irq)\w*\s*\(",
  "eeprom_firmware_io":r"\b(?:RtmpOSFileOpen|RTMPReadParametersHook|rtmp_ee_load_from_bin|NICReadEEPROMParameters|AsicLoadFirmware|FwInit)\s*\(",
  "apcli_symbols":r"\b(?:ApCli\w+|Set_ApCli_\w+)\s*\(",
  "vendor_net_hooks":r"\b(?:wlan_cspkernel_ops|ffe_receive_skb_locked|ffe_learn_skb|ra_sw_nat_hook_rx|alloc_etherdev_mqs)\b",
}

def collect(root):
    summary={}
    files=[]
    for p in sorted(root.rglob("*")):
        if not p.is_file() or p.suffix not in (".c",".h"):continue
        rel=p.relative_to(root).as_posix()
        source=p.read_text(encoding="latin-1",errors="replace")
        counters={}
        examples={}
        for cat,pat in PATTERNS.items():
            compiled=re.compile(pat)
            hits=list(compiled.finditer(source))
            if not hits:continue
            counters[cat]=len(hits)
            examples[cat]=[{"line":source.count("\n",0,m.start())+1,"expr":m.group(0)[:75]} for m in hits[:5]]
        files.append({"source":rel,"line_count":source.count("\n")+1,
                      "bytes":len(source),"counts":counters,"examples":examples})
    total={cat:sum(f["counts"].get(cat,0) for f in files) for cat in PATTERNS}
    source_count={cat:sum(bool(f["counts"].get(cat)) for f in files) for cat in PATTERNS}
    high_risk=[{"source":f["source"],"skb":f["counts"].get("skb_direct_members",0)+f["counts"].get("skb_inline_ops",0)+f["counts"].get("rt_os_packet_macros",0),
                "dma":f["counts"].get("dma_api",0),
                "netdev":f["counts"].get("netdevice_fields",0)+f["counts"].get("netdevice_queue",0)}
               for f in files]
    high_risk=sorted(high_risk,key=lambda f:f["skb"]+f["dma"]+f["netdev"],reverse=True)
    return {"status":"INVENTORY_ONLY_NOT_ABI_CERTIFICATION",
            "root":str(root),"scanned_source_files":len(files),
            "bytes_scanned":sum(f["bytes"] for f in files),
            "source_lines_scanned":sum(f["line_count"] for f in files),
            "per_category_hits":total,"per_category_files":source_count,
            "highest_kernel_abi_contact_files":high_risk[:60],
            "files":files,
            "limitations":[
              "Pattern matching includes comments and macro definitions; not a preprocessed program, control flow, or a proof.",
              "Only mtk-v2 OEM source can establish actual factory struct layout; generic BSP is a different kernel.",
              "No automated pass until binary OEM ABI gate and exact patched header compatibility are demonstrated.",
            ]}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("driver_dir")
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    root=Path(args.driver_dir).resolve()
    if not (root/"os/linux/rt_linux.c").is_file():
        raise SystemExit("Wrong source root, missing os/linux/rt_linux.c")
    report=collect(root)
    Path(args.output).write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n")
    print("Scanned",report["scanned_source_files"],"source files and",report["source_lines_scanned"],"lines")
    print("Kernel ABI-sensitive reference counts:")
    for k,v in report["per_category_hits"].items():print(" ",k,v)
    print("Status:",report["status"])
    return 0

if __name__=="__main__":sys.exit(main())
