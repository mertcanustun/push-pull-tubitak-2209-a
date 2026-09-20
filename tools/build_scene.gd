extends SceneTree

## Tek seferlik yardimci: main.gd icinde kodla kurulan SABIT dekoru
## (ortam, gunes, kamera, iki zemin, ayirici, cetveller) gercek node'lar
## olarak scenes/main.tscn icine yazar. Toplar/oklar/HUD kodda kalir.
##
## Calistirma:  godot --headless -s tools/build_scene.gd
##
## Transformlari ve malzemeleri Godot'un kendisi bakip serilestirir; boylece
## eldeki .tscn, eski kodun urettigiyle birebir ayni gorunur.

const HALF_X := 1.8
const GROUND_Y := 0.0


func _own(root: Node, n: Node) -> void:
	root.add_child(n)
	n.owner = root


func _add_ground(root: Node, nm: String, x: float, tint: Color) -> void:
	var slab := MeshInstance3D.new()
	slab.name = nm
	var bm := BoxMesh.new()
	bm.size = Vector3(3.1, 0.18, 2.2)
	slab.mesh = bm
	slab.position = Vector3(x, GROUND_Y - 0.09, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.92
	slab.material_override = mat
	_own(root, slab)


func _add_height_ruler(root: Node, side_nm: String, x: float) -> void:
	var sign_x: float = signf(x)
	for m in range(1, 4):
		var tick := MeshInstance3D.new()
		tick.name = "%s_Tick%d" % [side_nm, m]
		var bm := BoxMesh.new()
		bm.size = Vector3(0.44, 0.014, 0.014)
		tick.mesh = bm
		tick.position = Vector3(x + sign_x * 0.22, float(m), 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1, 0.35)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tick.material_override = mat
		tick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_own(root, tick)

		var lbl := Label3D.new()
		lbl.name = "%s_Label%d" % [side_nm, m]
		lbl.text = "%d m" % m
		lbl.font_size = 40
		lbl.pixel_size = 0.0028
		lbl.modulate = Color(1, 1, 1, 0.5)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(x + sign_x * 0.16, float(m) + 0.13, 0.0)
		_own(root, lbl)


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "Main"
	root.set_script(load("res://scripts/main.gd"))

	# --- ortam / gokyuzu ---
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.07, 0.09, 0.14)
	sky_mat.sky_horizon_color = Color(0.16, 0.18, 0.24)
	sky_mat.ground_bottom_color = Color(0.05, 0.05, 0.07)
	sky_mat.ground_horizon_color = Color(0.14, 0.15, 0.19)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_own(root, we)

	# --- gunes ---
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	_own(root, sun)

	# --- kamera ---
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 1.62, 4.7)
	camera.look_at_from_position(Vector3(0.0, 1.62, 4.7), Vector3(0.0, 1.38, 0.0), Vector3.UP)
	camera.fov = 54.0
	_own(root, camera)

	# --- zemin: iki plaka ---
	_add_ground(root, "GroundLeft", -HALF_X, Color(0.20, 0.30, 0.42))
	_add_ground(root, "GroundRight", HALF_X, Color(0.42, 0.30, 0.20))

	# --- ortadaki ayirici ---
	var divider := MeshInstance3D.new()
	divider.name = "Divider"
	var dm := BoxMesh.new()
	dm.size = Vector3(0.025, 4.2, 2.2)
	divider.mesh = dm
	divider.position = Vector3(0.0, 2.1, 0.0)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(1, 1, 1, 0.055)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	divider.material_override = dmat
	divider.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(root, divider)

	# --- cetveller ---
	_add_height_ruler(root, "RulerLeft", -0.62)
	_add_height_ruler(root, "RulerRight", 0.62)

	# --- paketle ve kaydet ---
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack hatasi: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://scenes/main.tscn")
	if err != OK:
		push_error("kaydetme hatasi: %d" % err)
		quit(1)
		return
	print("OK: scenes/main.tscn yazildi (%d cocuk node)" % root.get_child_count())
	quit(0)
