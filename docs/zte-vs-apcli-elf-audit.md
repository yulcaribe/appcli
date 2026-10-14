# ZTE H298A stock vs APCLI candidate: ELF ABI audit

**Status:** build #16 (`38643129823`, commit `a42e1d4`) compiles two modules but the static compatibility gate **fails**. **Do not load these candidate modules on the H298A.**

Compared actual ZTE firmware binaries (`/lib/modules/mt7603eap.ko`, `/lib/modules/mt7612e_ap.ko`) to GitHub Actions build #16 candidates, using ELF symbol tables, MIPS disassembly, and the router's June 2022 kernel configuration.

| Module | ZTE size | Candidate size | ZTE defined functions | Candidate defined functions |
|---|---:|---:|---:|---:|
| `mt7603eap.ko` (2.4 GHz) | 2,778,084 B | 1,853,084 B | 2,133 | 1,702 |
| `mt7612e_ap.ko` (5 GHz) | 2,637,120 B | 1,743,412 B | 1,983 | 1,553 |

Both use ELF32 MIPS Big Endian / MIPS32R2 / O32 and the same `vermagic=2.6.36 SMP mod_unload MIPS32_R2 32BIT MT_SMTC`. **Vermagic equality is not ABI compatibility.**

## Confirmed machine-code differences

1. In `RtmpOsStatsAlloc`, stock code allocates `0x70` (112) bytes for `net_device_stats`, whereas build #16 candidates allocate `0x5c` (92) bytes. Fixing the allocated byte count alone does **not** establish matching field layout.
2. In `RTMPAllocAdapterBlock`, stock 5 GHz `sizeof(RTMP_ADAPTER)` is `0x1566f8` (1,402,616 B), but build #16 is `0x121cc0` (1,187,008 B), **215,608 B smaller**. This is strong evidence that the build-time feature flags, type layouts, and/or driver variants are different.
3. The original H298A kernel reported a real kernel Oops during 5 GHz build #5 `insmod`, with trace `kmem_cache_alloc -> RtmpOsStatsAlloc -> RTMPAllocAdapterBlock -> rt_pci_probe` and `BadVA: 00c71000`. Later build #16 switched the 5 GHz allocator path to `__kmalloc`, but this does not solve all structure mismatches.
4. Stock modules contain WDS-named functions and vendor parameters that the candidate modules lack; candidates contain ApCli-named functions absent from the stock function symbol tables. This is a binary-symbol observation, not proof that every feature is wholly absent.

## Integration differences

Stock ZTE modules reference vendor integration symbols including `ffe_learn_skb`, `ffe_receive_skb_locked`, `wlan_cspkernel_ops`, and NAT-related hooks. Candidate builds differ in external imports. A module may be missing functional platform hooks even when it is accepted by the kernel loader.

## SHA-256

| File | SHA-256 |
|---|---|
| Stock 2.4 GHz | `4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5` |
| Candidate #16 2.4 GHz | `3319c8e9823fbf9fd16f91a46111d98f5b2f621b84f7f96ee2e449d3f2637b9b` |
| Stock 5 GHz | `2ee8df1b1fbad51f34645dd773009acf59fc37ea90ac9d00365ef91a516adee2` |
| Candidate #16 5 GHz | `e681450ea40c29a59e65a8e41693c5c69fc3f8089bb4cba281489a6ee114548c` |

## Next work

- Locate exact ZTE/ISP driver source, patched Linux headers, and the original GCC 4.3.4 MIPS toolchain; the generic MediaTek MT7510 vendor source plus firmware `.config` is not enough.
- Reconstruct the build flags and confirm structure member layouts and external vendor hooks *before* any new hardware test.
- First reproduce a compatible stock-feature driver in a controlled build; then add `APCLI_SUPPORT`.
- Until a meaningful ABI comparison passes, preserve the working firmware. **No further live `rmmod`/`insmod` attempts.**

Source evidence: ZTE backup binaries, GitHub Actions artifact build #16, device kernel Oops log supplied by the owner.
