# H298A APCLI driver build

This repository builds **experimental AP-Client-enabled MediaTek MT7603E / MT7612E driver candidates** for ZTE ZXHN H298A V1.0.25 (MT7510 family, MIPS32 big-endian, Linux 2.6.36).

## Status

**STOP: Known kernel Oops on H298A (2026-10-15)**

The experimental 5 GHz `mt7612e_ap.ko` from build #5
(commit `6f616d7b`) caused a kernel Oops during `insmod` on the actual
H298A: `kmem_cache_alloc -> RtmpOsStatsAlloc -> RTMPAllocAdapterBlock -> rt_pci_probe`.
No AP-Client netdev was created. Do NOT load the build #4 or #5 driver.
An attempted 5 GHz live replacement may reboot or hang the router.

**Root cause is not fully proven.** ELF comparison of genuine stock ZTE
`mt7612e_ap.ko` versus the new module reveals serious ABI mismatches:
- Stock `RtmpOsStatsAlloc` delegates to `os_alloc_mem`, which calls `__kmalloc`.
  Candidate inlines `kmalloc_caches -> kmem_cache_alloc`, the failing path.
- Stock allocates `0x70` (112) bytes for `net_device_stats`; candidate
  allocates `0x5c` (92) bytes. The generic vendor `mt7510_config` is
  not a substitute for original ZTE kernel headers/configuration.
- Matching `vermagic` and ELF architecture **does not imply ABI compatibility**.
- `scripts/check_modules.py` now rejects the known-crashing allocator
  signature rather than reporting a misleading static PASS.

**Kernel configuration recovered (2026-10-15):** A full file
`/etc/autokernelconf` was extracted from the user's original H298A
`ram_flash` backup. It declares Linux 2.6.36 and a 13 June 2022
build configuration, consistent with the router's `/proc/version`
(`xialei@localhost.localdomain`, GCC 4.3.4, 13 June 2022).
The boot command line is only `es=1`; it does not identify a boot slot.

The build accepts the extracted configuration as
`configs/h298a-zte-20220613.config`. The conversion is only
replacing vendor `@ CONFIG_... is not set` comment prefixes with
standard `# CONFIG_... is not set`. If this file is absent, the
workflow still builds experimental generic candidates **which are
not safe to load**. Placing the original config in this repo
does not make the generic upstream kernel headers match ZTE's
private patches. Exact kernel headers, symbol versions, and
layout comparisons are still required.

The MT7612E build script also replaces two `kmalloc` allocation sites
with direct `__kmalloc` calls to avoid the allocator path involved
in the observed kernel crash. This is a *build-only experiment*;
do not load the resulting modules until kernel ABI issues are resolved.

**Do NOT rerun the live `rmmod`/`insmod` test yet.**

**Build and hardware compatibility are not yet validated.** Passing compilation does not prove module loadability, correct Wi-Fi calibration or a working wireless uplink.

- Source: https://github.com/cjdelisle/EN751221-Linux26
- Driver paths: `tclinux_phoenix/modules/private/wifi/MT7603` and `MT7612E_LinuxAP_3.0.4.0.P2_DPA`.
- Both vendor `config.mk` and `config_BBU.mk` default to `HAS_APCLI=n`; the build enables both.
- A non-original vendor `mt7510_config` is used solely for an initial build candidate.

## Build

Open **Actions > H298A APCLI candidates**. A `push` to `main` automatically starts the build. The workflow uploads build logs and any produced `.ko` files as artifacts, even if compilation fails. The source is fetched within GitHub Actions. No WSL, Ubuntu installation or local compiler is required.

**Do not upload, `insmod`, `rmmod` or flash a generated module onto a working device before validating kernel ABI, dependency symbols and recovery procedures.**

The repository intentionally does not modify `yulcaribe/vpnengine`.
