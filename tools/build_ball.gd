extends SceneTree

## ============================================================================
## TOP SAHNESİ ÜRETİCİSİ — scenes/ball.tscn + main.tscn'de TopSol / TopSag
## ============================================================================
## Eskiden scripts/sim_ball.gd topu her açılışta KODLA kuruyordu (editörde
## görünmüyordu). Bu betik aynı topu, BİREBİR aynı değerlerle, gerçek
## node'lardan oluşan bir sahne olarak yazar; sonra main.tscn'ye iki örneğini
## koyar. Üretimden sonra her şey editörde düzenlenebilir.
##
## Çalıştırma (proje kökünde):
##     godot --path . -s tools/build_ball.gd
## (--headless gerekmez ama zararsız; burada MultiMesh yok.)
##
## Tekrar çalıştırılabilir: ball.tscn baştan yazılır, main.tscn'de yalnızca
## TopSol / TopSag değişir (Ortam, kamera, cetveller vb. dokunulmaz).

const BALL_SCENE := "res://scenes/ball.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"
const BALL_SCRIPT := "res://scripts/ball.gd"

const BALL_TEXTURE := "res://assets/basketball_albedo.png"
const DUST_TEXTURE := "res://assets/dust_particle.png"
const IMPACT_SOUND := "res://assets/impact.wav"

const RADIUS := 0.119
const MASS := 0.624
const DROP_HEIGHT := 3.0
const HALF_X := 1.8

## Fizik katmanları (Adım D'de Godot Melez modu bunları kullanacak):
## 1 = zemin/dekor, 2 = toplar. Toplar başka hiçbir şeyle çarpışmaz;
## zemin teması Godot'un değil bizim yay-sönüm modelimizin işi.
const LAYER_BALLS := 2


func _initialize() -> void:
	if "--sadece-yerlestir" in OS.get_cmdline_user_args():
		quit(0 if _place_in_main() == OK else 1)
		return
	var err := _build_ball_scene()
	if err != OK:
		_fail("ball.tscn yazılamadı: %d" % err)
		return
	err = _place_in_main()
	if err != OK:
		_fail("main.tscn yazılamadı: %d" % err)
		return
	quit(0)


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


func _own(n: Node, owner_node: Node) -> void:
	for ch in n.get_children():
		ch.owner = owner_node
		_own(ch, owner_node)


# ============================================================================
func _build_ball_scene() -> int:
	var root := RigidBody3D.new()
	root.name = "Top"
	# Scene panelinde ipucu: fizik ayarının yeri (bkz. scripts/ball.gd başı)
	root.editor_description = "Fizik ayarları (kütle, sekme, hava, temas) burada DEĞİL: config/sim2_config.tres. Bu topun Mass/Damp/Physics Material alanlarını değiştirmeyin."
	root.set_script(load(BALL_SCRIPT))
	root.set("radius", RADIUS)
	root.mass = MASS
	# Varsayılan KUKLA: main.gd set_puppet() çağırana kadar Godot yerçekimi
	# topu tek kare bile düşürmesin.
	root.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	root.freeze = true
	root.collision_layer = 1 << (LAYER_BALLS - 1)
	root.collision_mask = 0
	root.can_sleep = false

	# --- çarpışma şekli (Adım D için; kukla modda etkisiz) ---------------
	var shape := CollisionShape3D.new()
	shape.name = "Sekil"
	var ss := SphereShape3D.new()
	ss.radius = RADIUS
	shape.shape = ss
	root.add_child(shape)

	# --- küre (sim_ball.gd _build_mesh ile aynı) --------------------------
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	var mat := StandardMaterial3D.new()
	var tex: Texture2D = load(BALL_TEXTURE)
	if tex:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = Color(0.84, 0.40, 0.15)
	mat.roughness = 0.75
	mat.metallic = 0.0
	var mesh := MeshInstance3D.new()
	mesh.name = "Kure"
	mesh.mesh = sphere
	mesh.material_override = mat
	root.add_child(mesh)

	# --- toz (sim_ball.gd _build_dust ile aynı) ---------------------------
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = RADIUS * 0.55
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
	var dtex: Texture2D = load(DUST_TEXTURE)
	if dtex:
		dmat.albedo_texture = dtex
	quad.material = dmat

	var dust := GPUParticles3D.new()
	dust.name = "Toz"
	dust.process_material = pm
	dust.draw_pass_1 = quad
	dust.amount = 34
	dust.lifetime = 0.75
	dust.one_shot = true
	dust.emitting = false
	dust.explosiveness = 0.95
	dust.local_coords = false   # toz topun değil, zeminin üzerinde patlar
	root.add_child(dust)

	# --- ses (sim_ball.gd _build_audio ile aynı) --------------------------
	var audio := AudioStreamPlayer3D.new()
	audio.name = "Ses"
	var snd: AudioStream = load(IMPACT_SOUND)
	if snd:
		audio.stream = snd
	audio.unit_size = 8.0
	audio.max_db = 0.0
	root.add_child(audio)

	# --- ok seti (sim_ball.gd _build_arrows ile aynı renk/etiketler) -----
	var arrow_root := Node3D.new()
	arrow_root.name = "Oklar"
	root.add_child(arrow_root)
	var defs := [
		["gravity", Color(0.94, 0.35, 0.35), "G"],
		["drag", Color(0.42, 0.72, 1.00), "Fs"],
		["contact", Color(0.40, 0.90, 0.55), "N"],
		["external", Color(0.85, 0.55, 1.00), "F"],
		["net", Color(1.00, 0.85, 0.25), "Fnet"],
		["net_minus_g", Color(1.00, 0.55, 0.15), "Fnet-G"],
	]
	for d in defs:
		var a := ForceArrow.new(d[1], d[2])
		a.name = d[0]
		arrow_root.add_child(a)

	_own(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, BALL_SCENE)
	root.free()
	if err == OK:
		print("OK: %s yazıldı" % BALL_SCENE)
	return err


# ============================================================================
func _place_in_main() -> int:
	var main_packed: PackedScene = load(MAIN_SCENE)
	var main := main_packed.instantiate()
	for nm in ["TopSol", "TopSag"]:
		var old := main.get_node_or_null(nm)
		if old:
			main.remove_child(old)
			old.free()

	# ball.tscn'yi taze yükle (önbellekteki eski sürüm değil)
	var ball_packed: PackedScene = ResourceLoader.load(BALL_SCENE, "", ResourceLoader.CACHE_MODE_REPLACE)
	var cam := main.get_node_or_null("Camera3D")
	for item in [["TopSol", -HALF_X], ["TopSag", HALF_X]]:
		# GEN_EDIT_STATE_INSTANCE: editörün yaptığı gibi — böylece paketleyici
		# ball.tscn'deki temel değerleri bilir ve main.tscn'ye yalnızca
		# gerçekten farklı olanları (konum) yazar, kopya override bırakmaz.
		var b := ball_packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		b.name = item[0]
		b.position = Vector3(item[1], DROP_HEIGHT, 0.0)
		main.add_child(b)
		if cam:
			main.move_child(b, cam.get_index())   # kameradan hemen önce, okunaklı dursun
		# YALNIZCA örnek kökünün sahibi main — iç node'lar ball.tscn'ye ait
		# kalmalı, yoksa main.tscn'ye kopyalanırlar.
		b.owner = main

	var out := PackedScene.new()
	var err := out.pack(main)
	if err == OK:
		err = ResourceSaver.save(out, MAIN_SCENE)
	main.free()
	if err == OK:
		print("OK: %s içine TopSol / TopSag kondu" % MAIN_SCENE)
	return err
