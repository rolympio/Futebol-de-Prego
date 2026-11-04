extends SceneTree
## Teste de rede com DOIS processos reais (servidor e convidado).
## Use tests/net_test.sh, que roda os dois e confere os registros.
##   godot --headless --path . --script res://tests/net_test.gd -- host <arquivo_codigo>
##   godot --headless --path . --script res://tests/net_test.gd -- client <arquivo_codigo>

var role := "host"
var code_file := ""
var main: Control
var save: Node
var net: Node
var rng := RandomNumberGenerator.new()
var max_diff := 0.0
var shots := 0
var last_line := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	role = a[0]
	code_file = a[1]
	rng.seed = 7 if role == "host" else 11
	_run.call_deferred()


func say(t: String) -> void:
	print("NET|%s|%s" % [role, t])


func _f(n := 1) -> void:
	for i in n:
		await process_frame


func _ms() -> Node:
	return main.current if main and main.current_name == "match" else null


func _wait(cond: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		if cond.call():
			return true
		await process_frame
	return false


func _run() -> void:
	save = root.get_node("Save")
	net = root.get_node("Net")
	save.settings["sound"] = false
	save.settings["vibration"] = false
	save.settings["tutorial_seen"] = true
	save.settings["net_name"] = "Ana" if role == "host" else "Beto"
	save.settings["net_color"] = 0 if role == "host" else 0   # cor repetida de propósito
	save.match_cfg["rules"] = "rapida"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _f(3)
	main.goto("lan")
	await _f(3)
	say("local_ip|%s" % net.local_ip())
	if role == "host":
		await _host()
	else:
		await _client()
	say("fim")
	quit()


# ------------------------------------------------------------------ servidor
func _host() -> void:
	var lobby: Node = main.current
	lobby._create()
	var code: String = net.code_from_ip(net.host_ip)
	say("codigo|%s" % code)
	var f := FileAccess.open(code_file, FileAccess.WRITE)
	f.store_string(code)
	f.close()
	if not await _wait(func() -> bool: return _ms() != null, 30):
		say("ERRO|cliente não entrou")
		return
	var ms := _ms()
	say("partida|cores %d x %d|nomes %s x %s" % [ms.cfg["color0"], ms.cfg["color1"], ms.cfg["name0"], ms.cfg["name1"]])
	var saw_wait := false
	var goals_forced := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 150000:
		ms = _ms()
		if ms == null:
			await _f()
			continue
		if ms._net_wait and not saw_wait:
			saw_wait = true
			say("aguardando_reconexao|placar %d-%d" % [ms.score[0], ms.score[1]])
		if saw_wait and not ms._net_wait and ms.state != ms.S.OVER and not has_meta("resumed"):
			set_meta("resumed", true)
			say("retomou|placar %d-%d" % [ms.score[0], ms.score[1]])
		if ms.state == ms.S.OVER:
			say("fim_partida|placar %d-%d" % [ms.score[0], ms.score[1]])
			break
		if ms.state == ms.S.AIM and ms.turn == 0:
			await _f(10)
			if ms.state != ms.S.AIM:
				continue
			shots += 1
			# a partir do 2º chute, força gols para terminar a partida
			if shots >= 2:
				ms.board.place_coin(Vector2(-40, -420))
				ms._on_shot_fired(Vector2.UP, 0.5)
				goals_forced += 1
			else:
				ms._on_shot_fired(Vector2.from_angle(rng.randf_range(-2.4, -0.7)), rng.randf_range(0.3, 0.8))
			say("chute_host|%d" % shots)
		await _f()
	# revanche
	ms = _ms()
	if ms:
		await _f(60)
		ms._request_rematch()
		var ok := await _wait(func() -> bool:
			var m := _ms()
			return m != null and m != ms and m.score == [0, 0], 20)
		say("revanche|%s" % ("ok" if ok else "falhou"))
		await _f(30)
		_ms()._quit_net()
		await _f(30)


# ------------------------------------------------------------------ convidado
func _client() -> void:
	if not await _wait(func() -> bool: return FileAccess.file_exists(code_file) and FileAccess.get_file_as_string(code_file) != "", 30):
		say("ERRO|sem código")
		return
	var code := FileAccess.get_file_as_string(code_file)
	var lobby: Node = main.current
	lobby._show_join()
	await _f(2)
	lobby._code_edit.text = code
	lobby._join_code()
	say("entrando|codigo %s -> %s" % [code, net.ip_from_code(code)])
	if not await _wait(func() -> bool: return _ms() != null, 20):
		say("ERRO|não entrou na partida")
		return
	var ms := _ms()
	say("partida|cores %d x %d|tabuleiro_invertido %s" % [ms.cfg["color0"], ms.cfg["color1"], ms.board.flip])
	# confere determinismo: posição local x posição oficial do servidor
	net.message.connect(func(type: String, d: Dictionary) -> void:
		var m := _ms()
		if type == "turn" and m and d.has("pos"):
			var diff: float = m.board.sim.pos.distance_to(d["pos"])
			max_diff = maxf(max_diff, diff)
		if type == "goal":
			say("gol_recebido|time %d|placar %s" % [d["team"], str(d["score"])]))
	var dropped := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 150000:
		ms = _ms()
		if ms == null:
			await _f()
			continue
		if ms.state == ms.S.OVER:
			say("fim_partida|placar %d-%d|maior_diferenca %.4f" % [ms.score[0], ms.score[1], max_diff])
			break
		if ms.state == ms.S.AIM and ms.turn == 1:
			await _f(10)
			if ms.state != ms.S.AIM:
				continue
			if shots == 2 and not dropped:
				# simula queda do Wi-Fi no meio da partida
				dropped = true
				say("derrubando_conexao|placar %d-%d" % [ms.score[0], ms.score[1]])
				net.leave(false)
				await _f(90)
				net.join_room(net.host_ip)
				var back := await _wait(func() -> bool:
					var m := _ms()
					return m != null and m != ms and m.params.has("resume") and not (m.params["resume"] as Dictionary).is_empty(), 20)
				say("reconectou|%s|placar %s" % ["ok" if back else "falhou", str(_ms().score) if _ms() else "?"])
				continue
			shots += 1
			ms._on_shot_fired(Vector2.from_angle(rng.randf_range(0.7, 2.4)), rng.randf_range(0.3, 0.8))
			say("chute_cliente|%d" % shots)
		await _f()
	ms = _ms()
	if ms:
		ms._request_rematch()
		var ok := await _wait(func() -> bool:
			var m := _ms()
			return m != null and m != ms and m.score == [0, 0], 20)
		say("revanche|%s" % ("ok" if ok else "falhou"))
		var bye := await _wait(func() -> bool:
			var m := _ms()
			return m != null and m._opponent_quit, 20)
		say("adversario_saiu_detectado|%s" % ("ok" if bye else "falhou"))
