extends CanvasLayer
class_name Hud

## Tum arayuz kodla kurulur - .tscn duzenlemeye gerek yok.
##
## BOYUTLAR "dp" CINSINDEN: 1 dp ≈ 1 CSS px ≈ iOS 1 pt ≈ Android 1 dp.
## _olcek_uygula() kok pencerenin content_scale_factor'unu ekranin DPI'ina
## gore ayarlar; boylece 48 dp'lik dugme telefonda da masaustunde de ~9 mm
## olur. Kaynaklar:
##   - dokunma hedefi: Material 48 dp, Apple HIG 44 pt, WCAG 2.5.5 44 px
##   - govde yazisi: Material Body Large 16 sp, kucuk yazi en az 14 sp
## Yerlesim (_yerlestir) ekranin dp cinsinden boyutuna gore uyarlanir:
##   GENIS   - masaustu / yatay tablet: paneller dort kosede
##   SIKISIK - yatay telefon: aciklamalar ve ayarlar katlanir
##   DIKEY   - dikey telefon: paneller yan yana, alt cubuk tam genislik

signal start_pressed
signal reset_pressed
signal speed_changed(value: float)
signal arrow_toggled(key: String, on: bool)
signal tool_toggled(on: bool)
signal choice_made(choice: String)
## Panellerin kapladigi ekran orani (0-1): sahnenin (toplarin) gorunmesi
## gereken bos alan bunun icinde kalir. main.gd kamerayi buna gore uydurur.
signal sahne_payi_degisti(sol: float, sag: float, ust: float, alt: float)
## Ust kisimdaki arayuzun (baslik, ustteki geri bildirim) bittigi y (dp).
signal ust_serbest_degisti(y: float)
## Koşu sonu soru penceresi kapandı. kaydet: öğrenci "Kaydet"e bastı.
signal soru_kapandi(cevap: String, kaydet: bool)
## Ayarlar → Referanssız mod değişti (main.gd sahneyi sıfırlar).
signal referanssiz_degisti(on: bool)

## KATMANLAR (CanvasLayer.layer) — projedeki tüm katmanlar:
##     1  Hud (bu düğüm): başlık, paneller, kontroller, seçim, geri bildirim
##     5  BGosterimKamera: (b) yükseklik yazısı / "En yüksek" rekoru
##    80  PerformansDenetimi: FPS göstergesi (fareyi yutmaz)
##    90  Koşu sonu soru penceresi (modal)
##   100  Ayarlar penceresi (modal) — HER ZAMAN EN ÜSTTE
const SORU_KATMANI := 90
const AYAR_KATMANI := 100

const BG := Color(0.07, 0.08, 0.11, 0.88)
const ACCENT := Color(1.0, 0.65, 0.2)
const TEXT := Color(0.92, 0.93, 0.96)
const MUTED := Color(0.62, 0.66, 0.74)

# ---------------------------------------------------- boyut belirtecleri (dp)
const KENAR := 16.0          # ekran kenar boslugu
const BOSLUK := 12.0         # paneller arasi
const DOKUN := 48.0          # dugme yuksekligi (Material 48 dp)
const SATIR := 44.0          # onay kutusu / kaydirici satiri (Apple 44 pt)
const YAN_GEN := 320.0       # yan panel + kontrol paneli genisligi (genis yerlesim)
const YAN_GEN_SIKISIK := 244.0
const KONTROL_GEN := 440.0   # genis ekranda kontrol paneli (2 sutun onay kutusu)
const SECIM_GEN := 680.0     # secim paneli azami genislik
const GERI_GEN := 820.0      # geri bildirim azami genislik

## Ekranin kisa kenari dp cinsinden bu araliga sikistirilir: en dar telefon
## 360 dp; buyuk ekranda (projektor, 4K) arayuz 900 dp'den kucuk kalmaz.
const KISA_KENAR_MIN := 360.0
const KISA_KENAR_MAX := 900.0

const AYAR_GEN := 560.0      # ayarlar penceresi azami genislik
const SORU_GEN := 600.0      # soru penceresi azami genislik

enum Mod { GENIS, SIKISIK, DIKEY }

const ARROW_DEFS := [
	["gravity", "Yerçekimi  Fg", Color(0.94, 0.35, 0.35), true],
	["drag", "Hava sürtünmesi  Fs", Color(0.42, 0.72, 1.00), true],
	["contact", "Zemin tepkisi  N", Color(0.40, 0.90, 0.55), true],
	["external", "Uygulanan kuvvet  F", Color(0.85, 0.55, 1.00), true],
	["net", "Net kuvvet  Fnet", Color(1.00, 0.85, 0.25), false],
	["net_minus_g", "Fnet − Fg", Color(1.00, 0.55, 0.15), false],
]

const SVG_ACIK := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect x="2" y="2" width="20" height="20" rx="5" fill="#ffa633"/><path d="M6.5 12.5l3.5 3.5 7.5-8" fill="none" stroke="#14161c" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'
const SVG_KAPALI := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect x="3" y="3" width="18" height="18" rx="4.5" fill="#ffffff10" stroke="#9aa3b5" stroke-width="2"/></svg>'
const SVG_TUTAMAK := '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28"><circle cx="14" cy="14" r="11" fill="#f2f3f6" stroke="#ffa633" stroke-width="3"/></svg>'
const SVG_ASAGI := '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M5 8l5 5 5-5" fill="none" stroke="#c8cddb" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
const SVG_YUKARI := '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M5 12l5-5 5 5" fill="none" stroke="#c8cddb" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>'
const SVG_SAG := '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M8 5l5 5-5 5" fill="none" stroke="#c8cddb" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>'

var _left_readout: RichTextLabel
var _right_readout: RichTextLabel
var _status: Label
var _feedback: RichTextLabel
var _feedback_panel: PanelContainer
var _choice_panel: PanelContainer
var _start_btn: Button
var _backend_label: Label

var _kok: Control
var _ust: VBoxContainer          # baslik + yan paneller
var _baslik: Label
var _baslik_kutu: VBoxContainer
var _paneller: Array = []        # ic boslugu moda gore degisen paneller
var _satir_dugmeleri: Array = [] # Baslat / Sifirla / Ayarlar
var _secim_dugmeleri: Array = []
var _secim_baslik: Label
var _secim_ipucu: Label
var _yan_satir: BoxContainer
var _yan: Array = []             # [{panel, baslik, aciklama, okuma}] sol, sag
var _alt: BoxContainer           # kontrol paneli + geri bildirim
var _alt_bosluk: Control
var _kontrol_panel: PanelContainer
var _ayar_kaydir: ScrollContainer
var _ayar_icerik: VBoxContainer
var _ayar_btn: Button
var _ok_izgara: GridContainer
var _hiz_deger: Label
var _olcek_deger: Label
var _yazi_deger: Label
var _tema_ref: Theme
# ayarlar penceresi (kendi CanvasLayer'i, AYAR_KATMANI)
var _ayar_katman: CanvasLayer
var _ayar_panel: PanelContainer
var _ayar_baslik: Control
var _referans_cb: CheckBox
var _gelistirici_izgara: GridContainer
# koşu sonu soru penceresi (kendi CanvasLayer'i, SORU_KATMANI)
var _soru_katman: CanvasLayer
var _soru_panel: PanelContainer
var _soru_secenek: Label
var _soru_metin: Label
var _soru_giris: TextEdit
var _soru_kaydet: Button
var _soru_gec: Button
var _soru_icerik: VBoxContainer
var _secim_kaydir: ScrollContainer
var _secim_icerik: VBoxContainer
var _geri_kaydir: ScrollContainer

var _mod := Mod.GENIS
var _aciklama_kullanici := [false, false]
var _geri_ustte := false
var _yerlesim_sayac := 0
var _ikon := {}


func _ready() -> void:
	_ikonlari_hazirla()
	_tema_ref = _tema()
	_kok = Control.new()
	_kok.set_anchors_preset(Control.PRESET_FULL_RECT)
	_kok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kok.theme = _tema_ref
	add_child(_kok)

	_build_title()
	_build_side_panels()
	_build_controls()
	_build_choice_panel()
	_build_feedback()
	_build_settings()
	_build_question()

	get_tree().root.size_changed.connect(_ekran_degisti)
	Ayarlar.degisti.connect(_ayarlar_degisti)
	_ekran_degisti()


func _unhandled_key_input(event: InputEvent) -> void:
	if _ayar_katman.visible and event.is_action_pressed("ui_cancel"):
		ayarlari_ac(false)
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------- olcek / tema

func _olcek_uygula() -> void:
	var win := get_tree().root
	var px := Vector2(win.size)
	if px.x < 1.0 or px.y < 1.0:
		return
	var kisa := minf(px.x, px.y)
	# 1 dp'ye dusen fiziksel piksel
	var px_dp := maxf(_dpi() / _dpi_ref(), kisa / KISA_KENAR_MAX) * Ayarlar.arayuz_olcek
	px_dp = maxf(minf(px_dp, kisa / KISA_KENAR_MIN), 0.25)
	# canvas_items + expand: Godot zaten taban boyuta gore olcekliyor
	var taban := Vector2(win.content_scale_size)
	var germe := minf(px.x / taban.x, px.y / taban.y) if taban.x > 0.0 and taban.y > 0.0 else 1.0
	var f := px_dp / germe
	if absf(win.content_scale_factor - f) > 0.001:
		win.content_scale_factor = f


func _dpi() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arayuz-dpi="):
			return a.trim_prefix("--arayuz-dpi=").to_float()
	var d := float(DisplayServer.screen_get_dpi())
	return d if d > 0.0 else 96.0


## Web'de DPI = 96 x devicePixelRatio, yani 1 CSS px = 96 DPI. Yerel
## Android/iOS gercek DPI dondurur; orada 1 dp = 1/160 inc.
func _dpi_ref() -> float:
	if OS.has_feature("android") or OS.has_feature("ios"):
		return 160.0
	return 96.0


func _svg(kaynak: String) -> Texture2D:
	return DPITexture.create_from_string(kaynak)


func _ikonlari_hazirla() -> void:
	_ikon = {
		"acik": _svg(SVG_ACIK),
		"kapali": _svg(SVG_KAPALI),
		"tutamak": _svg(SVG_TUTAMAK),
		"asagi": _svg(SVG_ASAGI),
		"yukari": _svg(SVG_YUKARI),
		"sag": _svg(SVG_SAG),
	}


func _kutu(bg: Color, radius: int = 10, h: float = 16.0, v: float = 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = h
	sb.content_margin_right = h
	sb.content_margin_top = v
	sb.content_margin_bottom = v
	sb.anti_aliasing = true
	return sb


func _tema() -> Theme:
	var t := Theme.new()

	t.set_color("font_color", "Label", TEXT)

	# Dugmeler: 48 dp yukseklik, belirgin basili / odak durumu
	t.set_stylebox("normal", "Button", _kutu(Color(0.17, 0.19, 0.25, 0.95)))
	t.set_stylebox("hover", "Button", _kutu(Color(0.23, 0.26, 0.33, 0.97)))
	var basili := _kutu(Color(0.30, 0.22, 0.10, 0.97))
	basili.border_color = ACCENT
	basili.set_border_width_all(2)
	t.set_stylebox("pressed", "Button", basili)
	t.set_stylebox("hover_pressed", "Button", basili)
	t.set_stylebox("disabled", "Button", _kutu(Color(0.12, 0.13, 0.17, 0.8)))
	var odak := _kutu(Color(0, 0, 0, 0))
	odak.draw_center = false
	odak.border_color = Color(ACCENT, 0.9)
	odak.set_border_width_all(2)
	t.set_stylebox("focus", "Button", odak)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("icon_normal_color", "Button", TEXT)
	t.set_constant("h_separation", "Button", 10)

	# Onay kutulari: 24 dp isaret, 44 dp satir, ustune gelince hafif zemin
	var cb_bos := _kutu(Color(0, 0, 0, 0), 8, 8, 6)
	var cb_ust := _kutu(Color(1, 1, 1, 0.06), 8, 8, 6)
	for s in ["normal", "pressed", "disabled"]:
		t.set_stylebox(s, "CheckBox", cb_bos)
	t.set_stylebox("hover", "CheckBox", cb_ust)
	t.set_stylebox("hover_pressed", "CheckBox", cb_ust)
	t.set_stylebox("focus", "CheckBox", odak)
	t.set_icon("checked", "CheckBox", _ikon["acik"])
	t.set_icon("unchecked", "CheckBox", _ikon["kapali"])
	t.set_icon("checked_disabled", "CheckBox", _ikon["acik"])
	t.set_icon("unchecked_disabled", "CheckBox", _ikon["kapali"])
	t.set_constant("h_separation", "CheckBox", 12)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_hover_pressed_color", "CheckBox", Color.WHITE)

	# Kaydirici: 8 dp iz, 28 dp tutamak (dokunma alani SATIR yuksekligi)
	var iz := _kutu(Color(1, 1, 1, 0.14), 4, 0, 4)
	var dolu := _kutu(Color(ACCENT, 0.85), 4, 0, 4)
	t.set_stylebox("slider", "HSlider", iz)
	t.set_stylebox("grabber_area", "HSlider", dolu)
	t.set_stylebox("grabber_area_highlight", "HSlider", dolu)
	t.set_icon("grabber", "HSlider", _ikon["tutamak"])
	t.set_icon("grabber_highlight", "HSlider", _ikon["tutamak"])
	t.set_icon("grabber_disabled", "HSlider", _ikon["tutamak"])

	# Kaydirma cubugu: 10 dp, dokunarak da surukleniyor
	var cubuk_iz := _kutu(Color(1, 1, 1, 0.05), 5, 5, 0)
	var cubuk := _kutu(Color(1, 1, 1, 0.28), 5, 5, 0)
	var cubuk_ust := _kutu(Color(1, 1, 1, 0.42), 5, 5, 0)
	t.set_stylebox("scroll", "VScrollBar", cubuk_iz)
	t.set_stylebox("grabber", "VScrollBar", cubuk)
	t.set_stylebox("grabber_highlight", "VScrollBar", cubuk_ust)
	t.set_stylebox("grabber_pressed", "VScrollBar", cubuk_ust)

	var cizgi := StyleBoxLine.new()
	cizgi.color = Color(1, 1, 1, 0.12)
	cizgi.thickness = 1
	t.set_stylebox("separator", "HSeparator", cizgi)
	t.set_constant("separation", "HSeparator", 14)

	t.set_constant("line_separation", "RichTextLabel", 3)
	t.set_color("default_color", "RichTextLabel", TEXT)

	# Soru penceresindeki cevap kutusu
	var giris := _kutu(Color(0.05, 0.06, 0.08, 0.95), 8, 12, 10)
	giris.border_color = Color(1, 1, 1, 0.18)
	giris.set_border_width_all(1)
	t.set_stylebox("normal", "TextEdit", giris)
	var giris_odak := giris.duplicate()
	giris_odak.border_color = ACCENT
	t.set_stylebox("focus", "TextEdit", giris_odak)
	t.set_color("font_color", "TextEdit", TEXT)
	t.set_color("font_placeholder_color", "TextEdit", Color(MUTED, 0.7))
	_tema_yazilari(t)
	return t


## YAZI ÖLÇEĞİ — TEK YER: temadaki taban yazı boyutları ve tek tek
## kontrollere _boyut() ile verilen boyutlar Ayarlar.fs()'den geçer.
## Ayarlar → Yazı boyutu değişince _ayarlar_degisti() ikisini de tazeler.
const TEMA_YAZI := [
	["default", "", 17], ["font_size", "Button", 18], ["font_size", "CheckBox", 16],
	["normal_font_size", "RichTextLabel", 17], ["bold_font_size", "RichTextLabel", 17],
	["font_size", "TextEdit", 17],
]

func _tema_yazilari(t: Theme) -> void:
	for d in TEMA_YAZI:
		if d[0] == "default":
			t.default_font_size = Ayarlar.fs(d[2])
		else:
			t.set_font_size(d[0], d[1], Ayarlar.fs(d[2]))


## Bir kontrole yazı boyutu ver: taban (dp, %100'de) meta'da saklanır,
## ölçek değişince _yazilari_tazele() aynı tabanla yeniden uygular.
func _boyut(c: Control, ad: String, taban: int) -> void:
	c.set_meta("fs_" + ad, taban)
	c.add_theme_font_size_override(ad, Ayarlar.fs(taban))


func _yazilari_tazele(n: Node) -> void:
	if n is Control:
		for m in n.get_meta_list():
			if String(m).begins_with("fs_"):
				n.add_theme_font_size_override(String(m).trim_prefix("fs_"), Ayarlar.fs(n.get_meta(m)))
	for c in n.get_children():
		_yazilari_tazele(c)


func _ayarlar_degisti() -> void:
	_tema_yazilari(_tema_ref)
	_yazilari_tazele(self)   # ayarlar ve soru katmanlari da bu dugumun cocugu
	_olcek_yazisi()
	if _referans_cb:
		_referans_cb.set_pressed_no_signal(Ayarlar.referanssiz())
	_ekran_degisti()


# ------------------------------------------------------------- yardimcilar

func _panel(bg: Color = BG) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _kutu(bg, 12, 16, 14)
	sb.border_color = Color(1, 1, 1, 0.09)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	_paneller.append(sb)
	return p


func _label(text: String, size: int = 17, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	_boyut(l, "font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _sarmali(l: Control) -> Control:
	l.set("autowrap_mode", TextServer.AUTOWRAP_WORD_SMART)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Duzen kaplari tiklamayi yutmasin - ok araci sahneye tiklamayla calisiyor.
func _gecirgen(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _kaydirma() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true
	return s


func _dugme(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, DOKUN)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


# -------------------------------------------------------------------- kurulum

func _build_title() -> void:
	_ust = _gecirgen(VBoxContainer.new())
	_ust.add_theme_constant_override("separation", BOSLUK)
	_kok.add_child(_ust)

	var box := _gecirgen(VBoxContainer.new())
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_ust.add_child(box)
	_baslik_kutu = box

	_baslik = _sarmali(_label("ETKİ – TEPKİ:  Basketbol topu yere çarptığında", 26, ACCENT))
	_baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_baslik)

	_status = _sarmali(_label("Başlatmak için SPACE ya da Başlat", 17, MUTED))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	# Ust baslik ve durum yazisi gosterilmiyor (set_status yine calisir).
	box.visible = false


func _side_panel(i: int, title: String, subtitle: String, color: Color) -> Dictionary:
	var p := _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	# Baslik dokunulabilir: aciklamayi acar / kapatir (dar ekranda yer acar)
	var t := Button.new()
	t.text = title
	t.flat = true
	t.alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(0, SATIR)
	_boyut(t, "font_size", 19)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.add_theme_color_override(k, color)
	var ince := _kutu(Color(0, 0, 0, 0), 8, 4, 4)
	for k in ["normal", "pressed", "hover_pressed"]:
		t.add_theme_stylebox_override(k, ince)
	t.add_theme_stylebox_override("hover", _kutu(Color(1, 1, 1, 0.06), 8, 4, 4))
	t.tooltip_text = "Açıklamayı göster / gizle"
	t.pressed.connect(func():
		_aciklama_kullanici[i] = true
		_aciklama_goster(i, not _yan[i]["aciklama"].visible)
		_yerlestir())
	v.add_child(t)

	var s := _sarmali(_label(subtitle, 15, MUTED))
	v.add_child(s)

	v.add_child(HSeparator.new())

	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(0, 4 * 24)
	v.add_child(r)
	return {"panel": p, "baslik": t, "aciklama": s, "okuma": r}


func _aciklama_goster(i: int, goster: bool) -> void:
	_yan[i]["aciklama"].visible = goster
	_yan[i]["baslik"].icon = _ikon["asagi"] if goster else _ikon["sag"]


func _build_side_panels() -> void:
	_yan_satir = _gecirgen(BoxContainer.new())
	_yan_satir.add_theme_constant_override("separation", BOSLUK)
	_ust.add_child(_yan_satir)

	_yan.append(_side_panel(0,
		"SOL  —  çarpışma AÇIK",
		"Fizik motoru her şeyi kendi çözüyor: yerçekimi, hava sürtünmesi ve zeminle çarpışma. Gerçek davranış bu.",
		Color(0.45, 0.85, 1.0)))
	_yan.append(_side_panel(1,
		"SAĞ  —  çarpışma KAPALI",
		"Yerçekimi ve hava sürtünmesi hâlâ işliyor, ama zeminle çarpışma çözülmüyor. Tepki kuvvetini SEN seçeceksin.",
		Color(1.0, 0.72, 0.45)))
	_left_readout = _yan[0]["okuma"]
	_right_readout = _yan[1]["okuma"]

	_yan_satir.add_child(_yan[0]["panel"])
	_yan_satir.add_child(_gecirgen(Control.new()))   # aradaki bos alan (sahne)
	_yan_satir.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_yan_satir.add_child(_yan[1]["panel"])
	for i in 2:
		_yan[i]["panel"].size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_aciklama_goster(i, true)
	# Sol/sag top durum panelleri gosterilmiyor.
	_yan_satir.visible = false


func _build_controls() -> void:
	_alt = _gecirgen(BoxContainer.new())
	_alt.add_theme_constant_override("separation", BOSLUK)
	_kok.add_child(_alt)

	_kontrol_panel = _panel()
	_kontrol_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_kontrol_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_alt.add_child(_kontrol_panel)
	_alt_bosluk = _gecirgen(Control.new())
	_alt_bosluk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alt.add_child(_alt_bosluk)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_kontrol_panel.add_child(v)

	# --- her zaman gorunen dugme satiri
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_start_btn = _dugme("Başlat", func(): start_pressed.emit())
	row.add_child(_start_btn)
	var sifirla := _dugme("Sıfırla", func(): reset_pressed.emit())
	row.add_child(sifirla)
	_ayar_btn = _dugme("Ayarlar", func(): ayarlari_ac(true))
	_ayar_btn.tooltip_text = "Hız, kuvvet okları, ok aracı, arayüz ve yazı boyutu"
	row.add_child(_ayar_btn)
	_satir_dugmeleri = [_start_btn, sifirla, _ayar_btn]


## Tam ekran, alttakileri karartan ve fareyi YUTAN modal katman. Kendi
## CanvasLayer'inda; arkadaki her sey (sahne, ok araci, secim paneli) tik almaz.
func _modal_katman(katman: int) -> Array:
	var k := CanvasLayer.new()
	k.layer = katman
	k.visible = false
	add_child(k)
	var kok := Control.new()
	kok.set_anchors_preset(Control.PRESET_FULL_RECT)
	kok.mouse_filter = Control.MOUSE_FILTER_STOP
	kok.theme = _tema_ref
	k.add_child(kok)
	var karart := ColorRect.new()
	karart.color = Color(0, 0, 0, 0.55)
	karart.set_anchors_preset(Control.PRESET_FULL_RECT)
	karart.mouse_filter = Control.MOUSE_FILTER_STOP
	kok.add_child(karart)
	var p := _panel(Color(0.09, 0.10, 0.14, 0.98))
	kok.add_child(p)
	return [k, karart, p]


func _build_settings() -> void:
	var m := _modal_katman(AYAR_KATMANI)
	_ayar_katman = m[0]
	_ayar_panel = m[2]
	# karartilmis alana dokunmak pencereyi kapatir
	(m[1] as ColorRect).gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			ayarlari_ac(false))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_ayar_panel.add_child(v)

	var ust := HBoxContainer.new()
	ust.add_theme_constant_override("separation", 8)
	v.add_child(ust)
	var baslik := _label("Ayarlar", 22, ACCENT)
	baslik.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	baslik.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ust.add_child(baslik)
	var kapat := _dugme("Kapat", func(): ayarlari_ac(false))
	kapat.size_flags_horizontal = Control.SIZE_SHRINK_END
	kapat.custom_minimum_size = Vector2(DOKUN * 2.0, DOKUN)
	ust.add_child(kapat)
	_ayar_baslik = ust

	_ayar_kaydir = _kaydirma()
	v.add_child(_ayar_kaydir)
	_ayar_icerik = VBoxContainer.new()
	_ayar_icerik.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ayar_icerik.add_theme_constant_override("separation", 4)
	_ayar_kaydir.add_child(_ayar_icerik)

	var hiz_satir := HBoxContainer.new()
	var hiz_lbl := _label("Simülasyon hızı", 15, MUTED)
	hiz_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hiz_satir.add_child(hiz_lbl)
	_hiz_deger = _label("1.00×", 16, TEXT)
	hiz_satir.add_child(_hiz_deger)
	_ayar_icerik.add_child(hiz_satir)

	var slider := HSlider.new()
	slider.min_value = 0.05
	slider.max_value = 1.5
	slider.step = 0.05
	slider.value = 1.0
	slider.custom_minimum_size = Vector2(0, SATIR)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(val: float):
		_hiz_deger.text = "%.2f×" % val
		speed_changed.emit(val))
	_ayar_icerik.add_child(slider)

	_ayar_icerik.add_child(HSeparator.new())
	_ayar_icerik.add_child(_label("Gösterilecek kuvvet okları", 15, MUTED))

	_ok_izgara = GridContainer.new()
	_ok_izgara.columns = 2
	_ok_izgara.add_theme_constant_override("h_separation", 8)
	_ok_izgara.add_theme_constant_override("v_separation", 0)
	_ayar_icerik.add_child(_ok_izgara)
	for def in ARROW_DEFS:
		var cb := _onay(def[1], def[3])
		for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
			cb.add_theme_color_override(k, def[2])
		var key: String = def[0]
		cb.toggled.connect(func(on: bool): arrow_toggled.emit(key, on))
		_ok_izgara.add_child(cb)

	_ayar_icerik.add_child(HSeparator.new())
	var tool_cb := _onay("Ok aracı (sürükle-bırak)", false)
	tool_cb.toggled.connect(func(on: bool): tool_toggled.emit(on))
	_ayar_icerik.add_child(tool_cb)

	# Referanssiz mod: ogrenci surumunde (student_build) zorla acik, gizli
	_referans_cb = _onay("Referanssız mod (doğru simülasyonu gösterme)", Ayarlar.referanssiz())
	_referans_cb.tooltip_text = "Soldaki gerçek fizik simülasyonu gizlenir; öğrenci yalnızca seçeneklerden birini seçer. Değişince simülasyon sıfırlanır."
	_referans_cb.toggled.connect(func(on: bool):
		Ayarlar.referanssiz_ayarla(on)
		referanssiz_degisti.emit(on))
	_referans_cb.visible = not Ayarlar.referanssiz_zorunlu()
	_ayar_icerik.add_child(_referans_cb)

	_ayar_icerik.add_child(HSeparator.new())
	_olcek_deger = _adim_satiri("Arayüz boyutu", "Arayüzü", Ayarlar.arayuz_olcek_adim)
	_yazi_deger = _adim_satiri("Yazı boyutu", "Yazıları", Ayarlar.yazi_olcek_adim)
	_olcek_yazisi()

	_gelistirici_izgara = GridContainer.new()
	_gelistirici_izgara.columns = 2
	_gelistirici_izgara.add_theme_constant_override("h_separation", 8)
	_gelistirici_izgara.add_theme_constant_override("v_separation", 0)


func _onay(text: String, acik: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = acik
	cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cb.custom_minimum_size = Vector2(0, SATIR)
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cb


## "Ad   A−  %100  A+" satiri; deger etiketini dondurur.
func _adim_satiri(ad: String, ipucu: String, adim: Callable) -> Label:
	var satir := HBoxContainer.new()
	satir.add_theme_constant_override("separation", 8)
	var lbl := _label(ad, 15, MUTED)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	satir.add_child(lbl)
	var kucult := _dugme("A−", func(): adim.call(-1))
	kucult.size_flags_horizontal = Control.SIZE_FILL
	kucult.custom_minimum_size = Vector2(DOKUN + 8, DOKUN)
	kucult.tooltip_text = ipucu + " küçült"
	satir.add_child(kucult)
	var deger := _label("", 16, TEXT)
	deger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deger.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deger.custom_minimum_size = Vector2(56, 0)
	satir.add_child(deger)
	var buyut := _dugme("A+", func(): adim.call(1))
	buyut.size_flags_horizontal = Control.SIZE_FILL
	buyut.custom_minimum_size = Vector2(DOKUN + 8, DOKUN)
	buyut.tooltip_text = ipucu + " büyüt"
	satir.add_child(buyut)
	_ayar_icerik.add_child(satir)
	return deger


## Ayarlar → "Geliştirici" bolumu: PerformansDenetimi'nin anahtarlari.
func gelistirici_kur(perf: PerformansDenetimi) -> void:
	_ayar_icerik.add_child(HSeparator.new())
	_ayar_icerik.add_child(_label("Geliştirici — performans testi (kaydedilmez)", 15, MUTED))
	_ayar_icerik.add_child(_gelistirici_izgara)
	for d in PerformansDenetimi.ANAHTARLAR:
		var anahtar: String = d[0]
		var cb := _onay(d[1], bool(perf.get(anahtar)))
		_boyut(cb, "font_size", 14)
		cb.toggled.connect(func(on: bool): perf.set(anahtar, on))
		_gelistirici_izgara.add_child(cb)
	_yerlestir()


func ayarlari_ac(acik: bool) -> void:
	_ayar_katman.visible = acik
	if acik:
		_yerlestir()


func _build_choice_panel() -> void:
	_choice_panel = _panel(Color(0.09, 0.10, 0.14, 0.97))
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choice_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_choice_panel.visible = false
	_kok.add_child(_choice_panel)

	_secim_kaydir = _kaydirma()
	_choice_panel.add_child(_secim_kaydir)
	_secim_icerik = VBoxContainer.new()
	_secim_icerik.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_secim_icerik.add_theme_constant_override("separation", 12)
	_secim_kaydir.add_child(_secim_icerik)

	_secim_baslik = _sarmali(_label(Ayarlar.metin("secim_basligi"), 22, ACCENT))
	_secim_icerik.add_child(_secim_baslik)

	_secim_ipucu = _sarmali(_label(Ayarlar.metin("secim_ipucu"), 16, MUTED))
	_secim_icerik.add_child(_secim_ipucu)

	# Secenekler config/secenekler.tres'ten (Ayarlar.secenek_listesi); kac
	# tane olursa olsun alt alta, kaydirilabilir alanda.
	for opt in Ayarlar.secenek_listesi():
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, DOKUN)
		b.text = "%s   %s" % [opt.get("harf", ""), opt.get("metin", "")]
		_boyut(b, "font_size", 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = opt.get("id", "")
		b.pressed.connect(func(): choice_made.emit(key))
		_secim_icerik.add_child(b)
		_secim_dugmeleri.append(b)


func _build_feedback() -> void:
	var p := _panel(Color(0.09, 0.10, 0.14, 0.93))
	p.visible = false
	_kok.add_child(p)

	_geri_kaydir = _kaydirma()
	p.add_child(_geri_kaydir)
	_feedback = RichTextLabel.new()
	_feedback.bbcode_enabled = true
	_feedback.fit_content = true
	_feedback.scroll_active = false
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_geri_kaydir.add_child(_feedback)
	_feedback_panel = p


func _build_question() -> void:
	var m := _modal_katman(SORU_KATMANI)
	_soru_katman = m[0]
	_soru_panel = m[2]

	var kaydir := _kaydirma()
	_soru_panel.add_child(kaydir)
	_soru_icerik = VBoxContainer.new()
	_soru_icerik.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_soru_icerik.add_theme_constant_override("separation", 12)
	kaydir.add_child(_soru_icerik)

	_soru_icerik.add_child(_label(Ayarlar.metin("soru_basligi", "Soru"), 22, ACCENT))
	_soru_secenek = _sarmali(_label("", 15, MUTED))
	_soru_icerik.add_child(_soru_secenek)
	_soru_metin = _sarmali(_label("", 19, TEXT))
	_soru_icerik.add_child(_soru_metin)

	_soru_giris = TextEdit.new()
	_soru_giris.placeholder_text = "Cevabını buraya yaz…"
	_soru_giris.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_soru_giris.custom_minimum_size = Vector2(0, 120)
	_soru_giris.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_soru_icerik.add_child(_soru_giris)

	var satir := HBoxContainer.new()
	satir.add_theme_constant_override("separation", 8)
	_soru_icerik.add_child(satir)
	_soru_gec = _dugme("Geç", func(): _soru_kapat(false))
	satir.add_child(_soru_gec)
	_soru_kaydet = _dugme("Kaydet", func(): _soru_kapat(true))
	satir.add_child(_soru_kaydet)
	_satir_dugmeleri.append_array([_soru_gec, _soru_kaydet])


func _soru_kapat(kaydet: bool) -> void:
	var cevap := _soru_giris.text.strip_edges() if _soru_giris.visible else ""
	_soru_katman.visible = false
	soru_kapandi.emit(cevap, kaydet and cevap != "")


# ------------------------------------------------------------ duyarli yerlesim

func _ekran_degisti() -> void:
	_olcek_uygula()
	_yerlestir()


func _tasi(c: Control, hedef: Container, sira: int) -> void:
	if c.get_parent() != hedef:
		c.get_parent().remove_child(c)
		hedef.add_child(c)
	hedef.move_child(c, sira)


## Ekranin dp boyutuna gore modu secer, genislik ve yazi boyutlarini verir.
## Sarilan yazilarin yuksekligi ancak bir kare sonra belli oldugu icin
## yukseklik sinirlari _sinirla()'da verilir.
func _yerlestir() -> void:
	if not is_inside_tree():
		return
	var v := _kok.get_viewport_rect().size
	var w := v.x
	var h := v.y
	if w < 760.0 and w < h * 0.9:
		_mod = Mod.DIKEY
	elif h < 620.0 or w < 1000.0:
		_mod = Mod.SIKISIK
	else:
		_mod = Mod.GENIS
	var genis := _mod == Mod.GENIS
	var dikey := _mod == Mod.DIKEY

	# yazi boyutlari ve ic bosluklar: dar ekranda bir kademe kucuk (>= 14 dp)
	# (taban boyutlar; yazi olcegi _boyut -> Ayarlar.fs icinde uygulanir)
	var govde := 17 if genis else 15
	_boyut(_baslik, "font_size", 26 if genis else 20)
	_boyut(_status, "font_size", 17 if genis else 15)
	for y in _yan:
		_boyut(y["okuma"], "normal_font_size", govde)
		_boyut(y["okuma"], "bold_font_size", govde)
		y["okuma"].custom_minimum_size.y = 4 * (Ayarlar.fs(govde) + 6)
		_boyut(y["baslik"], "font_size", 19 if genis else 15)
	_boyut(_feedback, "normal_font_size", govde)
	_boyut(_feedback, "bold_font_size", govde)
	var ic := 16.0 if genis else 12.0
	for sb: StyleBoxFlat in _paneller:
		sb.content_margin_left = ic
		sb.content_margin_right = ic
		sb.content_margin_top = ic - 2.0
		sb.content_margin_bottom = ic - 2.0
	for b: Button in _satir_dugmeleri:
		_boyut(b, "font_size", 18 if genis else 16)
		var sb := _kutu(Color(0, 0, 0, 0), 10, 16.0 if genis else 10.0, 10)
		b.add_theme_constant_override("h_separation", 10 if genis else 6)
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var o: StyleBoxFlat = _kok.theme.get_stylebox(k, "Button").duplicate()
			o.content_margin_left = sb.content_margin_left
			o.content_margin_right = sb.content_margin_right
			b.add_theme_stylebox_override(k, o)
	_boyut(_secim_baslik, "font_size", 22 if genis else 18)
	_boyut(_secim_ipucu, "font_size", 16 if genis else 14)
	_secim_icerik.add_theme_constant_override("separation", 12 if genis else 8)
	for b: Button in _secim_dugmeleri:
		_boyut(b, "font_size", 17 if genis else 15)
		# yazi sarilinca dugme kendiliginden uzar; en az dokunma hedefi kadar
		b.custom_minimum_size.y = maxf(DOKUN, (60.0 if genis else 52.0) * minf(Ayarlar.yazi_olcek, 1.0))

	# ust: baslik (+ dikey olmayan modda iki yan panel)
	_ust.position = Vector2(KENAR, KENAR * (0.75 if genis else 0.5))
	_ust.size = Vector2(w - 2.0 * KENAR, 0)
	var yan_w := YAN_GEN if genis else YAN_GEN_SIKISIK
	for i in 2:
		var p: PanelContainer = _yan[i]["panel"]
		p.custom_minimum_size.x = 0.0 if dikey else yan_w
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL if dikey else Control.SIZE_FILL
		if not _aciklama_kullanici[i]:
			_aciklama_goster(i, genis)
	_yan_satir.get_child(1).visible = not dikey

	# alt: dikeyde [yan paneller, kontrol] ust uste; yatayda yalniz kontrol
	# Kontrol paneli soldaki topun sutununa tasmasin (top ortadan ~0.41h
	# uzakta); yer varsa 2 sutun onay kutusu ile daha kisa olur.
	var kontrol_w := yan_w
	if dikey:
		kontrol_w = w - 2.0 * KENAR
	elif genis and w * 0.5 - 0.41 * h - KENAR >= 400.0:
		kontrol_w = KONTROL_GEN
	_kontrol_panel.custom_minimum_size.x = kontrol_w
	if dikey:
		_tasi(_yan_satir, _alt, 0)
	else:
		_tasi(_yan_satir, _ust, 1)
	_alt.vertical = dikey
	_alt_bosluk.visible = not dikey
	_alt.move_child(_kontrol_panel, -1 if dikey else 0)

	# geri bildirim: genis ekranda sag altta (kontrolun yaninda). Dar
	# ekranda ustte: secimden sonra toplar zeminde / alcakta, ust kisim
	# (baslik + birakilma yuksekligi) o an en az gerekli alan.
	var kontrol_gercek := maxf(kontrol_w, _kontrol_panel.get_combined_minimum_size().x)
	var geri_yan_w := w - 2.0 * KENAR - kontrol_gercek - BOSLUK
	_geri_ustte = not genis or geri_yan_w < 320.0
	_feedback_panel.custom_minimum_size.x = w - 2.0 * KENAR if _geri_ustte else minf(GERI_GEN, geri_yan_w)

	# secim paneli: ortada, ekrana sigar
	var secim_w := minf(SECIM_GEN, w - 2.0 * KENAR)
	_secim_icerik.custom_minimum_size.x = secim_w - 2.0 * ic

	# modal pencereler: ortada, ekrana sigar
	var ayar_w := minf(AYAR_GEN, w - 2.0 * KENAR)
	_ayar_icerik.custom_minimum_size.x = ayar_w - 2.0 * ic - 12.0   # kaydirma cubugu payi
	_ayar_baslik.custom_minimum_size.x = _ayar_icerik.custom_minimum_size.x
	var iki_sutun := _ayar_icerik.custom_minimum_size.x >= 400.0 * minf(Ayarlar.yazi_olcek, 1.0)
	_ok_izgara.columns = 2 if iki_sutun else 1
	_gelistirici_izgara.columns = 2 if iki_sutun else 1
	_soru_icerik.custom_minimum_size.x = minf(SORU_GEN, w - 2.0 * KENAR) - 2.0 * ic - 12.0
	_soru_giris.custom_minimum_size.y = clampf(h * 0.22, 72.0, 160.0)

	_yerlesim_sayac += 1
	var sayac := _yerlesim_sayac
	await get_tree().process_frame
	if sayac != _yerlesim_sayac:
		return   # bu arada yeni bir yerlesim istendi
	_sinirla(w, h)
	await get_tree().process_frame
	if sayac != _yerlesim_sayac:
		return
	_sinirla(w, h)   # ikinci tur: ilk turda degisen genisliklere gore yukseklikler
	_sahne_payini_bildir(w, h, yan_w)


## Sarilan yazilar artik olculmus durumda: kaydirma alanlarina yukseklik ver.
func _sinirla(w: float, h: float) -> void:
	var ic := 16.0 if _mod == Mod.GENIS else 12.0

	# Ayarlar penceresi (modal): icerik sigmazsa kaydirilir
	var ayar_max := h - 2.0 * KENAR - 2.0 * ic - _ayar_baslik.get_combined_minimum_size().y - 10.0
	_ayar_kaydir.custom_minimum_size = Vector2(
		_ayar_icerik.custom_minimum_size.x,
		clampf(_ayar_icerik.get_combined_minimum_size().y, 0.0, maxf(ayar_max, 80.0)))
	_ayar_panel.reset_size()
	_ayar_panel.position = ((Vector2(w, h) - _ayar_panel.size) * 0.5).max(Vector2.ZERO)

	# Soru penceresi (modal)
	var soru_kaydir := _soru_icerik.get_parent() as ScrollContainer
	soru_kaydir.custom_minimum_size = Vector2(
		_soru_icerik.custom_minimum_size.x,
		minf(_soru_icerik.get_combined_minimum_size().y, maxf(h - 2.0 * KENAR - 2.0 * ic, 80.0)))
	_soru_panel.reset_size()
	_soru_panel.position = ((Vector2(w, h) - _soru_panel.size) * 0.5).max(Vector2.ZERO)

	_alt.reset_size()
	_alt.size.x = w - 2.0 * KENAR
	_alt.position = Vector2(KENAR, h - KENAR - _alt.get_combined_minimum_size().y)

	# Geri bildirim
	var geri_max := h * (0.36 if _mod == Mod.DIKEY else 0.4)
	_geri_kaydir.custom_minimum_size.y = minf(_feedback.get_combined_minimum_size().y, maxf(geri_max, 96.0))
	_feedback_panel.reset_size()
	if _geri_ustte:
		_feedback_panel.position = Vector2(KENAR, KENAR * 0.5)
	else:
		_feedback_panel.position = Vector2(w - KENAR, h - KENAR) - _feedback_panel.size

	# Secim paneli
	var secim_max := h - 2.0 * KENAR - 2.0 * ic
	_secim_kaydir.custom_minimum_size = Vector2(
		_secim_icerik.custom_minimum_size.x,
		minf(_secim_icerik.get_combined_minimum_size().y, secim_max))
	_choice_panel.reset_size()
	_choice_panel.position = (Vector2(w, h) - _choice_panel.size) * 0.5


func _sahne_payini_bildir(w: float, h: float, yan_w: float) -> void:
	var serbest := _baslik_kutu.get_global_rect().end.y if _baslik_kutu.visible else KENAR
	var ust := (serbest + 4.0) / h if _baslik_kutu.visible else 0.0
	if _feedback_panel.visible and _geri_ustte:
		serbest = maxf(serbest, _feedback_panel.get_global_rect().end.y)
	ust_serbest_degisti.emit(serbest + 8.0)
	if not _yan_satir.visible:
		# yalniz alttaki kontrol cubugu kalir; dikeyde tam genislik
		var alt0 := (h - _alt.get_global_rect().position.y + 4.0) / h if _mod == Mod.DIKEY else 0.0
		sahne_payi_degisti.emit(0.0, 0.0, ust, alt0)
	elif _mod == Mod.DIKEY:
		var alt := (h - _yan_satir.get_global_rect().position.y + 4.0) / h
		sahne_payi_degisti.emit(KENAR / w, KENAR / w, ust, alt)
	else:
		var yan := (KENAR + yan_w + BOSLUK) / w
		sahne_payi_degisti.emit(yan, yan, ust, 0.0)


# -------------------------------------------------------------- arayuz olcegi

func _olcek_yazisi() -> void:
	_olcek_deger.text = "%d%%" % roundi(Ayarlar.arayuz_olcek * 100.0)
	_yazi_deger.text = "%d%%" % roundi(Ayarlar.yazi_olcek * 100.0)


# ----------------------------------------------------------------- disa acik

func set_status(text: String) -> void:
	_status.text = text

func set_start_text(text: String) -> void:
	_start_btn.text = text

func set_readout(side: String, bbcode: String) -> void:
	# dar panelde satir kayarsa "0.00 N" ikiye bolunmesin: deger-birim ve
	# etiket-deger arasina bolunmez bosluk
	bbcode = bbcode.replace(" N", "\u00a0N").replace(" m", "\u00a0m").replace("[/color] ", "[/color]\u00a0")
	# Ayni metni yeniden atamak da BBCode'u bastan ayristirir ve yerlesimi
	# kirletir (duran topta her karede oluyordu).
	var r := _left_readout if side == "left" else _right_readout
	if r.text != bbcode:
		r.text = bbcode

func show_choice(show_it: bool) -> void:
	_choice_panel.visible = show_it
	if show_it:
		_yerlestir()

## Ayarlar ya da soru penceresi acik mi? (main.gd klavye kisayollarini yutar)
func modal_acik() -> bool:
	return _ayar_katman.visible or _soru_katman.visible


## Referanssiz mod: soldaki (dogru fizik) panel ve secim ipucu.
func referans_goster(goster: bool) -> void:
	_yan[0]["panel"].visible = goster
	_secim_ipucu.text = Ayarlar.metin("secim_ipucu" if goster else "secim_ipucu_referanssiz")
	_yerlestir()


## Kosu sonu sorusu. metin_girisi false: soru yalnizca gosterilir (sozlu cevap).
func soru_goster(secenek_metni: String, soru: String, metin_girisi: bool) -> void:
	_soru_secenek.text = secenek_metni
	_soru_metin.text = soru
	_soru_giris.text = ""
	_soru_giris.visible = metin_girisi
	_soru_gec.visible = metin_girisi
	_soru_kaydet.text = "Kaydet" if metin_girisi else "Tamam"
	_soru_katman.visible = true
	_yerlestir()
	if metin_girisi:
		_soru_giris.grab_focus.call_deferred()


func soru_kapat() -> void:
	_soru_katman.visible = false


func show_feedback(bbcode: String) -> void:
	_feedback.text = bbcode
	_feedback_panel.visible = bbcode != ""
	_yerlestir()
