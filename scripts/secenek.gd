class_name Secenek
extends Resource
## Seçim ekranındaki TEK bir şık. res://config/secenekler.tres içindeki
## "Secenekler" listesinin bir elemanı — Inspector'dan düzenlenir.

## Kayıtlarda (cevaplar.csv, uzak kayıt) geçen kısa ad. Her şıkta farklı olmalı.
@export var id: String = "a"
## Düğmede metnin önünde görünen harf, ör. "a)".
@export var harf: String = "a)"
## Düğmede görünen şık metni.
@export_multiline var metin: String = ""
## Sağdaki topun bu şık seçilince ne yapacağı:
##   a - gerçek tepki (soldakiyle aynı sekiş)
##   b - Sim2Config → b_carpani kadar büyük kuvvet (top fırlar)
##   c - yukarı F + aşağı F (top durur)
@export_enum("a", "b", "c") var davranis: String = "a"
## Açıksa bu şıkta sağdaki topun üzerinde HİÇ kuvvet oku gösterilmez.
@export var oklari_gizle: bool = false
## Koşu sonunda çıkan soru. Boşsa soru penceresi AÇILMAZ.
@export_multiline var son_soru: String = ""


func sozluk() -> Dictionary:
	return {
		"id": id, "harf": harf, "metin": metin, "davranis": davranis,
		"oklari_gizle": oklari_gizle, "son_soru": son_soru,
	}
