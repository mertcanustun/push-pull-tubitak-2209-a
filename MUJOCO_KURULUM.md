# MuJoCo'yu Godot'ya eklenti olarak kurma

Bu adımları **senin makinende** yapman gerekiyor: derleme işi bende
çalışmıyor (MuJoCo ikili dosyaları ve Godot derleyici zinciri burada yok).
Kod tarafının tamamı hazır — `native/` altındaki C++ kaynağı, `SConstruct`
ve `mujoco/scene.xml` modeli yazıldı. Senin yapacağın: bağımlılıkları
indirip `scons` çalıştırmak.

Proje bu adımlar yapılmadan da çalışır (yedek fizik çözücüsüyle). Yani
sunuma yetişmeme riski yok; MuJoCo'yu sonradan da takabilirsin.

---

## 0. Önce bunu bil

**GDExtension web (HTML5) dışa aktarımda çalışmaz.** Yani MuJoCo'lu sürüm
masaüstü (Linux / Windows / macOS) içindir. Vercel'de duran sürüm yedek
çözücüyle çalışmaya devam eder. Hocaya bunu baştan söylemek iyi olur:
"MuJoCo masaüstü sürümde, web sürümünde aynı fizik GDScript'te yeniden
uygulandı ve iki çözücü aynı arayüzün arkasında" demek doğru ve savunulabilir
bir cümle.

---

## 1. Gerekenler

| | |
|---|---|
| Godot | 4.3 veya üstü (projeyi hangi sürümle açacaksan godot-cpp de o dalda olmalı) |
| Python + SCons | `pip install scons` |
| Derleyici | Linux: `gcc/g++` · Windows: Visual Studio 2022 Build Tools veya MinGW · macOS: Xcode command line tools |
| Git | godot-cpp'yi çekmek için |
| MuJoCo | github.com/google-deepmind/mujoco → Releases → işletim sistemine uygun **3.x** paketini indir (kaynaktan derlemene gerek yok) |

MuJoCo paketini açtığında şu yapıyı göreceksin — `SConstruct`'a vereceğin
yol bu klasörün kökü: 

```
mujoco-3.x.x/
  include/mujoco/mujoco.h
  lib/libmujoco.so.3        (Linux)
  lib/libmujoco.3.x.x.dylib (macOS)
  bin/mujoco.dll + lib/mujoco.lib (Windows)
```

---

## 2. godot-cpp'yi getir

```bash
cd native
git clone -b 4.3 https://github.com/godotengine/godot-cpp.git
```

Godot 4.4 kullanıyorsan `-b 4.4`, 4.5 kullanıyorsan `-b 4.5`. Dal ile
Godot sürümü uyuşmazsa eklenti yüklenmez ve konsolda "incompatible" hatası
görürsün.

---

## 3. Derle

```bash
cd native
scons target=template_debug   MUJOCO=/tam/yol/mujoco-3.x.x
scons target=template_release MUJOCO=/tam/yol/mujoco-3.x.x
```

Windows'ta "x64 Native Tools Command Prompt for VS 2022" içinden çalıştır,
yoksa derleyici bulunamaz.

Çıktı `addons/mujoco/bin/` altına düşer:
`libmujoco_godot.linux.template_debug.x86_64.so` gibi.

İlk derleme godot-cpp'yi de derlediği için 5–15 dakika sürer; sonrakiler
saniyeler.

---

## 4. MuJoCo kütüphanesini yanına kopyala

Eklenti, MuJoCo'nun kendi paylaşımlı kütüphanesine çalışma anında ihtiyaç
duyar ve onu kendi klasöründe arar:

```bash
# Linux
cp /yol/mujoco-3.x.x/lib/libmujoco.so.3  addons/mujoco/bin/
# Windows
copy \yol\mujoco-3.x.x\bin\mujoco.dll    addons\mujoco\bin\
# macOS
cp /yol/mujoco-3.x.x/lib/libmujoco.*.dylib addons/mujoco/bin/
```

---

## 5. Eklentiyi aç

`addons/mujoco/mujoco.gdextension.disabled` dosyasının adını
**`mujoco.gdextension`** yap (`.disabled` ekini sil).

> Bu dosya baştan kapalı çünkü ikili dosya yokken Godot her açılışta
> "kütüphane açılamadı" hatası verir. Derledikten sonra aç.

Kullanmadığın platformların satırlarını silmene gerek yok; dosya yoksa
Godot o platformda eklentiyi yüklemez ve proje yedek çözücüyle çalışır.

---

## 6. Doğrula

Godot'yu **tamamen kapat ve yeniden aç** (GDExtension'lar sadece açılışta
yüklenir), sonra F5.

Ekranın üstündeki durum satırında şu yazmalı:

```
Fizik motoru: MuJoCo (GDExtension yüklü)
```

Hâlâ "yedek" yazıyorsa Godot konsoluna bak — `mujoco_backend.gd` hatayı
oraya basıyor. En sık üç sebep:

| Hata | Sebep |
|---|---|
| `MuJoCoWorld sınıfı bulunamadı` | `.gdextension` adı hâlâ `.disabled`, ya da godot-cpp dalı Godot sürümüyle uyuşmuyor |
| `cannot open shared object file: libmujoco.so.3` | 4. adım atlanmış |
| `mj_loadXML: ...` | `mujoco/scene.xml` bozuk ya da MuJoCo sürümü XML'deki bir alanı tanımıyor (aşağıya bak) |

---

## 7. MuJoCo sürüm farkları (muhtemel tek sorun)

`mujoco/scene.xml` içinde MuJoCo 3.x'e özgü iki alan var:

- `fluidshape="ellipsoid"` ve `fluidcoef="..."` — hava sürtünmesini motorun
  kendisinin üretmesi için. MuJoCo bunu tanımazsa satırdan sil; sürtünme
  yalnızca `option density` üzerinden (kutu modeliyle) gelir, biraz daha
  kaba olur ama çalışır.
- `cone="elliptic"` — tanınmazsa sil, varsayılan `pyramidal` yeterli.

Bir de C++ tarafında tek bir işaret konvansiyonu var:
`mujoco_world.cpp` → `get_body_contact_force()` içinde `mj_contactForce`'un
döndürdüğü kuvvetin **ikinci cisme** (geom2) etki ettiğini varsaydım.
Doğrulaması kolay: top yerde dururken yeşil `N` oku **yukarı** bakmalı.
Aşağı bakıyorsa o fonksiyondaki `sign` değişkeninin işaretini ters çevir.

---

## 8. MuJoCo devredeyken neyin değiştiğini kontrol et

Plandaki maddeler MuJoCo altında şöyle karşılanıyor:

| Plan maddesi | MuJoCo tarafı |
|---|---|
| Fizik motoru eklenti olarak kurulsun | `addons/mujoco/` + `native/` |
| Serbest bırakma simülasyonu | `scene.xml`, `freejoint` + `plane` |
| Kuvvet okları cisme kuvvet uygulasın (rigidbody modifier) | `d->xfrc_applied` — motorun kendi çözümüne girer, okun kendi özelliği değil |
| Uygulanan kuvvet yerçekimi ve sürtünmeden etkilensin | `xfrc_applied` yerçekimi ve akışkan kuvvetleriyle **birlikte** entegre edilir; ayrıca bir şey yapman gerekmez |
| Net kuvveti oklarla göster | `Fnet = m·Δv/Δt` ölçümü, sarı ok |
| Net kuvvetten yerçekimini vektörel çıkar | turuncu `Fnet − G` oku (onay kutusundan aç) |
| Bir yarıda MuJoCo etki etsin, diğerinde etmesin | `set_body_contacts_enabled()` → `geom_contype/conaffinity = 0`. Yerçekimi ve sürtünme etkilenmez, sadece temas kapanır |

Son satır planın can alıcı noktasıydı: "rigidbody'ler MuJoCo'dan
etkilenmesin, yerçekimini ve sürtünmeyi bağımsız ekleyin" yerine daha temiz
bir yol var — cismi motorun içinde bırakıp sadece **çarpışma maskesini**
kapatmak. Böylece yerçekimi ve hava sürtünmesi hâlâ motorun kendi
çözümünden gelir, iki yarı arasındaki tek fark gerçekten temas olur ve
karşılaştırma adil kalır.
