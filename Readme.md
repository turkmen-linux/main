# Türkmen GNU/Linux Ana Paket Deposu (`main`) — Bakımcı ve AI Ajan Kılavuzu

Bu belge, **Türkmen GNU/Linux** dağıtımının resmi çekirdek, sistem ve masaüstü paket tariflerini (`ympbuild`) barındıran `main` deposu için kapsamlı teknik standartları, mimari kuralları, derleme süreçlerini, hata ayıklama yöntemlerini ve yapay zeka ajanlarının uyması gereken çalışma protokollerini tanımlar.

> **🤖 YAPAY ZEKA AJANLARI VE OTOMASYON BOTLARI İÇİN ZORUNLU TALİMAT:**
> Bu depoda herhangi bir inceleme, sürüm güncellemesi, bağımlılık düzenlemesi veya yeniden derleme (rebuild) işlemi yapmadan önce **bu belgenin tamamını okuyun ve "Bölüm 7: AI Ajan Çalışma Protokolü" altındaki 18 kurala istisnasız uyun.** Kurallara aykırı üretilen paket tarifleri ve toplu kontrolsüz değişiklikler doğrudan reddedilir.

---

## 1. Dağıtım Mimarisi ve Temel Teknik Kurallar

Paket tariflerini (`ympbuild`) sıfırdan yazarken veya mevcut tarifleri güncellerken Türkmen GNU/Linux'un temel mimari kararlarına kesinlikle uyulmalıdır:

### 1.1. Bağımsız Taban ve Paket Yöneticisi (`ymp`)
* Türkmen GNU/Linux; Arch, Debian, Alpine veya Gentoo gibi herhangi bir dağıtımın türevi değildir. Sıfırdan inşa edilmiş bağımsız bir tabana sahiptir.
* Paket yönetimi için kendi yerel aracı olan **`ymp` (Yerli ve Milli Paket)** kullanılır.
* Başka dağıtımlara ait araçlar, makrolar veya varsayımlar (`makepkg`, `apkbuild`, `rpmbuild`, `dpkg-buildpackage`, `apt`, `pacman`, `emerge` vb.) hiçbir koşulda kullanılmaz.

### 1.2. `systemd` Bağımsızlığı ve OpenRC Mimarisi
* Sistem servis yöneticisi (init) olarak **OpenRC** ve cihaz yöneticisi olarak **`eudev`** kullanır.
* Paketlere **asla** `systemd`, `libsystemd`, `elogind` (gerekmedikçe/alternatifi varsa) veya systemd tabanlı `udev` bağımlılığı eklemeyin.
* Derleme yapılandırmalarında systemd desteğini açıkça kapatan bayrakları kullanın:
  * **Meson:** `-Dsystemd=disabled -Dsystemd_system_unit_dir=no -Dsystemd_user_unit_dir=no`
  * **Autotools (`./configure`):** `--without-systemd --disable-systemd --with-systemdsystemunitdir=no`
  * **CMake:** `-DWITH_SYSTEMD=OFF -DENABLE_SYSTEMD=OFF -DUSE_SYSTEMD=OFF`
* Kaynak kod içerisinde `systemd` servis dosyaları (`.service`, `.socket`, `.target`) üretiliyorsa ve paket bir sistem servisi sunuyorsa, uyumlu bir OpenRC init betiği (`/etc/init.d/<servis>`) ekleyin; gereksiz systemd birim dosyalarını `package()` aşamasında temizleyin.

### 1.3. `-dev` / `-devel` Paket Ayrımı Yoktur
* Türkmen GNU/Linux'ta geliştirme dosyaları ayrı alt paketlere bölünmez. Başlık dosyaları (`.h`), `pkg-config` tanımları (`.pc`), CMake modülleri (`.cmake`), statik/dinamik geliştirme kütüphaneleri doğrudan ana paketin içinde paketlenir.
* `depends` veya `makedepends` dizilerine **asla** `-dev` veya `-devel` son ekine sahip paket isimleri yazmayın (Örn: `openssl-dev` yerine `openssl`, `libx11-devel` yerine `libX11` yazılmalıdır).

### 1.4. Kütüphane Yolları (`/usr/lib64`) ve FHS Standartları
* Sistem 64-bit (`x86_64`) mimaride tüm paylaşımlı ve statik kütüphaneleri standart **`/usr/lib64`** dizinine kurar.
* `/usr/lib` dizini (özel mimari bağımsız betikler veya Python site-packages istisnaları hariç) paylaşımlı `.so` kütüphaneleri için **kullanılmaz**.
* Derleme sistemlerinde kütüphane yolunu açıkça belirtin:
  * **Autotools:** `--prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc --localstatedir=/var`
  * **Meson:** `--prefix=/usr --libdir=lib64 --sysconfdir=/etc --localstatedir=/var`
  * **CMake:** `-DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib64 -DCMAKE_INSTALL_SYSCONFDIR=/etc`
* Eğer hatalı bir derleme sistemi dosyaları zorla `$DESTDIR/usr/lib` altına kuruyorsa, `package()` aşamasında bunları `$DESTDIR/usr/lib64` altına taşıyın ve boş kalan `/usr/lib` dizinini temizleyin.

### 1.5. Derleyici ve Bağlayıcı Standartları
* Varsayılan C/C++ derleyici altyapısı **GCC** ve C standart kütüphanesi **glibc**'dir.
* Sistem genelindeki `CFLAGS`, `CXXFLAGS`, `LDFLAGS` ve `MAKEFLAGS` değişkenleri `ymp` derleme ortamı tarafından otomatik olarak enjekte edilir. Özel bir hata çözümü gerekmedikçe `ympbuild` içinde bu bayrakları ezmeyin; gerekirse `CFLAGS+=" -fPIC"` şeklinde ekleme yapın.

---

## 2. Depo Yapısı ve Yönetim Araçları

Depo, paketlerin işlevlerine ve masaüstü ortamlarına göre kategorize edilmiş dizinlerden oluşur:

| Dizin | Kapsam ve İçerik Açıklaması |
| :--- | :--- |
| `sys/` | Çekirdek (kernel), glibc, gcc, binutils, OpenRC, eudev, temel sistem araçları |
| `dev/` | Derleyiciler, yorumlayıcılar (Python, Rust, Go, Lua), kütüphaneler, derleme araçları (`meson`, `cmake`, `cargo-c`) |
| `net/` | Ağ araçları, protokol kütüphaneleri, tarayıcı motorları, güvenlik ve VPN araçları |
| `media/` | Ses ve görüntü işleme kütüphaneleri (`ffmpeg`, `pipewire`, `mesa`, `gstreamer`), kodekler |
| `x11/` | X.Org sunucusu, X11 protokol başlıkları, `libX*` kütüphaneleri, X sürücüleri |
| `gui/` | Wayland protokolleri, GTK, Qt, pencere yöneticileri ve ortak grafik araç takımları |
| `app/` | Son kullanıcı komut satırı ve grafik uygulamaları, editörler, arşiv araçları |
| `www/` | Web sunucuları, web tabanlı araçlar ve istemciler |
| `gnome/` | GNOME masaüstü ortamı bileşenleri ve uygulamaları |
| `kde/` | KDE Plasma masaüstü ortamı ve KDE Frameworks paketleri |
| `xfce/` | XFCE masaüstü ortamı bileşenleri |
| `cinnamon/` | Cinnamon masaüstü ortamı bileşenleri |
| `lxde/` | LXDE masaüstü ortamı bileşenleri |
| `pantheon/` | Pantheon masaüstü ortamı bileşenleri |
| `hyprland/` | Hyprland Wayland dizgicisi (compositor) ve ekosistem araçları |

### Kök Dizin Otomasyon Betikleri
* **`build.sh`:** Bağımlılık sırasına göre toplu veya otomatik paket derleme süreçlerini yöneten ana betik.
* **`update-sums.sh`:** Paket tariflerindeki `source` URL'lerini indirerek doğrulama özetlerini (`sha256sums` / `md5sums`) güncelleyen betik.
* **`update.sh`:** Yukarı akış (upstream) sürümlerini kontrol eden ve depo sürüm takibini kolaylaştıran yardımcı betik.
* **`Makefile`:** CI/CD boru hatları ve yerel geliştirme doğrulama hedeflerini barındırır.

*(Not: AI ajanları bu kök dizin betiklerine veya `Makefile` dosyasına kullanıcı açıkça talep etmedikçe müdahale etmemelidir.)*

---

## 3. `ympbuild` Dosya Standartları ve Söz Dizimi

Her paket, ilgili kategori altında **kendi paket adıyla** açılmış bir dizinde yer alır (örneğin `x11/libX11/ympbuild`). Varsa yama dosyaları (`.patch`), servis betikleri (`.initd`) veya yapılandırma dosyaları aynı dizin içinde tutulur.

### 3.1. Zorunlu ve Standart Değişkenler

```bash
#!/usr/bin/env bash
name='paket-adi'
release='1'
version='1.0.0'
url='https://proje-resmi-adresi.org'
description='Paketin kısa, net ve açıklayıcı tanımı'
email='bakimci@turkmenlinux.org'
maintainer='Bakımcı Adı Soyadı'
license=('MIT')
source=("https://proje-resmi-adresi.org/releases/${name}-${version}.tar.xz")
depends=('bağımlılık1' 'bağımlılık2')
makedepends=('meson' 'ninja' 'pkg-config')
sha256sums=('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
group=(kategori.altkategori)
uses=()
arch=('x86_64')
```

### 3.2. Değişken Kuralları ve İnce Ayrıntılar
* **`name`:** Dizin adıyla birebir aynı olmalıdır. Küçük harf, rakam ve tire (`-`) kullanılır.
* **`version`:** Yukarı akış (upstream) sürüm numarasıdır. Tire (`-`) içeremez; upstream sürümünde tire varsa alt çizgi (`_`) veya nokta (`.`) ile normalize edilir.
* **`release`:** Tam sayı (integer) değerdir. **Asla sıfırlanmaz** (Detaylar için Bölüm 4.1).
* **`license`:** SPDX standartlarına uygun lisans tanımları kullanılır (`'MIT'`, `'GPLv2'`, `'GPLv3'`, `'LGPLv2.1'`, `'BSD-3-Clause'`, `'Apache-2.0'`). `xorg.freedesktop.org` ve benzeri X.Org / freedesktop bileşenleri için `'MIT'` kullanılır.
* **`source`:** Kaynak arşivin resmi ve doğrulanmış tam URL'si. Mümkün olduğunca `${name}` ve `${version}` değişkenleri kullanılarak okunabilirlik korunur. Yerel yama dosyaları varsa `source` dizisine dosya adıyla eklenir:
  ```bash
  source=("https://example.org/${name}-${version}.tar.gz"
          "fix-build-gcc14.patch")
  ```
* **`sha256sums` (Güvenlik Standardı):** Tüm yeni ve güncellenen paketlerde doğrulama özeti olarak **`sha256sums`** kullanılır. Eski tariflerde kalan `md5sums` alanları güncelleme sırasında `sha256sums` ile değiştirilmelidir. Yama dosyaları dahil `source` dizisindeki her öğe için sırasıyla bir özet bulunmalıdır (`'SKIP'` yalnızca dinamik git kaynakları için istisnai olarak kullanılabilir).
* **`depends` vs `makedepends`:**
  * `depends`: Paketin çalışma zamanında (runtime) ihtiyaç duyduğu paylaşımlı kütüphaneler ve araçlar.
  * `makedepends`: Yalnızca derleme sırasında ihtiyaç duyulan araçlar (`meson`, `cmake`, `ninja`, `pkg-config`, `python3-setuptools`, protokol başlıkları vb.).
* **`uses`:** Paketin opsiyonel özellik bayraklarını (USE flags) tanımlar (örn: `uses=('wayland' 'x11' 'alsa')`). Koşullu bağımlılıklar `wayland_depends=()` veya `use_opt` kontrolleri ile yönetilir.

### 3.3. Yaşam Döngüsü Fonksiyonları (`setup`, `build`, `package`)

1. **`setup()` (Hazırlık ve Yamalama):**
   * `ymp` kaynak arşivi otomatik olarak açar ve çalışma dizinini kaynak klasörünün içine ayarlar (`cd` yapmanıza gerek yoktur, ancak kaynak klasör adı standart dışıysa `cd "${name}-${version}"` belirtilebilir).
   * Yamalar burada uygulanır: `patch -Np1 -i "${WORKDIR}/fix-build.patch"`
   * Autotools projelerinde `configure` betiği yoksa `autoreconf -fiv` burada çalıştırılır.

2. **`build()` (Yapılandırma ve Derleme):**
   * Kaynak kodun yapılandırıldığı ve derlendiği aşamadır.
   * **Meson Örneği:**
     ```bash
     build() {
         meson setup build --prefix=/usr --libdir=lib64 -Dsystemd=disabled
         ninja -C build -j$(nproc)
     }
     ```
   * **Autotools Örneği:**
     ```bash
     build() {
         ./configure --prefix=/usr --libdir=/usr/lib64 --disable-static --without-systemd
         make -j$(nproc)
     }
     ```
   * **CMake Örneği:**
     ```bash
     build() {
         cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib64 -DWITH_SYSTEMD=OFF
         cmake --build build -j$(nproc)
     }
     ```

3. **`package()` (Kurulum ve Paketleme):**
   * Derlenen dosyaların sanal kök dizin olan **`$DESTDIR`** altına kurulduğu aşamadır. **Asla doğrudan `/` sistem dizinine dosya kopyalamayın.**
   * **Meson:** `DESTDIR="$DESTDIR" ninja -C build install`
   * **Autotools:** `make DESTDIR="$DESTDIR" install`
   * **CMake:** `DESTDIR="$DESTDIR" cmake --install build`
   * Lisans dosyası ve belgelerin kurulumu ile gereksiz dosyaların (`.la` libtool arşivleri, boş dizinler) temizliği bu aşamada yapılır.

---

## 4. Sürüm Yönetimi, `release` Kuralı ve Derleme Süreci

### 4.1. `release` Numarası Kuralı (ASLA SIFIRLANMAZ)
* Türkmen GNU/Linux'ta **`release` numarası hiçbir zaman `'1'`'e sıfırlanmaz.**
* Paket sürümü yükseltilse bile (örneğin `version='1.2.0'` -> `version='1.3.0'`), mevcut `release` değeri **kesinlikle 1 artırılır** (örneğin `release='4'` -> `release='5'`).
* Aynı sürüm üzerinde bağımlılık değişikliği, yama ekleme veya yeniden derleme (rebuild) yapıldığında da `release` değeri **1 artırılır**.
* **Neden?** `ymp` paket yükseltme ve veritabanı sürüm karşılaştırma algoritması `release` artışını temel alır; sıfırlama yapılması paket yükseltme zincirini bozar.

### 4.2. Paket Derleme Komutu (`ymp build`)

Paket derleme işlemi **depo kök dizininden**, hedef paketin `ympbuild` dosyasını içeren dizin yolu verilerek yürütülür:

```bash
ymp build --install --no-emerge --output=output <kategori/paket-adi>
```

**Örnek Kullanım:**
```bash
ymp build --install --no-emerge --output=output dev/cargo-c
```

**Parametrelerin Açıklamaları:**
* **`--install`:** Derleme başarıyla tamamlandıktan sonra üretilen `.ymp` paketini otomatik olarak yerel sisteme kurar (zincirleme bağımlılık derlemeleri için kritik öneme sahiptir).
* **`--no-emerge`:** Eksik bağımlılıkları kaynak koddan tekrar derlemeye çalışmak yerine doğrudan ikili paket deposundan kullanır.
* **`--output=output`:** Oluşturulan `.ymp` ikili paket dosyalarının depo kökündeki `output/` dizinine kaydedilmesini sağlar.

---

## 5. Sık Karşılaşılan Sorunlar ve Hata Ayıklama Rehberi

Paket güncelleme ve derleme sırasında sık rastlanan sorunlar ve standart çözümleri:

| Sorun / Hata Belirtisi | Kök Neden | Çözüm Yöntemi |
| :--- | :--- | :--- |
| `Package 'systemd' was not found` | Derleme sistemi varsayılan olarak systemd arıyor. | `build()` içine `-Dsystemd=disabled` veya `--without-systemd` ekleyin. |
| Kütüphaneler `/usr/lib` içine kurulmuş | `--libdir` parametresi eksik veya proje yoksayıyor. | `--libdir=/usr/lib64` ekleyin veya `package()` sonunda `mv "$DESTDIR/usr/lib/"* "$DESTDIR/usr/lib64/"` uygulayın. |
| `404 Not Found` (Kaynak URL hatası) | Upstream sürüm sıkıştırma formatını (`.tar.gz` -> `.tar.xz`) veya dizin yapısını değiştirmiş. | Resmi proje indirme sayfasını kontrol edip `source` uzantısını ve `sha256sums` değerini güncelleyin. |
| `sha256sums` uyuşmazlığı | Upstream arşivi yeniden paketlemiş veya yanlış sürüm indirilmiş. | İndirilen dosyanın gerçek bir kaynak arşiv olduğunu (HTML hata sayfası olmadığını) doğrulayın, ardından özeti güncelleyin. |
| Eksik başlık dosyası (`fatal error: X11/...: No such file`) | `makedepends` içinde ilgili X11/protokol paketi eksik. | Eksik paketi tespit edin (`xorgproto`, `libX11`, `libXvMC` vb.), önce o paketin kurulu olduğundan emin olun ve `makedepends` listesine ekleyin. |
| GCC 14+ derleme hataları (`incompatible-pointer-types`, `implicit-function-declaration`) | Eski C kodu modern GCC katı tip denetimine takılıyor. | Upstream'den ilgili düzeltme yamasını alıp paket dizinine `.patch` olarak ekleyin ve `setup()` içinde uygulayın. |

---

## 6. Sürüm Güncelleme Kontrol Listesi (Checklist)

Bir paketi güncellerken şu sırayı takip edin:
1. [ ] Mevcut `ympbuild` dosyasını ve dizindeki varsa `.patch` dosyalarını incele.
2. [ ] Upstream resmi kaynağından en güncel kararlı sürümü ve indirme URL'sini doğrula.
3. [ ] `version` değerini güncelle ve `release` değerini **mevcut değer + 1** olarak artır.
4. [ ] Kaynak arşivi `/tmp` dizinine indirip `sha256sum` değerini hesapla; `ympbuild` içindeki `sha256sums` (varsa eski `md5sums` yerine) alanını güncelle.
5. [ ] `depends` ve `makedepends` listelerini gözden geçir (`-dev` eki olmadığından ve `systemd` referansı bulunmadığından emin ol).
6. [ ] `ymp build --install --no-emerge --output=output <kategori/paket>` komutuyla derle.
7. [ ] `output/` dizininde `.ymp` paketinin oluştuğunu ve dosya içeriğinde `/usr/lib64` yapısının korunduğunu doğrula.
8. [ ] `/tmp` altındaki geçici dosyaları ve gereksiz çalışma kalıntılarını temizle; `git diff` ile yalnızca hedef dosyaların değiştiğini kontrol et.

---

## 7. 🤖 AI Ajan Çalışma Protokolü ve Prensipler

Bu depoda görev alan tüm yapay zeka modelleri, kod asistanları ve otomasyon ajanları aşağıdaki **18 prensibe** istisnasız uymak zorundadır:

### 🔐 GÜVENLİK VE İŞ AKIŞI PRENSİPLERİ

1. **Tekil İş Akışı Yönetimi:** Her işlem tekil ve kontrollü yürütülür. Kullanıcı açıkça toplu işlem istemedikçe birden fazla paket aynı anda işlenmez; her adım kullanıcı onayıyla ilerler.
2. **Aşamalı Süreç Kontrolü:** Her ana aşama (1: İnceleme ve Planlama, 2: `ympbuild` Düzenleme, 3: Derleme ve Doğrulama) tamamlandıktan sonra süreç duraklatılır, özet sunulur ve kullanıcı onayı beklenir.
3. **Sürüm ve `release` Bütünlüğü:** `release` numaraları paket kimliğinin ve yükseltme zincirinin ayrılmaz parçasıdır; her değişiklikte mevcut değere **+1** eklenir, sıfırlama (`'1'`) asla yapılmaz.
4. **Kod ve Stil Bütünlüğü:** Mevcut `ympbuild` dosyasının girinti, tırnak kullanımı ve fonksiyon yapısı korunur. Düzenleme öncesi mevcut tarif, yama dosyaları ve derleme geçmişi mutlaka incelenir.
5. **Dağıtım İzolasyonu:** Türkmen GNU/Linux paket sistemi (`ymp`, OpenRC, `eudev`, `/usr/lib64`) başka dağıtımlara özgü araçlar, dosya yolları ve varsayımlarla karıştırılmaz.

### 📦 DERLEME, KAYNAK VE GÜVENLİK PRENSİPLERİ

6. **Standart Derleme Komutu:** Tüm paketler depo kökünden `ymp build --install --no-emerge --output=output <dizin-konumu>` komutuyla derlenir. Sistem paketleri için `-dev`/`-devel` bağımlılıkları veya `systemd` referansları kesinlikle kullanılmaz.
7. **Geçici Dizin ve Kaynak Temizliği:** Paket kaynak arşifleri doğrulama için yalnızca geçici dizinlerde (`/tmp`) indirilir ve özet hesaplandıktan hemen sonra silinir; kaynak arşivleri asla git deposu dizinlerinde saklanmaz.
8. **Değişiklik Odaklı Müdahale:** Yalnızca görev kapsamında hedeflenen paket dizinindeki dosyalar düzenlenir. Kök dizindeki `Makefile`, `build.sh`, `update.sh` veya ilgisiz paket dosyalarına müdahale edilmez.
9. **Lisans Uyumluluğu:** `xorg.freedesktop.org` ve benzeri açık kaynak organizasyonlarından gelen paketler `MIT` lisansı ile paketlenir; diğer projelerde upstream lisans dosyası (`COPYING` / `LICENSE`) doğrulanarak SPDX formatında yazılır.
10. **Kriptografik Doğrulama Standartları:** Tüm yeni ve güncellenen paketler **`sha256sums`** ile doğrulanır; zayıf özet algoritması olan `md5sums` güvenlik nedeniyle kullanılmaz ve güncelleme sırasında `sha256sums` ile değiştirilir.
11. **Resmi Kaynak Doğruluğu:** Tüm `source` URL'leri resmi organizasyonlardan (`xorg.freedesktop.org`, `gitlab.freedesktop.org`, `github.com/<org>/<repo>/releases` vb.) alınır. URL'nin HTTP 200 döndürdüğü ve geçerli bir arşiv olduğu her zaman teyit edilir.
12. **FHS ve `/usr/lib64` Denetimi:** Derlenen paketin kütüphaneleri `/usr/lib` yerine `/usr/lib64` altına kurduğu ve `systemd` birim dosyası barındırmadığı kontrol edilir.

### 📊 İLETİŞİM, BAĞIMLILIK VE TEMİZLİK PRENSİPLERİ

13. **Yüksek Bilgi Yoğunluğu:** Her paket işlemi için yapılan değişiklikler, tespit edilen sorunlar ve gereksinimler **en fazla 3 madde** halinde net biçimde özetlenir; gereksiz açıklamalardan kaçınılır.
14. **Proaktif Bağımlılık Bilinci:** Eksik derleme veya çalışma zamanı bağımlılıkları (örn: `xorgproto`, `libXvMC`, `meson`) derleme hatası beklenmeden proaktif olarak tespit edilir ve kullanıcıya bildirilir.
15. **Çıktı ve Paket Teyidi:** Her derlemeden sonra `output/` dizininde hedef `.ymp` paket dosyasının başarıyla oluşturulduğu (`ls -lh output/`) doğrulanır.
16. **Hata Durumunda Güvenli Durdurma:** Derleme veya indirme sırasında beklenmeyen bir hata oluşursa ajan rastgele denemelerle sistemi kirletmez; hatanın kök nedenini analiz edip çözüm önerisiyle birlikte kullanıcıya raporlar.
17. **Git ve Workspace Bütünlüğü:** İşlem tamamlandıktan sonra `/tmp` altındaki geçici dosyalar temizlenir ve `git status` / `git diff` kontrolü yapılarak çalışma alanının temiz ve tutarlı kaldığı teyit edilir.
18. **Gizli Bilgi ve Ortam Güvenliği:** Kişisel e-posta, API anahtarı veya yerel sistem yolları tariflere sızdırılmaz; yalnızca resmi bakımcı bilgileri ve standart değişkenler (`$DESTDIR`, `$WORKDIR`) kullanılır.
