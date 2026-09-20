extends Node3D
class_name SimBall

## Bir topun gorsel tarafi: kure + toz parcaciklari + carpma sesi + ok seti.
## Fizik burada YOK; konumu her karede PhysicsBackend'den alir.

const DUST_TEXTURE := "res://assets/dust_particle.png"
const BALL_TEXTURE := "res://assets/basketball_albedo.png"
const IMPACT_SOUND := "res://assets/impact.wav"

var radius := 0.119
var arrows: Dictionary = {}   # anahtar -> ForceArrow

var _mesh: MeshInstance3D
var _dust: GPUParticles3D
var _audio: AudioStreamPlayer3D
var _arrow_root: Node3D


func _init(p_radius: float = 0.119) -> void:
	radius = p_radius


func _ready() -> void:
	_build_mesh()
	_build_dust()
	_build_audio()
	_arrow_root = Node3D.new()
	add_child(_arrow_root)
	_build_arrows()


func _build_mesh() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24

	var mat := StandardMaterial3D.new()
	var tex := load(BALL_TEXTURE)
	if tex:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = Color(0.84, 0.40, 0.15)
	mat.roughness = 0.75
	mat.metallic = 0.0

	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.material_override = mat
	add_child(_mesh)


func _build_dust() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = radius * 0.55
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 78.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 1.15
	pm.gravity = Vector3(0, -2.6, 0)
	pm.damping_min = 1.2
	pm.damping_max = 2.6
	pm.scale_min = 0.30
	pm.scale_max = 0.85
	pm.color = Color(0.88, 0.84, 0.76, 0.42)

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.75))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var quad := QuadMesh.new()
	quad.size = Vector2(0.095, 0.095)
	var dmat := StandardMaterial3D.new()
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dmat.vertex_color_use_as_albedo = true
	var dtex := load(DUST_TEXTURE)
	if dtex:
		dmat.albedo_texture = dtex
	quad.material = dmat

	_dust = GPUParticles3D.new()
	_dust.process_material = pm
	_dust.draw_pass_1 = quad
	_dust.amount = 34
	_dust.lifetime = 0.75
	_dust.one_shot = true
	_dust.emitting = false
	_dust.explosiveness = 0.95
	# Toz topun degil, zeminin uzerinde patlar.
	_dust.local_coords = false
	add_child(_dust)


func _build_audio() -> void:
	_audio = AudioStreamPlayer3D.new()
	var snd := load(IMPACT_SOUND)
	if snd:
		_audio.stream = snd
	_audio.unit_size = 8.0
	_audio.max_db = 0.0
	add_child(_audio)


func _build_arrows() -> void:
	# anahtar: [renk, etiket]
	var defs := {
		"gravity": [Color(0.94, 0.35, 0.35), "G"],
		"drag": [Color(0.42, 0.72, 1.00), "Fs"],
		"contact": [Color(0.40, 0.90, 0.55), "N"],
		"external": [Color(0.85, 0.55, 1.00), "F"],
		"net": [Color(1.00, 0.85, 0.25), "Fnet"],
		"net_minus_g": [Color(1.00, 0.55, 0.15), "Fnet-G"],
	}
	for key in defs:
		var arrow := ForceArrow.new(defs[key][0], defs[key][1])
		_arrow_root.add_child(arrow)
		arrows[key] = arrow


## Toz + ses. impact_speed carpma hizi (m/s) - sesin sertligini belirler.
func play_impact(ground_y: float, impact_speed: float) -> void:
	if _dust:
		_dust.global_position = Vector3(global_position.x, ground_y + 0.02, global_position.z)
		_dust.restart()
		_dust.emitting = true
	if _audio and _audio.stream:
		var s: float = clampf(impact_speed / 7.0, 0.12, 1.0)
		_audio.volume_db = linear_to_db(s)
		_audio.pitch_scale = 0.88 + 0.28 * s
		_audio.play()


func set_arrow_visible(key: String, on: bool) -> void:
	if arrows.has(key) and not on:
		(arrows[key] as ForceArrow).set_force(Vector3.ZERO, 1.0)


func tint(c: Color) -> void:
	if _mesh and _mesh.material_override:
		(_mesh.material_override as StandardMaterial3D).albedo_color = c
