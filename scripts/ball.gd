extends RigidBody3D
class_name Ball

## Bir top: küre + toz parçacıkları + çarpma sesi + ok seti.
## Hepsi scenes/ball.tscn içinde GERÇEK node — editörde seçilip düzenlenir
## (malzeme, toz rengi/miktarı, ses, ok renkleri vb. doğrudan child node'larda).
## Bu betik yalnızca onları birbirine bağlar.
##
## İki çalışma biçimi:
##   KUKLA (MuJoCo / Yedek Çözücü): freeze = true, FREEZE_MODE_KINEMATIC.
##       Godot fiziği çalışmaz; main.gd konumu her karede backend'den yazar.
##   SERBEST (Godot Melez, Adım D): dondurulmaz, Godot fiziği işler.

## Yarıçap (m). main.gd bunu cfg.radius ile eşitler — küre, çarpışma şekli
## ve toz yayılım yarıçapı birlikte güncellenir.
@export_range(0.01, 1.0, 0.001, "suffix:m") var radius: float = 0.119:
	set(v):
		radius = v
		if is_node_ready():
			_apply_radius()

@export_group("Çarpma sesi")
## Bu hızda (m/s) çarpma sesi tam şiddette çalar; daha yavaşta kısılır.
@export_range(0.5, 30.0, 0.1, "suffix:m/s") var impact_full_speed: float = 7.0
@export_range(0.0, 1.0, 0.01) var impact_min_volume: float = 0.12
@export_range(0.1, 2.0, 0.01) var pitch_min: float = 0.88
@export_range(0.0, 1.0, 0.01) var pitch_range: float = 0.28

var arrows: Dictionary = {}   # anahtar -> ForceArrow ("gravity", "drag", ...)
## SERBEST modda (Godot Melez) her fizik adımının başında çağrılır —
## hava direnci ve zemin temasını GodotBackend buradan uygular.
var integrator: Callable = Callable()

@onready var _mesh: MeshInstance3D = $Kure
@onready var _shape: CollisionShape3D = $Sekil
@onready var _dust: GPUParticles3D = $Toz
@onready var _audio: AudioStreamPlayer3D = $Ses
@onready var _arrow_root: Node3D = $Oklar


func _ready() -> void:
	for a in _arrow_root.get_children():
		if a is ForceArrow:
			arrows[String(a.name)] = a
	_apply_radius()


func _apply_radius() -> void:
	var sm := _mesh.mesh as SphereMesh
	if sm:
		sm.radius = radius
		sm.height = radius * 2.0
	var ss := _shape.shape as SphereShape3D
	if ss:
		ss.radius = radius
	var pm := _dust.process_material as ParticleProcessMaterial
	if pm:
		pm.emission_sphere_radius = radius * 0.55


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if integrator.is_valid():
		integrator.call(state)


## Kukla modu: Godot fiziği kapalı, konum dışarıdan (backend) yazılır.
func set_puppet(on: bool) -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = on


## Toz + ses. impact_speed çarpma hızı (m/s) — sesin sertliğini belirler.
func play_impact(ground_y: float, impact_speed: float) -> void:
	_dust.global_position = Vector3(global_position.x, ground_y + 0.02, global_position.z)
	_dust.restart()
	_dust.emitting = true
	if _audio.stream:
		var s: float = clampf(impact_speed / impact_full_speed, impact_min_volume, 1.0)
		_audio.volume_db = linear_to_db(s)
		_audio.pitch_scale = pitch_min + pitch_range * s
		_audio.play()
