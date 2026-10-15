# YulCaribe H298A APCLI / Repeater | YENİ GPT'YE TAM TEKNİK DEVİR
**Son gözden geçirme:** 15 Ekim 2026  
**Hedef repo:** https://github.com/yulcaribe/appcli  
**Ayrı ve dokunulmayacak repo:** https://github.com/yulcaribe/vpnengine  
**Çalışma ilkesi:** Yapılan, cihazda doğrulanan, yalnızca derlenen ve başarısız olan işleri kesin şekilde ayır. Kullanıcı istemedikçe modem flash'ına ve çalışan Wi-Fi sürücülerine dokunma.

## 0. İLK OKUNACAK ÖZET (YENİ GPT)

Proje amacı ZTE ZXHN H298A V1.0/V1.0.25 Türk Telekom modemini başka bir WPA2 Wi-Fi ağına bağlanıp kendi 2.4/5 GHz Wi-Fi ve LAN portlarından internet dağıtabilen **universal Wi-Fi repeater** haline getirmek.

**Web paneli geliştirme kısmı kısmen çalışıyor:** Orijinal Haikui arayüzüne YulCaribe WiFi Repeater menüsü, ZTE Lua CGI backend'i, geçici AP ayarları, durum sorgusu, 2.4 ve 5 GHz için gerçek `iwpriv SiteSurvey` taraması, ham tarama sonucu ve log ekranı eklendi. En son v0.3 kaynak paketi `H298A_repeater_v0.3.zip` olarak mevcut. Bu bir **Lua/LP/shell kaynak paketi**; ayrıca derlenmesi gereken yeni `httpd` ikilisi değildir. Test edilen modem kurulumları /tmp RAM bind-mount yoluyla yapıldı, reboot sonrasında kaybolur. Tarama komutlarının gerçek cihazda çalıştığı gözlendi; tüm seçici tablolarının tüm SSID biçimlerini doğru işlediği kesin test edilmedi.

**Universal repeater yok:** Orijinal `mt7603eap` ve `mt7612e_ap` sürücüleri `ApCliEnable` çağrısını `Invalid argument` ile reddediyor; `/sys/class/net` içinde `apcli0` veya `apcli5g0` yok. Panelin `Connect2g`/`Connect5g` düğmeleri `APCLI_UNSUPPORTED_BY_DRIVER` hata veriyor. UI içinde görüntülenen `preferred netdev` hedef adı, aygıtın gerçekten var olduğu anlamına GELMEZ. Gerçek association + IP + NAT/bridge kanıtlanmadı.

**Kritik uyarı:** GitHub Actions'ta derlenen alternatif 5 GHz `.ko` modülü `insmod` ile cihazda gerçek kernel Oops/Segmentation fault üretti. Router watchdog reboot sonrası orijinal sürücülere dönmüş. Eski adayları **KESİNLİKLE tekrar insmod/rmmod/flashlama.** Araştırma, doğru ZTE BSP/sürücü varyantının bulunmasına odaklanmalı.

## 1. DONANIM VE SİSTEM

- Model: ZTE **ZXHN H298A V1.0**, hardware **V1.0.25**, bootloader **V1.0.2**.
- Operatör/firmware: Türk Telekom **TTN.21T1_220614**.
- SoC: MT751020 / MT7510 ailesi; CPU MIPS 34Kc, 32-bit **big endian** MIPS32r2, MT_SMTC SMP.
- `/proc/version`: `Linux version 2.6.36 (xialei@localhost.localdomain) (gcc version 4.3.4 (GCC) ) #1 SMP Mon Jun 13 23:49:50 CST 2022`.
- `/proc/cmdline`: yalnızca `es=1`. Bundan tek başına active kernel slot çıkmaz.
- `/etc/autokernelconf`: firmware ile tutarlı orijinal ZTE Kconfig; repoda `configs/h298a-zte-20220613.config` ve doğrulaması mevcut.
- Shell: BusyBox 1.17.2, SSH root. Eski OpenSSH istemcilerinde modem MAC algoritması gereği `ssh -o MACs=hmac-sha1 root@192.168.1.1` gerekti.
- Modem IP `192.168.1.1`. Önceki TFTP PC `192.168.1.33`, kullanıcı Windows klasörü `C:\Users\isa\Desktop\modem`. Bu örnek adresler değişmiş olabilir.
- Rootfs SquashFS salt okunur; `/tmp` tmpfs sınırlı (~12MB), bind mount kullanılan RAM deneyleri reboot sonrası silinir.
- Netdev örnekleri: `wlan0`–`wlan4` 2.4G ve `wlan5g0`–`wlan5g4` 5G. `br0` üzerinde LAN portları; aktifleştirilmiş STA/WPA2 bağlantısı YOK.

## 2. GERÇEK Wi-Fi SÜRÜCÜLERİ

Cihaz stok:
```
mt7612e_ap 1684832 1 - Live ...
mt7603eap 1749934 2 mt7612e_ap, Live ...
tccicmd 99972 2 mt7612e_ap,raeth, Live ...
```
- 2.4 GHz `/lib/modules/mt7603eap.ko` (2,778,084 bayt).
- 5 GHz `/lib/modules/mt7612e_ap.ko` (2,637,120 bayt).
- Orijinal modül `vermagic=2.6.36 SMP mod_unload MIPS32_R2 32BIT MT_SMTC`, GCC 4.3.4.
- EEPROM/radio sürücü yapılandırması: `/etc/Wireless/MT7603e/RT2860AP.dat` ve `/etc/Wireless/MT7612E/RT2860AP.dat`; `BssidNum=4`, `WdsEnable=0`. Bu tek başına ApCli'nin aktif olmasını sağlamaz.
- Stok `.ko` string/simge izleri vendor source path `/home/ws/mtk7510/csp/component/wlan/mtk_v2/drivers/MT7603e/` ve `.../MT7612E/`; kullandığımız genel açık kaynak SDK **aynı OEM ağaç değil**.

## 3. WEB PANELİ: DOSYALAR VE NASIL ÇALIŞIR

**Gerçek v0.3 kaynak snapshot** `H298A_repeater_v0.3.zip`. 7 dosya:
- `haikui_dmenu.lua`: orijinal ZTE Haikui menüsüne YulCaribe WiFi Repeater top-level sekmesi kaydı; `dmenuapi.dmenu_register`; stock 3G/topoloji ekleri korunmuş.
- `Internet_STA_t.lp`: Lua `cgilua.put` ile HTML üreten tek sayfa (jQuery, JS). Bölümler: ZTE durum/mod, 2.4 ve 5 GHz scan, SSID/parola ve STA connect, AP yayını yapılandırma/on-off, LAN hakkında bilgilendirme ve debug console. AJAX endpoint `getpage.lua?pid=1005&nextpage=Internet_STA_Switch_lua.lua`.
- `Internet_STA_Switch_lua.lua`: `cgilua.POST.IF_ACTION` ile allowlist action dispatch; XML yanıt; `cmapi.getinst` ile `DEV.MULTIAPCFG`, `DEV.WIFI.AP1`, `DEV.WIFI.AP5`; private profile `/tmp/yc_repeater` (`chmod 700`, dosyalar `600`).
- `Internet_STA_WLANProfile_lua.lua`: `cmapi.querylist` üzerinden `OBJ_WLANSETTING_ID`, `OBJ_WLANAP_ID`, `OBJ_WLANPSK_ID` için read-only debug/probe; varsayılan olarak yazmaz.
- `yc_repeater.sh`: sabit action isimleri ile MediaTek `iwpriv`, `ifconfig`, `sendcmd`, `brctl` çağrıları. **Tehlikeli test butonları da bulunur.** Model 7, AP kapatma/SSID değiştirme ve Connect yazma işlemlerini sırf sayfada var diye stabil kabul etme.
- `KURULUM_V03.txt`: önceki cihaz üzerinde kullanılan RAM/TFTP kurulum talimatı.
- `SHA256SUMS.txt`: orijinal kaynak dosya checksumları.

Doğrulanmış RAM mount yolları:
```sh
cp -R /home/httpd /tmp/httpd
# Kaynak Lua/LP dosyalarını /tmp/httpd/... içine indir, /tmp/yc_repeater.sh yükle.
chmod 700 /tmp/yc_repeater.sh
mount -o bind /tmp/httpd/haikui_dmenu.lua /home/httpd/haikui_dmenu.lua
mount -o bind /tmp/httpd/common_page /home/httpd/common_page
```
Önemli: Yalnızca dosyaları GitHub'a koymak modemin web sunucusuna kurulum yapmaz. Yönetici web paneli ile modeme fiziksel erişim gereklidir. Daha önce kullanılan test URL backend `getpage.lua?pid=1005&nextpage=Internet_STA_Switch_lua.lua`.

Çalışma mantığı `Scan2g`:
```sh
iwpriv wlan0 set SiteSurvey=1
sleep 4
iwpriv wlan0 get_site_survey
```
`Scan5g`:
```sh
iwpriv wlan5g0 set SiteSurvey=1
sleep 4
iwpriv wlan5g0 get_site_survey
```
Çıktı backend XML `<Output>` içine XML-escape edilerek verilir. JS ham çıktıyı gösterir; ayrıca özel regex ile SSID/BSSID ayrıştırmaya çalışır. Bazı vendor SiteSurvey sütun biçimleri regex'e uymayabilir: **ham çıktı varsa ama seçici boşsa driver scan çalışmıştır, parser ayrı debug edilmeli.** Listede bulunan SSID'nin seçilmesi STA bağlantısı kurmaz.

Backend action -> shell mapping:
```
Scan2g/Scan5g -> scan2g/scan5g
FullStatus -> status
Connect2g/Connect5g -> connect2g/connect5g
Publish2g/Publish5g -> publish2g/publish5g
APOn2g/APOff2g/APOn5g/APOff5g -> apon2g/apoff2g/apon5g/apoff5g
Mode7/Mode1/ConfirmMode/ModeLog -> mode7/mode1/confirm/log
```
Güvenlik notu: v0.3 deneysel yönetici panelidir, kapsamlı HTTP CSRF/yetkilendirme ve istemci uyumluluğu pentestinden geçmedi. SSID/parola dosyalarının gizlilik varsayımları router filesystem ve CGI yetkilerine bağlı. Public internetten admin paneli açılmamalı. Mod7'nin otomatik rollback işlemi 180sn best-effort, modem sert kilitlenirse GARANTİ DEĞİL.

## 4. SÜRÜM GEÇMİŞİ VE GERÇEK TESTLER

### v0.1
- Menüye eklenen repeater paneli ve ilk read-only WLAN model probeleri.
- `H298A_repeater_patch_v0.1.zip` ve `H298A_runtime_test_v0.1.zip` ile RAM üzerinde kurulum denendi.
- Panel CGI backend/probe HTTP 200 aldı.
- Erken ZTE repeater write testi **`HATA 197 / FAIL Mode`**; NetSphere `Mode=Master` ya da rolden türeyen `Enable` durumuyla `WORK_MODE_REPEATER=7` aynı şey değil.

### v0.2
- `haikui_dmenu.lua` ve `Internet_STA_WLANProfile_lua.lua` düzenlendi. Kötü/uyumsuz obje yazımı kaldırılıp read-only probe yapıldı.
- RAM bind mount ile menü entegrasyonu çalıştığı gözlendi.

### v0.3 (en son doğrulanmış web kaynak paketi)
- `Internet_STA_t.lp`: durumu, tarama listesi, uplink, AP ve Debug Console tek sayfada.
- `Internet_STA_Switch_lua.lua`: yanlış ZTE setter yerine allowlisted shell helper kullandı.
- `yc_repeater.sh`: wlan0/wlan5g0 scan, geçici AP SSID/WPA2, AP aç/kapat, STA ioctl ve Mode7 test yolları.
- 2.4/5 GHz **SiteSurvey çalıştı**, ancak Connect2g/Connect5g çağrısı `ApCliEnable=0` aşamasında `Invalid argument` ve `APCLI_UNSUPPORTED_BY_DRIVER` döndü. APCLI arayüzü yoktu.
- `Mode7` denemesinde ağ kopması yaşandı; stok NetSphere durumunda `bSupportRepeater=0`, `bStaLinkUp=0` görülmüş. GUI'de repeater yazması bunu değiştirmedi. `setmode 1` dönüşü durum kurtarma için not edildi.

## 5. DRIVER APCLI ARAŞTIRMASI, BAŞARISIZLIKLAR

Mediatek AP Software Programming Guide v4.6, bölüm 11 (p.102-110): gerçek AP-Client `APCLI_SUPPORT` derleme seçeneği gerektirir; normal `apcli0` benzeri cihazda WPA2PSK/AES, SSID, parola ve Enable komutları ile STA/AP köprüleme. Fakat bu belgede listelenen özellik cihazın stok sürücüsünde otomatik var demek değil.

Github `yulcaribe/appcli` deneysel derleme altyapısı `cjdelisle/EN751221-Linux26` kaynak ağacından iki sürücüyü GCC 10 `mips-linux-gnu-` ile `HAS_APCLI=y` oluşturuyor. `configs/h298a-zte-20220613.config` gerçek ZTE config, fakat kernel headers ve OEM patches halen birebir değil.

- Actions #38636495846 (build #4): iki .ko üretildi; MIPS big endian ve `vermagic` geçiyor; modül çalışma garantisi yok.
- Actions #38640001017 (build #5): 5 GHz eksik simbol `alloc_etherdev_mq`/`skbmgr_alloc_skb4k` için deneysel sarmalayıcı ile derleme başarılı.
- **Gerçek modem crash (5GHz build #5):** `ifconfig wlan5g{0..4} down`; `rmmod mt7612e_ap` başarılı; `insmod /tmp/mt7612e_test.ko` -> **Segmentation fault**. `dmesg`:
```
epc: 80368f5c kmem_cache_alloc
ra: RtmpOsStatsAlloc+0x3c [mt7612e_ap]
Call Trace:
 kmem_cache_alloc -> RtmpOsStatsAlloc
 -> RTMPAllocAdapterBlock -> rt_pci_probe
 -> pci_device_probe -> driver_register -> sys_init_module
BadVA: 00c71000
Tainted: P
```
  120sn reboot watchdog çalıştı; sonra `cat /proc/modules` stok modülleri Live gösterdi. Firmware'i değiştirmedi.
- Actions #38643129823 (build #16) gerçek ZTE Kconfig kullanarak yeniden derledi; **statik gate FAIL**. `net_device_stats` stok 112 B, candidate 92 B. Stok `RTMP_ADAPTER` 1,402,616 B, candidate 1,187,008 B (215,608 B fark). 5GHz'deki yeni derlemenin allocator yolu #5'teki oops yolundan farklılaştı, ama tip düzeni/platform hooks uyumsuzluğu çözülmedi.
- GitHub üzerinde `scripts/build.sh`, `scripts/check_modules.py`, `docs/zte-vs-apcli-elf-audit.md`, `docs/H298A_APCLI_kaynak_arastirmasi_ve_yol_haritasi.md` sürücü denemelerini belgeliyor. Statik uyuşma **cihazda test başarısı değildir**.

Cihaz stok `/proc/kallsyms` sonuçları: `ahbErrChk`, `pcie_init`, `tc3162_enable_irq`, `tc3162_disable_irq`, `os_TCIfQuery[tccicmd]`, `dev_alloc_skb` bulundu; `alloc_etherdev_mq` bulunmadı, buna benzeyen `alloc_etherdev_mqs` vardı. Bazı vendor fonksiyonları yalnızca özgün BSP'de bulunuyor.

## 6. NEDEN KAYNAK ARIYORUZ?

Modül içinde OEM derleme yolları:
```
/home/ws/mtk7510/csp/component/wlan/mtk_v2/drivers/MT7603e
/home/ws/mtk7510/csp/component/wlan/mtk_v2/drivers/MT7612E
```
Halka açık ve doğrulanmış birebir H298A TTN.21T1_220614 paket bulunmadı. `cjdelisle/EN751221-Linux26` yalnızca benzer BSP; `openwrt/mtk-wifi-gpl` aynı OEM varyant değil. ZTE GPL portalı: https://opensource.ztedevices.com/ ; GPL kaynak talebi `tech.sp@zte.com.cn`, `Open.Source@zte.com.cn`. H298A sürümü için ZTE kaynak, kernel patch/header, doğru Wi-Fi driver varyant, build flags, toolchain istenmeli.

## 7. GÜVENLİ GELİŞTİRME PLANI

**A: Web panelini ayrı tut.** En son v0.3 kaynaklarını repo `webpanel/v0.3/` içine koy; yine de paneldeki yazan/Mode7/STA düğmeleri çalışan özellik olarak pazarlanmasın. Scan frontend parser sorunlarını **stok sürücüleri değiştirmeden**, ham SiteSurvey örnekleriyle test et. CGI access control ve CSRF'yi doğrula.

**B: Kernel driver işini ayrı tut.** Vendor GPL source + gerçek ZTE headers/build options sağlanana kadar canlı driver değişimini DURDUR. Önce APCLI kapalı stok özelliğe sahip .ko'yu uygun GCC 4.3.4 toolchain ile üretebilmek; sonra bilinçli ABI/symbol karşılaştırması; ancak sonra APCLI=on.

**C: Gerçek repeater doğrulama kapıları** (sıra değişmez):
1. stok kablolu SSH / recovery hazır, orijinal firmware ve MTD yedekleri sağlam.
2. candidate driver no-ApCli statik ABI kabul + UART kurtarma ile kontrollü test.
3. APCLI ağ arayüzü gerçekten oluşuyor (`/sys/class/net`).
4. WPA2 association ve 4-way handshake başarılı; DHCP/IP veriliyor.
5. Uplink üzerinden ping/DNS/Internet çalışıyor.
6. LAN ve AP istemcilerinde L2 bridge / NAT, DHCP ve IPv6 kararları doğrulanıyor.
7. Ancak sonra güvenli kalıcı uygulama düşünülebilir.

**Kesinlikle yapılmayacaklar:** Yeniden #4/#5/#16 .ko insmod/rmmod, `flash_erase`, bilinmeyen firmware flaşlama, v0.3 UI üstünden Mod7'yi çalışır repeater varsayma, kullanıcı açık istemedikçe `yulcaribe/vpnengine` değiştirme.

## 8. MEVCUT UYGULAMA / TEST KAYITLARI

Cihazda şu anda son logda **stok modüller yeniden Live** durumdaydı. Kullanıcı kendi Windows bilgisayarından ve Ethernet üzerinden modem SSH kullanıyor. Depoya dosya eklemek cihazı değiştirmez. `/tmp` bind mount kalıcılığı olmadığından panel reboot sonrası tekrar deploy ister.

Sürüm/teslim kayıtlarının ve upload işleminin detayları repo commit history ve GitHub Actions üzerinden incelenmeli; eski #4/#5 paketleri **cihaza kurulacak çıktı değildir**.

## 9. DOSYA MANİFESTİ VE ÇALIŞMA KURALLARI

v0.3 kaynak SHA256:
```
3bd270e0720f5539bd94255db64dbaa841df6806e65c16c043d00d9e4f85e238  haikui_dmenu.lua
28f721ff1858c8b05234a4b4ea3ce0e8c8a3120ad98cf6927144439fac6dfcc4  Internet_STA_t.lp
c44de7d7a1b9e63580ea60be4a88e87c20897f65d544046e1e1dce178a5da22b  Internet_STA_Switch_lua.lua
568695b81b15b63b7d33673c56b5edf734e2b7bbe98add939826f3029a6af1a1  Internet_STA_WLANProfile_lua.lua
c79fb6f5443d8504bc88b638139e0e5d958a4394cb918cc7bfab8021377c67d0  yc_repeater.sh
```

Özel hayat/operasyon şifresi veya WLAN PSK hiçbir şekilde GitHub'a eklenmemeli. Kullanıcı kısa, net Türkçe yanıt ister; yalnızca istendiğinde kod/kurulum uygulaması yap; `dur`, `kod yazma`, `şuna dokunma` sınırları kesin.

**YENİ GPT'NİN İLK İŞİ:** Depodaki kaynakları ve bu raporu aç; kullanıcıdan zaten verdiği modem sürümü/çökmüş `.ko` testini yeniden isteme. Çalışan v0.3 GUI'yi koru, gerçek Wi-Fi scanning özelliğini test et; driver portu için OEM kaynaklarını bulmadan yeni live test önermeyip doğrulanabilir araştırmayla devam et.
