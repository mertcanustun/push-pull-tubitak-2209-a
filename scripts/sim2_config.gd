class_name Sim2Config
extends Resource
## Senaryo 2 — KOD YAZMADAN değiştirilebilir simülasyon ayarları.
##
## NASIL DÜZENLENİR (teknik olmayan ekip arkadaşları için):
##   1. Godot editörünü aç, res://config/sim2_config.tres dosyasına TIKLA.
##   2. Sağdaki Inspector panelinde tüm değerler slider/sayı kutusu olarak çıkar.
##   3. Değiştir, Ctrl+S ile kaydet, F5 ile dene.
##
## CANLI DÜZENLEME (oyun ÇALIŞIRKEN): Godot editöründe alttaki "Remote"
## sekmesine geç, sahne ağacında "Main" node'unu seç, Inspector'da "Cfg"
## alanını aç — oyunu durdurmadan değerleri değiştirip anlık etkisini
## görebilirsin (ör. Sekme'yi 0.76 → 0.5 yapıp sol topun daha az sektiğini
## izle). main.gd her kare DOĞRUDAN bu kaynaktan okur, değerleri kendi
## sabitlerine kopyalamaz — bu yüzden Remote'tan değişiklik anında işler.
##
## ÖNEMLİ — MuJoCo motoru hakkında: aşağıdaki Top/Hava/Temas değerleri
## MuJoCo seçiliyken yalnızca GDScript tarafındaki kayıtları (ok büyüklüğü,
## panel yazıları) günceller. MuJoCo'nun KENDİ fiziği res://mujoco/scene.xml
## dosyasından sabit okunur ve BU KAYNAKTAN ETKİLENMEZ (MJCF ayrı bir motor,
## kendi dosyasıyla tanımlı). "Sekmeyi değiştir, azaldığını gör" gibi canlı
## bir demo için Fizik Motoru'nu Yedek Çözücü'ye almalısın — o motor her
## değeri doğrudan bu kaynaktan okur.
##
## TİP NOTU: alanlar bilerek `: float = ...` ile yazıldı (`:=` değil) —
## başka scriptlerden "cfg.mass" gibi okunduğunda statik tip çıkarımı
## sorun çıkarmasın diye (bkz. fizik-sim projesindeki SimConfig.gd ile
## aynı gerekçe).

enum Backend { MUJOCO, YEDEK_COZUCU, GODOT_MELEZ }
enum HavaModeli { GERCEKCI_KARE, GODOT_SONUM_DOGRUSAL, KAPALI }

@export_group("Fizik Motoru")
## MUJOCO bulunamazsa (derlenmemişse) otomatik Yedek Çözücü'ye düşer.
## GODOT_MELEZ henüz uygulanmadı (Adım D) — seçilirse uyarıyla Yedek
## Çözücü'ye düşülür.
@export var backend: Backend = Backend.MUJOCO

@export_group("Top")
@export_range(0.05, 5.0, 0.001, "suffix:kg") var mass: float = 0.624
@export_range(0.01, 1.0, 0.001, "suffix:m") var radius: float = 0.119
@export_range(0.0, 1.0, 0.01) var restitution: float = 0.76

@export_group("Hava")
## Yalnızca Yedek Çözücü/Godot Melez bu alanlara bakar (MuJoCo kendi
## akışkan modelini kullanır, bkz. yukarıdaki not). GERCEKCI_KARE =
## main.gd'nin bugünkü davranışı (PhysicsBackend.drag_force, kare bağıntı).
## GODOT_SONUM_DOGRUSAL ve dogrusal_sonum alanı Adım D'de (GodotBackend)
## devreye girecek; şimdilik yalnızca Inspector'da görünür, davranışı
## değiştirmez (varsayılan GERCEKCI_KARE ile mevcut davranış korunuyor).
@export var hava_modeli: HavaModeli = HavaModeli.GERCEKCI_KARE
@export_range(0.0, 5.0, 0.001, "suffix:kg/m³") var hava_yogunlugu: float = 1.225
@export_range(0.0, 2.0, 0.01) var drag_cd: float = 0.47
@export_range(0.0, 5.0, 0.001) var dogrusal_sonum: float = 0.449   ## karşılaştırma için — aynı limit hıza göre ayarlı

@export_group("Temas")
## Seçim kuvvetinin (a/b/c) uygulandığı varsayımsal temas süresi — J = F·T
## formülündeki T. NativeBackend'in KENDİ yay-sönüm teması bundan bağımsız
## ayrıca gerçekleşir (ölçülen gerçek temas süresi farklı olabilir; bu alan
## yalnızca "zemin topa hangi F'yi uyguladı" hesabı içindir).
@export_range(0.001, 0.1, 0.0001, "suffix:sn") var temas_suresi: float = 0.008
## Yay sabiti (k). Sönüm (c) her zaman olduğu gibi sekme (restitution)
## değerinden türetilmeye devam eder (bkz. native_backend.gd add_body()).
@export_range(1.0e3, 1.0e6, 1.0, "suffix:N/m") var sertlik: float = 1.0e5

@export_group("Seçenekler")
## (b) seçeneğinde zeminin uyguladığı "yanlış" kuvvet çarpanı.
@export_range(1.0, 500.0, 1.0, "suffix:×") var b_carpani: float = 100.0

@export_group("Görsel")
@export_range(0.05, 2.0, 0.01) var ok_olcegi: float = 0.36
@export_range(0.001, 1.0, 0.001) var agir_cekim_carpani: float = 0.05
@export_range(1.0, 50.0, 0.5, "suffix:m") var ekrandan_cikis_yuksekligi: float = 9.0

# --- (b) gösterimi: sonraki adımda doldurulacak (bkz. ADIM2-PROMPT.md Adım E) ---
