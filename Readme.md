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

## 5. 🤖 AI Ajan Çalışma Protokolü (Botlar İçin Zorunlu Kurallar)

Bu depoda görev alan tüm yapay zeka modelleri ve otomasyon araçları aşağıdaki 6 kurala harfiyen uymalıdır:

1. **Tek Paket Kuralı (Batch Yasaktır):** Birden fazla paket verildiğinde asla hepsini tek seferde düzenlemeye çalışmayın. **Her yanıtta veya işlem adımında SADECE 1 paket üzerinde çalışın.**
2. **Dur ve Onay Bekle:** Bir paketin incelemesini, düzenlemesini ve/veya derleme komutunu tamamladıktan sonra **durun**. Kullanıcı *"devam et"*, *"onay"* veya *"sıradaki"* demeden listedeki bir sonraki pakete kesinlikle geçmeyin.
3. **`release` Kuralını İhlal Etme:** Sürüm yükseltmelerinde bile `release` değerini asla `'1'` yapmayın; daima mevcut sayıya `+1` ekleyin.
4. **Önce Oku, Sonra Yaz:** Bir pakete müdahale etmeden önce mutlaka o paketin mevcut `ympbuild` dosyasını, klasöründeki `.patch` dosyalarını ve kök dizindeki `build.sh` / `update-sums.sh` betiklerini okuyarak mevcut kod stiline sadık kalın.
5. **Doğru Derleme Komutunu Kullan:** Derleme komutu çalıştırırken veya kullanıcıya önerirken daima `ymp build --install --no-emerge --output=output <dizin-konumu>` formatını kullanın. Uydurma komutlar, `-dev` uzantılı bağımlılıklar veya `systemd` referansları eklemeyin.
6. **Kısa Raporlama:** Her paket işlemi bittiğinde yaptığınız değişikliği ve çalıştırılacak `ymp build` komutunu en fazla **3 kısa madde** halinde özetleyip beklemeye geçin.
