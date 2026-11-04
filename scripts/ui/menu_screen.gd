extends Control
## Menu inicial.

var main: Control
var params := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := UIKit.safe_margins(get_viewport())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", int(40 + sm["top"]))
	margin.add_theme_constant_override("margin_bottom", int(30 + sm["bottom"]))
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(v)

	var logo := preload("res://scripts/ui/logo_art.gd").new()
	logo.custom_minimum_size = Vector2(0, 250)
	v.add_child(logo)
	var tb := VBoxContainer.new()
	tb.add_theme_constant_override("separation", -46)
	tb.add_child(UIKit.outlined(UIKit.label("FUTEBOL", 88, Color.WHITE, true), 18))
	tb.add_child(UIKit.outlined(UIKit.label("DE PREGO", 88, UIKit.ACCENT, true), 18))
	v.add_child(tb)
	var sub := UIKit.label("puxe, mire, solte  •  gol!", 28, Color(1, 1, 1, 0.75))
	v.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	v.add_child(sp)

	var btns := [
		UIKit.button("JOGAR CONTRA A CPU", UIKit.GREEN, func() -> void: main.goto("setup", {"mode": "cpu"}), 38, 108),
		UIKit.button("2 JOGADORES", UIKit.BLUE, func() -> void: main.goto("setup", {"mode": "local"})),
	]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var b_tr := UIKit.button("TREINO", UIKit.ORANGE, func() -> void: main.goto("match", {"mode": "training"}))
	var b_ch := UIKit.button("DESAFIOS", UIKit.PINK, func() -> void: main.goto("challenges"))
	for b in [b_tr, b_ch]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	btns.append(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	var b_set := UIKit.button("AJUSTES", Color("475569"), func() -> void: main.goto("settings"), 28, 80)
	var b_help := UIKit.button("COMO JOGAR", Color("475569"), func() -> void: main.goto("help"), 28, 80)
	for b in [b_set, b_help]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(b)
	btns.append(row2)
	var i := 0
	for b: Control in btns:
		v.add_child(b)
		UIKit.pop_in(b, 0.05 * i)
		i += 1
	var foot := UIKit.label("Sem anúncios  •  sem cadastro  •  funciona offline", 20, Color(1, 1, 1, 0.45))
	v.add_child(foot)
