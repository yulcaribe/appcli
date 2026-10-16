# ZTE ZXHN H298 Repeater / APCLI Araştırma Projesi

Bu depo, **ZTE ZXHN H298/H298A** (TTN.21T1_220614, MediaTek MT7510 ailesi, Linux 2.6.36, MIPS big-endian) için **Wi-Fi'den internet alıp Ethernet ve yerel Wi-Fi üzerinden paylaşma** hedefinin web panelini, sürücü denemelerini, kaynaklarını ve bütün çalışma raporlarını içerir.

> **Durum (16.10.2026):** Modemin stok sürücüsüyle **2.4 ve 5 GHz ağ taraması çalıştı**. Evrensel Wi-Fi uplink/repeater **çalışmıyor**. Arşivlenen **V7 deneysel 2.4 GHz sürücüsü**, kernel BUG oluşturduğu için **modeme yüklenmeye hazır bir sürücü değildir**. Bu depo firmware veya kalıcı kurulum paketi değildir.

## Dizinler

| Konum | İçerik |
|---|---|
| [web/](web/) | Son doğrulanmış v0.3 Haikui web arayüzü: gerçek Lua/LP (HTML oluşturan şablon), CGI, menü ve BusyBox scriptleri |
| [driver/](driver/) | **mt7603eap_v7.ko** (deneysel/kırık), SHA-256, gözlenen V7 cihaz logları |
| [driver/build/](driver/build/) | V1–V7 yama zinciri, kaynak üretim/derleme scriptleri, offline ABI testleri, eski sürücü varyantları |
| [docs/manual.md](docs/manual.md) | Projenin başından beri amacı, root/SSH/TFTP erişimi, web panelinin kurulumu, geri alma, bütün denemeler ve çalışma yöntemimiz |
| [docs/driver.md](docs/driver.md) | Tüm sürücü denemeleri, V1–V7 hata zinciri, MIPS/ABI bulguları, karşılaştırmalar ve güvenli devam planı |
| [source/](source/) | Kaynak kod bağlantıları, gerçek stok modül checksumları, orijinal kernel config, araştırma dosyalarının manifesti |

## Doğrulanan / doğrulanmayan

- **Doğrulanan:** Web paneli 2.4/5 GHz SiteSurvey ham taraması ve stok Haikui menü açılımı; V7 yüklenmesi ve profil okunması.
- **Doğrulanmayan:** APCLI cihazı, WPA2 istasyon bağlantısı, kablosuz uplink üzerinden DHCP, LAN'a internet, kalıcı repeater.
- **Hatalı:** V7 `ra0 up` sırasında `r4k_dma_cache_wback_inv` / `AndesMTPciKickOutCmdMsg` kernel BUG.

Hiçbir sistem dosyası/flash otomatik değiştirilmez. Modeme müdahale için kullanıcı ayrıca işlem başlatmalıdır. Bu depo yeni firmware üretmez.

**Önce:** [docs/manual.md](docs/manual.md) → [docs/driver.md](docs/driver.md) → [source/README.md](source/README.md).
