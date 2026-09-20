extends RefCounted
class_name PhysicsBackend

## Soyut fizik arka ucu / Abstract physics backend.
##
## Sahnedeki hicbir sey Godot'nun kendi RigidBody3D'sine ya da dogrudan
## MuJoCo'ya bagli degil. Her sey bu arayuzden gecer, boylece MuJoCo
## eklentisi derlendiginde tek satir degistirerek gecis yapabilirsin.
##
## Nothing in the scene talks to Godot's RigidBody3D or to MuJoCo directly.
## Everything goes through this interface, so swapping in the compiled
## MuJoCo extension is a one-line change in main.gd.


## Bir cismin o anki durumu. Kuvvetler Newton cinsinden, dunya eksenlerinde.
class BodyState extends RefCounted:
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var mass := 1.0
	## Ayrisik kuvvet bilesenleri - ok gosterimi bunlari kullanir.
	var f_gravity := Vector3.ZERO      # m * g
	var f_drag := Vector3.ZERO         # hava surtunmesi
	var f_contact := Vector3.ZERO      # zeminden gelen tepki kuvveti (normal force)
	var f_external := Vector3.ZERO     # kullanicinin okla uyguladigi kuvvet
	var f_net := Vector3.ZERO          # m * a  (olcum, toplam degil)
	var touching_ground := false
	## Zemine degdigi an true olur, bir kare surer (tetikleyici / one-shot).
	var just_hit_ground := false
	## O temas boyunca biriken dusey impuls (N*s). "Gercek F" bundan cikar.
	var contact_impulse := 0.0


## Bir cismin tanimi.
class BodySpec extends RefCounted:
	var id := ""
	var mass := 0.624           # NBA basketbolu ~624 g
	var radius := 0.119         # ~23.8 cm cap
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var restitution := 0.76     # basketbol: 1.8 m'den birakinca ~1.05 m
	var drag_coefficient := 0.47  # kure
	## false ise: yercekimi ve hava surtunmesi isler ama CARPISMA islemez.
	## Sahnenin sag yarisi bunu kullanir (senaryo planindaki istek).
	var collisions_enabled := true

	func _init(p_id: String = "") -> void:
		id = p_id


const GRAVITY := Vector3(0.0, -9.81, 0.0)
const AIR_DENSITY := 1.225      # kg/m^3, deniz seviyesi
const GROUND_Y := 0.0

var _specs: Dictionary = {}     # id -> BodySpec


func backend_name() -> String:
	return "abstract"

## Arka uc gercekten kullanilabilir mi? (MuJoCo icin: eklenti yuklu mu?)
func is_available() -> bool:
	return false

func add_body(spec: BodySpec) -> void:
	_specs[spec.id] = spec

func get_spec(id: String) -> BodySpec:
	return _specs.get(id)

func body_ids() -> Array:
	return _specs.keys()

## Kullanicinin uyguladigi surekli dis kuvvet (Newton).
func set_external_force(_id: String, _force: Vector3) -> void:
	pass

func set_position(_id: String, _pos: Vector3) -> void:
	pass

func set_velocity(_id: String, _vel: Vector3) -> void:
	pass

## Simulasyonu dt kadar ilerlet.
func step(_dt: float) -> void:
	pass

func get_state(_id: String) -> BodyState:
	return BodyState.new()

## Tum cisimleri baslangic durumuna dondur.
func reset() -> void:
	pass

## Yercekimi ve hava surtunmesi her iki arka uc icin de ayni formulle
## hesaplanir, boylece iki yari arasindaki karsilastirma adil kalir.
static func drag_force(velocity: Vector3, radius: float, cd: float) -> Vector3:
	var speed := velocity.length()
	if speed < 0.0001:
		return Vector3.ZERO
	var area := PI * radius * radius
	# F_d = -1/2 * rho * Cd * A * |v| * v
	return -0.5 * AIR_DENSITY * cd * area * speed * velocity
