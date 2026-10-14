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
