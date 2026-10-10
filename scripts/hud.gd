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

const BG := Color(0.07, 0.08, 0.11, 0.88)
const ACCENT := Color(1.0, 0.65, 0.2)
const TEXT := Color(0.92, 0.93, 0.96)
const MUTED := Color(0.62, 0.66, 0.74)

# ---------------------------------------------------- boyut belirtecleri (dp)
const KENAR := 16.0          # ekran kenar boslugu
const BOSLUK := 12.0         # paneller arasi
const DOKUN := 48.0          # dugme yuksekligi (Material 48 dp)
const SATIR := 44.0          # onay kutusu / kaydirici satiri (Apple 44 pt)
const YAN_GEN := 340.0       # yan panel genisligi (genis yerlesim)
const KONTROL_GEN := 440.0   # kontrol paneli: 2 sutun onay kutusu sigar
const SECIM_GEN := 680.0     # secim paneli azami genislik
const GERI_GEN := 820.0      # geri bildirim azami genislik
const TOP_SUTUNU := 0.41     # top merkezi ortadan 0.373h; +yaricap ve pay

## Ekranin kisa kenari dp cinsinden bu araliga sikistirilir: en dar telefon
## 360 dp; buyuk ekranda (projektor, 4K) arayuz 900 dp'den kucuk kalmaz.
const KISA_KENAR_MIN := 360.0
const KISA_KENAR_MAX := 900.0

const AYAR_DOSYASI := "user://arayuz.cfg"
const OLCEK_ADIMLARI := [0.8, 0.9, 1.0, 1.1, 1.25, 1.4, 1.6]

enum Mod { GENIS, SIKISIK, DIKEY }

const ARROW_DEFS := [
	["gravity", "Yerçekimi  G", Color(0.94, 0.35, 0.35), true],
	["drag", "Hava sürtünmesi  Fs", Color(0.42, 0.72, 1.00), true],
	["contact", "Zemin tepkisi  N", Color(0.40, 0.90, 0.55), true],
	["external", "Uygulanan kuvvet  F", Color(0.85, 0.55, 1.00), true],
	["net", "Net kuvvet  Fnet", Color(1.00, 0.85, 0.25), true],
	["net_minus_g", "Fnet − G", Color(1.00, 0.55, 0.15), false],
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
var _secim_kaydir: ScrollContainer
var _secim_icerik: VBoxContainer
var _geri_kaydir: ScrollContainer

var _mod := Mod.GENIS
var _kullanici_olcek := 1.0
var _ayar_acik := true
var _ayar_kullanici := false          # kullanici Ayarlar'a dokunduysa otomatik karar verme
var _aciklama_kullanici := [false, false]
var _ayar_icerik_h := 0.0
var _yerlesim_sayac := 0
var _ikon := {}


func _ready() -> void:
	_ayar_oku()
	_ikonlari_hazirla()
	_kok = Control.new()
	_kok.set_anchors_preset(Control.PRESET_FULL_RECT)
	_kok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kok.theme = _tema()
	add_child(_kok)

	_build_title()
	_build_side_panels()
	_build_controls()
	_build_choice_panel()
	_build_feedback()

	get_tree().root.size_changed.connect(_ekran_degisti)
	_ekran_degisti()


# ------------------------------------------------------------- olcek / tema

func _olcek_uygula() -> void:
	var win := get_tree().root
	var px := Vector2(win.size)
	if px.x < 1.0 or px.y < 1.0:
		return
	var kisa := minf(px.x, px.y)
	# 1 dp'ye dusen fiziksel piksel
	var px_dp := maxf(_dpi() / _dpi_ref(), kisa / KISA_KENAR_MAX) * _kullanici_olcek
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
	t.default_font_size = 17

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
	t.set_font_size("font_size", "Button", 18)
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
	t.set_font_size("font_size", "CheckBox", 16)
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

	t.set_font_size("normal_font_size", "RichTextLabel", 17)
	t.set_font_size("bold_font_size", "RichTextLabel", 17)
	t.set_constant("line_separation", "RichTextLabel", 3)
	t.set_color("default_color", "RichTextLabel", TEXT)
	return t


# ------------------------------------------------------------- yardimcilar

func _panel(bg: Color = BG) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _kutu(bg, 12, 16, 14)
	sb.border_color = Color(1, 1, 1, 0.09)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int = 17, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
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
	_ust.add_child(box)

	_baslik = _sarmali(_label("ETKİ – TEPKİ:  Basketbol topu yere çarptığında", 26, ACCENT))
	_baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_baslik)

	_status = _sarmali(_label("Başlatmak için SPACE ya da Başlat", 17, MUTED))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


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
	t.add_theme_font_size_override("font_size", 19)
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

	# --- ayarlar (dugme satirinin USTUNDE acilir, panel yukari buyur)
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
		var cb := CheckBox.new()
		cb.text = def[1]
		cb.button_pressed = def[3]
		cb.custom_minimum_size = Vector2(0, SATIR)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
			cb.add_theme_color_override(k, def[2])
		var key: String = def[0]
		cb.toggled.connect(func(on: bool): arrow_toggled.emit(key, on))
		_ok_izgara.add_child(cb)

	_ayar_icerik.add_child(HSeparator.new())
	var tool_cb := CheckBox.new()
	tool_cb.text = "Ok aracı (sürükle-bırak)"
	tool_cb.custom_minimum_size = Vector2(0, SATIR)
	tool_cb.toggled.connect(func(on: bool): tool_toggled.emit(on))
	_ayar_icerik.add_child(tool_cb)

	_ayar_icerik.add_child(HSeparator.new())
	var olcek_satir := HBoxContainer.new()
	olcek_satir.add_theme_constant_override("separation", 8)
	var olcek_lbl := _label("Arayüz boyutu", 15, MUTED)
	olcek_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	olcek_satir.add_child(olcek_lbl)
	var kucult := _dugme("A−", func(): _olcek_degistir(-1))
	kucult.size_flags_horizontal = Control.SIZE_FILL
	kucult.custom_minimum_size = Vector2(DOKUN + 8, DOKUN)
	kucult.tooltip_text = "Arayüzü küçült"
	olcek_satir.add_child(kucult)
	_olcek_deger = _label("", 16, TEXT)
	_olcek_deger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_olcek_deger.custom_minimum_size = Vector2(56, 0)
	_olcek_deger.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	olcek_satir.add_child(_olcek_deger)
	var buyut := _dugme("A+", func(): _olcek_degistir(1))
	buyut.size_flags_horizontal = Control.SIZE_FILL
	buyut.custom_minimum_size = Vector2(DOKUN + 8, DOKUN)
	buyut.tooltip_text = "Arayüzü büyüt"
	olcek_satir.add_child(buyut)
	_ayar_icerik.add_child(olcek_satir)
	_olcek_yazisi()

	# --- her zaman gorunen dugme satiri
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_start_btn = _dugme("Başlat", func(): start_pressed.emit())
	row.add_child(_start_btn)
	row.add_child(_dugme("Sıfırla", func(): reset_pressed.emit()))
	_ayar_btn = _dugme("Ayarlar", func():
		_ayar_kullanici = true
		_ayar_ac(not _ayar_acik)
		_yerlestir())
	_ayar_btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ayar_btn.tooltip_text = "Hız, kuvvet okları, ok aracı, arayüz boyutu"
	row.add_child(_ayar_btn)
	_ayar_ac(true)


func _ayar_ac(acik: bool) -> void:
	_ayar_acik = acik
	_ayar_kaydir.visible = acik
	_ayar_btn.icon = _ikon["asagi"] if acik else _ikon["yukari"]


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

	var t := _sarmali(_label("Top tam zemine değdi. Zemin topa hangi kuvveti uygular?", 22, ACCENT))
	_secim_icerik.add_child(t)

	var hint := _sarmali(_label("Sol taraf gerçek fiziği gösteriyor. Sağdaki top için sen karar ver.", 16, MUTED))
	_secim_icerik.add_child(hint)

	var options := [
		["a", "a)   Yukarı yönlü F kadar kuvvet", "Topun momentumunu tersine çevirecek kadar tepki kuvveti."],
		["b", "b)   Yukarı yönlü 100·F kadar kuvvet", "Zemin çok daha büyük bir kuvvetle iter."],
		["c", "c)   Hem yukarı hem aşağı F  →  top durur", "Etki ve tepki topun üzerinde birbirini götürür."],
	]
	for opt in options:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 72)
		b.text = "%s\n%s" % [opt[1], opt[2]]
		b.add_theme_font_size_override("font_size", 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = opt[0]
		b.pressed.connect(func(): choice_made.emit(key))
		_secim_icerik.add_child(b)


func _build_feedback() -> void:
	var p := _panel(Color(0.09, 0.10, 0.14, 0.93))
	p.size_flags_vertical = Control.SIZE_SHRINK_END
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	p.visible = false
	_alt.add_child(p)

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


# ------------------------------------------------------------ duyarli yerlesim

func _ekran_degisti() -> void:
	_olcek_uygula()
	_yerlestir()


## Ekranin dp boyutuna gore modu secer, genislikleri verir; bir kare
## bekleyip (sarilan yazilarin yuksekligi ancak o zaman belli) kaydirma
## alanlarinin yuksekligini sinirlar.
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

	# yazi boyutlari: dar ekranda bir kademe kucuk (yine de >= 14 dp)
	_baslik.add_theme_font_size_override("font_size", 26 if genis else 20)
	_status.add_theme_font_size_override("font_size", 17 if genis else 15)
	for y in _yan:
		y["okuma"].add_theme_font_size_override("normal_font_size", 17 if genis else 15)
		y["okuma"].add_theme_font_size_override("bold_font_size", 17 if genis else 15)
		y["okuma"].custom_minimum_size.y = 4 * (24 if genis else 21)
		y["baslik"].add_theme_font_size_override("font_size", 19 if genis else 17)
	_feedback.add_theme_font_size_override("normal_font_size", 17 if genis else 15)
	_feedback.add_theme_font_size_override("bold_font_size", 17 if genis else 15)

	# ust: baslik + iki yan panel
	_ust.position = Vector2(KENAR, KENAR * (0.75 if genis else 0.5))
	_ust.size = Vector2(w - 2.0 * KENAR, 0)
	# Toplar ekran ortasindan +-0.373*h uzakta duser (kamera 16:9, KEEP_HEIGHT;
	# yaricap ~0.03h). Sol/sag paneller bu sutunlara tasmasin, yoksa
	# birakilma anindaki top panelin arkasinda kalir.
	var sutun_w := w * 0.5 - TOP_SUTUNU * h - KENAR
	var yan_w := clampf(sutun_w, 220.0, YAN_GEN)
	for i in 2:
		var p: PanelContainer = _yan[i]["panel"]
		p.custom_minimum_size.x = 0.0 if dikey else yan_w
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL if dikey else Control.SIZE_FILL
		if not _aciklama_kullanici[i]:
			_aciklama_goster(i, genis)
	_yan_satir.get_child(1).visible = not dikey

	# alt: kontrol paneli + geri bildirim
	var kontrol_w := w - 2.0 * KENAR if dikey else clampf(sutun_w, 320.0, KONTROL_GEN)
	_kontrol_panel.custom_minimum_size.x = kontrol_w
	_ok_izgara.columns = 2 if kontrol_w >= 400.0 else 1
	var geri_yan_w := w - 2.0 * KENAR - kontrol_w - BOSLUK
	var geri_ustte := geri_yan_w < 320.0
	_alt.vertical = geri_ustte
	_alt_bosluk.visible = not geri_ustte
	if geri_ustte:
		_alt.move_child(_feedback_panel, 0)
		_feedback_panel.custom_minimum_size.x = w - 2.0 * KENAR
	else:
		_alt.move_child(_feedback_panel, -1)
		_feedback_panel.custom_minimum_size.x = minf(GERI_GEN, geri_yan_w)

	# secim paneli: ortada, ekrana sigar
	var secim_w := minf(SECIM_GEN, w - 2.0 * KENAR)
	_secim_icerik.custom_minimum_size.x = secim_w - 32.0

	_yerlesim_sayac += 1
	var sayac := _yerlesim_sayac
	await get_tree().process_frame
	if sayac != _yerlesim_sayac:
		return   # bu arada yeni bir yerlesim istendi
	_sinirla(w, h)


## Sarilan yazilar artik olculmus durumda: kaydirma alanlarina yukseklik ver.
func _sinirla(w: float, h: float) -> void:
	var ust_alt := _ust.position.y + _ust.get_combined_minimum_size().y
	var satir_h := DOKUN + 2.0 * 14.0 + 2.0   # dugme satiri + panel ic boslugu

	# Ayarlar: sigiyorsa (genis ekranda) kendiliginden acik kalir
	if _ayar_acik:
		_ayar_icerik_h = _ayar_icerik.get_combined_minimum_size().y
	if not _ayar_kullanici:
		var bos_h := h - KENAR - ust_alt - BOSLUK - satir_h - 10.0
		var ac := _mod == Mod.GENIS and _ayar_icerik_h <= bos_h
		# Sigmiyorsa: aciklamalari katlayinca sigiyor mu? (ayarlar daha cok is gorur)
		if _mod == Mod.GENIS and not ac and not (_aciklama_kullanici[0] or _aciklama_kullanici[1]):
			var acik_h := 0.0
			for y in _yan:
				if y["aciklama"].visible:
					acik_h = maxf(acik_h, y["aciklama"].size.y + 6.0)
			if acik_h > 0.0 and _ayar_icerik_h <= bos_h + acik_h:
				for i in 2:
					_aciklama_goster(i, false)
				ac = true
		if ac != _ayar_acik:
			_ayar_ac(ac)
			if ac:
				_ayar_icerik_h = _ayar_icerik.get_combined_minimum_size().y
	# Kullanici actiysa ust panellerin uzerine tasabilir (gecici katman)
	var ayar_max := h - 2.0 * KENAR - satir_h - 10.0 - 40.0
	_ayar_kaydir.custom_minimum_size.y = clampf(_ayar_icerik_h, 0.0, maxf(ayar_max, 120.0))

	# Geri bildirim
	var kontrol_h := _kontrol_panel.get_combined_minimum_size().y
	var geri_max: float
	if _alt.vertical:
		geri_max = h - KENAR - kontrol_h - BOSLUK - ust_alt - BOSLUK - 28.0
	else:
		# yatay telefonda sag paneli gecici olarak ortebilir: aciklama o an onemli
		geri_max = h * (0.4 if _mod == Mod.GENIS else 0.62)
	geri_max = maxf(geri_max, 96.0)
	_geri_kaydir.custom_minimum_size.y = minf(_feedback.get_combined_minimum_size().y, geri_max)

	_alt.size = Vector2(w - 2.0 * KENAR, 0)
	_alt.reset_size()
	_alt.size.x = w - 2.0 * KENAR
	_alt.position = Vector2(KENAR, h - KENAR - _alt.get_combined_minimum_size().y)

	# Secim paneli
	var secim_max := h - 2.0 * KENAR - 28.0
	_secim_kaydir.custom_minimum_size = Vector2(
		_secim_icerik.custom_minimum_size.x,
		minf(_secim_icerik.get_combined_minimum_size().y, secim_max))
	_choice_panel.reset_size()
	_choice_panel.position = (Vector2(w, h) - _choice_panel.size) * 0.5


# -------------------------------------------------------------- arayuz olcegi

func _ayar_oku() -> void:
	var c := ConfigFile.new()
	if c.load(AYAR_DOSYASI) == OK:
		_kullanici_olcek = clampf(float(c.get_value("arayuz", "olcek", 1.0)), 0.5, 2.0)


func _olcek_degistir(yon: int) -> void:
	var i := OLCEK_ADIMLARI.find(_kullanici_olcek)
	if i < 0:
		i = OLCEK_ADIMLARI.find(1.0)
	i = clampi(i + yon, 0, OLCEK_ADIMLARI.size() - 1)
	_kullanici_olcek = OLCEK_ADIMLARI[i]
	_olcek_yazisi()
	var c := ConfigFile.new()
	c.set_value("arayuz", "olcek", _kullanici_olcek)
	c.save(AYAR_DOSYASI)
	_ekran_degisti()


func _olcek_yazisi() -> void:
	_olcek_deger.text = "%d%%" % roundi(_kullanici_olcek * 100.0)


# ----------------------------------------------------------------- disa acik

func set_status(text: String) -> void:
	_status.text = text

func set_start_text(text: String) -> void:
	_start_btn.text = text

func set_readout(side: String, bbcode: String) -> void:
	if side == "left":
		_left_readout.text = bbcode
	else:
		_right_readout.text = bbcode

func show_choice(show_it: bool) -> void:
	_choice_panel.visible = show_it
	if show_it:
		_yerlestir()

func show_feedback(bbcode: String) -> void:
	_feedback.text = bbcode
	_feedback_panel.visible = bbcode != ""
	_yerlestir()
