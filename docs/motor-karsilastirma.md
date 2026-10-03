# Fizik motoru karşılaştırması — Senaryo 2 (Etki–Tepki)

Simülasyonda üç fizik motoru seçilebilir (`config/sim2_config.tres` → **Fizik Motoru**,
oyun çalışırken Godot editörünün *Remote* sekmesinden de değiştirilebilir):

| Motor | Uçuş (yerçekimi + hava) | Zemin teması | Notlar |
|---|---|---|---|
| **MuJoCo** | MuJoCo | MuJoCo (`mujoco/scene.xml`) | Derlenmiş GDExtension gerekir. Bu makinede (macOS) derlenmediği için ölçülemedi. |
| **Yedek Çözücü** | GDScript, yarı-örtük Euler, kare başına 40 alt adım | Yay–sönüm modeli (bizim) | MuJoCo yoksa varsayılan olarak kullanılan motor. |
| **Godot Melez** | Godot'nun `RigidBody3D` fiziği | Yay–sönüm modeli (bizim), `_integrate_forces` içinde | Hava direnci ve temas yasası Yedek Çözücü ile **aynı sabitlerle**. Toplar Godot çarpışması yapmaz. |

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

## Geliştirme sırasında bulunan iki hata (Godot Melez'e özgü, düzeltildi)

1. **(b) impulsunun yarısı kayboluyordu** (top 585 m/s'de kalıyordu). Godot'da motor adımı
   `main.gd`'nin `_physics_process`'inden *sonra* geliyor; impuls bitince dış kuvvet aynı
   tikte sıfırlandığı için son parça hiç uygulanmıyordu. Artık bu modda kuvvet bir sonraki
   tikte kaldırılıyor.
2. **Temasın dip noktasında ağır çekim bir anlığına kapanıyordu** (top dönerken hızı ~0
   olduğu için "temas + hızlı" koşulu düşüyordu). Bu, temasın ortasında tek bir 8 ms'lik
   adıma yol açıyordu. Bu modda temas kuvveti ağırlığın 3 katından büyükken de ağır
   çekimde kalınıyor. Diğer motorlarda davranış değişmedi.

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
