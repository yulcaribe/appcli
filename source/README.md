# Kaynaklar ve orijinal modem yedekleri

Bu klasör, proje boyunca araştırılan sürücü ağaçlarını, gerçek cihaz dosyalarının SHA-256 manifestini ve orijinal kernel yapılandırmasını bir arada tutar.

**Dosyaların kaynak/menşe ayrımı:**

- [kernel/h298a-zte-20220613.config](kernel/h298a-zte-20220613.config): Cihaz `/etc/autokernelconf` üzerinden kurtarılmış orijinal Kconfig'in standartlaştırılmış metni. Derleme için ikinci kopyası `driver/build/configs/` içinde.
- [original/README.md](original/README.md): **Orijinal 2.4 GHz ve 5 GHz `.ko` dosyaları için SHA256, boyut, orijinal modem yolu ve yedekleme adımları**.
- [references.md](references.md): internet bağlantıları, araştırma paketi manifesti, kullanıcıdan alınan RAR, ZTE kaynak linkleri ve Actions.
- `driver/mt7603eap_v7.ko`: tek arşivlenmiş deneysel derleme çıktısı, **orijinal ZTE modülü değildir**.

**Eksik dosyaları varmış gibi göstermeyin:** Orijinal `.ko` dosyalarının SHA-256'ları yerel yedekten doğrulandı, ancak GitHub'a binary aktarımı henüz yapılmadı. Bu klasördeki `original/` altına yüklenmediği sürece onları repoda var kabul etmeyin. Tam orijinal dosyalar ile V7'nin birlikte saklandığı ayrı yerel teslim paketi bulunur.

Bağlantılı [docs/driver.md](../docs/driver.md) raporu stok ve deneysel sürücülerin farkını açıkça tutar.
