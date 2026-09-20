extends PhysicsBackend
class_name MuJoCoBackend

## Derlenmis MuJoCo GDExtension'ini saran arka uc.
##
## Eklenti yoksa is_available() false doner ve main.gd sessizce
## NativeBackend'e duser - proje her zaman calisir.
##
## Beklenen eklenti API'si (native/src/mujoco_world.cpp bunu saglar):
##   MuJoCoWorld.load_model_from_path(abs_path: String) -> bool
##   .reset()
##   .step(dt: float)
##   .set_body_external_force(name: String, f: Vector3)
##   .get_body_position(name: String) -> Vector3
##   .get_body_velocity(name: String) -> Vector3
##   .set_body_position(name: String, p: Vector3)
##   .set_body_velocity(name: String, v: Vector3)
##   .get_body_contact_force(name: String) -> Vector3
##   .set_body_contacts_enabled(name: String, on: bool)
##   .get_last_error() -> String

const MODEL_RES_PATH := "res://mujoco/scene.xml"
const MODEL_USER_PATH := "user://scene.xml"

var _world: Object = null
var _state: Dictionary = {}
var _error := ""


func backend_name() -> String:
	return "MuJoCo"

## GDScript tarafindaki "left"/"right" kimlikleri MJCF'teki govde adlarina
## ("ball_left"/"ball_right") eslenir.
static func _mj(id: String) -> String:
	return "ball_" + id

static func extension_present() -> bool:
	return ClassDB.class_exists("MuJoCoWorld")

func is_available() -> bool:
	return _world != null

func get_error() -> String:
	return _error


## Eklenti varsa modeli yukler. Basarisizsa false doner (hata get_error()'da).
func initialize() -> bool:
	if not extension_present():
		_error = "MuJoCoWorld sinifi bulunamadi - eklenti derlenmemis."
		return false

	# MuJoCo diskte gercek bir dosya yolu ister; res:// disa aktarimda
	# .pck icine gomulu oldugu icin modeli user:// altina kopyalariz.
	var src := FileAccess.open(MODEL_RES_PATH, FileAccess.READ)
	if src == null:
		_error = "Model bulunamadi: %s" % MODEL_RES_PATH
		return false
	var xml := src.get_as_text()
	src.close()
	var dst := FileAccess.open(MODEL_USER_PATH, FileAccess.WRITE)
	if dst == null:
		_error = "user:// altina yazilamadi."
		return false
	dst.store_string(xml)
	dst.close()

	_world = ClassDB.instantiate("MuJoCoWorld")
	var abs_path := ProjectSettings.globalize_path(MODEL_USER_PATH)
	if not _world.load_model_from_path(abs_path):
		_error = str(_world.get_last_error())
		_world = null
		return false
	return true


func add_body(spec: PhysicsBackend.BodySpec) -> void:
	super.add_body(spec)
	var s := PhysicsBackend.BodyState.new()
	s.mass = spec.mass
	s.position = spec.position
	s.f_gravity = spec.mass * PhysicsBackend.GRAVITY
	_state[spec.id] = s
	if _world:
		# Senaryo plani: sag yarida MuJoCo yercekimi ve hava surtunmesi icin
		# calisir ama CARPISMA icin calismaz. MJCF'te contype/conaffinity 0.
		_world.set_body_contacts_enabled(_mj(spec.id), spec.collisions_enabled)
		_world.set_body_position(_mj(spec.id), spec.position)
		_world.set_body_velocity(_mj(spec.id), spec.velocity)


func reset() -> void:
	if _world == null:
		return
	_world.reset()
	for id in _specs:
		var spec: PhysicsBackend.BodySpec = _specs[id]
		_world.set_body_contacts_enabled(_mj(spec.id), spec.collisions_enabled)
		_world.set_body_position(_mj(spec.id), spec.position)
		_world.set_body_velocity(_mj(spec.id), spec.velocity)
		_world.set_body_external_force(_mj(spec.id), Vector3.ZERO)
		var s: PhysicsBackend.BodyState = _state[id]
		s.position = spec.position
		s.velocity = spec.velocity
		s.f_external = Vector3.ZERO
		s.f_contact = Vector3.ZERO
		s.f_net = Vector3.ZERO
		s.touching_ground = false


func set_external_force(id: String, force: Vector3) -> void:
	var s: PhysicsBackend.BodyState = _state.get(id)
	if s:
		s.f_external = force
	if _world:
		_world.set_body_external_force(_mj(id), force)

func set_position(id: String, pos: Vector3) -> void:
	if _world:
		_world.set_body_position(_mj(id), pos)

func set_velocity(id: String, vel: Vector3) -> void:
	if _world:
		_world.set_body_velocity(_mj(id), vel)

func get_state(id: String) -> PhysicsBackend.BodyState:
	return _state.get(id)


func step(dt: float) -> void:
	if _world == null:
		return
	var prev: Dictionary = {}
	for id in _specs:
		prev[id] = (_state[id] as PhysicsBackend.BodyState).velocity

	_world.step(dt)

	for id in _specs:
		var spec: PhysicsBackend.BodySpec = _specs[id]
		var s: PhysicsBackend.BodyState = _state[id]
		var was_touching := s.touching_ground

		s.position = _world.get_body_position(_mj(id))
		s.velocity = _world.get_body_velocity(_mj(id))
		s.f_gravity = spec.mass * PhysicsBackend.GRAVITY
		s.f_contact = _world.get_body_contact_force(_mj(id))
		# Net kuvvet OLCUMU: m * a. NativeBackend ile birebir ayni tanim.
		s.f_net = spec.mass * (s.velocity - prev[id]) / dt
		# Senaryo planindaki istek: "net kuvvetten yercekimini vektorel olarak
		# cikart". Kalan = surukleme (MuJoCo'nun kendi akiskan modelinden).
		s.f_drag = s.f_net - s.f_gravity - s.f_contact - s.f_external

		s.touching_ground = s.f_contact.length() > 0.001
		s.just_hit_ground = s.touching_ground and not was_touching
		s.contact_impulse = s.f_contact.y * dt
