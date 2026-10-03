extends SceneTree
## Adım E görsel doğrulama: (b) gösteriminin zaman içindeki kareleri.
## Pencereli çalıştır (gerçek render gerekir):
##     godot --path . --script tools/shots_b.gd -- --mod=IKISI --motor=yedek
## --mod: IKISI | FIRLATMA_AGIR_CEKIM | KAMERA_TAKIP | HICBIRI
## Kareler seçimden sonraki GERÇEK saniyelerde alınır (ağır çekim süreleri
## uzatmasın diye zamanlayıcılar Engine.time_scale'i yok sayar).
## Çıktı: res://tools/shots_b/<mod>_<motor>/

const ANLAR := [0.3, 0.8, 1.6, 2.4, 3.4, 4.8, 5.6, 6.3, 7.6]

var cfg: Sim2Config = load("res://config/sim2_config.tres")


func _init() -> void:
	var mod := "IKISI"
	var motor := "yedek"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mod="):
			mod = a.trim_prefix("--mod=")
		elif a.begins_with("--motor="):
			motor = a.trim_prefix("--motor=")
	cfg.b_gosterim = Sim2Config.BGosterim.keys().find(mod)
	cfg.backend = Sim2Config.Backend.GODOT_MELEZ if motor == "godot" else Sim2Config.Backend.YEDEK_COZUCU
	var out := "res://tools/shots_b/%s_%s" % [mod, motor]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._on_start()
	while int(main.phase) != 2:   # Phase.CHOICE
		await process_frame
	main._on_choice("b")
	var t0 := Time.get_ticks_msec()
	for anı in ANLAR:
		var bekle: float = anı - (Time.get_ticks_msec() - t0) / 1000.0
		if bekle > 0.0:
			await create_timer(bekle, true, false, true).timeout
		await process_frame
		var ad := "%s/t%04.1f.png" % [out, anı]
		root.get_texture().get_image().save_png(ad)
		print("kare %.1f sn  kamera_durum=%s  kamera_y=%.1f  sağ_top_y=%.1f" % [
			anı, BGosterimKamera.Durum.keys()[main._bcam.durum],
			main.camera.global_position.y, (main.balls["right"] as Node3D).global_position.y])
	print("bitti -> ", ProjectSettings.globalize_path(out))
	quit(0)
