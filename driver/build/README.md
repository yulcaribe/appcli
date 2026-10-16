# Driver kaynak/derleme çalışma alanı (arşiv)

Bu dizin bir **build çalışma alanıdır**, V7'yi otomatik olarak güvenilir çalışır sürücüye dönüştürmez. İçindeki kaynak kod/scriptler ve yamalar V1–V7 gelişimini ve 16 Ekim ABI araştırmasını yeniden üretmek içindir.

**Önemli:** V7 arşiv .ko dosyası, 16 Ekim'deki en son `patch_oem_eeprom_path.py` eklenmeden önce 38826661215 numaralı Actions çalışmasında derlenmiştir. Bu klasördeki **güncel script zinciri** artık EEPROM düzeltmesini de uygular ve V7 ile byte düzeyinde aynı modülü üretmez. Bunun adı 'V7 aynısını yeniden derle' değil 'V7 sonrası deneysel araştırma' olmalıdır.

```text
driver/build/
  scripts/build.sh             # kaynakları sabit commit'ten indiren orijinal betik
  scripts/check_modules.py     # statik ELF/ABI denetim denemesi
  configs/h298a-zte-20220613.config   # gerçek ZTE kernel config
  experiments/h298-mt7603e-oem/
      build_bsp_candidate.py    # donor build script üretir
      port.py                   # alternatif USB donor source port
      patch_netdev_abi_v3.py    # ZTE net_device ofsetleri
      patch_ra0_open_v5.py      # kernel debug + queue düzeltmesi
      patch_rx_skb_v6.py       # RX DMA + sk_buff başlık düzeltmesi
      patch_profile_path_v7.py # orijinal 2.4G RT2860AP.dat yolu
      patch_oem_eeprom_path.py  # V7 sonrası EEPROM araştırma yaması
      oem_abi_gate.py           # FAIL-CLOSED kaynak/offline OEM ABI denetimi
      source_abi_inventory.py   # 407 C/H kaynak dosyası envanteri
      audit_stock_ko_only.py   # gerçek fabrika .ko ELF audit
      abi_audit.py              # OEM ve aday symbol karşılaştırması
      tests/                    # unit testler
  experiments/driver-matrix/   # önceki varyant build çalışmaları
```

**Deneysel kaynak üretimi:** Linux üzerinde `cd driver/build`; `python3 experiments/h298-mt7603e-oem/build_bsp_candidate.py`; daha sonra oluşan `experiments/h298-mt7603e-oem/mtk-v2-bsp-build.sh` çalıştırılabilir. Gereken MIPS compiler, binutils, bison, flex vb. GitHub Actions eski loglarında kayıtlıdır. Bu genel kaynak ağacı **orijinal OEM patched kernel headerlarıyla aynı değildir**.

**Not:** Silinen eski root-level Actions workflow dosyaları tarihsel Git geçmişinde durur; bu temiz repoda otomatik build workflow'u etkin değildir. Derlemeden çıkan `.ko` üzerinde önce `oem_abi_gate.py` ve gerçek kernel/firmware denetimi yapılmalıdır. `BLOCKED` çıkan binary canlı yüklenmez.

Orijinal OEM modülleri burada **güvenilir referans** olarak kullanılmalıdır. Tek başına generic donor `HAS_APCLI=y` demek işlevsel Wi-Fi istemcisi sağlamaz. [driver.md](../../docs/driver.md).
