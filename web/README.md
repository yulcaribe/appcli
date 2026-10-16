# Web paneli: Haikui v0.3 kaynakları

Bu dizindeki **7 web dosyası** son bilinen v0.3 kaynaklarıdır; orijinal Git blob'ları değiştirilmeden taşınmıştır. Ayrı bir HTML dosyası yoktur: **Internet_STA_t.lp** ZTE'nin Lua/LP şablonu üzerinden HTML/jQuery sayfasını üretir.

| Dosya | İşlev |
|---|---|
| haikui_dmenu.lua | Modemin orijinal Haikui menüsüne Repeater sekmesi |
| Internet_STA_t.lp | Tek sayfalık HTML/JavaScript arayüzü, tarama listesi, status, debug |
| Internet_STA_Switch_lua.lua | CGI AJAX action route + XML cevap |
| Internet_STA_WLANProfile_lua.lua | Read-only modem Wi-Fi obje sondası |
| yc_repeater.sh | BusyBox iwpriv/ifconfig/sendcmd işlem katmanı |
| KURULUM_V03.txt | RAM bind-mount kurulum/geri alma yönergeleri |
| SHA256SUMS.txt | v0.3 içerik checksumları |

**İşleyen:** 2.4GHz ve 5GHz gerçek `SiteSurvey` tarama ve önceki oturumlarda web menüsü. **Çalışmayan:** kablosuz uplink/APCLI ve Ethernet internete yönlendirme. `Mode7`, `APOff` ve yayın ayarı düğmeleri ağ kesintisi yaratabilir, gerçek repeater değildir. Panel test amaçlıdır; internetten modem yönetimine açılmaz.

Doğrulama:
```sh
cd web
sha256sum -c SHA256SUMS.txt
sh -n yc_repeater.sh
```

Tam adımlar: [docs/manual.md](../docs/manual.md). `KURULUM_V03.txt` önceki /tmp RAM kurulum denemesini anlatır. Stok orijinal /home/httpd dosyalarına kalıcı yazılmaz.

Kaynak korunumu: `web/` altındaki 7 içerik taşıma sırasında byte düzeyinde değişmemiştir.
