# MT7603E sürücü durum kaydı

**Buradaki tek sürücü çıktısı `mt7603eap_v7.ko`, deneysel ve başarısız V7 örneğidir.** Yüklenebilir/çalışır APCLI firmware değildir.

| Özellik | Son test |
|---|---|
| MIPS ELF / vermagic | Doğrulandı |
| `insmod` | 0, `ra0` üretildi |
| İlk RX DMA | Geçildi (V6 fix) |
| Orijinal 2.4 GHz profil | Açıldı (V7 fix) |
| Firmware komut DMA ve MAC init | Kernel BUG / Segmentation fault |
| Çalışır APCLI / STA | Yok |
| Wi-Fi→Ethernet uplink | Yok |

Beklenen V7 SHA-256:
```text
016046fb7193680a300f5f80b4855b2574c60d3e0f1bf92e5d39b468ee1dbf4c  mt7603eap_v7.ko
```
Dosya 1.854.400 bayt. GitHub Actions arşivinden birebir SHA kontrolü ile projeye alındı.

**Tüm sürücü denemelerinin ayrıntıları:** [docs/driver.md](../docs/driver.md). **Kaynak/derleme kodları:** [build/](build/). Sadece `driver/mt7603eap_v7.ko` çıktı kabul edilir; önceki ara derlemeler raporlarda izlenir, canlı teste hazırlanmış değildir.
