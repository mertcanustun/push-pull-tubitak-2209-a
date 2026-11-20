class_name SecenekVerisi
extends Resource
## Seçim ekranı ve koşu sonu sorusu — KOD YAZMADAN değiştirilir.
##
## NASIL DÜZENLENİR: Godot editöründe res://config/secenekler.tres dosyasına
## tıkla (ya da sahnede Main → Inspector → "Secenekler"). Şıkları
## "Secenekler" listesinden aç, metin/soru alanlarını değiştir, Ctrl+S.
## Değişiklik bir sonraki çalıştırmada (F5) görünür.

@export_group("Giriş")
## Açılışta katılımcı kodu istensin mi. Kod girilmeden simülasyona geçilmez;
## kod uzak kayıtta "oturum" sütununun başına yazılır (ör. K12-…).
@export var kod_iste: bool = true
## Kod ekranının başlığı.
@export var kod_basligi: String = "Katılımcı Kodu"
## Kod ekranındaki açıklama.
@export_multiline var kod_aciklamasi: String = ""
## Açılışta (koddan sonra) kullanım yönergesi gösterilsin mi.
@export var yonerge_goster: bool = true
## Yönerge metni. BBCode kullanılabilir: [b]kalın[/b], • madde işareti.
@export_multiline var yonerge: String = ""
## Yönergeyi kapatıp simülasyonu başlatan düğmenin yazısı.
@export var devam_dugmesi: String = "Devam Et"

@export_group("Soru")
## Ana soru. Seçim anında sorulur ve simülasyon boyunca ekranın üstünde kalır.
@export_multiline var secim_basligi: String = ""
## Başlığın altındaki ipucu (referanslı mod: sol tarafta gerçek fizik var).
@export_multiline var secim_ipucu: String = ""
## Başlığın altındaki ipucu (referanssız mod).
@export_multiline var secim_ipucu_referanssiz: String = ""
## Koşu sonunda şıkkın sorusunun altında çıkan küçük yazı (boşsa çıkmaz).
@export_multiline var bitis_ipucu: String = ""
## Koşu sonu soru penceresinin başlığı (pencere artık kullanılmıyor: soru
## üstteki şeritte çıkar; eski kayıtlar için duruyor).
@export var soru_basligi: String = "Soru"
## Açık: öğrenci cevabını yazar, user://cevaplar.csv'ye kaydedilir.
## Kapalı: soru yalnızca gösterilir (cevap sözlü).
@export var soru_metin_girisi: bool = true
## Şıklar, düğmelerin sırasıyla.
@export var secenekler: Array[Secenek] = []


## Ayarlar autoload'unun kullandığı biçim (bkz. Ayarlar.secenek_listesi).
func sozluk() -> Dictionary:
	var liste: Array = []
	for s in secenekler:
		if s:
			liste.append(s.sozluk())
	return {
		"kod_iste": kod_iste,
		"kod_basligi": kod_basligi,
		"kod_aciklamasi": kod_aciklamasi,
		"yonerge_goster": yonerge_goster,
		"yonerge": yonerge,
		"devam_dugmesi": devam_dugmesi,
		"bitis_ipucu": bitis_ipucu,
		"secim_basligi": secim_basligi,
		"secim_ipucu": secim_ipucu,
		"secim_ipucu_referanssiz": secim_ipucu_referanssiz,
		"soru_basligi": soru_basligi,
		"soru_metin_girisi": soru_metin_girisi,
		"secenekler": liste,
	}
