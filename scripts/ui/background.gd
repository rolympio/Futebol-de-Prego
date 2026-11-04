extends Control
## Fundo em degradê com moedas e pregos flutuando devagar.

var _t := 0.0
var _items: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cols := [Color("facc15"), Color("3b82f6"), Color("ec4899"), Color("22c55e"), Color("f97316")]
	for i in 16:
		_items.append({"x": rng.randf(), "y": rng.randf(), "r": rng.randf_range(10, 34),
			"sp": rng.randf_range(0.01, 0.035), "ph": rng.randf() * TAU, "c": cols[i % cols.size()]})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([UIKit.BG_TOP, Color("4c1d95"), UIKit.BG_BOTTOM, UIKit.BG_BOTTOM]))
	for it: Dictionary in _items:
		var y := fposmod(it["y"] - _t * it["sp"], 1.2) - 0.1
		var x: float = it["x"] + sin(_t * 0.6 + it["ph"]) * 0.02
		var p := Vector2(x * s.x, y * s.y)
		var c: Color = it["c"]
		var r: float = it["r"]
		draw_circle(p, r, Color(c.r, c.g, c.b, 0.08))
		draw_arc(p, r * 0.62, 0, TAU, 24, Color(c.r, c.g, c.b, 0.14), 3.0, true)
