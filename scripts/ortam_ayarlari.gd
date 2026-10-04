@tool
class_name OrtamAyarlari
extends Resource
## Salonun (sahnedeki "Ortam" düğümü) KOD YAZMADAN değiştirilebilir ayarları.
##
## NASIL DÜZENLENİR:
##   1. FileSystem → config/ortam_ayarlari.tres dosyasına TIKLA.
##   2. Inspector'da renkleri / ölçüleri / seyirciyi / ışığı değiştir.
##   3. En üstteki "Salonu yeniden üret" düğmesine bas → salon sahnede
##      hemen yeniden kurulur. main.tscn açıksa Cmd+S (Ctrl+S) ile kaydet.
##   4. Bu dosyayı da kaydet (Cmd+S); değişiklik kalıcıdır, betik tekrar
##      çalışsa bile kaybolmaz.
##
## Varsayılan değerler, salonun bugünkü görünüşüyle BİREBİR aynıdır.
## Salona elle bir şey eklemek için: Scene panelinde Ortam/ElleEklenenler
## düğümünün İÇİNE ekle — yeniden üretim o düğüme dokunmaz.
##
## Üretici: tools/ortam_uretici.gd (terminalden: tools/build_environment.gd).

## Inspector'daki düğme: salonu bu ayarlarla yeniden üretir.
@export_tool_button("Salonu yeniden üret", "Reload") var salonu_yeniden_uret: Callable = _yeniden_uret

@export_group("Renkler")
## Parke tahtalarının tonları; her tahta bunlardan rastgele (SEED'e göre) birini alır.
@export var parke_tonlari: PackedColorArray = PackedColorArray([Color("e2b077"), Color("d9a468"), Color("e8bb86"), Color("d49c5e")])
## Saha çizgileri (dip, yan, serbest atış, üçlük).
@export var saha_cizgisi: Color = Color("fbfaf5")
## Boyalı alan (pota altındaki dikdörtgen).
@export var boyali_alan: Color = Color("2f6fb5")
## Sol topun altındaki yarı saydam bölge (Bolge1). Saydamlık: rengin A (alfa) değeri.
## Defne'nin seçimi: iki bölge de turuncu (eskiden sol mavi "gerçek dünya" idi).
@export var sol_bolge_rengi: Color = Color(0.95, 0.55, 0.20, 0.22)
## Sağ topun altındaki yarı saydam bölge (Bolge2). Saydamlık: rengin A (alfa) değeri.
@export var sag_bolge_rengi: Color = Color(0.95, 0.55, 0.20, 0.22)
## Arka ve yan duvarlar.
@export var duvar: Color = Color("2b3550")
## Duvarlardaki turuncu şeritler.
@export var serit: Color = Color("e8742a")
## Tribün basamakları; sıralar bu renkleri sırayla kullanır.
@export var tribun_basamaklari: PackedColorArray = PackedColorArray([Color("c8553d"), Color("b0473a")])
## Seyirci formaları (her seyirci rastgele birini alır). Flamalar da bu renkleri kullanır.
@export var seyirci_formalari: PackedColorArray = PackedColorArray([Color("e8742a"), Color("2f6fb5"), Color("f2f2ee"), Color("f2c14e"), Color("3aa17e"), Color("7a5cc9")])
## Seyirci ten renkleri (her seyirci rastgele birini alır).
@export var seyirci_ten: PackedColorArray = PackedColorArray([Color("f1c7a1"), Color("d9a47c"), Color("b27a52"), Color("7d5236")])
## Pota direği, kolu ve tabanı.
@export var pota_direk: Color = Color("3a3f4a")
## Panya (beyaz tahta).
@export var panya: Color = Color("f4f6f8")
## Panyadaki kırmızı çerçeve ve atış karesi.
@export var panya_isareti: Color = Color("d7392f")
## Çember ve bağlantısı.
@export var cember: Color = Color("e8601c")
## File (yarı saydam; saydamlık A değeri).
@export var file: Color = Color(1, 1, 1, 0.55)
## Arka plan ve sis rengi.
@export var arka_plan: Color = Color("1a2130")

@export_group("Ölçüler")
## Dip çizginin konumu (m, kameradan uzaklaşan yön eksi).
@export_range(-15.0, -3.0, 0.05, "suffix:m") var dip_cizgi_z: float = -7.2
## Yan çizgilerin merkezden uzaklığı (m). Saha eni bunun iki katı.
@export_range(2.0, 10.0, 0.05, "suffix:m") var yan_cizgi_x: float = 7.5
## Üçlük çizgisinin yarıçapı (m).
@export_range(3.0, 9.0, 0.05, "suffix:m") var ucluk_yaricap: float = 6.75
## Köşe üçlük çizgilerinin merkezden uzaklığı (m). Üçlük yarıçapından küçük olmalı.
@export_range(2.0, 8.9, 0.05, "suffix:m") var ucluk_kose_x: float = 6.6
## Boyalı alanın yarı eni (m). 2.45 → 4.9 m genişlik.
@export_range(0.5, 4.0, 0.05, "suffix:m") var boyali_alan_yari_genislik: float = 2.45
## Parkenin merkezden yanlara uzanımı (m). Tribün ve duvarlar da buna göre genişler.
@export_range(5.0, 20.0, 0.5, "suffix:m") var parke_yari_genislik: float = 10.0
## Tribündeki sıra (basamak) sayısı.
@export_range(1, 12, 1) var tribun_sira_sayisi: int = 6
## Her basamağın yüksekliği (m).
@export_range(0.1, 1.0, 0.01, "suffix:m") var basamak_yuksekligi: float = 0.42
## Duvarların yüksekliği (m). Flamalar ve skorbord buna göre yerleşir.
@export_range(4.0, 20.0, 0.1, "suffix:m") var duvar_yuksekligi: float = 9.0

@export_group("Seyirci")
## Tribünün ne kadarı dolu (0 = boş, 1 = tam dolu). Bugün %70.
@export_range(0.0, 1.0, 0.01) var doluluk_orani: float = 0.7
## Rastgelelik tohumu: aynı SEED → birebir aynı salon (seyirci renkleri,
## boşluklar, parke tonları). Başka bir sayı → başka bir dağılım.
@export var seed_sayisi: int = 2209

@export_group("Işık ve ortam")
## Tavandaki 3 ışığın gücü. (Web'de parlama yapmasın diye 0.6'ya düşürülmüştü.)
@export_range(0.0, 4.0, 0.05) var tavan_isik_gucu: float = 0.6
## Tavan ışıklarının rengi.
@export var tavan_isik_rengi: Color = Color("fff1dc")
## Ana ışığın (Sun) gücü.
@export_range(0.0, 4.0, 0.05) var gunes_gucu: float = 0.85
## Ana ışığın rengi.
@export var gunes_rengi: Color = Color("fff4e2")
## Ortam ışığının rengi (gölgede kalan yerlerin aydınlığı).
@export var ortam_isik_rengi: Color = Color("c9c2b8")
## Ortam ışığının gücü.
@export_range(0.0, 4.0, 0.05) var ortam_isik_gucu: float = 0.55
## Sis yoğunluğu (uzaktaki tribünün hafif puslu görünmesi). 0 = sis yok.
@export_range(0.0, 0.2, 0.001) var sis_yogunlugu: float = 0.012
## Parlama (glow) açık mı.
@export var parlama: bool = true
## Parlamanın şiddeti. (Web'de abartılı görünmesin diye 0.35.)
@export_range(0.0, 2.0, 0.01) var parlama_siddeti: float = 0.35
## Parlamanın yayılması (bloom).
@export_range(0.0, 1.0, 0.01) var parlama_yayilmasi: float = 0.03

@export_group("Skorbord")
## Skorborddaki büyük başlık.
@export var baslik: String = "ETKİ  –  TEPKİ"
## Başlığın altındaki küçük yazı.
@export var alt_baslik: String = "Newton'un 3. yasası"


func _yeniden_uret() -> void:
	var uretici = load("res://tools/ortam_uretici.gd").new()
	var sonuc: String = uretici.editorde_uret(self)
	print("[Salon] ", sonuc)
