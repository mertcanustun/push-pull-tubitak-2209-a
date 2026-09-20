# Etki–Tepki Simülasyonu (Godot 4, 3D)

Basketbol topu yere çarptığında zemin topa hangi kuvveti uygular? Newton'un
3. yasasına dair klasik kavram yanılgısını hedefleyen simülasyon.

## Hemen çalıştırma

1. Godot 4.3 veya üstünü aç.
2. **Import** → bu klasördeki `project.godot` dosyasını seç.
3. F5 (Run).

MuJoCo derlenmemiş olsa bile proje çalışır: yedek fizik çözücü (GDScript)
devreye girer ve ekranın üstünde hangi motorun kullanıldığı yazar.
MuJoCo'yu gerçekten devreye almak için → `MUJOCO_KURULUM.md`.

**Kontroller**

| | |
|---|---|
| `SPACE` / Başlat | başlat – duraklat |
| `R` / Sıfırla | baştan |
| Hız kaydırıcısı | 0.05× – 1.5× |
| Onay kutuları | hangi kuvvet oklarının görüneceği |
| Ok aracı | topa tıklayıp sürükle, bıraktığında o kuvvet cisme uygulanır |

Temas anı ~8 ms sürdüğü için top zemine yaklaşırken **zaman otomatik
yavaşlar** (0.05×). Yoksa temas kuvveti okunu tek karede görürdün.

## Sahne nasıl kurgulandı

| Sol yarı | Sağ yarı |
|---|---|
| Fizik motoru her şeyi çözer: yerçekimi, hava sürtünmesi, **çarpışma dahil** | Yerçekimi ve hava sürtünmesi çalışır, **çarpışma çözülmez** |
| Gerçek davranış – referans | Zemin tepkisine öğrenci karar verir |

İki top aynı anda, aynı yükseklikten (3 m) bırakılır. Temas anına kadar iki
taraf birebir aynıdır (test çıktısı: her iki top da t=0.75 s'de y = 0.4016 m).
Sağdaki top zemine tam değdiğinde simülasyon durur ve üç seçenek çıkar:

- **a)** yukarı yönlü `F` → soldaki gerçek zıplamayla aynı yüksekliğe çıkar
- **b)** yukarı yönlü `100·F` → top ekrandan çıkar, tepe noktası yazdırılır
- **c)** yukarı `F` + aşağı `F` → net sıfır, top olduğu yerde kalır

(c) en sık görülen yanılgıdır: "etki ve tepki birbirini götürür". Geri
bildirim paneli her seçenekten sonra nedenini açıklar — etki/tepki çifti
**farklı cisimlere** etki eder (zemin→top ve top→zemin), aynı cisme değil.

### Kuvvetin verilme biçimi

Seçilen kuvvet süreyle değil **impulsla** verilir:

```
J = F · T = m · v · (1 + e)        T = 0.008 s (gerçek basketbol teması)
```

Kısmi son adımda kuvvet ölçeklenir, böylece toplam impuls tam olarak J olur.
(a) seçeneğinde sağdaki top, soldaki topun **ölçülen** çıkış hızını
yakalayacak impulsu alır — yani "eşdeğer görsel" gerçekten eşdeğerdir, teorik
bir yaklaşım değil.

## Oklar

| Ok | Anlamı |
|---|---|
| kırmızı `G` | `m·g` |
| mavi `Fs` | hava sürtünmesi |
| yeşil `N` | zemin tepki kuvveti |
| mor `F` | senin uyguladığın kuvvet (ok aracı / seçim) |
| sarı `Fnet` | ölçülen net kuvvet, `m·a` |
| turuncu `Fnet − G` | net kuvvetten yerçekimi vektörel olarak çıkarılmış |

Ok uzunlukları **logaritmiktir**: bu sahnede yerçekimi ~6 N, temas kuvveti
~1000 N, (b) seçeneği ~100.000 N. Doğrusal ölçekte küçük oklar görünmezdi.
Gerçek sayı her zaman okun ucunda yazar.

`Fnet` bir toplam değil, bir **ölçümdür**: `m · Δv / Δt`. İki fizik arka
ucunda da aynı tanım kullanılır, böylece okun anlamı motordan bağımsızdır.

## Dosya düzeni

```
scripts/
  physics_backend.gd   soyut arayüz - sahne hiçbir motora bağlı değil
  native_backend.gd    yedek çözücü (yarı-örtük Euler + yay-sönüm teması)
  mujoco_backend.gd    MuJoCo GDExtension sarmalayıcısı
  force_arrow.gd       kuvvet oku (gövde + uç + etiket, tamamen kod)
  sim_ball.gd          küre + toz parçacıkları + çarpma sesi
  hud.gd               tüm arayüz
  main.gd              sahne kurulumu ve senaryo akışı
mujoco/scene.xml       MJCF modeli (iki top, sağdakinde contype=0)
native/                MuJoCo GDExtension C++ kaynağı + SConstruct
addons/mujoco/         derlenmiş eklenti buraya gelir
assets/                basketbol dokusu, toz dokusu, çarpma sesi
```

Fizik arka uçları `PhysicsBackend` arayüzünün arkasındadır. `main.gd` içinde
tek bir `if` MuJoCo'ya mı yedeğe mi düşüleceğine karar verir; sahnenin geri
kalanı hangisinin çalıştığını bilmez.

## Ayar noktaları (`main.gd` başı)

| Sabit | Anlamı |
|---|---|
| `BALL_MASS` / `BALL_RADIUS` | 0.624 kg / 0.119 m (NBA topu) |
| `RESTITUTION` | 0.76 – MuJoCo yoksa kullanılan teorik geri tepme |
| `DRAG_CD` | 0.47 (küre) |
| `DROP_HEIGHT` | bırakma yüksekliği |
| `T_CONTACT` | temas süresi, impuls bu süreye bölünür |
| `ARROW_K` | ok uzunluğu ölçeği |
| `ESCAPE_Y` | (b) seçeneğinde "ekrandan çıktı" eşiği |
