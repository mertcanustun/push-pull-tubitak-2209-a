class_name Secenek
extends Resource
## Seçim ekranındaki TEK seçenek (config/secenekler.tres → Secenekler listesi).
## Inspector'da listeyi aç, bir öğeye tıkla: alanlar burada.

## Kısa kimlik (a, b, c, d …). Öğrenci cevap kaydında (cevaplar.csv) bu yazar.
@export var id: String = ""
## Düğmede metnin önündeki harf ("a)").
@export var harf: String = ""
## Düğmedeki seçenek metni.
@export_multiline var metin: String = ""
## Sağdaki topun nasıl hareket edeceği:
##   a = gerçek tepki (soldakiyle aynı sekiyor)
##   b = b_carpani kadar büyük kuvvet (fırlar)
##   c = top durur
@export_enum("a", "b", "c") var davranis: String = "a"
## Açıksa bu seçenekte sağdaki topun üzerinde HİÇ kuvvet oku gösterilmez.
@export var oklari_gizle: bool = false
## Koşu sonunda çıkan soru. BOŞSA soru penceresi açılmaz.
@export_multiline var son_soru: String = ""
## Seçimden sonra alttaki doğru/yanlış açıklaması (Sim2Config → Görünüm →
## geri_bildirim açıkken görünür). BBCode kullanılabilir. Yer tutucular:
## {f} = gerçek tepki kuvveti (N), {fb} = (b)'de uygulanan kuvvet (N),
## {carpan} = b çarpanı.
@export_multiline var geri_bildirim: String = ""
