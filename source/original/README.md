# Orijinal ZTE kernel modülü manifesti

**Bu dizinde orijinal binary'ler henüz bulunmuyor.** Bu README yol/özet kaydıdır; hiç yokmuş gibi göstermiyoruz.

| Orijinal modül | Modemdeki yol | Boyut | SHA-256 |
|---|---|---:|---|
| MT7603E 2.4 GHz `mt7603eap.ko` | `/lib/modules/mt7603eap.ko` | 2.778.084 | `4081714141389765e7d8dfd70bd86ac4119de247ea09220a4ce07629ec4697e5` |
| MT7612E 5 GHz `mt7612e_ap.ko` | `/lib/modules/mt7612e_ap.ko` | 2.637.120 | `2ee8df1b1fbad51f34645dd773009acf59fc37ea90ac9d00365ef91a516adee2` |

Bu iki dosya daha önce modemden Windows'a yedeklendi, 16 Ekim 2026 tarihinde analiz için yerel çalışma alanında bulunup checksum ile doğrulandı. **Sıfırdan üretilemeyen modem kaynak dosyalarıdır.**

Repo'ya eklemek için dosyalar `source/original/` içine gerçekten kopyalanmalı, SHA256 kontrolü yapılmalı, ardından Git commit/push yapılmalıdır. Repo temizliği bunların orijinal PC yedeklerini silmez.

**Güvenlik:** Orijinal modülü yeniden derlemek için `gcc 4.3.4`, kernel config ve OEM include headerları henüz eksiktir. Stok dosyalarını modemde değiştirmeyin.
