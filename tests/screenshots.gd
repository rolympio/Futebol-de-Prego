extends SceneTree
## Gera capturas de tela das principais telas (precisa de GPU/X; use xvfb-run).
## godot --path . --script res://tests/screenshots.gd -- <pasta_saida>

var out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var save: Node = root.get_node("Save")
	save.settings["sound"] = false
	save.settings["tutorial_seen"] = false
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(30)
	await _snap("01_menu")
	main.goto("setup", {"mode": "cpu"})
	await _frames(20)
	await _snap("02_setup")
	main.goto("match", {"mode": "cpu"})
	await _frames(40)
	await _snap("03_partida_tutorial")
	var ms: Node = main.current
	var b: Board = ms.board
	ms._coach.queue_free()
	ms._coach = null
	# mira simulada: puxando para baixo-esquerda
	b.place_coin(Vector2(40, 260))
	b._aiming = true
	b._aim_start = Vector2(40, 300)
	b._aim_now = Vector2(-20, 470)
	ms._on_aim_changed(true, b._current_power())
	await _frames(8)
	await _snap("04_mira")
	b._aiming = false
	ms._on_aim_changed(false, 0)
	b.place_coin(Vector2(-38, -430))
	ms._launch(Vector2.UP, 0.5)
	for i in 300:
		if ms.state == ms.S.GOAL:
			break
		await process_frame
	await _frames(14)
	await _snap("05_gol")
	save.settings["theme"] = "madeira"
	main.goto("match", {"mode": "local"})
	await _frames(30)
	await _snap("06_tema_madeira")
	save.settings["theme"] = "noturna"
	save.settings["coin"] = "ficha"
	main.goto("match", {"mode": "challenge", "challenge": 6})
	await _frames(30)
	await _snap("07_desafio_noturna")
	save.settings["theme"] = "campinho"
	save.settings["coin"] = "real"
	main.goto("challenges")
	await _frames(30)
	await _snap("08_desafios")
	main.goto("match", {"mode": "local"})
	await _frames(10)
	ms = main.current
	ms.score = [3, 1]
	ms._finish_match()
	await _frames(60)
	await _snap("09_resultado")
	main.goto("settings")
	await _frames(20)
	await _snap("10_ajustes")
	# Wi-Fi
	main.goto("menu")
	await _frames(30)
	await _snap("11_menu_wifi")
	save.settings["net_name"] = "Ricardo"
	main.goto("lan")
	await _frames(20)
	await _snap("12_wifi_inicio")
	main.current._create()
	await _frames(20)
	await _snap("13_wifi_sala")
	main.current._show_join()
	await _frames(5)
	main.current._code_edit.text = "1061"
	main.current._on_room_found({"ip": "192.168.4.37", "code": "1061", "name": "Ricardo"})
	await _frames(20)
	await _snap("14_wifi_entrar")
	root.get_node("Net").leave()
	var cfg: Dictionary = load("res://scripts/ui/lan_screen.gd").build_cfg("rapida", {"name": "Beto", "color": 2})
	main.goto("match", {"mode": "lan", "net_cfg": cfg, "resume": {"pos": Vector2(30, -120), "turn": 1, "score": [1, 2], "time_left": 95.0}})
	await _frames(30)
	await _snap("15_wifi_convidado_invertido")
	quit()
