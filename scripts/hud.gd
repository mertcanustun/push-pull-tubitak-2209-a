extends CanvasLayer
class_name Hud

## Tum arayuz kodla kurulur - .tscn duzenlemeye gerek yok.

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

var _left_readout: RichTextLabel
var _right_readout: RichTextLabel
var _status: Label
var _feedback: RichTextLabel
var _feedback_panel: PanelContainer
var _choice_panel: PanelContainer
var _start_btn: Button
var _backend_label: Label

const ARROW_DEFS := [
	["gravity", "Yerçekimi  G", Color(0.94, 0.35, 0.35), true],
	["drag", "Hava sürtünmesi  Fs", Color(0.42, 0.72, 1.00), true],
	["contact", "Zemin tepkisi  N", Color(0.40, 0.90, 0.55), true],
	["external", "Uygulanan kuvvet  F", Color(0.85, 0.55, 1.00), true],
	["net", "Net kuvvet  Fnet", Color(1.00, 0.85, 0.25), true],
	["net_minus_g", "Fnet − G", Color(1.00, 0.55, 0.15), false],
]


func _ready() -> void:
	_build_title()
	_build_side_panels()
	_build_controls()
	_build_choice_panel()
	_build_feedback()


func _panel(bg: Color = BG) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.border_color = Color(1, 1, 1, 0.09)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build_title() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -320
	box.offset_right = 320
	box.offset_top = 12
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	var t := _label("ETKİ – TEPKİ:  Basketbol topu yere çarptığında", 22, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	_status = _label("Başlatmak için SPACE ya da Başlat", 14, MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


func _side_panel(title: String, subtitle: String, color: Color) -> Array:
	var p := _panel()
	p.custom_minimum_size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)

	var t := _label(title, 16, color)
	v.add_child(t)
	var s := _label(subtitle, 12, MUTED)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(312, 0)
	v.add_child(s)

	var sep := HSeparator.new()
	v.add_child(sep)

	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.custom_minimum_size = Vector2(312, 96)
	r.add_theme_font_size_override("normal_font_size", 13)
	r.scroll_active = false
	v.add_child(r)
	return [p, r]


func _build_side_panels() -> void:
	var left: Array = _side_panel(
		"SOL  —  çarpışma AÇIK",
		"Fizik motoru her şeyi kendi çözüyor: yerçekimi, hava sürtünmesi ve zeminle çarpışma. Gerçek davranış bu.",
		Color(0.45, 0.85, 1.0))
	var lp: PanelContainer = left[0]
	_left_readout = left[1]
	lp.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lp.offset_left = 16
	lp.offset_top = 92
	add_child(lp)

	var right: Array = _side_panel(
		"SAĞ  —  çarpışma KAPALI",
		"Yerçekimi ve hava sürtünmesi hâlâ işliyor, ama zeminle çarpışma çözülmüyor. Tepki kuvvetini SEN seçeceksin.",
		Color(1.0, 0.72, 0.45))
	var rp: PanelContainer = right[0]
	_right_readout = right[1]
	rp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rp.offset_right = -16
	rp.offset_left = -356
	rp.offset_top = 92
	add_child(rp)


func _build_controls() -> void:
	var p := _panel()
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.offset_left = 16
	p.offset_right = 258
	p.offset_top = -302
	p.offset_bottom = -16
	add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)

	var row := HBoxContainer.new()
	v.add_child(row)
	_start_btn = Button.new()
	_start_btn.text = "Başlat"
	_start_btn.custom_minimum_size = Vector2(102, 28)
	_start_btn.pressed.connect(func(): start_pressed.emit())
	row.add_child(_start_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Sıfırla"
	reset_btn.custom_minimum_size = Vector2(102, 28)
	reset_btn.pressed.connect(func(): reset_pressed.emit())
	row.add_child(reset_btn)

	v.add_child(_label("Simülasyon hızı", 12, MUTED))
	var slider := HSlider.new()
	slider.min_value = 0.05
	slider.max_value = 1.5
	slider.step = 0.05
	slider.value = 1.0
	slider.custom_minimum_size = Vector2(210, 16)
	slider.value_changed.connect(func(val: float): speed_changed.emit(val))
	v.add_child(slider)

	v.add_child(HSeparator.new())
	v.add_child(_label("Gösterilecek kuvvet okları", 12, MUTED))

	for def in ARROW_DEFS:
		var cb := CheckBox.new()
		cb.text = def[1]
		cb.button_pressed = def[3]
		cb.add_theme_font_size_override("font_size", 11)
		cb.add_theme_color_override("font_color", def[2])
		cb.add_theme_color_override("font_pressed_color", def[2])
		cb.add_theme_color_override("font_hover_color", def[2])
		var key: String = def[0]
		cb.toggled.connect(func(on: bool): arrow_toggled.emit(key, on))
		v.add_child(cb)

	v.add_child(HSeparator.new())
	var tool_cb := CheckBox.new()
	tool_cb.text = "Ok aracı (sürükle-bırak)"
	tool_cb.add_theme_font_size_override("font_size", 11)
	tool_cb.toggled.connect(func(on: bool): tool_toggled.emit(on))
	v.add_child(tool_cb)


func _build_choice_panel() -> void:
	_choice_panel = _panel(Color(0.09, 0.10, 0.14, 0.97))
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.offset_left = -330
	_choice_panel.offset_right = 330
	_choice_panel.offset_top = -170
	_choice_panel.offset_bottom = 170
	_choice_panel.visible = false
	add_child(_choice_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_choice_panel.add_child(v)

	var t := _label("Top tam zemine değdi. Zemin topa hangi kuvveti uygular?", 18, ACCENT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(600, 0)
	v.add_child(t)

	var hint := _label("Sol taraf gerçek fiziği gösteriyor. Sağdaki top için sen karar ver.", 13, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(600, 0)
	v.add_child(hint)

	var options := [
		["a", "a)   Yukarı yönlü F kadar kuvvet", "Topun momentumunu tersine çevirecek kadar tepki kuvveti."],
		["b", "b)   Yukarı yönlü 100·F kadar kuvvet", "Zemin çok daha büyük bir kuvvetle iter."],
		["c", "c)   Hem yukarı hem aşağı F  →  top durur", "Etki ve tepki topun üzerinde birbirini götürür."],
	]
	for opt in options:
		var b := Button.new()
		b.custom_minimum_size = Vector2(600, 46)
		b.text = "%s\n%s" % [opt[1], opt[2]]
		b.add_theme_font_size_override("font_size", 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var key: String = opt[0]
		b.pressed.connect(func(): choice_made.emit(key))
		v.add_child(b)


func _build_feedback() -> void:
	var p := _panel(Color(0.09, 0.10, 0.14, 0.93))
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.offset_left = -820
	p.offset_right = -16
	p.offset_top = -132
	p.offset_bottom = -16
	p.visible = false
	add_child(p)

	_feedback = RichTextLabel.new()
	_feedback.bbcode_enabled = true
	_feedback.fit_content = true
	_feedback.scroll_active = false
	_feedback.custom_minimum_size = Vector2(776, 96)
	_feedback.add_theme_font_size_override("normal_font_size", 14)
	p.add_child(_feedback)
	_feedback_panel = p


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

func show_feedback(bbcode: String) -> void:
	_feedback.text = bbcode
	_feedback_panel.visible = bbcode != ""
