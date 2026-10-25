class_name SecenekAyarlari
extends Resource
## Seçim ekranı, seçenekler ve koşu sonu soruları — KOD YAZMADAN değiştirilir.
##
## NASIL DÜZENLENİR: FileSystem → config/secenekler.tres dosyasına TIKLA,
## Inspector'da metinleri değiştir, Cmd+S (Ctrl+S) ile kaydet. Bir sonraki
## başlatmada işler. Seçenek eklemek için "Secenekler" listesinde
## "Add Element" → New Secenek; sırası ekrandaki sırasıdır.

## Seçim penceresinin başlığı.
@export_multiline var secim_basligi: String = ""
## Başlığın altındaki ipucu (iki toplu, normal mod).
@export_multiline var secim_ipucu: String = ""
## Başlığın altındaki ipucu (referanssız mod: tek top).
@export_multiline var secim_ipucu_referanssiz: String = ""
## Koşu sonu soru penceresinin başlığı.
@export var soru_basligi: String = "Soru"
## Açık: soru penceresinde öğrenci cevabını yazar, user://cevaplar.csv'ye
## kaydedilir. Kapalı: soru yalnızca gösterilir (cevap sözlü).
@export var soru_metin_girisi: bool = true
## Referanssız modda doğru/yanlış açıklaması da gösterilsin mi (Sim2Config →
## Görünüm → geri_bildirim de açık olmalı).
@export var referanssiz_geri_bildirim: bool = false
## Seçenekler (ekrandaki sırayla).
@export var secenekler: Array[Secenek] = []
