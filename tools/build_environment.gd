extends SceneTree

## ============================================================================
## PROSEDÜREL ORTAM ÜRETİCİSİ — stilize / low-poly basketbol salonu
## ============================================================================
## scenes/main.tscn'i açar, "Ortam" alt ağacını SIFIRDAN üretir ve sahneye
## GERÇEK node'lar olarak kaydeder. Üretimden sonra her şey editörde görünür,
## elle taşınabilir / renk değiştirilebilir. Toplar, oklar ve HUD kodda kalır
## (dinamik nesneler); bu betik yalnızca STATİK dekoru yazar.
##
## Çalıştırma (proje kökünde):
##     godot --headless --path . -s tools/build_environment.gd
##
## Tekrar çalıştırılabilir: yalnızca "Ortam" düğümü ve eski "GroundLeft/
## GroundRight" plakaları değişir; kamera, ayırıcı ve cetvellere dokunulmaz.
## Aynı SEED → birebir aynı salon (seyirci renkleri/boşlukları dahil).
##
## Koordinatlar: Y yukarı, zemin üstü y = 0 (fizik GROUND_Y ile aynı).
## Kamera +Z'de (z = 4.7) ve -Z'ye bakıyor; toplar x = ±1.8, z = 0'da düşüyor.
## Pota arka tarafta (-Z), seyirci onun arkasında.

const SCENE_PATH := "res://scenes/main.tscn"
const SEED := 2209

# --- saha ölçüleri (m) — FIBA yarım saha, ölçek gerçek -------------------
const BASELINE_Z := -7.2       # dip çizgi
const SIDELINE_X := 7.5        # yan çizgiler ±7.5 (saha eni 15 m)
const RIM_Z := -5.625          # çember merkezi: dip çizgiden 1.575 m
const RIM_Y := 3.05            # çember yüksekliği
const THREE_R := 6.75          # üçlük yarıçapı
const THREE_CORNER_X := 6.6    # köşe üçlük çizgisi
const KEY_HALF_W := 2.45       # boyalı alan yarı eni (4.9 m)
const FT_Z := BASELINE_Z + 5.8 # serbest atış çizgisi
const FT_R := 1.8

# --- salon ------------------------------------------------------------------
const FLOOR_X := 10.0          # parke ±10 m
const FLOOR_Z0 := -15.0
const FLOOR_Z1 := 7.0
const PLANK_W := 0.5
const STAND_ROWS := 6
const STAND_Z0 := -9.4         # ilk tribün sırası
const STAND_DEPTH := 0.85
const STAND_STEP_H := 0.42
const WALL_H := 9.0

# --- çizgi ------------------------------------------------------------------
const LINE_W := 0.06
const LINE_H := 0.004
const LINE_Y := 0.003          # parkenin hemen üstü (z-fighting yok)

# --- palet (low-poly: düz renkler, doku yok) --------------------------------
const C_WOOD := [Color("e2b077"), Color("d9a468"), Color("e8bb86"), Color("d49c5e")]
const C_LINE := Color("fbfaf5")
const C_PAINT := Color("2f6fb5")
const C_ZONE_L := Color(0.20, 0.45, 0.85, 0.22)   # sol yarı: gerçek dünya
const C_ZONE_R := Color(0.95, 0.55, 0.20, 0.22)   # sağ yarı: öğrencinin dünyası
const C_WALL := Color("2b3550")
const C_WALL_STRIPE := Color("e8742a")
const C_STAND := [Color("c8553d"), Color("b0473a")]
const C_SHIRTS := [Color("e8742a"), Color("2f6fb5"), Color("f2f2ee"), Color("f2c14e"), Color("3aa17e"), Color("7a5cc9")]
const C_SKIN := [Color("f1c7a1"), Color("d9a47c"), Color("b27a52"), Color("7d5236")]
const C_POLE := Color("3a3f4a")
const C_RIM := Color("e8601c")
const C_BOARD := Color("f4f6f8")
const C_BOARD_MARK := Color("d7392f")
const C_NET := Color(1, 1, 1, 0.55)
const C_BG := Color("1a2130")

var rng := RandomNumberGenerator.new()
var _mat_cache := {}


# ============================================================================
func _initialize() -> void:
	rng.seed = SEED
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		_fail("sahne yüklenemedi: " + SCENE_PATH)
		return
	var root: Node = packed.instantiate()

	# eski üretimi ve eski düz zemin plakalarını kaldır
	for nm in ["Ortam", "GroundLeft", "GroundRight"]:
		var old := root.get_node_or_null(nm)
		if old:
			root.remove_child(old)
			old.free()

	var ortam := Node3D.new()
	ortam.name = "Ortam"
	root.add_child(ortam)
	# Ortam, sahne ağacında en üste yakın dursun (editörde okunaklı)
	root.move_child(ortam, 1)

	_build_floor(ortam)
	_build_zones(ortam)
	_build_court_lines(ortam)
	_build_hoop(ortam)
	_build_stands(ortam)
	_build_walls(ortam)
	_build_scoreboard(ortam)
	_build_lights(ortam)
	_style_environment(root)

	_set_owner_recursive(ortam, root)

	var out := PackedScene.new()
	var err := out.pack(root)
	if err != OK:
		_fail("pack hatası: %d" % err)
		return
	err = ResourceSaver.save(out, SCENE_PATH)
	if err != OK:
		_fail("kaydetme hatası: %d" % err)
		return
	print("OK: 'Ortam' üretildi (%d node) -> %s  [seed %d]" % [_count(ortam), SCENE_PATH, SEED])
	root.free()
	quit(0)


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


# ============================================================================
# yardımcılar
# ============================================================================
func _mat(c: Color, rough := 0.85, emit_energy := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [c.to_html(), rough, emit_energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if c.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit_energy
	_mat_cache[key] = m
	return m


func _group(parent: Node, nm: String) -> Node3D:
	var g := Node3D.new()
	g.name = nm
	parent.add_child(g)
	return g


func _box(parent: Node, nm: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(parent: Node, nm: String, r_top: float, r_bot: float, h: float, segs: int, pos: Vector3, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Zemin üstünde a→b arasında düz çizgi (Vector2 = (x, z)).
func _floor_line(parent: Node, nm: String, a: Vector2, b: Vector2) -> void:
	var d := b - a
	var mi := _box(parent, nm, Vector3(LINE_W, LINE_H, d.length() + LINE_W),
		Vector3((a.x + b.x) * 0.5, LINE_Y, (a.y + b.y) * 0.5), _mat(C_LINE, 0.6))
	mi.rotation.y = atan2(d.x, d.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Zemin üstünde çember yayı — kasıtlı olarak az parçalı (low-poly).
func _floor_arc(parent: Node, nm: String, center: Vector2, r: float, a0: float, a1: float, segs: int) -> void:
	var prev := center + Vector2(sin(a0), cos(a0)) * r
	for i in range(1, segs + 1):
		var t := a0 + (a1 - a0) * float(i) / float(segs)
		var p := center + Vector2(sin(t), cos(t)) * r
		_floor_line(parent, "%s_%02d" % [nm, i], prev, p)
		prev = p


func _set_owner_recursive(n: Node, owner_node: Node) -> void:
	for ch in n.get_children():
		ch.owner = owner_node
		_set_owner_recursive(ch, owner_node)
	if n != owner_node:
		n.owner = owner_node


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c


func _pick(arr: Array) -> Color:
	return arr[rng.randi_range(0, arr.size() - 1)]


# ============================================================================
# 1) parke — tahtalar tek MultiMesh (tek çizim çağrısı, web dostu)
# ============================================================================
func _build_floor(ortam: Node) -> void:
	var g := _group(ortam, "Parke")
	var n := int(round(FLOOR_X * 2.0 / PLANK_W))
	var depth := FLOOR_Z1 - FLOOR_Z0
	var bm := BoxMesh.new()
	bm.size = Vector3(PLANK_W, 0.2, depth)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true          # instance_count'tan ÖNCE ayarlanmalı
	mm.mesh = bm
	mm.instance_count = n
	for i in n:
		var x := -FLOOR_X + PLANK_W * (float(i) + 0.5)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, -0.1, (FLOOR_Z0 + FLOOR_Z1) * 0.5)))
		mm.set_instance_color(i, _pick(C_WOOD))

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55           # hafif cilalı parke
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Tahtalar"
	mmi.multimesh = mm
	mmi.material_override = mat
	g.add_child(mmi)


# ============================================================================
# 2) sol/sağ bölge renkleri — eski GroundLeft/GroundRight'ın yerini alır
# ============================================================================
## NOT (2026-09-27): Defne'nin isteğiyle iki renkli ayrım (mavi "gerçek dünya" /
## turuncu "senin dünyan") kaldırıldı — Defne turuncu (C_ZONE_R / eski
## "BolgeSenin") tonunu her iki tarafta da istedi. PEDAGOJİK NOT: bu, sol/sağ
## panelin görsel ayrımını kaldırıyor (plan dokümanında bilinçli bir tasarım
## kararıydı); bilerek ve onaylanarak yapıldı. Geri almak istenirse: aşağıdaki
## tek satırı "for side in [[-1.8, "BolgeGercek", C_ZONE_L], [1.8, "BolgeSenin", C_ZONE_R]]:"
## olarak değiştirmek yeterli (bkz. git geçmişi).
func _build_zones(ortam: Node) -> void:
	var g := _group(ortam, "Bolgeler")
	for side in [[-1.8, "Bolge1"], [1.8, "Bolge2"]]:
		var mi := _box(g, side[1], Vector3(3.1, 0.002, 2.2), Vector3(side[0], 0.0015, 0.0),
			_mat(C_ZONE_R, 0.9))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ============================================================================
# 3) saha çizgileri
# ============================================================================
func _build_court_lines(ortam: Node) -> void:
	var g := _group(ortam, "SahaCizgileri")
	# dip çizgi + yan çizgiler
	_floor_line(g, "DipCizgi", Vector2(-SIDELINE_X, BASELINE_Z), Vector2(SIDELINE_X, BASELINE_Z))
	_floor_line(g, "YanCizgiSol", Vector2(-SIDELINE_X, BASELINE_Z), Vector2(-SIDELINE_X, FLOOR_Z1))
	_floor_line(g, "YanCizgiSag", Vector2(SIDELINE_X, BASELINE_Z), Vector2(SIDELINE_X, FLOOR_Z1))

	# boyalı alan (dolgu + kenarlar)
	var key_len := FT_Z - BASELINE_Z
	var paint := _box(g, "BoyaliAlan", Vector3(KEY_HALF_W * 2.0, 0.002, key_len),
		Vector3(0.0, 0.001, BASELINE_Z + key_len * 0.5), _mat(C_PAINT, 0.7))
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor_line(g, "BoyaliSol", Vector2(-KEY_HALF_W, BASELINE_Z), Vector2(-KEY_HALF_W, FT_Z))
	_floor_line(g, "BoyaliSag", Vector2(KEY_HALF_W, BASELINE_Z), Vector2(KEY_HALF_W, FT_Z))
	_floor_line(g, "SerbestAtis", Vector2(-KEY_HALF_W, FT_Z), Vector2(KEY_HALF_W, FT_Z))

	# serbest atış yarım dairesi (kameraya bakan yarı)
	_floor_arc(g, "SerbestAtisYay", Vector2(0.0, FT_Z), FT_R, -PI * 0.5, PI * 0.5, 10)

	# üçlük: köşe düzleri + yay
	var a_max := asin(THREE_CORNER_X / THREE_R)
	var corner_z := RIM_Z + THREE_R * cos(a_max)
	_floor_line(g, "UclukKoseSol", Vector2(-THREE_CORNER_X, BASELINE_Z), Vector2(-THREE_CORNER_X, corner_z))
	_floor_line(g, "UclukKoseSag", Vector2(THREE_CORNER_X, BASELINE_Z), Vector2(THREE_CORNER_X, corner_z))
	_floor_arc(g, "UclukYay", Vector2(0.0, RIM_Z), THREE_R, -a_max, a_max, 18)


# ============================================================================
# 4) pota: direk, kol, panya, işaret karesi, çember, file
# ============================================================================
func _build_hoop(ortam: Node) -> void:
	var g := _group(ortam, "Pota")
	var board_z := BASELINE_Z + 1.2        # panya yüzü dip çizgiden 1.2 m içeride
	var board_y := 2.9 + 0.525             # panya alt kenarı 2.9 m
	var pole_z := BASELINE_Z - 1.1

	_box(g, "Taban", Vector3(1.0, 0.35, 1.4), Vector3(0.0, 0.175, pole_z - 0.2), _mat(C_POLE, 0.7))
	_cyl(g, "Direk", 0.1, 0.12, board_y, 8, Vector3(0.0, board_y * 0.5, pole_z), _mat(C_POLE, 0.6))
	_box(g, "Kol", Vector3(0.14, 0.14, board_z - pole_z), Vector3(0.0, board_y, (board_z + pole_z) * 0.5), _mat(C_POLE, 0.6))

	_box(g, "Panya", Vector3(1.8, 1.05, 0.05), Vector3(0.0, board_y, board_z), _mat(C_BOARD, 0.3))
	# panya çerçevesi + atış karesi (ön yüzde ince kırmızı çubuklar)
	var fz := board_z + 0.03
	var mark := _mat(C_BOARD_MARK, 0.5)
	var rects := [
		[Vector3(1.8, 0.05, 0.01), Vector3(0.0, board_y + 0.5, fz)],
		[Vector3(1.8, 0.05, 0.01), Vector3(0.0, board_y - 0.5, fz)],
		[Vector3(0.05, 1.05, 0.01), Vector3(-0.875, board_y, fz)],
		[Vector3(0.05, 1.05, 0.01), Vector3(0.875, board_y, fz)],
		[Vector3(0.59, 0.05, 0.01), Vector3(0.0, RIM_Y + 0.45, fz)],
		[Vector3(0.59, 0.05, 0.01), Vector3(0.0, RIM_Y + 0.02, fz)],
		[Vector3(0.05, 0.45, 0.01), Vector3(-0.27, RIM_Y + 0.235, fz)],
		[Vector3(0.05, 0.45, 0.01), Vector3(0.27, RIM_Y + 0.235, fz)],
	]
	for i in rects.size():
		_box(g, "PanyaIsaret%d" % i, rects[i][0], rects[i][1], mark)

	# çember (az parçalı torus = low-poly)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.215
	tm.outer_radius = 0.245
	tm.rings = 14
	tm.ring_segments = 5
	var rim := MeshInstance3D.new()
	rim.name = "Cember"
	rim.mesh = tm
	rim.material_override = _mat(C_RIM, 0.45)
	rim.position = Vector3(0.0, RIM_Y, RIM_Z)
	g.add_child(rim)
	_box(g, "CemberBaglanti", Vector3(0.06, 0.04, board_z - RIM_Z - 0.2),
		Vector3(0.0, RIM_Y, (board_z + RIM_Z + 0.2) * 0.5), _mat(C_RIM, 0.45))

	# file: yarı saydam, aşağı daralan silindir
	var net := _cyl(g, "File", 0.225, 0.13, 0.42, 10, Vector3(0.0, RIM_Y - 0.21, RIM_Z), _mat(C_NET, 0.9))
	var nm := net.material_override as StandardMaterial3D
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ============================================================================
# 5) tribün + seyirci (seyirciler MultiMesh; SEED ile tekrarlanabilir)
# ============================================================================
func _build_stands(ortam: Node) -> void:
	var g := _group(ortam, "Tribun")
	var seats: Array = []   # [pozisyon, gömlek rengi, ten rengi]
	for i in STAND_ROWS:
		var top := STAND_STEP_H * float(i + 1)
		var z := STAND_Z0 - STAND_DEPTH * float(i)
		_box(g, "Basamak%d" % i, Vector3(FLOOR_X * 2.0, top, STAND_DEPTH), Vector3(0.0, top * 0.5, z),
			_mat(C_STAND[i % 2], 0.8))
		var x := -FLOOR_X + 0.5
		while x < FLOOR_X - 0.4:
			if rng.randf() > 0.3:   # ~%70 dolu
				seats.append([Vector3(x + rng.randf_range(-0.06, 0.06), top, z - 0.05),
					_pick(C_SHIRTS), _pick(C_SKIN)])
			x += 0.55

	# gövdeler
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.17
	body_mesh.height = 0.62
	body_mesh.radial_segments = 6
	body_mesh.rings = 1
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.12
	head_mesh.height = 0.24
	head_mesh.radial_segments = 6
	head_mesh.rings = 3
	g.add_child(_crowd_layer("SeyirciGovde", body_mesh, seats, 1, 0.31))
	g.add_child(_crowd_layer("SeyirciKafa", head_mesh, seats, 2, 0.74))


func _crowd_layer(nm: String, mesh: Mesh, seats: Array, color_idx: int, y_off: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = seats.size()
	for i in seats.size():
		var p: Vector3 = seats[i][0]
		var b := Basis(Vector3.UP, rng.randf_range(-0.25, 0.25))   # hafif farklı bakışlar
		mm.set_instance_transform(i, Transform3D(b, p + Vector3(0.0, y_off, 0.0)))
		mm.set_instance_color(i, seats[i][color_idx])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


# ============================================================================
# 6) duvarlar, şerit, flamalar
# ============================================================================
func _build_walls(ortam: Node) -> void:
	var g := _group(ortam, "Duvarlar")
	var back_z := STAND_Z0 - STAND_DEPTH * float(STAND_ROWS) - 0.3
	var wall := _mat(C_WALL, 0.95)
	_box(g, "ArkaDuvar", Vector3(FLOOR_X * 2.0 + 0.6, WALL_H, 0.3), Vector3(0.0, WALL_H * 0.5, back_z), wall)
	for s in [-1.0, 1.0]:
		var depth := FLOOR_Z1 - back_z
		_box(g, "YanDuvar%s" % ("Sol" if s < 0 else "Sag"), Vector3(0.3, WALL_H, depth),
			Vector3(s * (FLOOR_X + 0.15), WALL_H * 0.5, back_z + depth * 0.5), wall)
		_box(g, "Serit%s" % ("Sol" if s < 0 else "Sag"), Vector3(0.05, 0.35, depth),
			Vector3(s * (FLOOR_X - 0.01), 1.4, back_z + depth * 0.5), _mat(C_WALL_STRIPE, 0.7))
	_box(g, "SeritArka", Vector3(FLOOR_X * 2.0, 0.35, 0.05), Vector3(0.0, STAND_STEP_H * STAND_ROWS + 0.6, back_z + 0.17),
		_mat(C_WALL_STRIPE, 0.7))
	# flamalar: üstte asılı üçgen yerine low-poly dikdörtgen bayraklar
	var n_flags := 7
	for i in n_flags:
		var x := -7.2 + 14.4 * float(i) / float(n_flags - 1)
		if absf(x) < 2.5:
			continue   # ortada skorbord var
		_box(g, "Flama%d" % i, Vector3(0.9, 1.6, 0.04), Vector3(x, WALL_H - 1.4, back_z + 0.2),
			_mat(C_SHIRTS[i % C_SHIRTS.size()], 0.8))


# ============================================================================
# 7) skorbord: senaryonun adını taşıyan, parlayan ekran
# ============================================================================
func _build_scoreboard(ortam: Node) -> void:
	var g := _group(ortam, "Skorbord")
	var back_z := STAND_Z0 - STAND_DEPTH * float(STAND_ROWS) - 0.3
	var y := WALL_H - 1.55          # panyanın ÜSTÜNDE kalsın (kamera hesabıyla kontrol edildi)
	_box(g, "Kasa", Vector3(3.6, 1.5, 0.3), Vector3(0.0, y, back_z + 0.3), _mat(Color("15181f"), 0.6))
	_box(g, "Ekran", Vector3(3.3, 1.2, 0.04), Vector3(0.0, y, back_z + 0.47), _mat(Color("0b3d2e"), 0.4, 0.6))
	var l1 := Label3D.new()
	l1.name = "Baslik"
	l1.text = "ETKİ  –  TEPKİ"
	l1.font_size = 96
	l1.pixel_size = 0.004
	l1.modulate = Color("ffd54a")
	l1.outline_size = 0
	l1.position = Vector3(0.0, y + 0.22, back_z + 0.5)
	g.add_child(l1)
	var l2 := Label3D.new()
	l2.name = "AltBaslik"
	l2.text = "Newton'un 3. yasası"
	l2.font_size = 56
	l2.pixel_size = 0.004
	l2.modulate = Color("9fe8c2")
	l2.outline_size = 0
	l2.position = Vector3(0.0, y - 0.28, back_z + 0.5)
	g.add_child(l2)


# ============================================================================
# 8) ışık: tavan ışıkları (gölgesiz, web dostu); ana ışık mevcut "Sun"
# ============================================================================
func _build_lights(ortam: Node) -> void:
	var g := _group(ortam, "TavanIsiklari")
	for p in [Vector3(-4.0, 7.5, -3.0), Vector3(4.0, 7.5, -3.0), Vector3(0.0, 7.0, -8.5)]:
		var l := OmniLight3D.new()
		l.name = "Tavan_%d_%d" % [int(p.x), int(p.z)]
		l.position = p
		l.omni_range = 14.0
		# NOT (2026-09-27): Compatibility (Web) renderer'da HDR/tonemap yok —
		# aynı ışık+glow değerleri masaüstünde (Forward+) yumuşak bir parıltı
		# iken Web'de zeminde sarı ışın/parlama olarak taşıyordu. Enerji
		# düşürüldü (1.1 -> 0.6); ihtiyaç olursa glow_intensity/glow_bloom da
		# aşağıdaki _style_environment()'ta ayrıca düşürüldü.
		l.light_energy = 0.6
		l.light_color = Color("fff1dc")
		l.shadow_enabled = false
		g.add_child(l)


func _style_environment(root: Node) -> void:
	# kapalı salon: gökyüzü yerine düz koyu arka plan, sıcak ortam ışığı,
	# hafif sis (derinlik) ve parlama. Hepsi Compatibility (web) renderer'da çalışır.
	var we := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = C_BG
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("c9c2b8")
		env.ambient_light_energy = 0.55
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_intensity = 0.35   # Compatibility'de abartılı parlama vermesin diye 0.6'dan düşürüldü
		env.glow_bloom = 0.03
		env.fog_enabled = true
		env.fog_light_color = C_BG
		env.fog_density = 0.012
		we.environment = env
	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.rotation_degrees = Vector3(-62.0, -25.0, 0.0)
		sun.light_energy = 0.85
		sun.light_color = Color("fff4e2")
		# NOT (2026-09-27): Compatibility (Web) renderer'da bu GPU/sürücüde
		# Sun'ın gölgesi zeminde sarı ışın/parlama artefaktı üretiyordu (ışığın
		# kendisi değil, gölge render'ı — izole testlerle doğrulandı: ışık
		# enerjisini/glow'u düşürmek etkisizdi, yalnızca shadow_enabled=false
		# düzeltti). Masaüstünde (Forward+) zeminde ince bir temas gölgesi
		# kayboluyor ama fark edilmiyor; iki platformda da tutarlı ve güvenli
		# olsun diye kapatıldı.
		sun.shadow_enabled = false
