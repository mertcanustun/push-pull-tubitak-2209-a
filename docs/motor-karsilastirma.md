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

(b) seçeneği (zemin 100·F uygular):

| Motor | Sağ topun en yüksek hızı (m/s) | Ekrana yazılan tepe noktası |
|---|---|---|
| MuJoCo | yok | yok |
| Yedek Çözücü | 1186 | ~200 m |
| Godot Melez | 1185 | ~211 m |

Kabul ölçütü (≥ 15 temas adımı; Yedek Çözücü ile birkaç % içinde) sağlanıyor.

## Farkın kaynağı: adım büyüklüğü

Godot Melez'in tik sayısı artırıldıkça sonuçlar Yedek Çözücü'ye yakınsıyor; yani fark
fizikten değil, zamanın ayrıklaştırılmasından geliyor. Temas süresindeki fark tam olarak
bir adım kadar (0.42 ms).

| Godot Melez tik | Temas adımı | İlk sekme (m) | Temas (ms) | Tepe N | (b) tepe |
|---|---|---|---|---|---|
| 120 (varsayılan) | 18 | 1.572 | 7.50 | 1665 | 211 m |
| 240 | 37 | 1.564 | 7.71 | 1646 | 199 m |
| 480 | 75 | 1.561 | 7.81 | 1638 | 200 m |
| *Yedek Çözücü* | *378* | *1.559* | *7.88* | *1632* | *200 m* |

(b)'deki tepe noktası farkı, impuls bittikten sonra ağır çekimin kalkmasından kaynaklanıyor:
top ~1185 m/s hızla tek bir 8.3 ms'lik Godot adımıyla ilerliyor ve hava direnci bu büyük
adımda yaklaşık hesaplanıyor. Yedek Çözücü aynı süreyi 40 alt adımla integre ediyor.

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
