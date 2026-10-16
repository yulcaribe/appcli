# H298: OEM .ko Binary-Only Reverse Engineering

**2026-10-16 | Branch dev/h298-mt7603e-oem-abi-port | NO VERIFIED APCLI DRIVER**

## Genuine OEM inputs, hashes checked

| Metric | MT7603E 2.4 GHz | MT7612E 5 GHz |
|---|---|---|
| Size | 2,778,084 B | 2,637,120 B |
| SHA-256 | 4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5 | 2ee8df1b1fbad51f34645dd773009acf59fc37ea90ac9d00365ef91a516adee2 |
| Compiler | GCC 4.3.4 | GCC 4.3.4 |
| Defined functions | 2133 | 1983 |
| Kernel undefined imports | 137 | 136 |
| Exported symbols | 10 | 0 |
| Function-symbol relocation references | 4560 | 4140 |
| Compiled functions named ApCli | 0 | 0 |
| WDS functions | 10 | 10 |

Both target ELF32 MIPS big-endian MIPS32r2, vermagic 2.6.36 SMP mod_unload MIPS32_R2 32BIT MT_SMTC.

This binary-only inventory is obtained from readelf ELF symbols/relocations, __ksymtab_strings and LLVM MIPS disassembly. A relocation reference does not necessarily imply a dynamically executed call.

## Verified original 2.4 GHz code data offsets

| Field | Original offset |
|---|---|
| sk_buff.data | +0xC4 |
| sk_buff.len | +0x58 |
| sk_buff.head | +0xB8 |
| RX reserve | 32 bytes |
| net_device.netdev_ops | +0x134 |
| net_device.ethtool_ops | +0x138 |
| net_device.dev_addr | +0x1D0 |
| net_device._tx | +0x220 |
| netdev_queue.state | tx +0x50 |
| RTMP_ADAPTER allocation (private structure, not kernel ABI) | 0x11FD58, 1,178,968B |

This list provides real field-use instructions, not a complete definition of the original C structures.

## Why a binary flag cannot enable repeater

The original module has AP-side WPA, survey/scanning, CliWds proxy and AP station association/reporting functions. However, neither OEM ELF has named APCLI client state-machine functions ApCliIfUp, ApCliLinkUp, ApCliAuthStateMachineInit, ApCliAssocStateMachineInit, ApCliCtrlStateMachineInit, Set_ApCli_Enable_Proc or Set_ApCli_WPAPSK_Proc.

The literal "ApCli" in a string and CliWds_* symbols do not establish an ordinary WPA2 Wi-Fi client capable of associating with an unrelated access point. Set_WorkMode_Proc only stores a setting in the visible disassembly; no implemented STA client engine was found.

The OEM 2.4 GHz module exports just ten functions. Unexported internal symbols cannot normally be resolved by an independent external .ko. A relocatable MIPS binary can in principle be extended, but safe APCLI requires actually implementing association, authentication, key installation, transmit and receive flow, firmware protocol, disconnection and bridging while respecting ZTE internal kernel ABI. Hex patching a mode value is not sufficient.

## Complete locally delivered reverse-engineering artifact

The user package H298_ZTE_ORIJINAL_KO_TAM_BINARY_AUDIT_2026-10-16.zip includes:
- All 2G and 5G defined-function names and sizes in CSV.
- MIPS function reference edges in CSV (possible calls or pointer references).
- Targeted original assembly for IRQ, RX skb, netdevice, radio, ioctl, workmode, WDS proxy, profile and firmware.
- Full per-band section/import/export/feature summary JSON.
- 2G-versus-5G function comparison.
- Reproducible offline Python audit script, ABI map, README and evidence notes.

**Never commit OEM proprietary .ko binaries to this repository.** Only notes and scripts belong on the development branch. Main and modem flash remain unchanged.

**Outcome:** Original .ko binary reverse engineering completed for this phase. A functioning APCLI Wi-Fi-to-Ethernet driver is NOT implemented or verified. Prior generic donor V1-V7 modules must not be described as production-ready.
