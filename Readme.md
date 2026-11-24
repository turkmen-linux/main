# Türkmen GNU/Linux Ana Paket Deposu (`main`) — Bakımcı ve AI Ajan Kılavuzu

Bu depo, Türkmen GNU/Linux dağıtımının resmi çekirdek ve masaüstü paket tariflerini (`ympbuild`) barındırır. 

> **🤖 YAPAY ZEKA AJANLARI VE BOTLAR İÇİN ZORUNLU TALİMAT:**
> Bu depoda herhangi bir değişiklik, sürüm güncellemesi veya yeniden derleme (rebuild) işlemi yapmadan önce **bu belgenin tamamını okuyun ve "AI Ajan Çalışma Protokolü" bölümündeki kurallara istisnasız uyun.**

---

## 1. Dağıtım Mimarisi ve Temel Kurallar

Paket tariflerini yazarken veya güncellerken Türkmen GNU/Linux'un mimari kararlarına kesinlikle uyulmalıdır:

* **Bağımsız Taban:** Türkmen Linux herhangi bir dağıtımın (Arch, Debian, Alpine vb.) türevi değildir; kendi paket yöneticisi olan **`ymp` (Yerli ve Milli Paket)** sistemini kullanır.
* **`systemd` Yoktur:** Sistem init olarak **OpenRC** kullanır. Paketlere asla `systemd`, `libsystemd` veya `udev` (systemd tabanlı) bağımlılığı eklemeyin. Derleme seçeneklerinde her zaman `-Dsystemd=disabled`, `--without-systemd` veya `-DWITH_SYSTEMD=OFF` gibi bayraklar kullanın.
* **`-dev` / `-devel` Ayrımı Yoktur:** Başlık dosyaları (`.h`), `pkg-config` (`.pc`) ve geliştirme kütüphaneleri doğrudan ana paketin içinde paketlenir. `depends` veya `makedepends` listelerine asla `-dev` veya `-devel` ekli paket isimleri yazmayın.
* **Kütüphane Yolları:** Sistem 64-bit mimaride kütüphaneleri standart `/usr/lib64` dizinine kurar (`/usr/lib` kullanılmaz; derleme sistemlerinde `--libdir=/usr/lib64` veya `-DCMAKE_INSTALL_LIBDIR=lib64` belirtilmelidir).

---

## 2. Depo Yapısı ve Araçlar

Paketler işlevlerine göre kategorize edilmiş dizinler altında tutulur (`app/`, `cinnamon/`, `dev/`, `gnome/`, `gui/`, `hyprland/`, `kde/`, `lxde/`, `media/`, `net/`, `pantheon/`, `sys/`, `www/`, `x11/`, `xfce/`).

### Kök Dizin Betikleri
* `build.sh`: Toplu veya otomatik paket derleme süreçlerini yöneten ana betik.
* `update-sums.sh`: Paket kaynak dosyalarının (`source`) doğrulama özetlerini (`md5sums` / `sha256sums`) otomatik güncelleyen betik.
* `update.sh`: Depo ve paket sürüm kontrolleri için kullanılan yardımcı betik.
* `Makefile`: CI/CD ve yerel geliştirme otomasyon hedeflerini içerir.

---

## 3. `ympbuild` Dosya Standartları

Her paket kendi adıyla açılmış bir klasör içinde yer alır ve en azından bir `ympbuild` dosyası içerir.

### Zorunlu ve Standart Değişkenler
```bash
#!/usr/bin/env bash
name='paket-adi'
release='1'
version='1.0.0'
url='https://proje-adresi.org'
description='Paketin kısa açıklaması'
email='bakimci@turkmenlinux.org'
maintainer='Bakımcı Adı'
license=('GPLv3')
source=("https://proje-adresi.org")
depends=('bağımlılık1' 'bağımlılık2')
makedepends=('derleme-bağımlılığı1')
md5sums=('d41d8cd98f00b204e9800998ecf8427e')
group=(kategori.altkategori)
uses=()
arch=('x86_64')
```

### Standart Fonksiyonlar
* `setup()`: Kaynak arşiv açıldıktan sonra, derleme öncesi uygulanacak yamalar (`patch -Np1 -i ...`) ve hazırlık komutları burada yer alır.
* `build()`: Yapılandırma (`./configure`, `meson setup`, `cmake -B build`, `python3 -m build` vb.) ve derleme (`make -j$(nproc)`, `ninja -C build`) komutları burada çalışır.
* `package()`: Derlenen dosyaların `$DESTDIR` değişkeni altına kurulduğu aşamadır (`make DESTDIR="$DESTDIR" install`, `DESTDIR="$DESTDIR" ninja -C build install` vb.).

---

## 4. Sürüm, `release` ve Derleme Süreci

### `release` Numarası Kuralı (ASLA SIFIRLANMAZ)
* Türkmen Linux'ta **`release` numarası hiçbir zaman `'1'`'e sıfırlanmaz.**
* İster **sürüm güncellemesi (version bump)** yapın, ister aynı sürüm üzerinde **yeniden derleme (rebuild)** yapın; mevcut `release` değerini her zaman **1 artırın** (örneğin `release='4'` ise yeni sürümde veya rebuild işleminde `release='5'` yapın).
* Sürüm değiştiyse `source` bağlantısının çalıştığını doğrulayın ve `md5sums` değerini güncelleyin (veya `./update-sums.sh` betiğini kullanın).

### Derleme Nasıl Yapılır? (`ymp build`)
*(Not: Asla `makepkg`, `apkbuild`, `rpmbuild` veya `dpkg-buildpackage` gibi başka dağıtımlara ait komutlar kullanmayın.)*

Paket derleme işlemi depo kök dizininden, hedef paketin `ympbuild` dosyasını içeren dizin konumu verilerek yapılır:

```bash
ymp build --install --no-emerge --output=output <ympbuild-içeren-dizin-konumu>
```

**Örnek Kullanım:**
```bash
ymp build --install --no-emerge --output=output dev/cargo-c
```
*(Birden fazla paket tek komutta derlenecekse dizin konumları boşluk bırakılarak yan yana eklenir: `ymp build --install --no-emerge --output=output kategori/paket1 kategori/paket2`)*

* **`--install`:** Derleme tamamlandıktan sonra üretilen `.ymp` paketini otomatik olarak sisteme kurar.
* **`--no-emerge`:** Bağımlılıkları kaynak koddan tekrar derlemek yerine doğrudan ikili paket olarak işler.
* **`--output=output`:** Derlenen `.ymp` paket çıktılarının kaydedileceği dizini belirler.

---

## 5. 🤖 AI Ajan Çalışma Protokolü ve Prensipler

Bu depoda görev alan tüm yapay zeka modelleri ve otomasyon araçları aşağıdaki **15 prensibe** göre çalışmalıdır:

### 🔐 GÜVENLİK VE İŞ AKIŞI PRENSİPLERİ

1. **İş Akışı Yönetimi:** Her işlem tekil ve kontrol edilmiştir. Birden fazla paket aynı anda işlenmemeli, her adım kullanıcı onayıyla ilerlenmelidir.
2. **Süreç Kontrolü:** Her aşama (inceleme, düzenleme, derleme) tamamlandıktan sonra süreç duraklatılmalı ve kullanıcı onayı beklenmelidir.
3. **Sürüm Bütünlüğü:** `release` numaraları paket kimliğinin ve yükseltme zincirinin bir parçasıdır; her değişiklikte mevcut değere +1 eklenir, sıfır asla kullanılmaz.
4. **Kod Bütünlüğü:** Mevcut kod stilini ve yapısını koruyarak değişiklikler yapılmalıdır. Mevcut `ympbuild` dosyaları, patch dosyaları ve build betikleri öncelikle incelenmelidir.
5. **Paket Yönetimi:** Türkmen Linux paket sistemi (`ymp`, OpenRC, `/usr/lib64`) dağıtımlara özgü araçlar ve varsayımlarla çalışmamalıdır.

### 📦 DERLEME VE KAYNAK PRENSİPLERİ

6. **Derleme Standartları:** Tüm paketler `ymp build --install --no-emerge --output=output <dizin-konumu>` komutuyla derlenir. Sistem paketleri için `-dev` bağımlılıkları veya `systemd` referansları kullanılmaz.
7. **Kaynak Temizliği:** Paket kaynak arşifleri geçici dizinlerde (`/tmp`) indirilir, derleme tamamlandıktan sonra otomatik olarak temizlenir; asla repo dizinlerinde saklanmaz.
8. **Değişiklik Odaklı İş:** Sadece git diff'de belirtilen ve değiştirilmiş dosyalar işlenir. Gerekli olmayan dosyalara (Makefile, betikler, config dosyaları) müdahale edilmez.
9. **Lisans Uyumluluğu:** xorg.freedesktop.org ve benzeri açık kaynak organizasyonlarından gelen paketler MIT lisansı ile paketlenir.
10. **Güvenlik Standartları:** Tüm paketler `sha256sums` ile doğrulanır; MD5 checksums güvenlik nedeniyle kullanılmaz.
11. **Kaynak Doğruluğu:** Tüm `source` URL'leri resmi organizasyonlardan (xorg.freedesktop.org, proje siteleri) ve doğrulanmış kaynaklardan alınır. URL ve sürüm doğruluğu her zaman teyit edilir.

### 📊 İLETİŞİM VE TEMİZLİK PRENSİPLERİ

12. **Bilgi Yoğunluğu:** Her paket işlemi için yapılan değişiklikler ve gereksinimler en fazla 3 madde halinde özetlenir; gereksiz detaylardan kaçınılır.
13. **Bağımlılık Bilinci:** Eksik bağımlılıklar (örn: xv, libXvMC) proaktif olarak tespit edilir ve kullanıcıya bildirilir.
14. **Süreç Teyidi:** Her derlemeden sonra çıktıların (`output/` dizinindeki `.ymp` dosyaları) başarıyla oluşturulduğunu doğrulama yapılır.
15. **Workspace Bütünlüğü:** İşlem tamamlandıktan sonra geçici dosyalar ve workspace temizliği yapılır; git workspace her zaman temiz bir durumda bırakılır.
