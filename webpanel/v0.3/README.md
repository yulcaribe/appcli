# YulCaribe H298A Repeater web paneli | v0.3 (deneysel)

Bu klasör, **ZTE ZXHN H298A V1.0 / V1.0.25, TTN.21T1_220614** modeminde RAM üzerinden test edilmiş web panelinin **orijinal yedi dosyalık kaynak snapshot'ıdır**. Her dosya `H298A_repeater_v0.3.zip` kaynağıyla byte düzeyinde karşılaştırılmıştır. Orijinal kaynaklar değiştirilmedi.

## Ne çalışıyor, ne çalışmıyor?

| Bölüm | Kanıt durumu |
| --- | --- |
| Haikui'ye WiFi Repeater menüsü ekleme | Eski cihaz testlerinde çalıştığı gözlendi |
| CGI durum sorgusu, hata/debug alanları | Test edilen sürümde görüldü |
| `iwpriv wlan0 set SiteSurvey=1` ve `get_site_survey` | **2.4 GHz tarama komutları çalıştı** |
| `iwpriv wlan5g0 set SiteSurvey=1` ve `get_site_survey` | **5 GHz tarama komutları çalıştı** |
| Taramayı seçenek listesine ayırma | Ham tarama çalışır; vendor çıktısı değişirse regex sonuçları eksik gösterebilir |
| WPA2/SSID uygulama / AP aç-kapat düğmeleri | Deneysel, kesinti yaratabilir; kalıcı değildir |
| `Connect2g` / `Connect5g` gerçek Wi-Fi uplink | **ÇALIŞMIYOR**: stok sürücü ApCli ioctl reddediyor |
| `apcli0` / `apcli5g0` | **YOK**; UI içindeki önerilen isim netdev kanıtı değildir |
| Ethernet LAN'a wireless uplink ile internet dağıtımı | **YAPILMADI/DOĞRULANMADI** |
| `Mode7` NetSphere repeater modu | Cihazda kesinti yaratabildi; `bSupportRepeater=0` görüldü |

**Bu klasör çalışma prototipidir, tam Wi-Fi repeater çözümü değildir.** `Mode7`, AP kapatma ve STA bağlantısı butonları test menüsüdür. Yönetim sayfasını internete açmayın ve kurtarma planı olmadan modem ağ ayarlarını değiştirmeyin.

## Kaynaklar

```
webpanel/v0.3/
  haikui_dmenu.lua
  Internet_STA_t.lp
  Internet_STA_Switch_lua.lua
  Internet_STA_WLANProfile_lua.lua
  yc_repeater.sh
  KURULUM_V03.txt
  SHA256SUMS.txt
```

`Internet_STA_t.lp`, ZTE stok Lua/LP interpreter tarafından çalıştırılır, **yeni `httpd` ikilisi, kernel modülü veya firmware değildir**. `yc_repeater.sh` stok BusyBox komutlarıyla radyo site survey ve deneysel ayarları çağırır. Basit tarama için yeni `.ko` **gerekmez**.

## Kaynak doğrulama

```sh
cd webpanel/v0.3
sha256sum -c SHA256SUMS.txt
sh -n yc_repeater.sh
```

Bu kontroller yalnızca dosya bütünlüğü/sözdizimidir; modem üstünde canlı regresyon testi değildir.

## Modeme yükleme / geri alma

Önce [orijinal KURULUM_V03.txt](KURULUM_V03.txt) belgesini okuyun. Özetle mevcut ZTE `/home/httpd` ağacı `/tmp/httpd` altına kopyalanır; kaynaklar RAM'e alınır; menü dosyası ve `common_page` dizini **bind-mount** edilir. Reboot sonrasında RAM değişiklikleri kaybolur. Orijinal dosya sistemine, MTD'ye, çalışan `.ko` modüllerine dokunmayın.

- Menü: `/tmp/httpd/haikui_dmenu.lua` → bind `/home/httpd/haikui_dmenu.lua`
- Backend + LP: `/tmp/httpd/common_page/*` → bind `/home/httpd/common_page`
- Helper: `/tmp/yc_repeater.sh` (`chmod 700`)
- Admin tarayıcı: `http://192.168.1.1` → WiFi Repeater

Geri alma için ilgili bind mount'lar **doğru sırayla** kaldırılır, ardından gerekliyse reboot edilir. Ağ modunu değiştirmiş olmak yalnızca mount'u kaldırarak geri alınmaz.

## Sorun giderme

- **TARA ham sonuç veriyor ama liste boş:** `get_site_survey` çıktısının sütunlarıyla JS regex'ini karşılaştır. Router driver scan çalışıyordur.
- **`APCLI_UNSUPPORTED_BY_DRIVER`:** Firmware bu ioctl'ü desteklemiyor. SSID/parola değiştirerek çözülemez.
- **`STA_NETDEV_NOT_PRESENT`:** Driverın gerçek STA ağı oluşturduğunu varsayma.
- **`BadVA ... kmem_cache_alloc` / `insmod` Oops:** Sürüm #5 APCLI modülüyle yaşanmış gerçek çekirdek çökmesi. Deneme `.ko` dosyalarını **tekrar yükleme**.
- **`Mode7` ağ kopardı:** `bSupportRepeater=0`, `bStaLinkUp=0`; moda geçmek uplink çalıştığı anlamına gelmez.

## Devir / sonraki GPT için

Tam, kaynakları ve çökme kayıtlarını ayrıştıran Türkçe rapor:
[DEVIR_YENI_GPT_H298A_2026-10-15.md](../../docs/DEVIR_YENI_GPT_H298A_2026-10-15.md)

Driver araştırması:
[zte-vs-apcli-elf-audit.md](../../docs/zte-vs-apcli-elf-audit.md)

Proje sınırı: `yulcaribe/vpnengine` repo'suna **dokunulmayacak**. Kullanıcının açık `dur`, `kod yazma`, `şuna dokunma` talimatlarına uyulacak.
