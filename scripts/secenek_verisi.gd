class_name SecenekVerisi
extends Resource
## Seçim ekranı ve koşu sonu sorusu — KOD YAZMADAN değiştirilir.
##
## NASIL DÜZENLENİR: Godot editöründe res://config/secenekler.tres dosyasına
## tıkla (ya da sahnede Main → Inspector → "Secenekler"). Şıkları
## "Secenekler" listesinden aç, metin/soru alanlarını değiştir, Ctrl+S.
## Değişiklik bir sonraki çalıştırmada (F5) görünür.

## Seçim penceresinin başlığı.
@export_multiline var secim_basligi: String = ""
## Başlığın altındaki ipucu (referanslı mod: sol tarafta gerçek fizik var).
@export_multiline var secim_ipucu: String = ""
## Başlığın altındaki ipucu (referanssız mod).
@export_multiline var secim_ipucu_referanssiz: String = ""
## Koşu sonu soru penceresinin başlığı.
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
		"secim_basligi": secim_basligi,
		"secim_ipucu": secim_ipucu,
		"secim_ipucu_referanssiz": secim_ipucu_referanssiz,
		"soru_basligi": soru_basligi,
		"soru_metin_girisi": soru_metin_girisi,
		"secenekler": liste,
	}
