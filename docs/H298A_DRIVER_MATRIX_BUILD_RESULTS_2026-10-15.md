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
