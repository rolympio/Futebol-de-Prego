extends Control
## Tela de partida: regras, turnos, IA, HUD, gol, pausa e resultado.
## Modos: "cpu", "local", "training", "challenge".

enum S { AIM, MOVING, AI, GOAL, OVER }

var main: Control
var params := {}

var mode := "cpu"
var cfg: Dictionary
var board: Board
var ai := AIPlayer.new()
var state := S.AIM
var turn := 0
var score := [0, 0]
var goals_to_win := 3
var time_limit := 0.0
var time_left := 0.0
var time_up := false
var golden := false
var continue_own := false
var extra_used := 0
var shots_left := 0
var shots_taken := 0
var challenge_idx := 0
var paused := false
var _token := 0

# HUD
var _hud: Control
var _top: PanelContainer
var _name_lbl: Array[Label] = []
var _score_lbl: Array[Label] = []
var _center_lbl: Label
var _banner: PanelContainer
var _banner_lbl: Label
var _hint: Label
var _power_bar: ProgressBar
var _bottom: HBoxContainer
var _coach: Control
var _overlay: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode = params.get("mode", "cpu")
	challenge_idx = int(params.get("challenge", 0))
	cfg = Save.match_cfg.duplicate()
	if mode == "local" or mode == "cpu":
		if cfg["rules"] == "rapida":
			goals_to_win = 3
			time_limit = 180.0
			continue_own = false
		else:
			goals_to_win = int(cfg["goals"])
			time_limit = float(cfg["time"])
			continue_own = bool(cfg["continue_own"])
	time_left = time_limit

	# fundo
	var bg := ColorRect.new()
	bg.color = Color("1a1446")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var glow := preload("res://scripts/ui/background.gd").new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.modulate.a = 0.6
	add_child(glow)

	board = Board.new()
	board.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(board)
	board.shot_fired.connect(_on_shot_fired)
	board.coin_stopped.connect(_on_coin_stopped)
	board.goal_scored.connect(_on_goal)
	board.aim_changed.connect(_on_aim_changed)
	board.aim_assist = Save.settings["aim_assist"]
	board.high_contrast = Save.settings["high_contrast"]

	_build_hud()
	resized.connect(_layout)
	_start()
	_layout.call_deferred()


func _exit_tree() -> void:
	get_tree().paused = false
	_token += 1


# ------------------------------------------------------------------ início
func _start() -> void:
	_token += 1
	score = [0, 0]
	time_left = time_limit
	time_up = false
	golden = false
	extra_used = 0
	shots_taken = 0
	turn = 0
	var cols: Array[Color] = [Save.team_color(0), Save.team_color(1)]
	var nails: Dictionary
	var start := Vector2.ZERO
	match mode:
		"challenge":
			nails = FieldData.challenge_nails(challenge_idx)
			var ch: Dictionary = FieldData.CHALLENGES[challenge_idx]
			start = ch["coin"]
			shots_left = int(ch["shots"])
		"training":
			nails = FieldData.build_nails(cfg["form0"], cfg["form1"])
		_:
			nails = FieldData.build_nails(cfg["form0"], cfg["form1"])
	board.setup(nails["pts"], nails["teams"], cols, Save.settings["theme"], Save.settings["coin"])
	board.place_coin(start)
	_update_hud()
	Sfx.play("whistle", 0.7)
	if not Save.settings["tutorial_seen"]:
		_show_coach()
	_start_turn()


func _start_turn() -> void:
	_update_hud()
	if state == S.OVER:
		return
	if mode == "cpu" and turn == 1:
		_ai_turn()
		return
	state = S.AIM
	board.aim_team = turn
	board.input_enabled = true
	_show_banner()


func _ai_turn() -> void:
	state = S.AI
	board.aim_team = 1
	board.input_enabled = false
	_show_banner()
	var tok := _token
	var t0 := Time.get_ticks_msec()
	var shot: Dictionary = await ai.choose_shot(board.sim.clone(), 1, int(cfg["difficulty"]), continue_own, get_tree())
	while is_inside_tree() and tok == _token and (paused or Time.get_ticks_msec() - t0 < 650):
		await get_tree().process_frame
	if not is_inside_tree() or tok != _token:
		return
	# anima a mira da CPU para o jogador ler a jogada
	var dir: Vector2 = shot["dir"]
	var pw: float = shot["power"]
	var steps := 24
	_power_bar.visible = true
	for i in steps + 1:
		board.show_ext_aim(dir, pw * float(i) / steps)
		_power_bar.value = pw * float(i) / steps * 100.0
		await get_tree().process_frame
		while paused and is_inside_tree():
			await get_tree().process_frame
		if not is_inside_tree() or tok != _token:
			return
	await get_tree().create_timer(0.18, false).timeout
	if not is_inside_tree() or tok != _token:
		return
	board.hide_ext_aim()
	_power_bar.value = 0
	_power_bar.visible = false
	_launch(dir, pw)


# ------------------------------------------------------------------ eventos
func _on_shot_fired(dir: Vector2, power: float) -> void:
	if state != S.AIM or paused:
		return
	_launch(dir, power)
	if _coach:
		_coach.queue_free()
		_coach = null
		Save.settings["tutorial_seen"] = true
		Save.save_all()


func _launch(dir: Vector2, power: float) -> void:
	board.input_enabled = false
	state = S.MOVING
	shots_taken += 1
	if mode == "challenge":
		shots_left -= 1
	board.launch(dir, power)
	_update_hud()
	_hint.text = ""


func _on_aim_changed(active: bool, power: float) -> void:
	_power_bar.visible = active or state == S.AI
	_power_bar.value = power * 100.0
	if active:
		_hint.text = "Força %d%%  •  volte ao início para cancelar" % int(power * 100) if power > 0.0 else "Puxe para trás"
	elif state == S.AIM:
		_set_aim_hint()


func _on_coin_stopped() -> void:
	if state != S.MOVING:
		return
	match mode:
		"training":
			_start_turn()
		"challenge":
			if shots_left <= 0:
				_finish_challenge(false)
			else:
				_start_turn()
		_:
			if time_up and not golden:
				if _resolve_time_up():
					return
			var mask := board.sim.touched_mask
			var mine := 1 << turn
			var other := 1 << (1 - turn)
			if continue_own and (mask & mine) != 0 and (mask & other) == 0 and extra_used < 2:
				extra_used += 1
				_flash_text("JOGA DE NOVO!", Save.team_color(turn), 54)
			else:
				extra_used = 0
				turn = 1 - turn
			_start_turn()


func _on_goal(team: int) -> void:
	state = S.GOAL
	board.input_enabled = false
	board.celebrate(team)
	Sfx.play("goal", 1.0)
	Save.vibrate(140)
	var tok := _token
	match mode:
		"training":
			_flash_text("GOOOL!", Save.team_color(team), 110)
			await get_tree().create_timer(1.5, false).timeout
			if tok != _token or not is_inside_tree():
				return
			board.place_coin(Vector2.ZERO)
			_start_turn()
		"challenge":
			_flash_text("GOOOL!" if team == 0 else "GOL CONTRA!", Save.team_color(0) if team == 0 else Color("ef4444"), 110)
			await get_tree().create_timer(1.4, false).timeout
			if tok != _token or not is_inside_tree():
				return
			_finish_challenge(team == 0)
		_:
			score[team] += 1
			_update_hud()
			_flash_text("GOOOL!", Save.team_color(team), 120, str(cfg["name%d" % team]).to_upper())
			await get_tree().create_timer(1.8, false).timeout
			if tok != _token or not is_inside_tree():
				return
			if golden or (goals_to_win > 0 and score[team] >= goals_to_win):
				_finish_match()
				return
			if time_up and _resolve_time_up():
				return
			board.place_coin(Vector2.ZERO)
			turn = 1 - team   # quem sofreu o gol sai jogando
			extra_used = 0
			_start_turn()


## Retorna true se a partida terminou.
func _resolve_time_up() -> bool:
	if score[0] != score[1]:
		_finish_match()
		return true
	if not golden:
		golden = true
		_flash_text("GOL DE OURO!", UIKit.ACCENT, 80, "quem marcar vence")
		_update_hud()
	return false


func _process(delta: float) -> void:
	if paused or state == S.OVER:
		return
	if time_limit > 0.0 and not time_up and (mode == "cpu" or mode == "local"):
		if state != S.GOAL:
			time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			time_up = true
			Sfx.play("whistle", 0.8)
			if state == S.AIM or state == S.AI:
				_resolve_time_up()
		_update_timer()
	if _coach:
		_coach.queue_redraw()


# ------------------------------------------------------------------ fim
func _finish_match() -> void:
	state = S.OVER
	_token += 1
	board.input_enabled = false
	board.hide_ext_aim()
	var winner := 0 if score[0] > score[1] else (1 if score[1] > score[0] else -1)
	Save.stats["matches"] += 1
	Save.stats["goals"] += score[0]
	var title := ""
	var col := UIKit.ACCENT
	if mode == "cpu":
		if winner == 0:
			title = "VITÓRIA!"
			Save.stats["wins_cpu"] += 1
			Sfx.play("goal")
		else:
			title = "DERROTA"
			col = Color("f87171")
			Save.stats["losses_cpu"] += 1
			Sfx.play("lose")
	else:
		title = ("%s VENCEU!" % str(cfg["name%d" % winner]).to_upper()) if winner >= 0 else "EMPATE"
		col = Save.team_color(winner) if winner >= 0 else Color.WHITE
		Sfx.play("whistle")
	Save.save_all()
	_show_result(title, col, "%d  x  %d" % [score[0], score[1]], [
		["REVANCHE", UIKit.GREEN, func() -> void: main.goto("match", params)],
		["MENU", Color("475569"), func() -> void: main.goto("menu")],
	])


func _finish_challenge(ok: bool) -> void:
	state = S.OVER
	_token += 1
	board.input_enabled = false
	if ok:
		var stars := clampi(shots_left + 1, 1, 3)
		Save.challenge_stars[challenge_idx] = maxi(int(Save.challenge_stars[challenge_idx]), stars)
		Save.save_all()
		var btns: Array = []
		if challenge_idx + 1 < FieldData.CHALLENGES.size():
			btns.append(["PRÓXIMO", UIKit.GREEN, func() -> void: main.goto("match", {"mode": "challenge", "challenge": challenge_idx + 1})])
		btns.append(["REPETIR", UIKit.BLUE, func() -> void: main.goto("match", params)])
		btns.append(["DESAFIOS", Color("475569"), func() -> void: main.goto("challenges")])
		_show_result("DESAFIO CONCLUÍDO!", UIKit.ACCENT, "", btns, stars)
	else:
		Sfx.play("lose")
		_show_result("QUASE!", Color("f87171"), "Acabaram os chutes", [
			["TENTAR DE NOVO", UIKit.GREEN, func() -> void: main.goto("match", params)],
			["DESAFIOS", Color("475569"), func() -> void: main.goto("challenges")],
		])


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	_top = PanelContainer.new()
	var sb := UIKit.box(Color(0.06, 0.04, 0.2, 0.85), 30, 12, 2, Color(1, 1, 1, 0.12))
	sb.content_margin_left = 14
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_top.add_theme_stylebox_override("panel", sb)
	_hud.add_child(_top)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_top.add_child(h)
	var pause_btn := UIKit.icon_button("II", Color("6366f1"), _toggle_pause, 76)
	h.add_child(pause_btn)

	if mode == "cpu" or mode == "local":
		for t in 2:
			var team := HBoxContainer.new()
			team.add_theme_constant_override("separation", 8)
			team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var chip := _chip(t)
			var nm := UIKit.label(str(cfg["name%d" % t]).to_upper(), 22, Color(1, 1, 1, 0.85), true)
			nm.autowrap_mode = TextServer.AUTOWRAP_OFF
			nm.clip_text = true
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if t == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			var sc := UIKit.outlined(UIKit.label("0", 58, Color.WHITE, true), 8)
			_name_lbl.append(nm)
			_score_lbl.append(sc)
			if t == 0:
				team.add_child(chip)
				team.add_child(nm)
				team.add_child(sc)
				h.add_child(team)
				_center_lbl = UIKit.label("3:00", 34, UIKit.ACCENT, true)
				_center_lbl.custom_minimum_size = Vector2(110, 0)
				h.add_child(_center_lbl)
			else:
				team.add_child(sc)
				team.add_child(nm)
				team.add_child(chip)
				h.add_child(team)
	else:
		_center_lbl = UIKit.label("", 32, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
		_center_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_center_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_center_lbl.clip_text = true
		h.add_child(_center_lbl)

	_banner = PanelContainer.new()
	_banner_lbl = UIKit.label("", 28, Color.WHITE, true)
	_banner_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_banner.add_child(_banner_lbl)
	_hud.add_child(_banner)

	_hint = UIKit.label("", 24, Color(1, 1, 1, 0.8))
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hud.add_child(_hint)

	_power_bar = ProgressBar.new()
	_power_bar.show_percentage = false
	_power_bar.custom_minimum_size = Vector2(0, 16)
	_power_bar.add_theme_stylebox_override("background", UIKit.box(Color(1, 1, 1, 0.15), 8))
	var fill := UIKit.box(UIKit.ACCENT, 8)
	_power_bar.add_theme_stylebox_override("fill", fill)
	_power_bar.visible = false
	_hud.add_child(_power_bar)

	if mode == "training":
		_bottom = HBoxContainer.new()
		_bottom.add_theme_constant_override("separation", 12)
		var b1 := UIKit.button("CENTRO", UIKit.BLUE, func() -> void: _place_training(Vector2.ZERO), 26, 76)
		var b2 := UIKit.button("PÊNALTI", UIKit.ORANGE, func() -> void: _place_training(Vector2(0, -FieldData.HH + 100)), 26, 76)
		var b3 := UIKit.button("LATERAL", UIKit.PINK, func() -> void: _place_training(Vector2(-200, -250)), 26, 76)
		for b in [b1, b2, b3]:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_bottom.add_child(b)
		_hud.add_child(_bottom)


func _chip(t: int) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(30, 30)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var col := Save.team_color(t)
	var sb := UIKit.box(col, 15, 0, 4 if t == 1 else 0, Color.WHITE)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _layout() -> void:
	if board == null:
		return
	var vs := size
	var sm := UIKit.safe_margins(get_viewport())
	var top_y: float = 14.0 + sm["top"]
	_top.position = Vector2(16, top_y)
	_top.size = Vector2(vs.x - 32, 92)
	var bottom_reserved: float = 64.0 + sm["bottom"] + (90.0 if _bottom else 0.0)
	var field_top: float = top_y + 92.0 + 58.0
	var rect := Rect2(12, field_top, vs.x - 24, vs.y - field_top - bottom_reserved)
	board.fit_to(rect)
	_banner.position.y = top_y + 100.0
	_center_banner()
	_hint.position = Vector2(0, vs.y - bottom_reserved + 10.0)
	_hint.size = Vector2(vs.x, 40)
	_power_bar.position = Vector2(vs.x * 0.25, vs.y - bottom_reserved + 50.0)
	_power_bar.size = Vector2(vs.x * 0.5, 14)
	if _bottom:
		_bottom.position = Vector2(24, vs.y - sm["bottom"] - 92.0)
		_bottom.size = Vector2(vs.x - 48, 76)


func _center_banner() -> void:
	_banner.reset_size()
	_banner.position.x = (size.x - _banner.size.x) * 0.5


func _show_banner() -> void:
	var text := ""
	var col := Save.team_color(turn)
	match mode:
		"training":
			text = "TREINO LIVRE"
			col = UIKit.ORANGE
		"challenge":
			text = FieldData.CHALLENGES[challenge_idx]["dica"]
			col = UIKit.PINK
		"cpu":
			text = "SUA VEZ  •  ataque para cima" if turn == 0 else "VEZ DA CPU"
		_:
			text = "VEZ DO %s  •  ataca para %s" % [str(cfg["name%d" % turn]).to_upper(), "cima" if turn == 0 else "baixo"]
	if golden:
		text = "GOL DE OURO  •  " + text
	_banner_lbl.text = text
	var tc := UIKit.INK if col.get_luminance() > 0.6 else Color.WHITE
	_banner_lbl.add_theme_color_override("font_color", tc)
	var sb := UIKit.box(col, 24, 8)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	_banner.add_theme_stylebox_override("panel", sb)
	_center_banner()
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.8, 0.8)
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_aim_hint()


func _set_aim_hint() -> void:
	if state == S.AI:
		_hint.text = "A CPU está mirando..."
	elif state == S.AIM:
		_hint.text = "Toque, PUXE PARA TRÁS e solte"
	else:
		_hint.text = ""


func _update_hud() -> void:
	for t in _score_lbl.size():
		_score_lbl[t].text = str(score[t])
	match mode:
		"training":
			_center_lbl.text = "TREINO  •  chutes: %d" % shots_taken
		"challenge":
			_center_lbl.text = "%d. %s  •  chutes: %d" % [challenge_idx + 1, FieldData.CHALLENGES[challenge_idx]["nome"], maxi(shots_left, 0)]
		_:
			_update_timer()


func _update_timer() -> void:
	if _center_lbl == null or not (mode == "cpu" or mode == "local"):
		return
	if golden:
		_center_lbl.text = "OURO"
	elif time_limit <= 0.0:
		_center_lbl.text = "a %d" % goals_to_win if goals_to_win > 0 else "--"
	else:
		var s := int(ceil(time_left))
		_center_lbl.text = "%d:%02d" % [s / 60, s % 60]


func _flash_text(text: String, col: Color, size_px: int, sub := "") -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.outlined(UIKit.label(text, size_px, col if col.get_luminance() > 0.5 else col.lightened(0.35), true), 22, Color("0f0c29"))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(l)
	if sub != "":
		box.add_child(UIKit.outlined(UIKit.label(sub, 34, Color.WHITE, true), 10, Color("0f0c29")))
	_hud.add_child(box)
	box.reset_size()
	box.position = (size - box.size) * 0.5
	box.pivot_offset = box.size * 0.5
	box.scale = Vector2(0.3, 0.3)
	box.rotation = -0.08
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "rotation", 0.0, 0.35)
	tw.tween_interval(0.8)
	tw.tween_property(box, "modulate:a", 0.0, 0.35)
	tw.tween_callback(box.queue_free)


func _place_training(p: Vector2) -> void:
	if state == S.MOVING or state == S.GOAL:
		return
	board.place_coin(p)
	_start_turn()


# ------------------------------------------------------------------ pausa
func _toggle_pause() -> void:
	if state == S.OVER:
		return
	if paused:
		_resume()
	else:
		_pause()


func _pause() -> void:
	if paused or state == S.OVER:
		return
	paused = true
	board.cancel_aim()
	get_tree().paused = true
	var progress := mode == "cpu" or mode == "local"
	_overlay = _panel_overlay("PAUSA", [
		["CONTINUAR", UIKit.GREEN, _resume],
		["REINICIAR", UIKit.BLUE, func() -> void:
			if progress and (score[0] + score[1] > 0 or time_left < time_limit - 5.0):
				UIKit.confirm(_overlay, "Reiniciar a partida? O placar atual será perdido.", "REINICIAR", func() -> void: main.goto("match", params))
			else:
				main.goto("match", params)],
		["SAIR PARA O MENU", Color("ef4444"), func() -> void:
			if progress and (score[0] + score[1] > 0 or time_left < time_limit - 5.0):
				UIKit.confirm(_overlay, "Abandonar a partida? O progresso não será salvo.", "SAIR", func() -> void: main.goto("menu"))
			else:
				main.goto("menu")],
	], _rules_summary())


func _resume() -> void:
	if not paused:
		return
	paused = false
	get_tree().paused = false
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _rules_summary() -> String:
	match mode:
		"training":
			return "Treino livre: sem placar. Use os botões para posicionar a moeda."
		"challenge":
			return "Desafio: marque no gol de cima em até %d chutes." % int(FieldData.CHALLENGES[challenge_idx]["shots"])
	var parts: Array[String] = []
	parts.append("Regras %s" % ("rápidas" if cfg["rules"] == "rapida" else "clássicas"))
	parts.append(("vence quem fizer %d" % goals_to_win) if goals_to_win > 0 else "sem limite de gols")
	parts.append(("%d min" % int(time_limit / 60)) if time_limit > 0 else "sem tempo")
	if continue_own:
		parts.append("prego do próprio time = nova jogada")
	return "  •  ".join(parts)


func on_app_paused() -> void:
	if state != S.OVER:
		_pause()


func on_back() -> void:
	if state == S.OVER:
		main.goto("menu")
	elif paused:
		_resume()
	else:
		_pause()


# ------------------------------------------------------------------ overlays
func _panel_overlay(title: String, buttons: Array, subtitle := "", big := "") -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.12, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var sb := UIKit.box(Color("1e1b4b"), 40, 30, 3, Color(1, 1, 1, 0.15))
	sb.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(minf(size.x - 60, 600), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)
	v.add_child(UIKit.outlined(UIKit.label(title, 64, UIKit.ACCENT, true), 12))
	if big != "":
		v.add_child(UIKit.label(big, 72, Color.WHITE, true))
	if subtitle != "":
		v.add_child(UIKit.label(subtitle, 24, Color(1, 1, 1, 0.75)))
	for b: Array in buttons:
		v.add_child(UIKit.button(b[0], b[1], b[2], 32, 92))
	UIKit.pop_in(panel)
	return dim


func _show_result(title: String, col: Color, big: String, buttons: Array, stars := -1) -> void:
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	var o := _panel_overlay(title, buttons, _rules_summary() if mode in ["cpu", "local"] else "", big)
	var lbl := o.get_child(0).get_child(0).get_child(0).get_child(0) as Label
	if lbl:
		lbl.add_theme_color_override("font_color", col if col.get_luminance() > 0.5 else col.lightened(0.45))
	if stars >= 0:
		var row := preload("res://scripts/ui/star_row.gd").new()
		row.set("stars", stars)
		row.custom_minimum_size = Vector2(0, 110)
		var v := lbl.get_parent()
		v.add_child(row)
		v.move_child(row, 1)
	_overlay = o


func _show_coach() -> void:
	_coach = preload("res://scripts/game/coach.gd").new()
	_coach.set("board", board)
	_coach.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_coach)
