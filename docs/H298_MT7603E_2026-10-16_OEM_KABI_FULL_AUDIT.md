# H298 / ZXHN H298A: OEM MT7603E vs. generic BSP integrated APCLI audit

**Date:** 2026-10-16 | **Branch:** dev/h298-mt7603e-oem-abi-port | **Status:** NOT VERIFIED TO LIVE-LOAD

Offline comparison of user-provided original ZTE MT7603E ELF vs. experimental V7. Factory binaries are **not** published to this repository.

## Binary baseline

| Metric | Factory OEM | Experimental V7 |
|---|---|---|
| Driver size | 2,778,084 bytes | 1,854,400 bytes |
| SHA-256 | 4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5 | 016046fb7193680a300f5f80b4855b2574c60d3e0f1bf92e5d39b468ee1dbf4c |
| GCC compiler | 4.3.4 | 10.3.0 |
| MIPS target | 32-bit big-endian, MIPS32R2 | Same |
| Kernel vermagic | 2.6.36 SMP mod_unload MIPS32_R2 32BIT MT_SMTC | Same |
| Defined functions | 2133 | 1702 |
| Common function names | 1462 | 1462 |
| Factory-only functions | 671 | absent in donor |
| Candidate-only functions | absent in factory | 240 |

Same target/vermagic is insufficient to prove kernel ABI compatibility. Function names are not a guarantee of identical logic.

## Kernel-facing structure evidence from MIPS instructions

| Field / call | ZTE factory | Candidate V7 |
|---|---:|---:|
| skb data pointer, RTMP_QueryPacketInfo | +0xC4 | +0xD4 |
| skb len, RTMP_QueryPacketInfo | +0x58 | +0x4C |
| skb RX head from RTMP_AllocateRxPacketBuffer | +0xB8 | V6 manual edit +0xB8 |
| RTMP_ADAPTER allocation, RTMPAllocAdapterBlock | 1,178,968 (0x11FD58) | 484,864 (0x76600) |
| RtmpOsStatsAlloc allocation | 112B | 112B |

The early V6 RX fix addressed one path; it did **not** rewrite other skb inlines and driver packet helper accesses. A full MIPS instruction-level review of RTMP_QueryPacketInfo proves generic skb offsets still compile into V7. This explains why a firmware DMA command may see a bogus or zero data length. A single fix in AndesMTPciKickOutCmdMsg is insufficient.

RTMP_ADAPTER is private to the driver. Its size mismatch means a different vendor feature/build variant; it is not *by itself* a kernel ABI violation. Similarly, a 112-byte stats allocation does NOT validate all net_device_stats members.

## Vendor APIs and kernel source

OEM external integration includes wlan_cspkernel_ops, ffe_receive_skb_locked, ffe_learn_skb, ra_sw_nat_hook_rx and specialized packet paths. These are absent in the candidate. Different imports and call conventions cannot be fixed safely with guessed wrappers. Earlier netdev layout patches cover only some members.

Factory source path: /home/ws/mtk7510/csp/component/wlan/mtk_v2/drivers/MT7603e/

Factory kernel header path embedded in ELF: /home/ws/mtk7510/csp/opensource/cspkernel3.4/linux/include/linux/netdevice.h

The directory name cspkernel3.4 is not proof that the running kernel is 3.4. Measured vermagic remains 2.6.36.

## V1 through V7 device observations

- V1 failed to load due to undefined pAd_save.
- V2/V3/V3.1 had kernel faults during attach.
- V4 loaded, but ra0 opening crashed.
- V5 identified RX DMA BadVA=0x20.
- V6 reached profile loader after RX DMA, then failed because the generic /etc/Wireless/RT2860AP/RT2860AP.dat path was absent.
- V7 loaded the real /etc/Wireless/MT7603e/RT2860AP.dat, initialized RX rings and parsed firmware information, but kernel BUG at r4k_dma_cache_wback_inv via AndesMTPciKickOutCmdMsg; no functional ra0 or APCLI interface was confirmed.

The factory MT7603E_EEPROM.bin file at /etc/Wireless/MT7603e/ is 512B. The donor tries nonexistent /etc/RT30xxEEPROM.bin. Branch now applies a targeted read-only EEPROM profile path correction; does not alter modem files.

## Required full compatibility verification

1. Obtain exact ZTE mtk_v2 MT7603e GPL driver, its patched Linux kernel headers, build configuration, firmware revision and original compiler GCC 4.3.4.
2. Build a stock-equivalent AP-only baseline FIRST; audit every kernel-facing struct: sk_buff (including recycling, head, data, tail, len), net_device, net_device_ops, netdev_queue, net_device_stats, PCI/DMA types, callback signatures, vendor hooks, IRQ, hotplug and SMP/MT_SMTC behavior.
3. Audit private firmware/control ring structures for driver variant equivalence. Reconstructing the entire RTMP_ADAPTER from a different source by magic offsets is unsafe.
4. Once the AP-only driver matches OEM ABI and operates, compile APCLI, MAT/WPA2/client state machine/WDS features and test association, packet flow, bridge/DHCP, roaming, restart and failure paths.
5. Fail closed: do not call any experimental .ko production-ready based only on successful insmod or vermagic. Retain RAM-only testing, physical Ethernet and independent recovery.

ZTE states source for GPL-governed components can be requested through https://opensource.ztedevices.com/ if a model is not listed. Do not assume the matching tree has been obtained until verified.

## Changes made on the dev branch

- Preserved V5/V6/V7 prototype code and experimental patch history.
- Added patch_oem_eeprom_path.py and wired factory 2.4 GHz EEPROM into the source-generation pipeline.
- Added oem_abi_gate.py with OEM disassembly-derived checks and explicit BLOCKED status.
- Added an ABI report step to experimental GitHub Actions; output OEM_ABI_GATE.json is archived.
- Main branch and real modem filesystem remain unchanged.

**Conclusion:** No safe, functional H298 APCLI driver is verified. Current blockers are structural; iterative runtime-crash patching must not substitute for real OEM source and kernel ABI reconstruction.


## Automated whole-donor source inventory (verified CI 38828995554)

A separate runner step scanned the **entire patched generic MT7603 donor tree** (all 407 C/H files, 311,610 source lines, 10,771,028 source bytes). This is a file-by-file *lexical inventory*, **not** proof that all behaviors match the unknown OEM source.

| Risk category (including comments and macros) | Occurrences |
|---|---:|
| Direct skb member access | 26 |
| skb inline manipulation | 51 |
| OS packet helper macros | 252 |
| net_device struct fields | 8 |
| netdevice queue operations | 13 |
| DMA operations and wrappers | 64 |
| PCI/IRQ operations | 74 |
| EEPROM/firmware/profile operations | 31 |
| APCLI call sites | 258 |
| vendor networking references | 8 |

Highest-risk contact files: os/linux/rt_linux.c, common/cmm_data_pci.c, include/os/rt_linux.h, common/cmm_data.c, mcu/andes_mt.c, common/cmm_mac_pci.c, tx_rx/wdev_rx.c. These contain widely used packet and DMA paths; offset changes must be handled at the correct OEM kernel header/toolchain layer rather than individually.

GitHub Actions run: https://github.com/yulcaribe/appcli/actions/runs/38828995554

CI artifact contains **OEM_SOURCE_ABI_INVENTORY.json** with per-file, per-category counts and line-number samples, plus **OEM_ABI_GATE.json**, which returns **BLOCKED** for skb_data, skb_len, and RTMP_ADAPTER allocation mismatch. This preserves measurable results for every source revision.
