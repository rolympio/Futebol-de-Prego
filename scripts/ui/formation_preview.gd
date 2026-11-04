extends Control
## Prévia do campo com as formações e cores escolhidas (usa o próprio Board).

var _board: Board
var _sig := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_board = Board.new()
	_board.set_process_unhandled_input(false)
	add_child(_board)
	resized.connect(_sync)
	_sync()


func _draw() -> void:
	_sync()


func _sync() -> void:
	if _board == null:
		return
	var cfg := Save.match_cfg
	var sig := "%s|%s|%s|%s|%s" % [cfg["form0"], cfg["form1"], cfg["color0"], cfg["color1"], Save.settings["theme"]]
	if sig != _sig:
		_sig = sig
		var n := FieldData.build_nails(cfg["form0"], cfg["form1"])
		var cols: Array[Color] = [Save.team_color(0), Save.team_color(1)]
		_board.setup(n["pts"], n["teams"], cols, Save.settings["theme"], Save.settings["coin"])
		_board.place_coin(Vector2.ZERO)
	_board.fit_to(Rect2(Vector2.ZERO, size))
