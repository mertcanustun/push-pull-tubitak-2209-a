@tool
class_name OrtamUretici
extends RefCounted

## ============================================================================
## PROSEDÜREL ORTAM ÜRETİCİSİ — stilize / low-poly basketbol salonu
## ============================================================================
## Sahnenin "Ortam" alt ağacını config/ortam_ayarlari.tres'teki ayarlarla
## SIFIRDAN üretir ve GERÇEK node'lar olarak yazar. Toplar, oklar ve HUD
## kodda kalır (dinamik nesneler); bu betik yalnızca STATİK dekoru yazar.
##
## İki giriş:
##   - Inspector: config/ortam_ayarlari.tres → "Salonu yeniden üret" düğmesi
##     (editorde_uret). main.tscn editörde açıksa açık sahne güncellenir.
##   - Terminal: tools/build_environment.gd (sahne_dosyasini_uret).
##
## KORUNAN: "Ortam/ElleEklenenler" düğümü ve içindekiler yeniden üretimden
## önce ayrılır, sonra yeni Ortam'a OLDUĞU GİBİ geri takılır. Kamera,
## ayırıcı, cetveller ve toplar (Ortam dışı) hiç değişmez.
## Aynı ayarlar + aynı SEED → birebir aynı salon.
##
## Koordinatlar: Y yukarı, zemin üstü y = 0 (fizik GROUND_Y ile aynı).
## Kamera +Z'de (z = 4.7) ve -Z'ye bakıyor; toplar x = ±1.8, z = 0'da düşüyor.
## Pota arka tarafta (-Z), seyirci onun arkasında.
##
## UYARI: --headless ile ÇALIŞTIRMA — headless'ta MultiMesh örnekleri
## (parke tahtaları, seyirciler) yazılmıyor.

const SCENE_PATH := "res://scenes/main.tscn"
const AYAR_PATH := "res://config/ortam_ayarlari.tres"
const KORUNAN := "ElleEklenenler"

# --- ayara açılmayan sabitler (m) ------------------------------------------
const RIM_Y := 3.05            # çember yüksekliği (FIBA)
const RIM_DIP := 1.575         # çember merkezi dip çizgiden bu kadar içeride
const FT_DIP := 5.8            # serbest atış çizgisi dip çizgiden
const FT_R := 1.8
const FLOOR_Z0 := -15.0
const FLOOR_Z1 := 7.0
const PLANK_W := 0.5
const STAND_Z0 := -9.4         # ilk tribün sırası
const STAND_DEPTH := 0.85
const LINE_W := 0.06
const LINE_H := 0.004
const LINE_Y := 0.003          # parkenin hemen üstü (z-fighting yok)

var a: OrtamAyarlari
var rng := RandomNumberGenerator.new()
var _mat_cache := {}


# ============================================================================
# girişler
# ============================================================================

## Terminal: main.tscn dosyasını açar, Ortam'ı yeniden üretir, kaydeder.
func sahne_dosyasini_uret(ayar: OrtamAyarlari) -> String:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		return "HATA: sahne yüklenemedi: " + SCENE_PATH
	# Düzenleme durumuyla aç: toplar gibi alt sahne örnekleri, paketlenirken
	# gereksiz "override" satırları yazmasın.
	var root: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var n := uret(root, ayar)
	var out := PackedScene.new()
	var err := out.pack(root)
	root.free()
	if err != OK:
		return "HATA: pack %d" % err
	# Sahnenin uid'i korunmalı (başka dosyalar sahneye uid ile bağlanabilir);
	# yeni PackedScene'in uid'i yok, kaydettikten sonra eskisini geri yaz.
	var uid := ResourceLoader.get_resource_uid(SCENE_PATH)
	err = ResourceSaver.save(out, SCENE_PATH)
	if err != OK:
		return "HATA: kaydetme %d" % err
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(SCENE_PATH, uid)
	return "OK: 'Ortam' üretildi (%d node) -> %s  [seed %d]" % [n, SCENE_PATH, ayar.seed_sayisi]


## Inspector düğmesi: main.tscn editörde açıksa AÇIK sahneyi günceller
## (kaydetmek kullanıcıda); açık değilse dosyayı günceller.
func editorde_uret(ayar: OrtamAyarlari) -> String:
	if not Engine.is_editor_hint():
		return "Bu düğme yalnızca Godot editöründe çalışır."
	var ei = Engine.get_singleton("EditorInterface")
	var root: Node = ei.get_edited_scene_root() if ei else null
	if root and root.scene_file_path == SCENE_PATH:
		var n := uret(root, ayar)
		ei.mark_scene_as_unsaved()
		return "Salon açık sahnede yeniden üretildi (%d node). Kaydetmek için Cmd+S / Ctrl+S." % n
	var msg := sahne_dosyasini_uret(ayar)
	if ei and SCENE_PATH in ei.get_open_scenes():
		ei.reload_scene_from_path(SCENE_PATH)
	return msg


## Asıl üretim: root'un altındaki "Ortam"ı yeniden kurar. Üretilen node sayısını döner.
func uret(root: Node, ayar: OrtamAyarlari) -> int:
	a = ayar
	rng.seed = a.seed_sayisi
	_mat_cache.clear()

	# Korunan düğümü ayır (sahiplik bilgisiyle birlikte)
	var korunan: Node = null
	var sahipler := {}
	var eski := root.get_node_or_null("Ortam")
	if eski:
		korunan = eski.get_node_or_null(KORUNAN)
		if korunan:
			_sahipleri_kaydet(korunan, root, sahipler)
			eski.remove_child(korunan)

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

	if korunan == null:
		korunan = Node3D.new()
		korunan.name = KORUNAN
		korunan.editor_description = "Salona elle eklenen nesneler buraya. Salon yeniden üretilirken bu düğüme ve içindekilere dokunulmaz."
		ortam.add_child(korunan)
		korunan.owner = root
	else:
		ortam.add_child(korunan)
		_sahipleri_geri_yukle(sahipler)
	var count := _count(ortam)
	return count


func _sahipleri_kaydet(n: Node, root: Node, out: Dictionary) -> void:
	out[n] = n.owner
	for ch in n.get_children():
		_sahipleri_kaydet(ch, root, out)


func _sahipleri_geri_yukle(sahipler: Dictionary) -> void:
	for n in sahipler:
		if is_instance_valid(n) and sahipler[n] != null:
			n.owner = sahipler[n]


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
func _floor_line(parent: Node, nm: String, p0: Vector2, p1: Vector2) -> void:
	var d := p1 - p0
	var mi := _box(parent, nm, Vector3(LINE_W, LINE_H, d.length() + LINE_W),
		Vector3((p0.x + p1.x) * 0.5, LINE_Y, (p0.y + p1.y) * 0.5), _mat(a.saha_cizgisi, 0.6))
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


func _pick(arr: PackedColorArray) -> Color:
	return arr[rng.randi_range(0, arr.size() - 1)]


# türetilmiş ölçüler
func _rim_z() -> float:
	return a.dip_cizgi_z + RIM_DIP

func _ft_z() -> float:
	return a.dip_cizgi_z + FT_DIP

func _back_z() -> float:
	return STAND_Z0 - STAND_DEPTH * float(a.tribun_sira_sayisi) - 0.3


# ============================================================================
# 1) parke — tahtalar tek MultiMesh (tek çizim çağrısı, web dostu)
# ============================================================================
func _build_floor(ortam: Node) -> void:
	var g := _group(ortam, "Parke")
	var fx := a.parke_yari_genislik
	var n := int(round(fx * 2.0 / PLANK_W))
	var depth := FLOOR_Z1 - FLOOR_Z0
	var bm := BoxMesh.new()
	bm.size = Vector3(PLANK_W, 0.2, depth)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true          # instance_count'tan ÖNCE ayarlanmalı
	mm.mesh = bm
	mm.instance_count = n
	for i in n:
		var x := -fx + PLANK_W * (float(i) + 0.5)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, -0.1, (FLOOR_Z0 + FLOOR_Z1) * 0.5)))
		mm.set_instance_color(i, _pick(a.parke_tonlari))

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
## NOT (2026-09-27): Defne'nin isteğiyle iki bölge de turuncu (eski
## "BolgeSenin" tonu). PEDAGOJİK NOT: bu, sol/sağ panelin görsel ayrımını
## kaldırıyor (plan dokümanında bilinçli bir tasarım kararıydı); bilerek ve
## onaylanarak yapıldı. Geri almak için ortam_ayarlari.tres → Sol Bolge Rengi'ni
## eski maviye (0.20, 0.45, 0.85, 0.22) çekmek yeterli.
func _build_zones(ortam: Node) -> void:
	var g := _group(ortam, "Bolgeler")
	for side in [[-1.8, "Bolge1", a.sol_bolge_rengi], [1.8, "Bolge2", a.sag_bolge_rengi]]:
		var mi := _box(g, side[1], Vector3(3.1, 0.002, 2.2), Vector3(side[0], 0.0015, 0.0),
			_mat(side[2], 0.9))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ============================================================================
# 3) saha çizgileri
# ============================================================================
func _build_court_lines(ortam: Node) -> void:
	var g := _group(ortam, "SahaCizgileri")
	var bz := a.dip_cizgi_z
	var sx := a.yan_cizgi_x
	var kw := a.boyali_alan_yari_genislik
	var ft_z := _ft_z()
	# dip çizgi + yan çizgiler
	_floor_line(g, "DipCizgi", Vector2(-sx, bz), Vector2(sx, bz))
	_floor_line(g, "YanCizgiSol", Vector2(-sx, bz), Vector2(-sx, FLOOR_Z1))
	_floor_line(g, "YanCizgiSag", Vector2(sx, bz), Vector2(sx, FLOOR_Z1))

	# boyalı alan (dolgu + kenarlar)
	var key_len := ft_z - bz
	var paint := _box(g, "BoyaliAlan", Vector3(kw * 2.0, 0.002, key_len),
		Vector3(0.0, 0.001, bz + key_len * 0.5), _mat(a.boyali_alan, 0.7))
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor_line(g, "BoyaliSol", Vector2(-kw, bz), Vector2(-kw, ft_z))
	_floor_line(g, "BoyaliSag", Vector2(kw, bz), Vector2(kw, ft_z))
	_floor_line(g, "SerbestAtis", Vector2(-kw, ft_z), Vector2(kw, ft_z))

	# serbest atış yarım dairesi (kameraya bakan yarı)
	_floor_arc(g, "SerbestAtisYay", Vector2(0.0, ft_z), FT_R, -PI * 0.5, PI * 0.5, 10)

	# üçlük: köşe düzleri + yay
	var cx: float = minf(a.ucluk_kose_x, a.ucluk_yaricap - 0.01)
	var a_max := asin(cx / a.ucluk_yaricap)
	var corner_z := _rim_z() + a.ucluk_yaricap * cos(a_max)
	_floor_line(g, "UclukKoseSol", Vector2(-cx, bz), Vector2(-cx, corner_z))
	_floor_line(g, "UclukKoseSag", Vector2(cx, bz), Vector2(cx, corner_z))
	_floor_arc(g, "UclukYay", Vector2(0.0, _rim_z()), a.ucluk_yaricap, -a_max, a_max, 18)


# ============================================================================
# 4) pota: direk, kol, panya, işaret karesi, çember, file
# ============================================================================
func _build_hoop(ortam: Node) -> void:
	var g := _group(ortam, "Pota")
	var rim_z := _rim_z()
	var board_z := a.dip_cizgi_z + 1.2     # panya yüzü dip çizgiden 1.2 m içeride
	var board_y := 2.9 + 0.525             # panya alt kenarı 2.9 m
	var pole_z := a.dip_cizgi_z - 1.1
	var pole := _mat(a.pota_direk, 0.7)

	_box(g, "Taban", Vector3(1.0, 0.35, 1.4), Vector3(0.0, 0.175, pole_z - 0.2), pole)
	_cyl(g, "Direk", 0.1, 0.12, board_y, 8, Vector3(0.0, board_y * 0.5, pole_z), _mat(a.pota_direk, 0.6))
	_box(g, "Kol", Vector3(0.14, 0.14, board_z - pole_z), Vector3(0.0, board_y, (board_z + pole_z) * 0.5), _mat(a.pota_direk, 0.6))

	_box(g, "Panya", Vector3(1.8, 1.05, 0.05), Vector3(0.0, board_y, board_z), _mat(a.panya, 0.3))
	# panya çerçevesi + atış karesi (ön yüzde ince kırmızı çubuklar)
	var fz := board_z + 0.03
	var mark := _mat(a.panya_isareti, 0.5)
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
	rim.material_override = _mat(a.cember, 0.45)
	rim.position = Vector3(0.0, RIM_Y, rim_z)
	g.add_child(rim)
	_box(g, "CemberBaglanti", Vector3(0.06, 0.04, board_z - rim_z - 0.2),
		Vector3(0.0, RIM_Y, (board_z + rim_z + 0.2) * 0.5), _mat(a.cember, 0.45))

	# file: yarı saydam, aşağı daralan silindir
	var net := _cyl(g, "File", 0.225, 0.13, 0.42, 10, Vector3(0.0, RIM_Y - 0.21, rim_z), _mat(a.file, 0.9))
	var nm := net.material_override as StandardMaterial3D
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ============================================================================
# 5) tribün + seyirci (seyirciler MultiMesh; SEED ile tekrarlanabilir)
# ============================================================================
func _build_stands(ortam: Node) -> void:
	var g := _group(ortam, "Tribun")
	var fx := a.parke_yari_genislik
	var seats: Array = []   # [pozisyon, gömlek rengi, ten rengi]
	for i in a.tribun_sira_sayisi:
		var top := a.basamak_yuksekligi * float(i + 1)
		var z := STAND_Z0 - STAND_DEPTH * float(i)
		_box(g, "Basamak%d" % i, Vector3(fx * 2.0, top, STAND_DEPTH), Vector3(0.0, top * 0.5, z),
			_mat(a.tribun_basamaklari[i % a.tribun_basamaklari.size()], 0.8))
		var x := -fx + 0.5
		while x < fx - 0.4:
			if rng.randf() > 1.0 - a.doluluk_orani:   # varsayılan ~%70 dolu
				seats.append([Vector3(x + rng.randf_range(-0.06, 0.06), top, z - 0.05),
					_pick(a.seyirci_formalari), _pick(a.seyirci_ten)])
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
	var fx := a.parke_yari_genislik
	var wh := a.duvar_yuksekligi
	var back_z := _back_z()
	var wall := _mat(a.duvar, 0.95)
	_box(g, "ArkaDuvar", Vector3(fx * 2.0 + 0.6, wh, 0.3), Vector3(0.0, wh * 0.5, back_z), wall)
	for s in [-1.0, 1.0]:
		var depth := FLOOR_Z1 - back_z
		_box(g, "YanDuvar%s" % ("Sol" if s < 0 else "Sag"), Vector3(0.3, wh, depth),
			Vector3(s * (fx + 0.15), wh * 0.5, back_z + depth * 0.5), wall)
		_box(g, "Serit%s" % ("Sol" if s < 0 else "Sag"), Vector3(0.05, 0.35, depth),
			Vector3(s * (fx - 0.01), 1.4, back_z + depth * 0.5), _mat(a.serit, 0.7))
	_box(g, "SeritArka", Vector3(fx * 2.0, 0.35, 0.05),
		Vector3(0.0, a.basamak_yuksekligi * a.tribun_sira_sayisi + 0.6, back_z + 0.17), _mat(a.serit, 0.7))
	# flamalar: üstte asılı üçgen yerine low-poly dikdörtgen bayraklar
	var n_flags := 7
	for i in n_flags:
		var x := -7.2 + 14.4 * float(i) / float(n_flags - 1)
		if absf(x) < 2.5:
			continue   # ortada skorbord var
		_box(g, "Flama%d" % i, Vector3(0.9, 1.6, 0.04), Vector3(x, wh - 1.4, back_z + 0.2),
			_mat(a.seyirci_formalari[i % a.seyirci_formalari.size()], 0.8))


# ============================================================================
# 7) skorbord: senaryonun adını taşıyan, parlayan ekran
# ============================================================================
func _build_scoreboard(ortam: Node) -> void:
	var g := _group(ortam, "Skorbord")
	var back_z := _back_z()
	var y := a.duvar_yuksekligi - 1.55   # panyanın ÜSTÜNDE kalsın (kamera hesabıyla kontrol edildi)
	_box(g, "Kasa", Vector3(3.6, 1.5, 0.3), Vector3(0.0, y, back_z + 0.3), _mat(Color("15181f"), 0.6))
	_box(g, "Ekran", Vector3(3.3, 1.2, 0.04), Vector3(0.0, y, back_z + 0.47), _mat(Color("0b3d2e"), 0.4, 0.6))
	var l1 := Label3D.new()
	l1.name = "Baslik"
	l1.text = a.baslik
	l1.font_size = 96
	l1.pixel_size = 0.004
	l1.modulate = Color("ffd54a")
	l1.outline_size = 0
	l1.position = Vector3(0.0, y + 0.22, back_z + 0.5)
	g.add_child(l1)
	var l2 := Label3D.new()
	l2.name = "AltBaslik"
	l2.text = a.alt_baslik
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
		# iken Web'de zeminde sarı ışın/parlama olarak taşıyordu. Varsayılan
		# enerji bu yüzden 0.6 (eskiden 1.1).
		l.light_energy = a.tavan_isik_gucu
		l.light_color = a.tavan_isik_rengi
		l.shadow_enabled = false
		g.add_child(l)


func _style_environment(root: Node) -> void:
	# kapalı salon: gökyüzü yerine düz koyu arka plan, sıcak ortam ışığı,
	# hafif sis (derinlik) ve parlama. Hepsi Compatibility (web) renderer'da çalışır.
	var we := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = a.arka_plan
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = a.ortam_isik_rengi
		env.ambient_light_energy = a.ortam_isik_gucu
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = a.parlama
		env.glow_intensity = a.parlama_siddeti   # Compatibility'de abartılı parlama vermesin diye 0.6'dan düşürüldü
		env.glow_bloom = a.parlama_yayilmasi
		env.fog_enabled = a.sis_yogunlugu > 0.0
		env.fog_light_color = a.arka_plan
		env.fog_density = a.sis_yogunlugu
		we.environment = env
	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.rotation_degrees = Vector3(-62.0, -25.0, 0.0)
		sun.light_energy = a.gunes_gucu
		sun.light_color = a.gunes_rengi
		# NOT (2026-09-27): Compatibility (Web) renderer'da bu GPU/sürücüde
		# Sun'ın gölgesi zeminde sarı ışın/parlama artefaktı üretiyordu (ışığın
		# kendisi değil, gölge render'ı — izole testlerle doğrulandı: ışık
		# enerjisini/glow'u düşürmek etkisizdi, yalnızca shadow_enabled=false
		# düzeltti). Masaüstünde (Forward+) zeminde ince bir temas gölgesi
		# kayboluyor ama fark edilmiyor; iki platformda da tutarlı ve güvenli
		# olsun diye kapatıldı.
		sun.shadow_enabled = false
