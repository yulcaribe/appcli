# H298A APCLI driver build

This repository builds **experimental AP-Client-enabled MediaTek MT7603E / MT7612E driver candidates** for ZTE ZXHN H298A V1.0.25 (MT7510 family, MIPS32 big-endian, Linux 2.6.36).

## Status

**Build and hardware compatibility are not yet validated.** Passing compilation does not prove module loadability, correct Wi-Fi calibration or a working wireless uplink.

- Source: https://github.com/cjdelisle/EN751221-Linux26
- Driver paths: `tclinux_phoenix/modules/private/wifi/MT7603` and `MT7612E_LinuxAP_3.0.4.0.P2_DPA`.
- Both vendor `config.mk` and `config_BBU.mk` default to `HAS_APCLI=n`; the build enables both.
- A non-original vendor `mt7510_config` is used solely for an initial build candidate.

## Build

Open **Actions > H298A APCLI candidates**. A `push` to `main` automatically starts the build. The workflow uploads build logs and any produced `.ko` files as artifacts, even if compilation fails. The source is fetched within GitHub Actions. No WSL, Ubuntu installation or local compiler is required.

**Do not upload, `insmod`, `rmmod` or flash a generated module onto a working device before validating kernel ABI, dependency symbols and recovery procedures.**

The repository intentionally does not modify `yulcaribe/vpnengine`.
