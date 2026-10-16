# Kullanılan kaynaklar ve bulunan dosyalar

Son tarama: 16.10.2026. Linklerin verilmesi dosyanın H298 için birebir uyumlu olduğunu kanıtlamaz. **Kaynaklar birebir OEM / benzer donör / teknik doküman** olarak sınıflandırılır.

## Gerçek firmware, kullanıcı yedekleri

- ZTE MT7603E orijinal `mt7603eap.ko` ve MT7612E orijinal `mt7612e_ap.ko`. Hash ve boyut: [original/README.md](original/README.md).
- Kconfig: `/etc/autokernelconf` → `kernel/h298a-zte-20220613.config`.
- Stok profil: `/etc/Wireless/MT7603e/RT2860AP.dat` (2.100B), `/etc/Wireless/MT7612E/RT2860AP.dat` (2.217B). İçerik modemden repoya aktarılmadı, parolalar korunur.
- Stok EEPROM: `MT7603E_EEPROM.bin` ve `MT7612E_EEPROM.bin` (512B). Bunların modemden ayrı yedeklerine dair yalnızca cihazda dosya bulunduğu kesin; repoda binary yok.
- Kullanıcının sağladığı `_20151027134607312.rar` (MediaTek eski sürücü donor araştırması): SHA256 `ea0fc64e7cbc7368ce537c619e0d29a0dfade30d8f3d0cf60192e83df2261bd2`. Ayrı yerel pakette saklı, bu GitHub ağacında içerik yok.
- `H298_MT7603E_APCLI_KAYNAK_V1.zip` (önceki kullanıcıya teslim edilmiş 512 girdilik kaynak paket): SHA256 `aa093ec74dd56d26df83633dd7606f03b4a1deae4bd03b25ec6a448417ae51b4`. Düzeltmelerin asıl izi: [driver/build/](../driver/build/).

## İnternette araştırılmış kaynaklar

| URL | Açıklama / doğrulama |
|---|---|
| https://github.com/cjdelisle/EN751221-Linux26 | Açık erişimli EN751221 / MT7603 / MT7612 donör Linux26 BSP. **ZTE exact kaynak değildir.** `scripts/build.sh` sabit commit `aea3a43562e8d3dc0335624202fde08d713a18c2` kullanır |
| https://github.com/openwrt/mtk-wifi-gpl | MediaTek Wi-Fi açık sürücü ağacı; OEM H298 birebir aynı dal değil |
| https://github.com/mand3v/MT7603U | MT7603U USB tabanlı DPA eski kaynak; gerçek donanım PCIe MT7603E. Önceki `port.py` kaynağı |
| https://github.com/mkst/zte-config-utility | ZTE konfigürasyon aracı; eski firmware/config analizi için araştırıldı |
| https://github.com/mkst/zte-config-utility/issues/116 | ZTE / modem konfigürasyonu tartışması |
| https://github.com/smx-smx/asuswrt-rt | AsusWRT / Wi-Fi sürücü referansı; doğrudan H298 binary değil |
| https://wireless.docs.kernel.org/en/latest/en/users/drivers/mediatek.html | Linux MediaTek Wi-Fi sürücü dokümanları; yeni mt76 sürücüsü eski ZTE kernel üzerinde doğrudan çalışmaz |
| https://opensource.ztedevices.com/ | ZTE açık kaynak kodu sayfası; exact ZTE GPL kernel/MT7603e yamasını arama/talep |
| https://support.zte.com.cn/support/news/NewsDetail.aspx?newsId=1022304 | ZTE destek sayfası, eski araştırma bağlantısı |
| https://support.zte.com.cn/support/news/NewsDetail.aspx?newsId=1037164 | ZTE destek sayfası, eski araştırma bağlantısı |

ZTE kaynak talep iletişimleri tarihsel notlarda `tech.sp@zte.com.cn` ve `Open.Source@zte.com.cn` olarak geçmişti; **bu adreslere yeni talep gönderilmedi**. Exact mtk_v2 kaynak yolu orijinal MIPS ELF'de `/home/ws/mtk7510/csp/component/wlan/mtk_v2/drivers/MT7603e/` olarak görüldü.

## Orijinal dökümler / proje kaynakları

- https://github.com/yulcaribe/appcli/actions/runs/38636495846 (ilk build #4 olarak belgelenen çalışma)
- https://github.com/yulcaribe/appcli/actions/runs/38640001017 (#5 / 5G)
- https://github.com/yulcaribe/appcli/actions/runs/38643129823 (ZTE config ile #16)
- https://github.com/yulcaribe/appcli/actions/runs/38744860204 (driver matrix varyant çalışmaları)
- https://github.com/yulcaribe/appcli/actions/runs/38823553117 (V5)
- https://github.com/yulcaribe/appcli/actions/runs/38824935546 (V6)
- https://github.com/yulcaribe/appcli/actions/runs/38826661215 (**V7** derlemesi)
- https://github.com/yulcaribe/appcli/actions/runs/38828664794 (ABI gate BLOCKED)
- https://github.com/yulcaribe/appcli/actions/runs/38828995554 (407 dosya kaynak envanteri)
- https://github.com/yulcaribe/appcli/actions/runs/38862914166 (V7'yi proje staging ağacına checksum ile aktarma)

**Önemli:** Eski GitHub Actions artifactleri zamanla silinebilir; V7'nin `driver/` içindeki kalıcı blob'u bu nedenle tutuluyor. Orijinal modem .ko'ları artefaktlarda değil, kullanıcı yedeğinde ve ayrı yerel pakette bulunuyor.
