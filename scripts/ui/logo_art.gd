extends Control
## Arte do logo: moeda quicando entre pregos numerados, desenhada em código.

const FONT := preload("res://assets/fonts/Baloo2-ExtraBold.woff2")
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.y * 0.42, 120.0)
	# disco gramado
	draw_circle(c + Vector2(0, 10), r + 10, Color(0, 0, 0, 0.3))
	draw_circle(c, r + 10, Color("d9a86c"))
	draw_circle(c, r, Color("3fbf4a"))
	draw_arc(c, r * 0.45, 0, TAU, 48, Color(1, 1, 1, 0.9), 4.0, true)
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Color(1, 1, 1, 0.9), 4.0)
	# pregos
	var pegs := [[Vector2(-0.55, -0.45), Color("1d4ed8"), "7"], [Vector2(0.5, -0.5), Color("facc15"), "9"],
		[Vector2(-0.45, 0.5), Color("facc15"), "4"], [Vector2(0.55, 0.42), Color("1d4ed8"), "10"]]
	for pg: Array in pegs:
		var p: Vector2 = c + (pg[0] as Vector2) * r
		var col: Color = pg[1]
		draw_circle(p + Vector2(3, 5), 15, Color(0, 0, 0, 0.3))
		draw_circle(p, 15, col)
		draw_circle(p + Vector2(-4, -5), 4, Color(1, 1, 1, 0.5))
		var txt: String = pg[2]
		var fc := Color("111827") if col.get_luminance() > 0.55 else Color.WHITE
		var w := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(FONT, p + Vector2(-w / 2, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, fc)
	# moeda em órbita
	var a := _t * 1.6
	var cp := c + Vector2(cos(a) * r * 0.25, sin(a * 2.0) * r * 0.18)
	draw_circle(cp + Vector2(4, 7), 24, Color(0, 0, 0, 0.35))
	draw_circle(cp, 24, Color("b7791f"))
	draw_circle(cp, 20.5, Color("f6c445"))
	draw_arc(cp, 15, 0, TAU, 32, Color("d69e2e"), 2.0, true)
	var star := PackedVector2Array()
	for k in 10:
		var rr := 9.0 if k % 2 == 0 else 4.0
		star.append(cp + Vector2.from_angle(_t * 2.0 + k * TAU / 10.0 - PI / 2) * rr)
	draw_colored_polygon(star, Color("d69e2e"))
	draw_arc(cp, 22, deg_to_rad(200), deg_to_rad(290), 12, Color("fff3c4"), 3.0, true)
