extends Node3D
class_name ForceArrow

## Kuvvet vektoru oku. Govde (silindir) + uc (koni) + deger etiketi.
## Tamamen kod uretimi - sahne dosyasi gerektirmez.

const SHAFT_RADIUS := 0.022
const HEAD_RADIUS := 0.055
const HEAD_LENGTH := 0.16
const MIN_LENGTH := 0.10

var label_text := ""
var show_label := true
## Etiketler birbirinin uzerine binmesin diye her oka farkli bir kaldirma.
var label_lift := 0.0
var color := Color.WHITE : set = _set_color

var _shaft: MeshInstance3D
var _head: MeshInstance3D
var _label: Label3D
var _mat: StandardMaterial3D
var _force := Vector3.ZERO


func _init(p_color: Color = Color.WHITE, p_label: String = "") -> void:
	color = p_color
	label_text = p_label


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 0.55
	# Oklar cismin icinden gecse bile gorunsun - ogretici acidan daha iyi.
	_mat.no_depth_test = true
	_mat.render_priority = 2

	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = SHAFT_RADIUS
	shaft_mesh.bottom_radius = SHAFT_RADIUS
	shaft_mesh.height = 1.0
	shaft_mesh.radial_segments = 12
	shaft_mesh.rings = 1
	_shaft = MeshInstance3D.new()
	_shaft.mesh = shaft_mesh
	_shaft.material_override = _mat
	_shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shaft)

	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = HEAD_RADIUS
	head_mesh.height = HEAD_LENGTH
	head_mesh.radial_segments = 14
	head_mesh.rings = 1
	_head = MeshInstance3D.new()
	_head.mesh = head_mesh
	_head.material_override = _mat
	_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_head)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 3
	_label.font_size = 44
	_label.pixel_size = 0.0028
	_label.outline_size = 14
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.modulate = color
	add_child(_label)

	visible = false


func _set_color(c: Color) -> void:
	color = c
	if _mat:
		_mat.albedo_color = c
		_mat.emission = c
	if _label:
		_label.modulate = c


## force : Newton cinsinden vektor
## k     : olcek katsayisi (tum oklarda AYNI olmali ki karsilastirma adil olsun)
##
## Uzunluk logaritmiktir: bu sahnede yercekimi ~6 N iken temas kuvveti
## ~1000 N, (b) secenegi ise ~100.000 N. Dogrusal olcekte kucuk oklar
## gorunmez olurdu. Gercek sayi her zaman etikette yazar.
func set_force(force: Vector3, k: float, logarithmic: bool = true) -> void:
	_force = force
	var magnitude := force.length()
	if not is_node_ready() or magnitude < 0.02:
		visible = false
		return

	var length: float
	if logarithmic:
		length = MIN_LENGTH + k * (log(1.0 + magnitude) / log(10.0))
	else:
		length = maxf(magnitude * k, MIN_LENGTH)
	var dir := force / magnitude

	# Godot'da silindirin ekseni +Y.
	# DIKKAT: Quaternion(Vector3, Vector3) tam ters yonde (dir == -Y) hatali
	# sonuc verir - Y ekseni etrafinda 180 derece dondurur, ki bu +Y'yi yine
	# +Y'ye tasir. Yercekimi oku tam olarak bu durumda oldugu icin ayrica
	# ele aliyoruz: X ekseni etrafinda 180 derece.
	if Vector3.UP.dot(dir) < -0.999999:
		basis = Basis(Vector3.RIGHT, PI)
	else:
		basis = Basis(Quaternion(Vector3.UP, dir))

	var shaft_len: float = maxf(length - HEAD_LENGTH, 0.01)
	_shaft.scale = Vector3(1.0, shaft_len, 1.0)
	_shaft.position = Vector3(0.0, shaft_len * 0.5, 0.0)
	_head.position = Vector3(0.0, shaft_len + HEAD_LENGTH * 0.5, 0.0)

	if show_label:
		_label.visible = true
		var num := "%.1f" % magnitude if magnitude < 10.0 else "%.0f" % magnitude
		_label.text = "%s %s N" % [label_text, num]
		# Etiket dunya eksenine gore hafif saga kaysin, ok donse de okunsun.
		_label.position = Vector3(0.0, length + 0.14 + label_lift, 0.0)
	else:
		_label.visible = false

	visible = true


func get_force() -> Vector3:
	return _force
