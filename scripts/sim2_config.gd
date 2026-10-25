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
## alanını aç — oyunu durdurmadan değerleri değiştirebilirsin.
##   - Top / Hava / Temas grupları: bir sonraki Sıfırla'da (R) işler
##     (ör. Restitution'ı 0.76 → 0.5 yap, R'ye bas, sol top daha az seker).
##   - Fizik Motoru: değişince sahne kendiliğinden sıfırlanır.
##   - Seçenekler / Görsel / Görünüm / (b) gösterimi / Hava Modeli: anında işler.
##
## ÖNEMLİ — MuJoCo motoru hakkında: aşağıdaki Top/Hava/Temas değerleri
## MuJoCo seçiliyken yalnızca GDScript tarafındaki kayıtları (ok büyüklüğü,
## panel yazıları) günceller. MuJoCo'nun KENDİ fiziği res://mujoco/scene.xml
## dosyasından sabit okunur ve BU KAYNAKTAN ETKİLENMEZ (MJCF ayrı bir motor,
## kendi dosyasıyla tanımlı). "Sekmeyi değiştir, azaldığını gör" gibi canlı
## bir demo için Fizik Motoru Godot Melez (varsayılan) ya da Yedek Çözücü
## olmalı — bu ikisi her değeri bu kaynaktan okur.
##
## TİP NOTU: alanlar bilerek `: float = ...` ile yazıldı (`:=` değil) —
## başka scriptlerden "cfg.mass" gibi okunduğunda statik tip çıkarımı
## sorun çıkarmasın diye (bkz. fizik-sim projesindeki SimConfig.gd ile
## aynı gerekçe).

enum Backend { MUJOCO, YEDEK_COZUCU, GODOT_MELEZ }
enum HavaModeli { GERCEKCI_KARE, GODOT_SONUM_DOGRUSAL, KAPALI }
enum BGosterim { KAMERA_TAKIP, FIRLATMA_AGIR_CEKIM, IKISI, HICBIRI }
enum EnYuksek { CANLI, SON_REKOR, GIZLI }

@export_group("Fizik Motoru")
## Varsayılan: GODOT_MELEZ. MUJOCO bulunamazsa (derlenmemişse) otomatik
## Yedek Çözücü'ye düşer.
## GODOT_MELEZ: uçuş Godot'nun RigidBody3D fiziğinde, temas + hava bizim
## modelimiz (scripts/godot_backend.gd). Oyun çalışırken değiştirilirse
## simülasyon otomatik sıfırlanır.
@export var backend: Backend = Backend.GODOT_MELEZ
## Yalnızca Godot Melez: saniyedeki fizik adımı. Ağır çekimde (0.05) adım
## = (1/tik) × 0.05 → 120'de 0.42 ms, 8 ms'lik temas 18 adıma bölünür
## (hedef ≥ 15). Yükseltmek Yedek Çözücü'ye yaklaştırır (240'ta farklar
## %2'nin altında) ama işlemciyi daha çok yorar. Değişiklik bir sonraki
## motor seçiminde/başlatmada geçerli olur. Diğer motorlar 60'ta kalır.
@export_range(60, 960, 60, "suffix:Hz") var godot_tik_sayisi: int = 120

@export_group("Top")
## Kütle (kg). NBA topu 0.624 kg. Ağırlık oku (Fg) ve zemin kuvveti bununla
## orantılı değişir. Sıfırla'da işler.
@export_range(0.05, 5.0, 0.001, "suffix:kg") var mass: float = 0.624
## Yarıçap (m). Topun görünen boyu da bundan gelir. Sıfırla'da işler.
@export_range(0.01, 1.0, 0.001, "suffix:m") var radius: float = 0.119
## Sekme katsayısı: 0 = hiç sekmez, 1 = kayıpsız seker. 0.76'da 3 m'den
## bırakılan top ~1.5 m'ye seker. Sıfırla'da işler.
@export_range(0.0, 1.0, 0.01) var restitution: float = 0.76

@export_group("Hava")
## Uçuştaki hava direnci modeli. Godot Melez motoru üçünü de uygular ve
## her adımda canlı okur. Yedek Çözücü her zaman GERCEKCI_KARE kullanır;
## MuJoCo kendi akışkan modelini (bkz. yukarıdaki not). (b)'deki tepe
## noktası yazısı her motorda bu seçime göre hesaplanır.
@export var hava_modeli: HavaModeli = HavaModeli.GERCEKCI_KARE
## Hava yoğunluğu (deniz seviyesi 1.225). Artırınca hava direnci (mavi Fs
## oku) büyür. Sıfırla'da işler.
@export_range(0.0, 5.0, 0.001, "suffix:kg/m³") var hava_yogunlugu: float = 1.225
## Sürüklenme katsayısı (Cd). Küre için 0.47. Etkisi hava yoğunluğu gibi.
## Sıfırla'da işler.
@export_range(0.0, 2.0, 0.01) var drag_cd: float = 0.47
## Yalnızca Hava Modeli = GODOT_SONUM_DOGRUSAL iken kullanılır (karşılaştırma
## için; gerçekçi modelle aynı limit hıza göre ayarlı). Diğer modellerde etkisiz.
@export_range(0.0, 5.0, 0.001) var dogrusal_sonum: float = 0.449

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
## (b) seçeneğinde zeminin uyguladığı "yanlış" kuvvet çarpanı. Senaryo
## planında 100. 10'da bile top ekrandan çıkar (~84 m tepe); 2'de de çıkar.
## Top yalnızca 1'de ekranda kalır.
@export_range(1.0, 500.0, 1.0, "suffix:×") var b_carpani: float = 100.0

@export_group("Görsel")
## Okların genel boyu. Ölçek logaritmik: küçük ve dev kuvvetler aynı ekrana
## sığsın diye. Oklar ekrandan taşıyorsa küçült.
@export_range(0.05, 2.0, 0.01) var ok_olcegi: float = 0.36
## Top zemine yaklaşırken/temas ederken zaman ne kadar yavaşlasın
## (0.05 = 20 kat yavaş).
@export_range(0.001, 1.0, 0.001) var agir_cekim_carpani: float = 0.05
## (b)'de top bu yüksekliği geçince "ekrandan çıktı" sayılır ve tepe noktası
## yazısı çıkar.
@export_range(1.0, 50.0, 0.5, "suffix:m") var ekrandan_cikis_yuksekligi: float = 9.0

@export_group("Koşu sonu")
## Sağdaki topun ulaştığı yükseklik göstergesi ("En yüksek: X m"):
##   CANLI     - eski davranış: (b) takibinde canlı sayaç + tepe noktası yazısı
##   SON_REKOR - koşu sırasında gizli, koşu BİTİNCE "En yüksek: X m" rekoru
##               (Sıfırla'ya kadar ekranda kalır)
##   GIZLI     - hiç gösterilmez
## Anında işler.
@export var en_yuksek_gosterimi: EnYuksek = EnYuksek.GIZLI
## Seçimden sonra koşunun "bitti" sayılması için geçen süre (gerçek saniye,
## duraklatma sayılmaz). Süre dolunca koşu HER DURUMDA biter: (b)'de kamera
## takibi sürüyorsa kamera ana poza döner. Koşu bitince rekor (yukarıda) ve
## seçeneğin son sorusu (config/secenekler.tres) gösterilir.
@export_range(0.5, 30.0, 0.5, "suffix:sn") var kosu_sonu_bekleme: float = 4.0

@export_group("Görünüm")
## Başlık ("ETKİ – TEPKİ: …") ve altındaki durum yazısı. Anında işler.
@export var ust_yazilar: bool = false
## SOL / SAĞ durum panelleri (yükseklik, hız, kuvvetler). Anında işler.
@export var durum_panelleri: bool = false
## Seçimden sonra alttaki doğru/yanlış açıklaması. Anında işler.
@export var geri_bildirim: bool = false
## Sahnedeki 1 / 2 / 3 m cetvelleri ve (b) kamera takibindeki yükseklik
## cetveli. Anında işler.
@export var cetveller: bool = false
## Okların yanında kuvvet büyüklüğü ("Fg 6.1 N"). Kapalıyken yalnız ad
## ("Fg") yazar. Anında işler.
@export var ok_degerleri: bool = false
## Temas ağır çekimi seçimden SONRA da sürsün mü. Kapalıyken yalnızca ilk
## çarpma (seçim anı) yavaşlar; sonraki sekmeler normal hızda görünür (fizik
## adımı yine aynı küçüklükte, yalnızca saniyede daha çok adım atılır).
@export var secimden_sonra_agir_cekim: bool = false

@export_group("(b) gösterimi")
## (b)'de top ~1200 m/s ile fırlar: 9 m'ye (ekrandan çıkış) 11 ms'de varır,
## normal hızda tek kareden kısa. Bu ayarlar YALNIZCA görüntüyü/zamanı
## değiştirir; fizik ve ekrana yazılan tepe noktası hesabı aynı kalır.
##   FIRLATMA_AGIR_CEKIM: seçim anından top ekrandan çıkana kadar ağır çekim
##   KAMERA_TAKIP: top ekrandan çıkınca kamera onu tepe noktasına kadar izler,
##                 kısa bekler, sonra ana kamera pozuna geri döner
##   IKISI: önce fırlatma ağır çekimde, sonra kamera takibi
##   HICBIRI: eski davranış (top 9 m'de durdurulur, yalnızca yazı)
@export var b_gosterim: BGosterim = BGosterim.KAMERA_TAKIP
## Fırlatma ağır çekim çarpanı (0.01 → ilk 9 m yaklaşık 1 saniyede izlenir).
@export_range(0.001, 1.0, 0.001) var firlatma_agir_cekim_carpani: float = 0.01
## Fırlatma ağır çekiminin üst sınırı (gerçek saniye). Normalde top ekrandan
## çıkınca zaten biter; bu yalnızca bir güvenlik sınırı.
@export_range(0.1, 10.0, 0.1, "suffix:sn") var firlatma_agir_cekim_suresi: float = 3.0
## Kamera takibinin üst sınırı (gerçek saniye). Tepe noktasına ~3.5 sn'de
## varılıyor; bu süre dolarsa takip tepeyi beklemeden biter.
@export_range(0.5, 20.0, 0.1, "suffix:sn") var kamera_takip_suresi: float = 8.0
## Kamera en fazla bu yüksekliğe kadar çıkar; top daha yükseğe giderse
## kadrajdan çıkar ama yükseklik göstergesi saymaya devam eder.
@export_range(10.0, 2000.0, 5.0, "suffix:m") var kamera_takip_max_yukseklik: float = 250.0
## Kamera tepe noktasında bu kadar bekler (gerçek saniye).
@export_range(0.0, 5.0, 0.1, "suffix:sn") var kamera_tepe_bekleme: float = 1.0
## Kameranın ana konumuna dönüş süresi (gerçek saniye). Sonunda BİREBİR eski
## konumda durur.
@export_range(0.1, 5.0, 0.1, "suffix:sn") var kamera_donus_suresi: float = 1.5
## Takip sırasında topun yanında yükseklik cetveli: her 1 m'de çentik, bu
## aralıkta etiket. Kadraj dikeyde ~5 m gösterir; 5 m'de her an bir etiket görünür.
@export_range(1.0, 100.0, 1.0, "suffix:m") var yukseklik_isaret_araligi: float = 5.0
