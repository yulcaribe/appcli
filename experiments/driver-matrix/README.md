# H298A beş sürücü varyantı: yalnızca offline derleme

**Donanım:** ZTE ZXHN H298A V1.0/V1.0.25; firmware `TTN.21T1_220614`; Linux 2.6.36, MIPS32 big endian.

Orijinal H298A stok sürücüleri `mt7603eap.ko` ve `mt7612e_ap.ko` firmware'den çıkarılmış **derlenmiş ikililerdir**. Gerçek ZTE `csp/component/wlan/mtk_v2/drivers/MT7603e` ve `MT7612E` **C kaynak ağacı yok**. Dolayısıyla **`zte-stocklike` gerçek orijinalden derleme değildir**. Bütün varyantlar yalnızca [cjdelisle/EN751221-Linux26](https://github.com/cjdelisle/EN751221-Linux26) kaynaklarının sabit `aea3a43562e8d3dc0335624202fde08d713a18c2` commit'inden ve repodaki **orijinal ZTE .config** ile, fakat **ZTE'nin gerçek kernel yamaları/headers olmadan** oluşturulur.

| Profil | APCLI | WDS | Client-WDS | MAC repeater |
|---|---|---|---|---|
| `zte-stocklike` | n | y | n | n |
| `apcli-minimal` | y | n | n | n |
| `apcli-wds` | y | y | n | n |
| `apcli-client-wds` | y | y | y | n |
| `apcli-mac-repeater` | y | n | n | y |

Her deney `mt7603eap.ko` (2.4 GHz) ve `mt7612e_ap.ko` (5 GHz) için derleme dener: başarılı olursa **10 ikili çıktı** elde edilir. Çıktı dizini `experiments/driver-matrix/out/<profil>/`; GitHub Actions artifact adı `h298a-<profil>-<run-number>`.

GitHub Actions → **H298A five experimental WiFi drivers** üzerinden izlenir. Her artifact `*.ko`, derleme logları, ELF/sembol raporları, değişmeden önceki ve profil uygulanmış MediaTek build config'leri ve `verification.txt` (mevcut statik uyumluluk denetimi) içerir.

**UYARI: BU MODÜLLER CİHAZDA TEST İÇİN ONAYLI DEĞİLDİR.** GCC 10 / generic kernel headers ile derleme, stok GCC 4.3.4 / üretici BSP uyumluluğunu kanıtlamaz. Mevcut ABI doğrulaması 112/92 bayt `net_device_stats` farkını ve eksik OEM hook'larını kaydediyor. Önceki 5 GHz modül kernel Oops oluşturdu. GitHub Actions `success` yalnızca **derleme** anlamına gelir. Modem üzerinde `insmod`, `rmmod` veya firmware flashlama yapmayın. Önce ZTE OEM kaynakları + eksiksiz ABI ve UART recovery gerekir.

Orijinal karşılaştırması: [ELF raporu](../../docs/zte-vs-apcli-elf-audit.md). Mevcut web paneline ve `yulcaribe/vpnengine` projesine dokunulmadı.
