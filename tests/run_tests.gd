extends SceneTree
## Testes automatizados. Rode:
##   godot --headless --path . --script res://tests/run_tests.gd
## Sai com código 0 se tudo passar.

var passed := 0
var failed := 0
var log_lines: Array[String] = []


func check(cond: bool, name: String, extra := "") -> void:
	if cond:
		passed += 1
		log_lines.append("  OK    " + name + (("  (" + extra + ")") if extra != "" else ""))
	else:
		failed += 1
		log_lines.append("  FALHA " + name + (("  (" + extra + ")") if extra != "" else ""))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Física ==")
	_test_physics()
	print("== Formações ==")
	_test_formations()
	print("== Desafios ==")
	_test_challenges()
	print("== IA ==")
	await _test_ai()
	print("== Interface / fluxo ==")
	await _test_flow()
	for l in log_lines:
		print(l)
	print("\nRESULTADO: %d ok, %d falhas" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _sim_full() -> CoinSim:
	var n := FieldData.build_nails("piramide", "piramide")
	var s := CoinSim.new()
	s.setup(n["pts"], n["teams"])
	return s


func _test_physics() -> void:
	# 1) gol reto para cima e para baixo
	var s := CoinSim.new()
	s.setup(PackedVector2Array(), PackedInt32Array())
	s.pos = Vector2(0, 200)
	s.vel = Vector2.UP * CoinSim.launch_speed(0.8)
	var r := s.run_until_stop()
	check(r["goal"] == 0, "gol reto no gol de cima")
	s.pos = Vector2(0, -200)
	s.vel = Vector2.DOWN * CoinSim.launch_speed(0.8)
	r = s.run_until_stop()
	check(r["goal"] == 1, "gol reto no gol de baixo")
	# 2) chute fraco para e não é gol
	s.pos = Vector2(0, 200)
	s.vel = Vector2.UP * CoinSim.launch_speed(0.05)
	r = s.run_until_stop()
	check(r["goal"] == -1 and s.vel == Vector2.ZERO, "chute fraco para antes do gol", "parou em y=%.0f" % s.pos.y)
	# 3) entrada diagonal pelo canto da trave
	var diag_goals := 0
	for k in 20:
		s.pos = Vector2(-140 + k * 14, -330)
		var target := Vector2(randf_range(-15, 15), -FieldData.HH - 30)
		s.vel = (target - s.pos).normalized() * CoinSim.launch_speed(0.7)
		r = s.run_until_stop()
		if r["goal"] == 0:
			diag_goals += 1
	check(diag_goals >= 16, "gols em diagonal detectados", "%d/20" % diag_goals)
	# 4) moeda batendo na trave (fora da boca) não conta gol
	s.pos = Vector2(FieldData.GW + 40, -300)
	s.vel = Vector2.UP * CoinSim.launch_speed(1.0)
	r = s.run_until_stop()
	check(r["goal"] == -1, "chute na linha de fundo fora do gol não é gol")
	# 5) nunca atravessa pregos / sai do campo, sempre para (500 chutes aleatórios)
	var full := _sim_full()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var max_pen := 0.0
	var out := 0
	var never_stop := 0
	var goals := 0
	var rr := CoinSim.COIN_R + CoinSim.NAIL_R
	for i in 500:
		var t := full.clone()
		t.pos = Vector2(rng.randf_range(-260, 260), rng.randf_range(-460, 460))
		var ok := true
		for j in t.nails.size():
			if t.pos.distance_to(t.nails[j]) < rr + 1:
				ok = false
		if not ok:
			continue
		t.vel = Vector2.from_angle(rng.randf() * TAU) * CoinSim.launch_speed(rng.randf())
		var steps := 0
		while steps < 1500:
			t.step()
			for j in t.nails.size():
				max_pen = maxf(max_pen, rr - t.pos.distance_to(t.nails[j]))
			if absf(t.pos.x) > FieldData.HW + 0.5 or absf(t.pos.y) > FieldData.HH + FieldData.GD + 0.5:
				out += 1
				break
			if t.goal_state() >= 0:
				goals += 1
				break
			if t.vel == Vector2.ZERO:
				break
			steps += 1
		if steps >= 1500:
			never_stop += 1
	check(max_pen < 0.5, "moeda nunca atravessa pregos", "penetração máx %.3f px" % max_pen)
	check(out == 0, "moeda nunca sai do tabuleiro", "%d saídas" % out)
	check(never_stop == 0, "moeda sempre para em < 12,5 s", "%d sem parar" % never_stop)
	log_lines.append("        (gols em 500 chutes aleatórios: %d)" % goals)
	# 6) prévia é curta (não revela várias colisões)
	var pv := full.preview(Vector2(0, 300), Vector2.UP * CoinSim.launch_speed(1.0))
	var length := 0.0
	for i in range(1, pv.size()):
		length += pv[i - 1].distance_to(pv[i])
	check(pv.size() > 2 and length < 900.0, "prévia de mira curta", "%.0f px" % length)
	# 7) determinismo (mesma entrada = mesmo resultado; base da IA justa)
	var a := full.clone()
	var b := full.clone()
	a.pos = Vector2(10, 300)
	b.pos = Vector2(10, 300)
	a.vel = Vector2(0.3, -1).normalized() * 1500
	b.vel = a.vel
	var ra := a.run_until_stop()
	var rb := b.run_until_stop()
	check(ra["pos"] == rb["pos"], "simulação determinística")


func _test_formations() -> void:
	for f0: String in FieldData.FORMATION_ORDER:
		for f1: String in FieldData.FORMATION_ORDER:
			var n := FieldData.build_nails(f0, f1)
			var pts: PackedVector2Array = n["pts"]
			var mind := 9999.0
			for i in pts.size():
				for j in range(i + 1, pts.size()):
					mind = minf(mind, pts[i].distance_to(pts[j]))
			var mouth_ok := true
			for p in pts:
				# nada a menos de 45 px da linha dentro da boca do gol
				if absf(p.x) < FieldData.GW + 15 and absf(p.y) > FieldData.HH - 45:
					mouth_ok = false
			check(pts.size() == 22 and mind >= FieldData.MIN_NAIL_GAP - 1.0 and mouth_ok,
				"formação %s x %s" % [f0, f1], "22 pregos, dist. mín %.0f" % mind)


func _test_challenges() -> void:
	for i in FieldData.CHALLENGES.size():
		var ch: Dictionary = FieldData.CHALLENGES[i]
		var n := FieldData.challenge_nails(i)
		var s := CoinSim.new()
		s.setup(n["pts"], n["teams"])
		var sols := 0
		for a in 360:
			for p: float in [0.4, 0.55, 0.7, 0.85, 1.0]:
				var t := s.clone()
				t.pos = ch["coin"]
				t.vel = Vector2.from_angle(deg_to_rad(a * 1.0)) * CoinSim.launch_speed(p)
				if t.run_until_stop()["goal"] == 0:
					sols += 1
		check(sols > 0, "desafio %d '%s' tem solução em 1 chute" % [i + 1, ch["nome"]], "%d soluções de 1800" % sols)


func _test_ai() -> void:
	var full := _sim_full()
	for lvl in 3:
		var ai := AIPlayer.new()
		var t0 := Time.get_ticks_msec()
		var base := full.clone()
		base.pos = Vector2(0, 0)
		var shot: Dictionary = await ai.choose_shot(base, 1, lvl, false, self)
		var ms := Time.get_ticks_msec() - t0
		var d: Vector2 = shot["dir"]
		check(absf(d.length() - 1.0) < 0.01 and shot["power"] > 0.0 and shot["power"] <= 1.0,
			"IA nível %d escolhe chute válido" % lvl, "%d ms no PC" % ms)
	# IA avançada contra gol aberto marca quase sempre
	var empty := CoinSim.new()
	empty.setup(PackedVector2Array([Vector2(0, 0)]), PackedInt32Array([0]))
	var hits := 0
	for k in 10:
		var ai := AIPlayer.new()
		ai.rng.seed = k
		var base := empty.clone()
		base.pos = Vector2(-60 + k * 12, 250)
		var shot: Dictionary = await ai.choose_shot(base, 1, 2, false, self)
		var t := base.clone()
		t.vel = (shot["dir"] as Vector2) * CoinSim.launch_speed(shot["power"])
		if t.run_until_stop()["goal"] == 1:
			hits += 1
	check(hits >= 7, "IA avançada converte gol livre", "%d/10" % hits)
	# Iniciante erra mais que o avançado (amostra)
	var beg := 0
	for k in 10:
		var ai := AIPlayer.new()
		ai.rng.seed = 100 + k
		var base := empty.clone()
		base.pos = Vector2(-60 + k * 12, 250)
		var shot: Dictionary = await ai.choose_shot(base, 1, 0, false, self)
		var t := base.clone()
		t.vel = (shot["dir"] as Vector2) * CoinSim.launch_speed(shot["power"])
		if t.run_until_stop()["goal"] == 1:
			beg += 1
	check(beg <= hits, "iniciante acerta menos ou igual ao avançado", "iniciante %d/10" % beg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _drag(board: Board, from_local: Vector2, to_local: Vector2) -> void:
	var xf := board.get_global_transform_with_canvas()
	var vp := root
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = xf * from_local
	vp.push_input(e, true)
	await _frames(2)
	for k in 6:
		var m := InputEventMouseMotion.new()
		m.position = xf * from_local.lerp(to_local, (k + 1) / 6.0)
		vp.push_input(m, true)
		await _frames(1)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = xf * to_local
	vp.push_input(u, true)
	await _frames(2)


func _wait_state(ms: Node, st: int, max_frames := 1800) -> bool:
	for i in max_frames:
		if ms.state == st:
			return true
		await process_frame
	return false


func _test_flow() -> void:
	var save: Node = root.get_node("Save")
	save.settings["tutorial_seen"] = false
	save.settings["sound"] = false
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	check(main.current_name == "menu", "menu abre")
	for scr in ["setup", "challenges", "settings", "help", "menu"]:
		main.goto(scr, {"mode": "cpu"})
		await _frames(4)
		check(main.current != null and main.current_name == scr, "tela '%s' abre" % scr)

	# ---- partida local 2 jogadores, gesto real de arrastar
	save.match_cfg["rules"] = "rapida"
	main.goto("match", {"mode": "local"})
	await _frames(6)
	var ms: Node = main.current
	var board: Board = ms.board
	check(ms.state == ms.S.AIM and board.input_enabled, "partida começa aguardando o chute")
	check(ms._coach != null, "tutorial aparece no primeiro acesso")
	# arrasto curto = cancelado
	var c := board.sim.pos
	await _drag(board, c + Vector2(0, 40), c + Vector2(0, 50))
	check(not board.is_moving() and ms.state == ms.S.AIM, "arrasto curto cancela (não chuta)")
	# arrasto para BAIXO -> moeda vai para CIMA (corredor livre em x=-60)
	board.place_coin(Vector2(-55, 290))
	c = board.sim.pos
	await _drag(board, c + Vector2(0, 40), c + Vector2(0, 200))
	check(ms.state == ms.S.MOVING, "arrasto longo dispara")
	check(board.sim.vel.y < 0.0, "puxar para baixo lança para cima (sentido oposto)", "vy=%.0f" % board.sim.vel.y)
	check(ms._coach == null and save.settings["tutorial_seen"], "tutorial some após 1º chute")
	# toque durante o movimento é ignorado
	var v_before := board.sim.vel
	await _drag(board, board.sim.pos + Vector2(40, 0), board.sim.pos + Vector2(200, 0))
	check(board.sim.vel.dot(v_before) > 0 or board.sim.vel == Vector2.ZERO, "toque durante a jogada é ignorado")
	var stopped := false
	for i in 2400:
		if ms.state == ms.S.AIM or ms.state == ms.S.GOAL:
			stopped = true
			break
		await process_frame
	check(stopped, "moeda para e próxima jogada começa")
	check(ms.turn == 1 or ms.score[0] + ms.score[1] > 0, "vez passa para o outro time")
	# gol forçado: coloca a moeda na boca do gol de cima e chuta reto
	await _wait_state(ms, ms.S.AIM)
	board.place_coin(Vector2(0, -FieldData.HH + 60))
	ms.turn = 0
	ms._launch(Vector2.UP, 0.6)
	var got := await _wait_state(ms, ms.S.GOAL, 600)
	check(got, "gol detectado na partida")
	await _wait_state(ms, ms.S.AIM, 600)
	check(ms.score[0] >= 1 and ms.turn == 1 and board.sim.pos == Vector2.ZERO, "placar soma, moeda ao centro, quem sofreu sai jogando")
	# pausa
	ms._pause()
	await _frames(3)
	check(paused and ms.paused and ms._overlay != null, "pausa congela o jogo")
	ms._resume()
	await _frames(2)
	check(not paused and not ms.paused, "retomar funciona")
	ms.on_app_paused()
	await _frames(2)
	check(ms.paused, "sair do app pausa automaticamente")
	ms._resume()
	# vitória: força 3 gols
	for g in 2:
		await _wait_state(ms, ms.S.AIM, 600)
		board.place_coin(Vector2(0, -FieldData.HH + 60))
		ms.turn = 0
		ms._launch(Vector2.UP, 0.6)
		await _wait_state(ms, ms.S.GOAL, 600)
	var over := await _wait_state(ms, ms.S.OVER, 600)
	await _frames(40)
	check(over and ms._overlay != null, "partida termina com tela de resultado", "placar %d x %d" % [ms.score[0], ms.score[1]])
	# revanche
	main.goto("match", {"mode": "local"})
	await _frames(5)
	check(main.current.score == [0, 0] and main.current.state == main.current.S.AIM, "revanche reinicia a partida")

	# ---- contra CPU: CPU joga sozinha
	main.goto("match", {"mode": "cpu"})
	await _frames(5)
	ms = main.current
	board = ms.board
	ms.turn = 1
	ms._start_turn()
	check(ms.state == ms.S.AI, "CPU assume a vez")
	var moved := await _wait_state(ms, ms.S.MOVING, 20000)
	check(moved, "CPU mira e chuta")
	# tempo esgotado com empate -> gol de ouro
	await _wait_state(ms, ms.S.AIM, 2400)
	ms.score = [1, 1]
	ms.time_left = 0.05
	await _frames(10)
	check(ms.golden, "fim de tempo empatado ativa gol de ouro")

	# ---- treino e desafio
	main.goto("match", {"mode": "training"})
	await _frames(5)
	ms = main.current
	ms._place_training(Vector2(0, -FieldData.HH + 100))
	check(ms.board.sim.pos.y < -300, "treino: botão pênalti posiciona a moeda")
	ms.board.place_coin(Vector2(-40, -420))
	ms._launch(Vector2.UP, 0.5)
	await _wait_state(ms, ms.S.GOAL, 600)
	var back := await _wait_state(ms, ms.S.AIM, 600)
	check(back and ms.board.sim.pos == Vector2.ZERO, "treino: gol reinicia no centro")

	main.goto("match", {"mode": "challenge", "challenge": 0})
	await _frames(5)
	ms = main.current
	ms._launch(Vector2.UP, 0.8)
	var done := await _wait_state(ms, ms.S.OVER, 900)
	check(done and save.challenge_stars[0] >= 1, "desafio 1 concluído e estrelas salvas", "%d estrelas" % save.challenge_stars[0])
	await _frames(40)
	check(save.challenge_unlocked(1), "desafio 2 desbloqueado")
	main.goto("menu")
	await _frames(5)
	main.queue_free()
	await _frames(2)
