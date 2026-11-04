class_name Board
extends Node2D
## Tabuleiro: desenha campo/pregos/moeda, lê o gesto de estilingue
## e roda a simulação em passo fixo. As regras ficam em match_screen.gd.

signal shot_fired(dir: Vector2, power: float)
signal coin_stopped
signal goal_scored(team: int)
signal aim_changed(active: bool, power: float)

const FRAME_SIDE := 30.0
const FRAME_END := 76.0
const MAX_PULL := 230.0
const CANCEL_PULL := 24.0
const FONT := preload("res://assets/fonts/Baloo2-ExtraBold.woff2")

var sim := CoinSim.new()
var theme_key := "campinho"
var coin_key := "real"
var team_colors: Array[Color] = [Color("1d4ed8"), Color("facc15")]
var nail_numbers := PackedInt32Array()
var nail_flash := PackedFloat32Array()

var input_enabled := false
var aim_team := 0
var aim_assist := true
var high_contrast := false

var _aiming := false
var _aim_start := Vector2.ZERO
var _aim_now := Vector2.ZERO
var _ext_aim := false          # mira "fantasma" (IA ou demonstração)
var _ext_dir := Vector2.UP
var _ext_power := 0.0
var _moving := false
var _goal_sent := false
var _acc := 0.0
var _time := 0.0
var _trail: Array[Vector2] = []
var _particles: Array[Dictionary] = []
var _shake := 0.0
var _base_pos := Vector2.ZERO
var _sb_outer: StyleBoxFlat
var _sb_inner: StyleBoxFlat
var _preview_cache := PackedVector2Array()
var _preview_key := Vector3.ZERO


func setup(nail_pts: PackedVector2Array, teams: PackedInt32Array, colors: Array[Color], theme: String, coin: String) -> void:
	sim = CoinSim.new()
	sim.setup(nail_pts, teams)
	team_colors = colors
	theme_key = theme
	coin_key = coin
	nail_flash = PackedFloat32Array()
	nail_flash.resize(nail_pts.size())
	nail_numbers = PackedInt32Array()
	var count := [0, 0]
	for t in teams:
		var tt := clampi(t, 0, 1)
		count[tt] += 1
		nail_numbers.append(count[tt])
	_build_styles()
	_trail.clear()
	_particles.clear()
	queue_redraw()


func _build_styles() -> void:
	var th: Dictionary = FieldData.THEMES[theme_key]
	_sb_outer = StyleBoxFlat.new()
	_sb_outer.bg_color = th["frame_edge"]
	_sb_outer.set_corner_radius_all(34)
	_sb_outer.shadow_color = Color(0, 0, 0, 0.45)
	_sb_outer.shadow_size = 26
	_sb_outer.shadow_offset = Vector2(0, 14)
	_sb_outer.anti_aliasing = true
	_sb_inner = StyleBoxFlat.new()
	_sb_inner.bg_color = th["frame"]
	_sb_inner.set_corner_radius_all(28)
	_sb_inner.border_color = th["frame_top"]
	_sb_inner.border_width_top = 5
	_sb_inner.border_width_left = 3
	_sb_inner.border_width_right = 3
	_sb_inner.anti_aliasing = true


func board_size() -> Vector2:
	return Vector2((FieldData.HW + FRAME_SIDE) * 2.0, (FieldData.HH + FRAME_END) * 2.0)


func fit_to(rect: Rect2) -> void:
	var bs := board_size()
	var s := minf(rect.size.x / bs.x, rect.size.y / bs.y)
	scale = Vector2(s, s)
	_base_pos = rect.get_center()
	position = _base_pos


func place_coin(p: Vector2) -> void:
	sim.pos = p
	sim.vel = Vector2.ZERO
	_moving = false
	_goal_sent = false
	_trail.clear()
	queue_redraw()


func is_moving() -> bool:
	return _moving


func launch(dir: Vector2, power: float) -> void:
	if _moving:
		return
	sim.reset_touch()
	sim.vel = dir.normalized() * CoinSim.launch_speed(power)
	_moving = true
	_goal_sent = false
	_acc = 0.0
	_ext_aim = false
	Sfx.play("launch", 0.4 + power * 0.6, 0.9 + power * 0.3)
	Save.vibrate(int(8 + power * 18))


func show_ext_aim(dir: Vector2, power: float) -> void:
	_ext_aim = true
	_ext_dir = dir.normalized()
	_ext_power = power
	queue_redraw()


func hide_ext_aim() -> void:
	_ext_aim = false
	queue_redraw()


func cancel_aim() -> void:
	if _aiming:
		_aiming = false
		aim_changed.emit(false, 0.0)
		queue_redraw()


func celebrate(team: int) -> void:
	_shake = 18.0
	var goal_y := -FieldData.HH - FieldData.GD * 0.5 if team == 0 else FieldData.HH + FieldData.GD * 0.5
	var col := team_colors[team]
	for i in 90:
		var a := randf() * TAU
		var sp := randf_range(150.0, 720.0)
		var c := [col, Color.WHITE, col.lightened(0.4), Color("facc15")][i % 4] as Color
		_particles.append({"p": Vector2(randf_range(-40, 40), goal_y), "v": Vector2.from_angle(a) * sp,
			"life": randf_range(0.9, 1.7), "max": 1.7, "c": c, "s": randf_range(4.0, 9.0), "rot": randf() * TAU, "conf": true})


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var lp := _to_local(event.position)
		if event.pressed:
			if input_enabled and not _moving and _in_board(lp):
				_aiming = true
				_aim_start = lp
				_aim_now = lp
				aim_changed.emit(true, 0.0)
				get_viewport().set_input_as_handled()
		elif _aiming:
			_aiming = false
			_aim_now = lp
			var pull := _aim_start - _aim_now
			aim_changed.emit(false, 0.0)
			if input_enabled and pull.length() >= CANCEL_PULL:
				var power := clampf(pull.length() / MAX_PULL, 0.0, 1.0)
				shot_fired.emit(pull.normalized(), power)
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _aiming:
		_aim_now = _to_local(event.position)
		aim_changed.emit(true, _current_power())
		queue_redraw()
		get_viewport().set_input_as_handled()


func _to_local(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func _in_board(lp: Vector2) -> bool:
	var bs := board_size() * 0.5
	return absf(lp.x) <= bs.x + 40.0 and absf(lp.y) <= bs.y + 40.0


func _current_power() -> float:
	var pull := _aim_start - _aim_now
	if pull.length() < CANCEL_PULL:
		return 0.0
	return clampf(pull.length() / MAX_PULL, 0.0, 1.0)


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	_time += delta
	if _moving:
		_acc += minf(delta, 0.1)
		while _acc >= CoinSim.DT and _moving:
			_acc -= CoinSim.DT
			sim.step()
			_handle_hits()
			var g := sim.goal_state()
			if g >= 0 and not _goal_sent:
				_goal_sent = true
				_moving = false
				sim.vel = Vector2.ZERO
				goal_scored.emit(g)
				break
			if not sim.is_moving():
				_moving = false
				coin_stopped.emit()
		_trail.append(sim.pos)
		if _trail.size() > 22:
			_trail.remove_at(0)
	elif not _trail.is_empty():
		_trail.remove_at(0)
	for i in nail_flash.size():
		if nail_flash[i] > 0.0:
			nail_flash[i] = maxf(0.0, nail_flash[i] - delta * 2.5)
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["life"] -= delta
		if p["life"] <= 0.0:
			_particles.remove_at(i)
			continue
		p["p"] += p["v"] * delta
		if p.get("conf", false):
			p["v"] = p["v"] * 0.96 + Vector2(0, 260) * delta
			p["rot"] += delta * 8.0
		else:
			p["v"] *= 0.9
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 40.0)
		position = _base_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * scale.x
	else:
		position = _base_pos
	queue_redraw()


func _handle_hits() -> void:
	for h: Dictionary in sim.hits:
		var s: float = h["s"]
		var vol := clampf(s / 1400.0, 0.12, 1.0)
		if h["t"] == "nail":
			var i: int = h["i"]
			nail_flash[i] = 1.0
			Sfx.play("nail", vol, randf_range(0.95, 1.08))
			if s > 420.0:
				Save.vibrate(12)
			var col := team_colors[clampi(sim.nail_team[i], 0, 1)]
			for k in 6:
				_particles.append({"p": h["p"], "v": Vector2.from_angle(randf() * TAU) * randf_range(80, 220) * vol,
					"life": 0.35, "max": 0.35, "c": col.lightened(0.5), "s": 3.0})
		else:
			Sfx.play("wall", vol, randf_range(0.9, 1.1))
			if s > 700.0:
				Save.vibrate(8)


# ------------------------------------------------------------------ desenho
func _draw() -> void:
	var th: Dictionary = FieldData.THEMES[theme_key]
	var hw := FieldData.HW
	var hh := FieldData.HH
	var gw := FieldData.GW
	var gd := FieldData.GD
	var bs := board_size()
	# moldura de madeira
	draw_style_box(_sb_outer, Rect2(-bs * 0.5, bs))
	draw_style_box(_sb_inner, Rect2(-bs * 0.5 + Vector2(6, 6), bs - Vector2(12, 16)))
	# sombra interna do campo
	draw_rect(Rect2(-hw - 4, -hh - 2, hw * 2 + 8, hh * 2 + 10), Color(0, 0, 0, 0.28))
	# gramado com faixas
	var bands := 12
	var bh := hh * 2.0 / bands
	for i in bands:
		var c: Color = th["stripe_a"] if i % 2 == 0 else th["stripe_b"]
		draw_rect(Rect2(-hw, -hh + i * bh, hw * 2.0, bh + 0.5), c)
	# bolsões dos gols (fenda na moldura)
	for s: float in [-1.0, 1.0]:
		var y0: float = hh * s
		var r := Rect2(-gw, minf(y0, y0 + gd * s), gw * 2.0, gd)
		draw_rect(r, th["goal_fill"])
		draw_rect(r.grow(-2), Color(0, 0, 0, 0.25))
		var net: Color = th["net"]
		var x := -gw + 10.0
		while x < gw:
			draw_line(Vector2(x, y0), Vector2(x, y0 + gd * s), net, 1.2)
			x += 12.0
		var yy := 10.0
		while yy < gd:
			draw_line(Vector2(-gw, y0 + yy * s), Vector2(gw, y0 + yy * s), net, 1.2)
			yy += 10.0
	# linhas do campo
	var lc: Color = th["line"]
	var lw := 5.0 if high_contrast else 3.5
	draw_rect(Rect2(-hw + 2, -hh + 2, hw * 2 - 4, hh * 2 - 4), lc, false, lw)
	draw_line(Vector2(-hw, 0), Vector2(hw, 0), lc, lw)
	draw_arc(Vector2.ZERO, 85.0, 0, TAU, 64, lc, lw, true)
	draw_circle(Vector2.ZERO, 5.0, lc)
	for s: float in [-1.0, 1.0]:
		var gy: float = hh * s
		# grande área
		var pa := Rect2(-175, gy if s < 0 else gy - 140, 350, 140)
		draw_rect(pa, lc, false, lw)
		# pequena área
		var ga := Rect2(-95, gy if s < 0 else gy - 55, 190, 55)
		draw_rect(ga, lc, false, lw)
		var spot := Vector2(0, gy - 100.0 * s)
		draw_circle(spot, 4.0, lc)
		var a0 := deg_to_rad(28.0) if s < 0 else deg_to_rad(-152.0)
		draw_arc(spot, 85.0, a0, a0 + deg_to_rad(124.0), 32, lc, lw, true)
	# cantos chanfrados (taquinhos de madeira)
	var ch := FieldData.CHAMFER
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner := Vector2(hw * sx, hh * sy)
			draw_colored_polygon(PackedVector2Array([corner, corner - Vector2(ch * sx, 0), corner - Vector2(0, ch * sy)]), th["frame"])
	# traves
	for s: float in [-1.0, 1.0]:
		for px: float in [-gw, gw]:
			var post := Vector2(px, hh * s)
			draw_circle(post + Vector2(2, 3), 6.0, Color(0, 0, 0, 0.3))
			draw_circle(post, 6.0, Color.WHITE)
			draw_circle(post, 3.0, Color("cbd5e1"))
	# pregos
	for i in sim.nails.size():
		_draw_nail(i)
	# rastro
	var tcol := team_colors[aim_team]
	for i in _trail.size():
		var k := float(i) / _trail.size()
		draw_circle(_trail[i], CoinSim.COIN_R * (0.3 + 0.6 * k), Color(tcol.r, tcol.g, tcol.b, 0.28 * k))
	# mira
	if _aiming and input_enabled:
		_draw_aim(_aim_start - _aim_now, true)
	elif _ext_aim:
		_draw_aim(_ext_dir * _ext_power * MAX_PULL, false)
	# moeda
	if input_enabled and not _moving and not _aiming:
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		draw_arc(sim.pos, CoinSim.COIN_R + 8.0 + pulse * 5.0, 0, TAU, 48, Color(tcol.r, tcol.g, tcol.b, 0.85 - pulse * 0.5), 4.0, true)
	_draw_coin(sim.pos)
	# partículas
	for p: Dictionary in _particles:
		var a: float = clampf(p["life"] / p["max"], 0.0, 1.0)
		var c: Color = p["c"]
		c.a = a
		if p.get("conf", false):
			var sz: float = p["s"]
			var tr := Transform2D(p["rot"], p["p"])
			draw_set_transform_matrix(tr)
			draw_rect(Rect2(-sz * 0.5, -sz * 0.3, sz, sz * 0.6), c)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			draw_circle(p["p"], p["s"] * a, c)


func _draw_nail(i: int) -> void:
	var p := sim.nails[i]
	var t := clampi(sim.nail_team[i], 0, 1)
	var col := team_colors[t]
	var r := CoinSim.NAIL_R + 1.0
	var fl := nail_flash[i]
	if fl > 0.0:
		draw_circle(p, r + 10.0 * fl, Color(1, 1, 1, 0.35 * fl))
	draw_circle(p + Vector2(4, 6), r, Color(0, 0, 0, 0.3))
	draw_circle(p, r + 1.5, col.darkened(0.45))
	draw_circle(p, r, col)
	if t == 1:
		# time 1: anel branco (diferença além da cor)
		draw_arc(p, r - 2.0, 0, TAU, 24, Color(1, 1, 1, 0.9), 2.0, true)
	if high_contrast:
		draw_arc(p, r + 2.5, 0, TAU, 24, Color.WHITE, 2.0, true)
	draw_circle(p + Vector2(-3.5, -4.0), 3.0, Color(1, 1, 1, 0.55))
	var txt := str(nail_numbers[i])
	var fs := 16
	var tc := Color("111827") if col.get_luminance() > 0.55 else Color.WHITE
	var w := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(FONT, p + Vector2(-w * 0.5, 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)


func _draw_coin(p: Vector2) -> void:
	var cd: Dictionary = FieldData.COINS[coin_key]
	var r := CoinSim.COIN_R
	draw_circle(p + Vector2(4, 7), r, Color(0, 0, 0, 0.35))
	draw_circle(p, r, cd["rim"])
	draw_circle(p, r - 2.5, cd["face"])
	draw_arc(p, r - 6.0, 0, TAU, 32, cd["mark"], 1.6, true)
	var rot := sim.rot
	if cd.get("ficha", false):
		# ficha telefônica: duas ranhuras
		for k: float in [-3.0, 3.0]:
			var off := Vector2(0, k).rotated(rot)
			var d := Vector2(7, 0).rotated(rot)
			draw_line(p + off - d, p + off + d, cd["rim"], 2.2, true)
	else:
		var star := PackedVector2Array()
		for k in 10:
			var rr := 6.5 if k % 2 == 0 else 2.8
			star.append(p + Vector2.from_angle(rot + k * TAU / 10.0 - PI / 2) * rr)
		draw_colored_polygon(star, cd["mark"])
	draw_arc(p, r - 1.5, deg_to_rad(200), deg_to_rad(290), 12, cd["shine"], 2.2, true)


func _draw_aim(pull: Vector2, live: bool) -> void:
	var length := pull.length()
	if length < CANCEL_PULL:
		if live:
			draw_arc(sim.pos, CoinSim.COIN_R + 14.0, 0, TAU, 40, Color(1, 1, 1, 0.5), 2.0, true)
			_draw_x(sim.pos + Vector2(0, -CoinSim.COIN_R - 30.0))
		return
	var power := clampf(length / MAX_PULL, 0.0, 1.0)
	var dir := pull / length
	var col := Color("22c55e").lerp(Color("facc15"), clampf(power * 2.0, 0, 1)).lerp(Color("ef4444"), clampf(power * 2.0 - 1.0, 0, 1))
	var c := sim.pos
	# elástico do estilingue (lado oposto ao chute)
	var back := c - dir * minf(length, MAX_PULL) * 0.55
	draw_line(c, back, Color(1, 1, 1, 0.55), 3.0, true)
	draw_circle(back, 9.0, Color(1, 1, 1, 0.35))
	draw_circle(back, 5.0, Color(1, 1, 1, 0.8))
	# prévia da trajetória
	if aim_assist:
		var v := dir * CoinSim.launch_speed(power)
		var key := Vector3(snappedf(v.x, 2.0), snappedf(v.y, 2.0), c.x + c.y * 3.0)
		if key != _preview_key:
			_preview_key = key
			_preview_cache = sim.preview(c, v)
		_draw_dotted(_preview_cache, col)
	# seta
	var tip := c + dir * (CoinSim.COIN_R + 30.0 + 95.0 * power)
	var base := c + dir * (CoinSim.COIN_R + 8.0)
	draw_line(base, tip, Color(0, 0, 0, 0.25), 11.0, true)
	draw_line(base, tip, col, 7.0, true)
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([tip + dir * 18.0, tip + side * 12.0, tip - side * 12.0]), col)
	# anel de força
	draw_arc(c, CoinSim.COIN_R + 13.0, 0, TAU, 48, Color(0, 0, 0, 0.3), 7.0, true)
	draw_arc(c, CoinSim.COIN_R + 13.0, -PI / 2, -PI / 2 + TAU * power, 48, col, 6.0, true)


func _draw_dotted(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 2:
		return
	var total := 0.0
	var next := 0.0
	var gap := 16.0
	var dots := 0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		while next <= total + seg and dots < 80:
			var p := a.lerp(b, (next - total) / maxf(seg, 0.001))
			var fade := 1.0 - float(dots) / 60.0
			draw_circle(p, 4.0, Color(1, 1, 1, 0.85 * fade))
			draw_circle(p, 2.4, Color(col.r, col.g, col.b, fade))
			next += gap
			dots += 1
		total += seg


func _draw_x(p: Vector2) -> void:
	var c := Color(1, 1, 1, 0.8)
	draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), c, 3.0, true)
	draw_line(p + Vector2(7, -7), p + Vector2(-7, 7), c, 3.0, true)
