#!/usr/bin/env python3
"""Offline/read-only stock ZTE H298 MT7603E/MT7612E binary inspection.

Requires Python3, binutils readelf, and genuine OEM .ko files as args.
Never patches ELF, writes to router, or claims a functional APCLI driver.
"""
import argparse
import collections
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

EXPECTED={
  "2g":"4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5",
  "5g":"2ee8df1b1fbad51f34645dd773009acf59fc37ea90ac9d00365ef91a516adee2",
}
APCLI_REQUIRED=[
    "ApCliIfUp","ApCliLinkUp","ApCliAuthStateMachineInit",
    "ApCliAssocStateMachineInit","ApCliCtrlStateMachineInit",
    "Set_ApCli_Enable_Proc","Set_ApCli_Ssid_Proc","Set_ApCli_WPAPSK_Proc",
]

def cmd(*argv):
    return subprocess.check_output(argv,text=True,stderr=subprocess.PIPE)

def symbols(path):
    data=[]
    for ln in cmd("readelf","-Ws",str(path)).splitlines():
        f=ln.split()
        if len(f)<8 or not f[0].endswith(":"):continue
        try: data.append((f[7],f[3],f[4],f[6],int(f[2])))
        except ValueError: pass
    return data

def relocation_function_references(path, functions):
    caller=None; refs=collections.Counter()
    for ln in cmd("readelf","-Wr",str(path)).splitlines():
        m=re.match(r"Relocation section '[.]rel[.]text[.]([^']+)'",ln)
        if m:
            caller=m.group(1);continue
        if ln.startswith("Relocation section "):
            caller=None;continue
        fields=ln.split()
        if not caller or len(fields)<5:continue
        target=fields[4]
        if target.startswith(".text."):target=target[len(".text."):]
        if (target in functions and target!=caller
                and fields[2] in ("R_MIPS_26","R_MIPS_HI16","R_MIPS_LO16","R_MIPS_32")):
            refs[(caller,target)]+=1
    return refs

def inspect(path,band,out):
    data=path.read_bytes()
    sha=hashlib.sha256(data).hexdigest()
    if sha!=EXPECTED[band]:
        raise ValueError("Wrong OEM module digest: "+str(path)+" SHA256 "+sha)
    elf=cmd("readelf","-h",str(path))
    if not ("big endian" in elf and "MIPS" in elf):
        raise ValueError("ELF not MIPS big-endian")
    syms=symbols(path)
    funcs={name:size for name,kind,binding,sec,size in syms
           if kind=="FUNC" and sec!="UND" and size}
    imports=sorted({name for name,kind,binding,sec,size in syms if sec=="UND"})
    exports=[]
    for ln in cmd("readelf","-p","__ksymtab_strings",str(path)).splitlines():
        m=re.search(r"\]\s+(.+)",ln)
        if m:exports.append(m.group(1).strip())
    refs=relocation_function_references(path,funcs)
    with (out/(band+"_functions.csv")).open("w",newline="") as stream:
        w=csv.writer(stream);w.writerow(["symbol","size_bytes"])
        w.writerows(sorted(funcs.items()))
    with (out/(band+"_function_refs.csv")).open("w",newline="") as stream:
        w=csv.writer(stream)
        w.writerow(["source_symbol","target_symbol","relocation_references_not_proven_calls"])
        w.writerows([caller,target,num] for (caller,target),num in sorted(refs.items()))
    summary={
       "band":band,"sha256":sha,"original_bytes":len(data),
       "functions":len(funcs),"imports":imports,"exports":exports,
       "function_relocation_reference_pairs":len(refs),
       "named_apcli":sorted(x for x in funcs if re.search(r"(?i)(?:^ApCli|_apcli|Set_ApCli)",x)),
       "apcli_required_symbols":{f:f in funcs for f in APCLI_REQUIRED},
       "wds_named_symbols":sorted(x for x in funcs if "wds" in x.lower()),
       "vermagic":cmd("readelf","-p",".modinfo",str(path)).split("vermagic=")[-1].splitlines()[0],
       "caution":"Named-symbol absence is not formal proof against all inlined code. A .ko does not contain source code, and no APCLI implementation has been supplied."
    }
    (out/(band+"_summary.json")).write_text(json.dumps(summary,indent=2,ensure_ascii=False)+"\n")
    return summary

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--stock2g",type=Path,required=True)
    p.add_argument("--stock5g",type=Path,required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args()
    a.out.mkdir(parents=True,exist_ok=True)
    results=[inspect(a.stock2g,"2g",a.out),inspect(a.stock5g,"5g",a.out)]
    for result in results:
        print(result["band"],"functions",result["functions"],
              "apcli",len(result["named_apcli"]),
              "exports",len(result["exports"]),
              "function refs",result["function_relocation_reference_pairs"])
    print("Offline OEM binary audit only; NOT an APCLI driver")

if __name__=="__main__":sys.exit(main())
