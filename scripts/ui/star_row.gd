extends Control
## Fileira de 3 estrelas (desenhadas em código, sem depender de fonte).

var stars := 0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	for i in 3:
		var p := c + Vector2((i - 1) * 110.0, 0)
		var on := i < stars
		var appear := clampf((_t - 0.15 * i) * 4.0, 0.0, 1.0)
		var r := 46.0 * (0.6 + 0.4 * appear) if on else 40.0
		draw_colored_polygon(_star(p + Vector2(0, 5), r), Color(0, 0, 0, 0.3))
		draw_colored_polygon(_star(p, r), Color("facc15") if on else Color(1, 1, 1, 0.15))
		if on:
			draw_colored_polygon(_star(p, r * 0.55), Color("fde68a"))


func _star(p: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(p + Vector2.from_angle(k * TAU / 10.0 - PI / 2) * rr)
	return pts
