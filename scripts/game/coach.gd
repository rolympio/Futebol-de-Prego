extends Control
## Tutorial interativo do primeiro acesso: mostra um dedo puxando a moeda
## para trás e a seta apontando para o lado oposto. Some no primeiro chute.

const FONT := preload("res://assets/fonts/Baloo2-ExtraBold.woff2")
var board: Board
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta


func _draw() -> void:
	if board == null:
		return
	var xf := board.get_global_transform_with_canvas()
	var coin := xf * board.sim.pos
	var k := board.scale.x
	var cyc := fmod(_t, 2.2) / 2.2
	var pull := clampf(cyc / 0.6, 0.0, 1.0)
	pull = 1.0 - pow(1.0 - pull, 3.0)
	var finger := coin + Vector2(0, 40 + 150 * pull) * k
	if cyc > 0.75:
		finger = coin + Vector2(0, 40) * k
	var a := 1.0 if cyc < 0.75 else maxf(0.0, 1.0 - (cyc - 0.75) * 6.0)
	# seta para cima (sentido do chute)
	if cyc < 0.75:
		var tip := coin + Vector2(0, -(60 + 140 * pull)) * k
		draw_line(coin + Vector2(0, -28) * k, tip, Color(1, 1, 1, 0.9), 8.0 * k, true)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -24) * k, tip + Vector2(-16, 0) * k, tip + Vector2(16, 0) * k]), Color.WHITE)
	# dedo
	draw_circle(finger, 34 * k, Color(1, 1, 1, 0.25 * a))
	draw_circle(finger, 22 * k, Color(1, 1, 1, 0.85 * a))
	draw_line(coin + Vector2(0, 26) * k, finger, Color(1, 1, 1, 0.5 * a), 3.0, true)
	# balão de texto
	var lines := ["PUXE PARA TRÁS E SOLTE", "a moeda vai para o lado oposto"]
	var y := finger.y + 70 * k
	var w0 := FONT.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var w1 := FONT.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var bw := maxf(w0, w1) + 48
	var r := Rect2(size.x * 0.5 - bw * 0.5, minf(y, size.y - 190), bw, 100)
	var sb := UIKit.box(Color(0.06, 0.04, 0.2, 0.9), 24, 8)
	draw_style_box(sb, r)
	draw_string(FONT, Vector2(size.x * 0.5 - w0 * 0.5, r.position.y + 46), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UIKit.ACCENT)
	draw_string(FONT, Vector2(size.x * 0.5 - w1 * 0.5, r.position.y + 82), lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
