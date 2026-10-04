# Fizik motoru karşılaştırması — Senaryo 2 (Etki–Tepki)

Simülasyonda üç fizik motoru seçilebilir (`config/sim2_config.tres` → **Fizik Motoru**,
oyun çalışırken Godot editörünün *Remote* sekmesinden de değiştirilebilir):

| Motor | Uçuş (yerçekimi + hava) | Zemin teması | Notlar |
|---|---|---|---|
| **MuJoCo** | MuJoCo | MuJoCo (`mujoco/scene.xml`) | Derlenmiş GDExtension gerekir. Bu makinede (macOS) derlenmediği için ölçülemedi. |
| **Yedek Çözücü** | GDScript, yarı-örtük Euler, kare başına 40 alt adım | Yay–sönüm modeli (bizim) | MuJoCo seçili ama derlenmemişse buna düşülür. |
| **Godot Melez** | Godot'nun `RigidBody3D` fiziği | Yay–sönüm modeli (bizim), `_integrate_forces` içinde | **Varsayılan motor.** Hava direnci ve temas yasası Yedek Çözücü ile **aynı sabitlerle**. Toplar Godot çarpışması yapmaz. |

**Godot'nun kendi 3B fizik motoru** (Project Settings → Physics → 3D → Physics Engine):
`DEFAULT` = **Godot Physics** (Jolt seçili değil). Godot Melez yalnızca uçuşu (yerçekimi +
hız/konum entegrasyonu) Godot'ya bıraktığı için motorun çarpışma çözücüsü hiç kullanılmıyor.

| Ayar | Değer | Web export'ta (Godot Melez) |
|---|---|---|
| Physics Engine (3D) | DEFAULT → Godot Physics | Çalışıyor: (a) sol/sağ 1.519 / 1.519, 0.826 / 0.826 m, konum farkı 0.0 mm; (b) 1239 m/s, yazılan tepe ~196 m; (c) top duruyor |

Web testi: proje kopyasına geçici bir autoload eklenip `Web` ön ayarıyla dışa aktarıldı, sonra
headless Chrome'da çalıştırıldı (2026-10-04). Web'de kare hızı sabit olmadığından ağır çekimin
başladığı an biraz kayıyor; (a)'daki ilk sekme masaüstünde 1.55–1.60 m, web'de 1.52 m.
İki topun birebir aynı olması her durumda korunuyor. Dışa aktarmadaki tek uyarı MuJoCo eklentisi
için (web'de zaten yok, Godot Melez ya da Yedek Çözücü kullanılır).

Temas yasası her iki modelde de: `pen = (zemin + r) − y > 0` ise
`N = max(0, k·pen − c·vy)`, `k = 1·10⁵ N/m`, `c` sekme katsayısından (e = 0.76) türetilir.

## Ölçüm yöntemi

`tools/motor_karsilastirma.gd`, gerçek oyun döngüsünde (sabit 60 kare/s) sol topu 3 m'den
bırakır ve **ilk temasını** ölçer. Godot Melez'de adımları motor attığı için ölçüm
`_physics_process`'i elle çağırarak değil, gerçek fizik kareleriyle yapılır.

```
godot --headless --path . --fixed-fps 60 --script tools/motor_karsilastirma.gd
```

- Proje yerçekimi: **9.81 m/s²** (`project.godot` → `physics/3d/default_gravity`; Godot varsayılanı 9.8'di).
- Temas anında ağır çekim: 0.05. Godot Melez'de bu `Engine.time_scale` ile yapılır ve bu mod
  açıkken fizik 120 Hz'de çalışır (`godot_tik_sayisi`). Adım = (1/120) × 0.05 = 0.42 ms.
- **e (ölçülen)** = temastan hemen sonraki hız / temastan hemen önceki hız.

## Sonuçlar (varsayılan ayarlar, 120 Hz)

| Motor | İlk sekme (m) | Temas (ms) | Tepe N | Temas adımı | Adım (ms) | e (ölçülen) |
|---|---|---|---|---|---|---|
| MuJoCo | yok | yok | yok | yok | yok | yok |
| Yedek Çözücü | 1.559 | 7.88 | 1632 | 378 | 0.0208 | 0.769 |
| Godot Melez | 1.572 | 7.50 | 1665 | 18 | 0.4167 | 0.783 |
| *Fark (Melez − Yedek)* | *+0.8 %* | *−4.8 %* | *+2.0 %* | | | *+1.8 %* |

(b) seçeneği (zemin 100·F uygular; varsayılan (b) gösterimi IKISI, yani fırlatma ağır çekimde):

| Motor | Sağ topun en yüksek hızı (m/s) | Ekrana yazılan tepe noktası |
|---|---|---|
| MuJoCo | yok | yok |
| Yedek Çözücü | 1195 | ~200 m |
| Godot Melez | 1202 | ~200 m |

(a) seçeneğinde sağdaki top, soldakinin zeminden aldığı temas kuvvetinin **aynısını, aynı
adımda** alıyor (`PhysicsBackend.set_contact_mirror`). Böylece iki top birebir aynı hareket
ediyor. Godot Melez'de sekme tepeleri sol/sağ 1.572 / 1.572, 0.838 / 0.838, 0.463 / 0.463 m;
iki topun konum farkı en kötü anda 0.0 mm. Yedek Çözücü'de de iki top birebir aynı.

Kabul ölçütü (≥ 15 temas adımı; Yedek Çözücü ile birkaç % içinde) sağlanıyor.

## Farkın kaynağı: adım büyüklüğü

Godot Melez'in tik sayısı artırıldıkça sonuçlar Yedek Çözücü'ye yakınsıyor; yani fark
fizikten değil, zamanın ayrıklaştırılmasından geliyor. Temas süresindeki fark tam olarak
bir adım kadar (0.42 ms).

| Godot Melez tik | Temas adımı | İlk sekme (m) | Temas (ms) | Tepe N |
|---|---|---|---|---|
| 120 (varsayılan) | 18 | 1.572 | 7.50 | 1665 |
| 240 | 37 | 1.564 | 7.71 | 1646 |
| 480 | 75 | 1.561 | 7.81 | 1638 |
| *Yedek Çözücü* | *378* | *1.559* | *7.88* | *1632* |

## Geliştirme sırasında bulunan hatalar (Godot Melez'e özgü, düzeltildi)

1. **(b) impulsunun yarısı kayboluyordu** (top 585 m/s'de kalıyordu). Godot'da motor adımı
   `main.gd`'nin `_physics_process`'inden *sonra* geliyor; impuls bitince dış kuvvet aynı
   tikte sıfırlandığı için son parça hiç uygulanmıyordu. Artık bu modda kuvvet bir sonraki
   tikte kaldırılıyor.
2. **Temasın dip noktasında ağır çekim bir anlığına kapanıyordu** (top dönerken hızı ~0
   olduğu için "temas + hızlı" koşulu düşüyordu). Bu, temasın ortasında tek bir 8 ms'lik
   adıma yol açıyordu. Bu modda temas kuvveti ağırlığın 3 katından büyükken de ağır
   çekimde kalınıyor. Diğer motorlarda davranış değişmedi.
3. **(a)'da sağ top fırlıyordu ve Fnet hep 0 görünüyordu.** Ölçerek doğrulandı: Godot'da
   `_integrate_forces` motor adımı *bittikten sonra* çağrılıyor ve orada verilen kuvvet
   *bir sonraki* adımda, o adımın süresiyle entegre ediliyor; ağır çekim de kare sınırında
   değişiyor. Ağır çekim kapandığı an 0.42 ms için hesaplanan kuvvet 8.3 ms boyunca
   uygulanıyordu. Artık dış kuvvet, biten adım için **impuls** (F × gerçek adım süresi)
   olarak veriliyor; Fnet de iki ardışık geri çağrı arasındaki hız farkından ölçülüyor.
   (1. hata da aslında bu kaymanın bir yüzüydü.)
4. **(a)'da soldaki top hep biraz önce yere değiyordu.** Sağdaki top tutulup tahmini bir
   impulsla fırlatılıyordu (yerçekimi ve temasın şekli hesaba katılmadan). Artık sağdaki
   top soldakinin temas kuvvetini motorun içinde, aynı adımda alıyor; fark 0.0 ms.
   Bu sırada ortaya çıkan bir yan etki de düzeltildi: temasın dip noktasında hız ~0 olduğu
   için ağır çekim bir kare kapanıyordu (2. hatadaki "bastırma" koşulu artık tüm motorlarda).

## Ekran görüntüleri

`godot --path . --script tools/shots.gd -- --motor=godot` (ya da `yedek`) →
`tools/shots_godot/` ve `tools/shots_yedek/`.

## (b) gösterimi ile (Adım E) — kamera takibinde gerçekten uçulan tepe

Kamera takibi modlarında sağdaki top 9 m'de durdurulmaz, tepe noktasına kadar gerçekten uçar.
`tools/b_gosterim_olc.gd` ile (60 kare/s, varsayılan ayarlar):

| Motor | Mod | Yazılan tepe (formül) | Gerçekten uçulan tepe |
|---|---|---|---|
| Yedek Çözücü | KAMERA_TAKIP / IKISI | 200 m | 199 m |
| Godot Melez (120 Hz) | KAMERA_TAKIP | 196 m | 184 m |
| Godot Melez (120 Hz) | IKISI | 200 m | 186 m |
| Godot Melez (240 Hz) | IKISI | 200 m | 193 m |

Yedek Çözücü'de formül ile gerçek uçuş %1 içinde. Godot Melez'de takip sırasında zaman normal
hızda aktığı için ~1200 m/s'deki top 8.3 ms'lik adımlarla ilerliyor ve hava direnci bu büyük
adımlarda fazla hesaplanıyor; gerçek tepe biraz düşük çıkıyor. Tik sayısını artırmak farkı
küçültür. (b) zaten bilerek yanlış bir fizik olduğu için ekrana yazılan değer formülden gelir.
IKISI modunda fırlatma ağır çekimi (0.01) yazılan değeri de doğrular: iki motorda 200 m.
