# H298 2.4 GHz MT7603E PCIe APCLI port

**State:** reverse-engineered source changes committed. No OEM-ABI-compatible .ko has been compiled yet.

Input: user-supplied `_20151027134607312.rar`, `MT7603U_DPA_LinuxSTA_3.0.0.4_20140825/DPA`. A public donor of the same generation is [mand3v/MT7603U](https://github.com/mand3v/MT7603U), pinned to commit `a99bc13905d59df14cb8708a79387907e26357ee`. These two source trees have not been established as byte-identical.

## Driver modifications

- Choose `mt7603e` PCIe instead of `mt7603u` USB.
- Switch STA to AP and compile existing APCLI code (`HAS_APCLI=y`).
- Remove the FPGA flag from *only* the MT7603E PCIe build branch.
- Switch net device allocation to the original ZTE module's `alloc_etherdev_mqs(privDataSize, 1, 1)` kernel entry point.
- Add a strict GCC 4.3-compatible compile-time assertion `sizeof(struct net_device_stats) == 112` (rather than padding an incompatible 92-byte struct).
- Keep native `sizeof(struct net_device_stats)` in `RtmpOsStatsAlloc`. The correct OEM headers must satisfy the guard.

## Genuine stock reference

- Original `mt7603eap.ko`: 2,778,084 bytes.
- SHA256: `4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5`.
- ELF32 MIPS Big Endian MIPS32R2; vermagic `2.6.36 SMP mod_unload MIPS32_R2 32BIT MT_SMTC`; GCC 4.3.4.
- OEM imports: `alloc_etherdev_mqs`, `wlan_cspkernel_ops`, `ffe_receive_skb_locked`, `ffe_learn_skb`.
- OEM build path embedded in ELF: `/home/ws/mtk7510/csp/component/wlan/mtk_v2/drivers/MT7603e/`.

## Running the source port

Extract the original vendor RAR into a folder, then:

```sh
python3 experiments/h298-mt7603e-oem/port.py --donor /path/to/DPA --output /tmp/h298-mt7603e
```

On the prepared output sources, when **matching ZTE patched kernel source and MIPS BE GCC 4.3.4** are available:

```sh
make -C /tmp/h298-mt7603e PLATFORM=BB_SOC KERNEL_DIR=/path/to/OEM/kernel \
  ARCH=mips CROSS_COMPILE=/path/to/mips-gcc-4.3.4-prefix- CHIPSET=mt7603e WIFI_MODE=AP all
```

With an output `.ko`, audit against the **original** 2.4 GHz module:

```sh
python3 experiments/h298-mt7603e-oem/abi_audit.py /path/to/stock/mt7603eap.ko /path/to/candidate.ko
```

## Important remaining engineering work

The genuine ZTE kernel headers and patched `mtk_v2` driver API are not present in this repository. The `wlan_cspkernel_ops` and `ffe_*` hooks require correct, not guessed, integration; the RTMP_ADAPTER and net_device field offsets remain unverified. An identical `vermagic` alone cannot establish full ABI equivalence. Source processing/build tests must not be labeled a working H298 Wi-Fi driver.

All changes are on `dev/h298-mt7603e-oem-abi-port`. Existing main branch and production code remain intact.