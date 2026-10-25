extends SceneTree
## Görsel doğrulama: açılış karesi + temas anı + (b) seçeneği ekran görüntüsü.
## --headless İLE ÇALIŞMAZ (gerçek piksel render gerekir, "dummy" sürücü boş
## PNG üretir) — normal pencereli modda çalıştır:
##     godot --path . --script tools/shots.gd
## PNG'ler res://tools/shots/ altına yazılır (proje köküne göreli, kolay okuma için).
## Motor seçmek için:  ... --script tools/shots.gd -- --motor=godot   (ya da yedek)
##   → res://tools/shots_godot/ (ya da shots_yedek/) altına yazar.
var OUT := "res://tools/shots"
## ÜYE değişken olmalı: yerel olursa kapsam bitince kaynak serbest kalır,
## önbellek onu tutmaz ve main.tscn varsayılan değerli YENİ bir kopya yükler.
var cfg: Sim2Config = load("res://config/sim2_config.tres")

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--motor="):
			var m := a.trim_prefix("--motor=")
			match m:
				"godot": cfg.backend = Sim2Config.Backend.GODOT_MELEZ
				"yedek": cfg.backend = Sim2Config.Backend.YEDEK_COZUCU
				_: cfg.backend = Sim2Config.Backend.MUJOCO
			OUT = "res://tools/shots_" + m
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# 1) açılış karesi — reset_sim() sonrası, iki top da bırakılma yüksekliğinde
	await _w(0.3)
	await _s("1_acilis")

	# düşüşü başlat, temas anını yakala (Phase.CHOICE'a geçince)
	main._on_start()
	var waited := 0.0
	const PHASE_CHOICE := 2   # enum Phase { READY, FALLING, CHOICE, RESOLVED } — main.gd
	while int(main.phase) != PHASE_CHOICE and waited < 5.0:
		await process_frame
		waited += 1.0 / 60.0   # kaba tahmin — sadece zaman aşımı için
	await _w(0.15)   # yavaş çekim (slowmo) tam devredeyken bir kare daha bekle
	await _s("2_temas_ani")

	# (b) seçeneği: zemin 100F uygular, top ~967 m/s ile fırlar
	main._on_choice("b")
	await _w(0.4)
	await _s("3_b_secenegi_firlama")
	await _w(1.2)
	await _s("3_b_secenegi_1_2sn_sonra")

	print("bitti -> %s" % ProjectSettings.globalize_path(OUT))
	quit(0)

func _w(sec: float) -> void:
	await create_timer(sec).timeout

func _s(n: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, n])
