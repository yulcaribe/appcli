# DRIVER.MD: H298 MT7603E / MT7612E sürücü çalışmalarının tam raporu

**16.10.2026, doğrulama seviyesi: deneysel.** Sürücü geliştirme ayrı yürütülür, stok rootfs/flash değişmez. **V7 yalnızca çalışmamış en ileri sürümün arşividir, tekrar insmod yapılmamalıdır.**

## 1. Amacımız ve mevcut son durum

Gerçek ZTE **MT7603E 2.4 GHz** donanımında orijinal AP fonksiyonunu bozmadan APCLI (STA uplink) eklemek; sonra 5 GHz MT7612E desteği, son olarak LAN/Wi-Fi ile internet paylaşmak. Modül derlenip kernel kabul etse bile WPA2 uplink denenene kadar repeater 'çalışıyor' denmez.

Önceki yaklaşım ayrı MediaTek/EN751221 kaynak ağacını derleyerek deneysel sürücüler üretmekti. Kullanıcının belirttiği gibi her Oops'un ardından tek ofset yaması yapmak doğru nihai strateji değil. Bu nedenle 16 Ekim'de orijinal ZTE `.ko` dosyaları makine kodundan karşılaştırıldı; binlerce sembol ve kernel ABI kontrolü çıkarıldı.

### V1–V7 kronolojik test tablosu

| Sürüm / kaynak | Denenen işlem | Gerçekte gözlenen | Sonuç |
|---|---|---|---|
| İlk 5 GHz denemeleri | MT7612E donor APCLI, `insmod` | `kmem_cache_alloc → RtmpOsStatsAlloc → RTMPAllocAdapterBlock → rt_pci_probe`, BadVA `00c71000`; stok `net_device_stats` 112B, aday 92B | Kernel Oops, **başarısız** |
| V1 2.4 GHz | `insmod` | `Unknown symbol pAd_save` | Yüklenmedi |
| V2 | Yedeklenmiş SDK kaynak ve ABI yaması | `RtmpOSNetDevAttach+0xc4/0x17c` BadVA 0 | Kernel Oops |
| V3 / V3.1 | `net_device` / callback offset yamaları | `insmod` sonrasında segfault; taşınmış ZTE ops yapısında daha fazla uyumsuzluk | Kernel Oops |
| V4 | Yeni ops tablosu ve private offsets | `insmod=0`, `ra0` oluştu, MAC `00:00:00:00:00:00`; `ifconfig ra0 up` segfault 139 | Arayüz açılamadı |
| V5 | `MainVirtualIF_open`, `rt28xx_init` izleme | `RTMP_AllocateRxPacketBuffer → dma_map_single → r4k_dma_cache_inv`; BadVA **`0x20`** | Kernel Oops |
| V6 | OEM `sk_buff` RX data / DMA konumu ve `__alloc_skb` | `H298V6: RX DMA skb=... data=... length=3840`; RX aşaması geçti, yanlış **`/etc/Wireless/RT2860AP/RT2860AP.dat`** | Profil okuma hatası, `ra0` UP olmadı |
| **V7** | Gerçek `/etc/Wireless/MT7603e/RT2860AP.dat` profili | Profil okundu, firmware tanındı, EEPROM okuma ve MAC init başladığında firmware command DMA kernel BUG | **En ileri test, hâlâ çalışmıyor** |

**Örnek doğrulanmış V7 gerçek terminal izi:**
```text
INSMOD_EXIT=0
H298V5: before rt28xx_init
H298V6: RX DMA skb=847e7e00 data=8295d020 tail=8295d020 length=3840
H298V7: profile path /etc/Wireless/MT7603e/RT2860AP.dat
FW Version:ap_pcie
FW Build Date:20160107100755
E2pAccessMode=2
RtmpOSFileOpen(): Error 2 opening /etc/RT30xxEEPROM.bin
rtmp_ee_load_from_bin::Error opening /etc/RT30xxEEPROM.bin
NICInitializeAsic(585): Not support rtmp_mac_sys_reset () for HIF_MT yet!
mt7603_init_mac_cr()-->
Kernel bug detected[#1]:
epc: r4k_dma_cache_wback_inv+0x34/0x240
ra: dma_map_single+0x84/0x8c
RtmpDrvPciMapSingle+0x68/0xc4 [mt7603eap]
AndesMTPciKickOutCmdMsg+0x1dc/0x3d0 [mt7603eap]
AndesSendCmdMsg+0x2a4/0x950 [mt7603eap]
CmdMultiPleMacRegAccessRead+0x11c/0x198 [mt7603eap]
CmdIORead32+0x4c/0x64 [mt7603eap]
Segmentation fault
RA0_CMD_EXIT=139
client_loop: send disconnect: Connection reset
```
**Not:** Çöken işlemden sonra `ifconfig ra0 up` komutu EXIT 139 döndü; V6'nın `RA0_EXIT=0` sonucu radyo çalışıyor kanıtı değildi; `SIOCSIFFLAGS` hata vermişti.

## 2. Gerçek OEM ve V7 dosyaları

| Modül | Boyut (byte) | SHA-256 | Açıklama |
|---|---:|---|---|
| Stok MT7603E `mt7603eap.ko` | 2.778.084 | `4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5` | Orijinal ZTE 2.4 GHz yedeği |
| Stok MT7612E `mt7612e_ap.ko` | 2.637.120 | `2ee8df1b1fbad51f34645dd773009acf59fc37ea90ac9d00365ef91a516adee2` | Orijinal ZTE 5 GHz yedeği |
| **V7** `driver/mt7603eap_v7.ko` | **1.854.400** | **`016046fb7193680a300f5f80b4855b2574c60d3e0f1bf92e5d39b468ee1dbf4c`** | CI artefaktı, 2.4 GHz, kernel BUG |

Her üç modül ELF32 MIPS32r2 **big endian** ve `2.6.36 SMP mod_unload MIPS32_R2 32BIT MT_SMTC` vermagic taşır. **Fark:** stok GCC 4.3.4, V7 GCC 10.3.0. Aynı vermagic doğru kernel ABI garantisi değildir.

**OEM binary tersine mühendislik envanteri:**

| | Orijinal MT7603E | Orijinal MT7612E |
|---|---:|---:|
| Tanımlı fonksiyon | 2133 | 1983 |
| Derlenmiş ismi ApCli olan fonksiyon | 0 | 0 |
| WDS ilişkili isimler | 10 | 10 |
| Fonksiyon sembol relokasyon referansı | 4560 | 4140 |
| Kernel export | 10 | 0 |

`CliWds` ve `Set_WorkMode_Proc` varlığı WPA2 STA istemci motoru anlamına gelmez. Modülün içerisinde sembol adlarına göre APCLI auth/assoc/control durum makineleri yok. Bu, yalnızca bir bayrağı değiştirerek stok .ko'dan APCLI açılabileceği iddiasını desteklemiyor. Orijinal C dosyaları eksik olduğundan temiz fonksiyonel kaynak kod geri çıkarımı otomatik yapılamıyor.

## 3. ABI uyumsuzluklarının merkezi özeti

| Yapı/alan | Orijinal OEM ofseti | BSP / V7 konumu |
|---|---:|---:|
| `sk_buff.data` | `+0xC4` | `+0xD4` |
| `sk_buff.len` | `+0x58` | `+0x4C` |
| `sk_buff.head` | `+0xB8` | V6 RX yoluna elle düzeltme |
| `net_device.netdev_ops` | `+0x134` | `+0xCC` (donor) |
| `net_device.ethtool_ops` | `+0x138` | `+0xD0` |
| `net_device.dev_addr` | `+0x1D0` | `+0x160` |
| `net_device._tx` | `+0x220` | farklı |
| `netdev_queue.state` | TX işaretçisi `+0x50` | donor `+0x08` |
| `netdev_priv` | `+0x3C0` | `+0x380` (donor) |
| `net_device_ops` boyutu | `0x88` | `0x6C` |
| `RTMP_ADAPTER` ayırma boyutu | 1.178.968 | 484.864 |

**Önemli ayrım:** `RTMP_ADAPTER` sürücü özel yapıdır ve boyut farkı tek başına kernel ABI hatası kanıtı değil, farklı sürücü derleme varyantı kanıtıdır. V6 RX yolunu tek başına düzeltmişti fakat diğer `sk_buff` inlineları hâlâ yanlış ofsetlerden okuyor. Bu durum V7 firmware DMA komutundaki hata için güçlü açıklamadır; tüm hata ağacı kesinleşmiş değildir.

Orijinal modülde kullanılan `wlan_cspkernel_ops`, `ffe_receive_skb_locked`, `ffe_learn_skb`, `ra_sw_nat_hook_rx` platform hook'ları donor APCLI adayında aynı şekilde bulunmuyor. Bu farkı basit wrapper ekleyerek tamir edilmiş kabul etmiyoruz.

**Orijinal profil/EEPROM:** V7 profil yamasını içerir; V7 modülünde EEPROM yolu hâlâ `/etc/RT30xxEEPROM.bin` olarak kalmış, dolayısıyla dosya açılmamıştır. Sonraki araştırma dalında `patch_oem_eeprom_path.py` fabrika yolunu kaynak seviyesinde düzeltti ama bu **V7 modülünün içeriğine dahil değildir**. V7 ile daha sonra derlenen ABI denetim adaylarını karıştırmayın.

## 4. Bütün kodlar, yamalar, derleme ve kaynak ağacı

[driver/build/](../driver/build/) altında V1–V7 deneyleri için gerçek kaynak işleme scriptleri korunuyor; eski `scripts/build.sh` ve `scripts/check_modules.py` ile orijinal Kconfig birlikte bulunuyor. `build_bsp_candidate.py` donor `cjdelisle/EN751221-Linux26` kaynaklarını sabit commit üzerinden çekerek `patch_netdev_abi_v3.py`, `patch_ra0_open_v5.py`, `patch_rx_skb_v6.py`, `patch_profile_path_v7.py` yamalarını sırayla uygular. Sonraki araştırmada `patch_oem_eeprom_path.py`, `oem_abi_gate.py`, `source_abi_inventory.py`, `audit_stock_ko_only.py` eklendi.

`source_abi_inventory` çıktısı: 407 C/H dosyası, 311.610 satır; 252 paket makrosu, 64 DMA bağlantısı, 74 PCI/IRQ kullanımı, 258 ApCli çağrı adayı. Bu **lexical envanter**, davranış eşitliği testi değildir.

Bu kodlar **çalışır modem driverı garantisi vermez**. Eski derleyici / exact OEM patched kernel headerları / ZTE `mtk_v2` kaynakları bulunmadığından yeni modül canlı test için uygun değil.

## 5. Kullanıcıya teslim edilen önceki artefaktlar / Actions kanıtları

- https://github.com/yulcaribe/appcli/actions/runs/38826661215 : V7 2.4 GHz deneysel modülünün başarılı **derlenmesi**.
- https://github.com/yulcaribe/appcli/actions/runs/38823553117 : V5 debug izleri.
- https://github.com/yulcaribe/appcli/actions/runs/38824935546 : V6 RX DMA kaynağı.
- https://github.com/yulcaribe/appcli/actions/runs/38828664794 : karşılaştırmalı ABI gate (`BLOCKED`).
- https://github.com/yulcaribe/appcli/actions/runs/38828995554 : donor 407 kaynak dosyası denetim koşusu.
- https://github.com/yulcaribe/appcli : bu projenin ana deposu.

## 6. Sıradaki doğrulama kapıları

1. Stok `.ko`, `/proc/kallsyms`, debug CRC/offsetleri ile kernel API/ABI envanteri.
2. Eksik ZTE `mtk_v2` fonksiyonları, exact kernel patch'leri ve compiler bayraklarını kaynak / binary analizle belirleme.
3. Deneysel AP-only temel işlevi orijinal donanım davranışıyla kıyaslama, simgesel uyum ve sıfır kernel Oops önkoşulu.
4. Ardından APCLI client authentication, association, WPA2 4-way, DHCP, AP+STA eşzamanlı, LAN bridge/NAT, 2.4/5 GHz regresyon.
5. Ancak kurtarma prosedürü hazırsa ve ABI gate **BLOCKED değilse** RAM'den kısa donanım testi.

**Yeni V8 gibi kör denemeler otomatik yapılmaz.** GitHub'a dosya yüklemek modeme yüklemek demek değildir; modem firmware'i bu çalışma kapsamında değiştirilmez.

## 7. Tam tarihsel kaynak raporları ve ham inceleme sonuçları

Bu bölüm, daha önce ayrı Markdown dosyalarına yazılmış bütün teknik bulguları kaybolmadan korur. Bazı eski metinler o zamanki 'güncel durum' ifadesini içerir; üstteki V7 kaydı son canlı testi ifade eder.



---

### Tarihsel belge: 15.10.2026 kaynak araştırması

# H298A APCLI: kaynak araştırması ve uygulama planı (2026-10-15)

## Kısa karar

**Yeni ko dosyalarını H298A'ya yükleme.** Hedef firmware ile birebir aynı ZTE kaynak/BSP ağacını elde etmeden yapılan derlemeler yalnızca *candidate* sayılmalıdır.

## Kanıtlar: cihazdan çıkarılmış gerçek ikili dosyalar

- Donanım: ZTE ZXHN H298A V1.0, hardware V1.0.25, firmware TTN.21T1_220614.
- Çalışan kernel: Linux 2.6.36, GCC **4.3.4**, SMP, 2022-06-13 23:49:50 CST.
- `/etc/autokernelconf`: 2022-06-13 23:44, ZTE yapılandırması.
- Orijinal `mt7612e_ap.ko` içindeki sabit derleme yolu:
  `/home/ws/mtk7510/csp/component/wlan/mtk_v2/drivers/MT7612E/`
- Orijinal `mt7603eap.ko` içindeki sabit derleme yolu:
  `/home/ws/mtk7510/csp/component/wlan/mtk_v2/drivers/MT7603e/`
- Orijinal sürücülerin `.comment` bölümü `GCC: (GNU) 4.3.4`, `.modinfo` bölümü `license=GPL` gösteriyor.
- Deneme sürücülerimiz `cjdelisle/EN751221-Linux26` içindeki **başka bir** `MT7612E_LinuxAP_3.0.4.0.P2_DPA` ve `MT7603` ağacından, GCC 10.3.0 ile çıkıyor. Çalışan kernel `vermagic` değeriyle eşleşiyor olması *yeterli değil*.
- 5 GHz stok kaynak fonksiyonlarının 1.983'ü, #16 adayında 1.553'ü var; fonksiyon sayısı farkı OEM varyant/derleme özellik farkını gösteriyor.
- Orijinal MT7612E içinde `RTMPAllocAdapterBlock` bellek boyutu 1.402.616 bayt, aday #16'da 1.187.008 bayt. **Bu tek başına kernel ABI hatası ispatı değildir**; ancak veri yapısı ve derleme seçeneklerinin çok farklı olduğuna işaret eder. Elle dolgu eklemek çözüm değildir.
- Orijinal `RtmpOsStatsAlloc` 112 bayt, #16 adayları 92 bayt ayırıyor; çekirdek ağ istatistikleri için layout ve header farkı araştırılmalı.
- Gerçek modem testi: 5GHz build #5 `insmod` sırasında `kmem_cache_alloc -> RtmpOsStatsAlloc -> RTMPAllocAdapterBlock -> rt_pci_probe` yolu üzerinden kernel Oops / `BadVA 00c71000`. **Kesin kök neden yalnızca bu call trace ile ispatlanmış değil.**
- OEM'deki `CliWds*` fonksiyonları standart WPA2 AP-client / universal repeater anlamına gelmez. `apcli0` / `apcli5g0` yok ve `ApCliEnable` ioctl desteği cihazda görülmedi.

## Dış kaynak araştırması

1. ZTE'nin resmî GPL kaynak sayfasında `Wireless Home Gateway` kategorisi ve kaynak kodu talebi için `tech.sp@zte.com.cn` adresi yayımlanıyor:
   https://opensource.ztedevices.com/
2. Toplulukta aynı H298A V1.0 / V1.0.25 modelinin repeater menüsünün görünmediği başka bir vaka:
   https://github.com/mkst/zte-config-utility/issues/116
   Aynı model adındaki arayüz/videosu bu firmware'in AP-client sürücüsüne sahip olduğunun kanıtı değil.
3. Bugün kullandığımız upstream aday kaynağı EcoNet EN751221 Linux 2.6.36 için:
   https://github.com/cjdelisle/EN751221-Linux26
   **Bu, orijinal H298A ZTE 2022 driver/BSP kaynağı değil.**

## Uygulanacak yol / karar kapıları

### A. Doğru kaynak ağacını temin et (öncelik 1)

ZTE/operatörden tam model+firmware ile şu girdileri iste:

- H298A TTN.21T1_220614 firmware'in **complete corresponding GPL source** ve kernel 2.6.36'a uygulanan üretici patch'leri; kullandığı `include/linux`, `include/net` ve SoC header dosyaları.
- Orijinal `csp/component/wlan/mtk_v2/drivers/MT7612E` ile `MT7603e` kaynak ağacı ve derleme yapılandırmaları **paylaşılabiliyorsa**. `license=GPL` olarak etiketlenen dağıtılmış modülleri belirt. GPL kapsamı somut lisans şartlarına bağlı.
- GCC 4.3.4 MIPS Big Endian cross toolchain'in adı/indirilebilir SDK, makefile'ları, kernel Module.symvers, OEM `.config` ve modül oluşturma scriptleri.

Not: Orijinal kernel .config zaten yedekte var; firmware dışında rastgele toolchain/kernel kaynaklarıyla eşleştirmek yeterli değil.

### B. Önce stok modülü yeniden üret (öncelik 2)

1. Vendor ağacını `yulcaribe/appcli` içine kopyalamadan veya lisansını ihlal etmeden kaynak edin; gerekiyorsa GitHub Actions sırasında kur.
2. Önce `HAS_APCLI=n` iken modülü derle. *Temel ölçüt*: stok semboller, GPL modinfo/parmtype, vendor `ffe_*`/NAT/`wlan_cspkernel_ops` kancaları, API çağrıları, yapı alanları ve derleme seçenekleri anlamlı biçimde eşleşmeli.
3. GCC 4.3.4 ve OEM yapılandırması kullan; yalnızca `vermagic` eşleşmesini yeterli sayma.
4. Statik karşılaştırmada orijinalde olup yeni modülde beklenen donanım işlevleri yoksa düzelt; `sizeof` değerlerini elle şişirme.

### C. ApCli'yi aç, yeniden karşılaştır

- Aynı baz sürücü üstünde APCLI derleme bayraklarını etkinleştir. APCLI kaynak dosyaları driver varyantında gerçekten mevcut mu doğrula.
- AP/STA eşzamanlı başlatma, aygıt arayüzleri, WPA2 association, DHCP ve bridge/NAT data-plane ayrı ayrı doğrulanmalı.
- Karşılıklı WDS değil, *evrensel WPA2 AP-client* istediğimiz unutulmamalı.

### D. Cihaz üstünde güvenli test, en son aşama

- Önceki kernel Oops'ten dolayı modül değişimi için seri **3,3V UART** konsol ve recovery/bootloader geri yükleme prosedürü hazır olmadan canlı test yok.
- Değişiklikler ilk aşamada sadece RAM'de, flash'a yazılmadan yapılmalı.
- Önce ApCli olmayan temel sürücünün kurulumunu kanıtla; sonra APCLI arayüzünü, WPA2 bağlantısını ve veri aktarımını ayrı test et.

## Alternatif karar

ZTE OEM kaynakları bulunmazsa, **bu firmware üzerinde yalnızca GUI ekleyerek veya mevcut sürücüye ayar yazarak gerçek universal repeater mümkün görünmüyor**. İki rasyonel seçenek:

1. Kablosuz uplink için harici, sürücü desteği doğrulanmış ayrı istemci köprü cihazı; H298A stok kablosuz erişim noktası olarak kalır.
2. Tam yazılım kontrolü veren OpenWrt destekli farklı cihaz üzerinde AP+STA kurmak.

## Yakın vadede yapılmayacaklar

- #4, #5, #16 .ko yüklemeleri, `rmmod`/`insmod` retry.
- Sayısal `0x5c -> 0x70` ve adapter boyutuna körlemesine bellek dolgusu ile “uyumluluk” ilanı.
- ZTE V9 veya başka HW revizyon firmware'ini doğrudan flashlama.


## 2026-10-15: Açık kaynak taramasının somut sonuçları

**Birebir H298A V1.0 / V1.0.25 / TTN.21T1_220614 kernel+Wi-Fi GPL kaynak arşivi doğrulanamadı.** Bu bir yokluk ispatı değildir; taranan herkese açık kaynaklarda teyit edilebilir birebir arşiv bulunmadı.

### Gerçekten ulaşılabilen kaynaklar

- **[cjdelisle/EN751221-Linux26](https://github.com/cjdelisle/EN751221-Linux26):** Linux 2.6.36, MT7603 ve MT7612E sürücü ağacı ve APCLI implementasyonu bulunuyor. **Orijinal ZTE `csp/component/wlan/mtk_v2/drivers` ağacı değildir.** Bu SDK ile hazırlanmış aday sürücü H298A'da kernel Oops oluşturdu. Cihazda yüklenmemeli.
- **[openwrt/mtk-wifi-gpl](https://github.com/openwrt/mtk-wifi-gpl):** Mediatek legacy Wi-Fi GPL sürücü kodu ve MT7612E derleme tanımları mevcut (ör. `os/linux/config.mk.cfg80211`). İncelenen `ap/` dizininde `ap_apcli.c`, `apcli_sync.c` gibi ApCli kaynak dosyaları yok. Dolayısıyla stok ZTE yerine geçecek veya APCLI ile doğrudan derlenebilecek paket değil.
- **[smx-smx/asuswrt-rt](https://github.com/smx-smx/asuswrt-rt):** Trendchip GPL BSP, `linux` ve `toolchain` dizinleri var; ancak kernel çok daha eski (2.6.22 ailesi), H298A'nın 2022 OEM kaynağı değil.
- **[Linux wireless/mt76](https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html):** MT7603E/MT7612E hardware desteği mevcut, fakat modern mac80211 kernel sürücüsü Linux 2.6.36 ZTE sistemine doğrudan takılamaz.

### Resmi ZTE kanalları

- [ZTE GPL/Open Source portalı](https://opensource.ztedevices.com/) cihaz listelenmiyorsa **tech.sp@zte.com.cn** üzerinden iletişim kurulmasını belirtiyor.
- [ZTE resmi açık kaynak bildirimi](https://support.zte.com.cn/support/news/NewsDetail.aspx?newsId=1037164) **Open.Source@zte.com.cn** iletişim adresini de açıkça gösteriyor. Bu bildirim H298A'ya özgü değil.
- [ZTE H298A V1.0 EOS bildirimi](https://support.zte.com.cn/support/news/NewsDetail.aspx?newsId=1022304) ürünün desteğinin **30 Ekim 2022** tarihinde bittiğini söylüyor (Hyperoptic/Blue-Intra istisnası). 2026'da kaynak kodu talebi cevapsız kalabilir; GPL kapsamındaki kaynak talebini yine de iletmek mantıklı.

### İstenen kaynakların TAM adı

Üreticiye hem ürünün yazılım versiyonunu hem derlenmiş modülden çıkan kaynak dizinlerini belirt:

- Product: **ZTE ZXHN H298A V1.0**, Hardware **V1.0.25**
- Firmware: **TTN.21T1_220614** (June 2022), ISP: Türk Telekom
- SoC MT751020; Linux 2.6.36 SMP MIPS32 Big Endian; build compiler GCC 4.3.4
- `csp/component/wlan/mtk_v2/drivers/MT7603e`
- `csp/component/wlan/mtk_v2/drivers/MT7612E`
- GPL kapsamındaki kernel kaynak ağacı + ZTE patches + ilgili header'lar, build flags, original Makefiles, toolchain tanımı, .config ve gerekliyse Module.symvers. Açık olmayan lisanslı sürücüleri de otomatik GPL varsayma.

**İstenen güvenli sonraki eşik:** Önce bu kaynaklarla ApCli kapalı bir modülün ZTE'nin fonksiyonları/platform hook'larıyla uyumlu derlenebilmesi; sonrasında ApCli etkinleştirme ve yalnızca güvenli donanım test düzeneğinde deneme.



---

### Tarihsel belge: 15.10.2026 sürücü varyantları ve build sonuçları

# H298A beş sürücü çifti: build #3 sonuçları (15 Ekim 2026)

Kaynak: [beşli matris kodu](../experiments/driver-matrix/README.md) | [Actions run #38744860204](https://github.com/yulcaribe/appcli/actions/runs/38744860204) | Commit `8c7d0cf44407e8b6d7abc776db995aeb56a9755c`.

## Derleme sonucu

**5 profil × 2 band = 10 ayrı .ko dosyası başarıyla üretildi**; hepsinin GitHub Actions artifact dosyası mevcut. Her profil, modülün iki bandını ayrı feature flag'lerle derler.

| Profil | Derleme | Artifact |
|---|---|---|
| zte-stocklike | İki .ko oluştu | [h298a-zte-stocklike-3](https://github.com/yulcaribe/appcli/actions/runs/38744860204/artifacts/11978835097) |
| apcli-minimal | İki .ko oluştu | [h298a-apcli-minimal-3](https://github.com/yulcaribe/appcli/actions/runs/38744860204/artifacts/11978580619) |
| apcli-wds | İki .ko oluştu | [h298a-apcli-wds-3](https://github.com/yulcaribe/appcli/actions/runs/38744860204/artifacts/11978345807) |
| apcli-client-wds | İki .ko oluştu | [h298a-apcli-client-wds-3](https://github.com/yulcaribe/appcli/actions/runs/38744860204/artifacts/11976918072) |
| apcli-mac-repeater | İki .ko oluştu | [h298a-apcli-mac-repeater-3](https://github.com/yulcaribe/appcli/actions/runs/38744860204/artifacts/11978150850) |

## Bütünlük doğrulaması (her bir ikili dosya SHA-256)

| Profil | 2.4 GHz `mt7603eap.ko` | 5 GHz `mt7612e_ap.ko` |
|---|---|---|
| zte-stocklike | `961f00accac4de7cd2807c4ec92774b3d1700ad2ab5665327071ab7b17b82d60` | `722890381822c10531b4c5ebd92c76903c29bd840bb408f1fc5ccf64e968983a` |
| apcli-minimal | `fbb78ad36425331761c3e808154f8e7a0438862f6a8e2266401010704cd5b7cf` | `7ce5a8a2abc26db27a92f0810903aaf6aba4614425c2bd2356126712b57a2184` |
| apcli-wds | `ba38bc3f0ad6d3fe1f813c927dcc11034480c0d6a676babc85fe69a65d1f2fe7` | `8c43931369c5830bb861d4f7fab763552eeb30a7c169ee2d69b4dde59040ea6f` |
| apcli-client-wds | `41398e70e5de83bcf5b123fe4c0878f021eeb33ba6b98c72fecabfd0dc1c7283` | `6afd7355ec42442fb6a4b5c9d7c675499211cbcad1c47cb05df0113500f3e3b8` |
| apcli-mac-repeater | `9fdc6e9653df72add0e4790b052aa61554c315a301837ec8450a89bb7e43ae66` | `88933de845c1e11c12aaccf9278a1ceaff0e342c71865e163e192515a2f09ef0` |

## KESİN DURUM: DONANIMA YÜKLEME ENGELLİ

Beş profilin de `verification.txt` içinde **static gate FAIL** çıkıyor. Firmware ile aynı MIPS BE ELF mimarisi ve vermagic, cihaz ABI uyumu değildir. Beş çiftin tamamında stok sürücüyle `net_device_stats` 112/92 bayt farkı devam ediyor. İki bandın 2.4 GHz adaylarında, eski H298A Oops ile ilişkili `kmalloc_caches -> kmem_cache_alloc` kod yolu bulunuyor. Üretici `ffe_*`, `wlan_cspkernel_ops` gibi hook'lar ve `RTMP_ADAPTER` yerleşimi eşleşmemiş.

Bu nedenle **yüklemek için uygun/doğrulanmış sürücü yok**. 5 çift ancak offline kaynak/ELF karşılaştırması için kullanılmalı. `insmod`, `rmmod`, flashlama **yapılmamalı**. Özellikle önceki v5 modül kernel Oops oluşturdu.

**Kaynak gerçekliği:** `zte-stocklike` dahil bütün modüller benzer MediaTek/EcoNet EN751221 GPL ağacı üzerine ZTE'den çıkarılmış yalnızca `.config` koyularak üretilmiştir. **Hiçbiri orijinal ZTE OEM 2022 Wi-Fi kaynak kodundan derlenmiş değildir.** Orijinal sürücüler kaynak kodu olmadan doğrudan yeniden derlenemez.

## Sonraki gerçek teknik engel

Önce ZTE OEM sürücü/kernal header kaynaklarını temin et ya da üretici data yapı yerleşimi + GCC 4.3.4 ile stok AP sürücüyü birebir statik olarak yeniden üret. Bu yapılmadan APCLI=on sürümü canlı test adayı değildir.



---

### Tarihsel belge: 15.10.2026 ZTE/deneysel ELF karşılaştırması

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



---

### Tarihsel belge: 16.10.2026 V7 ABI denetimi

# H298 / ZXHN H298A: OEM MT7603E vs. generic BSP integrated APCLI audit

**Date:** 2026-10-16 | **Branch:** dev/h298-mt7603e-oem-abi-port | **Status:** NOT VERIFIED TO LIVE-LOAD

Offline comparison of user-provided original ZTE MT7603E ELF vs. experimental V7. Factory binaries are **not** published to this repository.

## Binary baseline

| Metric | Factory OEM | Experimental V7 |
|---|---|---|
| Driver size | 2,778,084 bytes | 1,854,400 bytes |
| SHA-256 | 4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5 | 016046fb7193680a300f5f80b4855b2574c60d3e0f1bf92e5d39b468ee1dbf4c |
| GCC compiler | 4.3.4 | 10.3.0 |
| MIPS target | 32-bit big-endian, MIPS32R2 | Same |
| Kernel vermagic | 2.6.36 SMP mod_unload MIPS32_R2 32BIT MT_SMTC | Same |
| Defined functions | 2133 | 1702 |
| Common function names | 1462 | 1462 |
| Factory-only functions | 671 | absent in donor |
| Candidate-only functions | absent in factory | 240 |

Same target/vermagic is insufficient to prove kernel ABI compatibility. Function names are not a guarantee of identical logic.

## Kernel-facing structure evidence from MIPS instructions

| Field / call | ZTE factory | Candidate V7 |
|---|---:|---:|
| skb data pointer, RTMP_QueryPacketInfo | +0xC4 | +0xD4 |
| skb len, RTMP_QueryPacketInfo | +0x58 | +0x4C |
| skb RX head from RTMP_AllocateRxPacketBuffer | +0xB8 | V6 manual edit +0xB8 |
| RTMP_ADAPTER allocation, RTMPAllocAdapterBlock | 1,178,968 (0x11FD58) | 484,864 (0x76600) |
| RtmpOsStatsAlloc allocation | 112B | 112B |

The early V6 RX fix addressed one path; it did **not** rewrite other skb inlines and driver packet helper accesses. A full MIPS instruction-level review of RTMP_QueryPacketInfo proves generic skb offsets still compile into V7. This explains why a firmware DMA command may see a bogus or zero data length. A single fix in AndesMTPciKickOutCmdMsg is insufficient.

RTMP_ADAPTER is private to the driver. Its size mismatch means a different vendor feature/build variant; it is not *by itself* a kernel ABI violation. Similarly, a 112-byte stats allocation does NOT validate all net_device_stats members.

## Vendor APIs and kernel source

OEM external integration includes wlan_cspkernel_ops, ffe_receive_skb_locked, ffe_learn_skb, ra_sw_nat_hook_rx and specialized packet paths. These are absent in the candidate. Different imports and call conventions cannot be fixed safely with guessed wrappers. Earlier netdev layout patches cover only some members.

Factory source path: /home/ws/mtk7510/csp/component/wlan/mtk_v2/drivers/MT7603e/

Factory kernel header path embedded in ELF: /home/ws/mtk7510/csp/opensource/cspkernel3.4/linux/include/linux/netdevice.h

The directory name cspkernel3.4 is not proof that the running kernel is 3.4. Measured vermagic remains 2.6.36.

## V1 through V7 device observations

- V1 failed to load due to undefined pAd_save.
- V2/V3/V3.1 had kernel faults during attach.
- V4 loaded, but ra0 opening crashed.
- V5 identified RX DMA BadVA=0x20.
- V6 reached profile loader after RX DMA, then failed because the generic /etc/Wireless/RT2860AP/RT2860AP.dat path was absent.
- V7 loaded the real /etc/Wireless/MT7603e/RT2860AP.dat, initialized RX rings and parsed firmware information, but kernel BUG at r4k_dma_cache_wback_inv via AndesMTPciKickOutCmdMsg; no functional ra0 or APCLI interface was confirmed.

The factory MT7603E_EEPROM.bin file at /etc/Wireless/MT7603e/ is 512B. The donor tries nonexistent /etc/RT30xxEEPROM.bin. Branch now applies a targeted read-only EEPROM profile path correction; does not alter modem files.

## Required full compatibility verification

1. Obtain exact ZTE mtk_v2 MT7603e GPL driver, its patched Linux kernel headers, build configuration, firmware revision and original compiler GCC 4.3.4.
2. Build a stock-equivalent AP-only baseline FIRST; audit every kernel-facing struct: sk_buff (including recycling, head, data, tail, len), net_device, net_device_ops, netdev_queue, net_device_stats, PCI/DMA types, callback signatures, vendor hooks, IRQ, hotplug and SMP/MT_SMTC behavior.
3. Audit private firmware/control ring structures for driver variant equivalence. Reconstructing the entire RTMP_ADAPTER from a different source by magic offsets is unsafe.
4. Once the AP-only driver matches OEM ABI and operates, compile APCLI, MAT/WPA2/client state machine/WDS features and test association, packet flow, bridge/DHCP, roaming, restart and failure paths.
5. Fail closed: do not call any experimental .ko production-ready based only on successful insmod or vermagic. Retain RAM-only testing, physical Ethernet and independent recovery.

ZTE states source for GPL-governed components can be requested through https://opensource.ztedevices.com/ if a model is not listed. Do not assume the matching tree has been obtained until verified.

## Changes made on the dev branch

- Preserved V5/V6/V7 prototype code and experimental patch history.
- Added patch_oem_eeprom_path.py and wired factory 2.4 GHz EEPROM into the source-generation pipeline.
- Added oem_abi_gate.py with OEM disassembly-derived checks and explicit BLOCKED status.
- Added an ABI report step to experimental GitHub Actions; output OEM_ABI_GATE.json is archived.
- Main branch and real modem filesystem remain unchanged.

**Conclusion:** No safe, functional H298 APCLI driver is verified. Current blockers are structural; iterative runtime-crash patching must not substitute for real OEM source and kernel ABI reconstruction.


## Automated whole-donor source inventory (verified CI 38828995554)

A separate runner step scanned the **entire patched generic MT7603 donor tree** (all 407 C/H files, 311,610 source lines, 10,771,028 source bytes). This is a file-by-file *lexical inventory*, **not** proof that all behaviors match the unknown OEM source.

| Risk category (including comments and macros) | Occurrences |
|---|---:|
| Direct skb member access | 26 |
| skb inline manipulation | 51 |
| OS packet helper macros | 252 |
| net_device struct fields | 8 |
| netdevice queue operations | 13 |
| DMA operations and wrappers | 64 |
| PCI/IRQ operations | 74 |
| EEPROM/firmware/profile operations | 31 |
| APCLI call sites | 258 |
| vendor networking references | 8 |

Highest-risk contact files: os/linux/rt_linux.c, common/cmm_data_pci.c, include/os/rt_linux.h, common/cmm_data.c, mcu/andes_mt.c, common/cmm_mac_pci.c, tx_rx/wdev_rx.c. These contain widely used packet and DMA paths; offset changes must be handled at the correct OEM kernel header/toolchain layer rather than individually.

GitHub Actions run: https://github.com/yulcaribe/appcli/actions/runs/38828995554

CI artifact contains **OEM_SOURCE_ABI_INVENTORY.json** with per-file, per-category counts and line-number samples, plus **OEM_ABI_GATE.json**, which returns **BLOCKED** for skb_data, skb_len, and RTMP_ADAPTER allocation mismatch. This preserves measurable results for every source revision.



---

### Tarihsel belge: 16.10.2026 orijinal .ko tersine mühendislik bulguları

# H298: OEM .ko Binary-Only Reverse Engineering

**2026-10-16 | Branch dev/h298-mt7603e-oem-abi-port | NO VERIFIED APCLI DRIVER**

## Genuine OEM inputs, hashes checked

| Metric | MT7603E 2.4 GHz | MT7612E 5 GHz |
|---|---|---|
| Size | 2,778,084 B | 2,637,120 B |
| SHA-256 | 4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5 | 2ee8df1b1fbad51f34645dd773009acf59fc37ea90ac9d00365ef91a516adee2 |
| Compiler | GCC 4.3.4 | GCC 4.3.4 |
| Defined functions | 2133 | 1983 |
| Kernel undefined imports | 137 | 136 |
| Exported symbols | 10 | 0 |
| Function-symbol relocation references | 4560 | 4140 |
| Compiled functions named ApCli | 0 | 0 |
| WDS functions | 10 | 10 |

Both target ELF32 MIPS big-endian MIPS32r2, vermagic 2.6.36 SMP mod_unload MIPS32_R2 32BIT MT_SMTC.

This binary-only inventory is obtained from readelf ELF symbols/relocations, __ksymtab_strings and LLVM MIPS disassembly. A relocation reference does not necessarily imply a dynamically executed call.

## Verified original 2.4 GHz code data offsets

| Field | Original offset |
|---|---|
| sk_buff.data | +0xC4 |
| sk_buff.len | +0x58 |
| sk_buff.head | +0xB8 |
| RX reserve | 32 bytes |
| net_device.netdev_ops | +0x134 |
| net_device.ethtool_ops | +0x138 |
| net_device.dev_addr | +0x1D0 |
| net_device._tx | +0x220 |
| netdev_queue.state | tx +0x50 |
| RTMP_ADAPTER allocation (private structure, not kernel ABI) | 0x11FD58, 1,178,968B |

This list provides real field-use instructions, not a complete definition of the original C structures.

## Why a binary flag cannot enable repeater

The original module has AP-side WPA, survey/scanning, CliWds proxy and AP station association/reporting functions. However, neither OEM ELF has named APCLI client state-machine functions ApCliIfUp, ApCliLinkUp, ApCliAuthStateMachineInit, ApCliAssocStateMachineInit, ApCliCtrlStateMachineInit, Set_ApCli_Enable_Proc or Set_ApCli_WPAPSK_Proc.

The literal "ApCli" in a string and CliWds_* symbols do not establish an ordinary WPA2 Wi-Fi client capable of associating with an unrelated access point. Set_WorkMode_Proc only stores a setting in the visible disassembly; no implemented STA client engine was found.

The OEM 2.4 GHz module exports just ten functions. Unexported internal symbols cannot normally be resolved by an independent external .ko. A relocatable MIPS binary can in principle be extended, but safe APCLI requires actually implementing association, authentication, key installation, transmit and receive flow, firmware protocol, disconnection and bridging while respecting ZTE internal kernel ABI. Hex patching a mode value is not sufficient.

## Complete locally delivered reverse-engineering artifact

The user package H298_ZTE_ORIJINAL_KO_TAM_BINARY_AUDIT_2026-10-16.zip includes:
- All 2G and 5G defined-function names and sizes in CSV.
- MIPS function reference edges in CSV (possible calls or pointer references).
- Targeted original assembly for IRQ, RX skb, netdevice, radio, ioctl, workmode, WDS proxy, profile and firmware.
- Full per-band section/import/export/feature summary JSON.
- 2G-versus-5G function comparison.
- Reproducible offline Python audit script, ABI map, README and evidence notes.

**Never commit OEM proprietary .ko binaries to this repository.** Only notes and scripts belong on the development branch. Main and modem flash remain unchanged.

**Outcome:** Original .ko binary reverse engineering completed for this phase. A functioning APCLI Wi-Fi-to-Ethernet driver is NOT implemented or verified. Prior generic donor V1-V7 modules must not be described as production-ready.

