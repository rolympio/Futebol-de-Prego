extends Control
## Lista de desafios de precisão (desbloqueio por progresso).

var main: Control
var params := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := UIKit.safe_margins(get_viewport())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 24 + sm["top"]
	root.offset_bottom = -24 - sm["bottom"]
	root.offset_left = 32
	root.offset_right = -32
	root.add_theme_constant_override("separation", 18)
	add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(UIKit.icon_button("<", Color("475569"), func() -> void: main.goto("menu"), 76))
	var title := UIKit.label("DESAFIOS", 48, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(title)
	var total := 0
	for s in Save.challenge_stars:
		total += int(s)
	var stl := UIKit.label("%d/%d estrelas" % [total, FieldData.CHALLENGES.size() * 3], 26, UIKit.ACCENT, true)
	stl.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(stl)
	root.add_child(head)
	root.add_child(UIKit.label("Marque no gol de cima com poucos chutes. Menos chutes = mais estrelas.", 24, Color(1, 1, 1, 0.7)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	var colors := [UIKit.GREEN, UIKit.BLUE, UIKit.ORANGE, UIKit.PINK, UIKit.PURPLE, Color("14b8a6"), Color("ef4444"), Color("eab308")]
	for i in FieldData.CHALLENGES.size():
		var ch: Dictionary = FieldData.CHALLENGES[i]
		var unlocked := Save.challenge_unlocked(i)
		var stars := int(Save.challenge_stars[i])
		var col: Color = colors[i % colors.size()]
		var txt := "%d\n%s" % [i + 1, ch["nome"]] if unlocked else "%d\nbloqueado" % (i + 1)
		var idx := i
		var b := UIKit.button(txt, col if unlocked else Color("334155"), func() -> void:
			if Save.challenge_unlocked(idx):
				main.goto("match", {"mode": "challenge", "challenge": idx}), 28, 190)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = not unlocked
		var holder := VBoxContainer.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_theme_constant_override("separation", 0)
		holder.add_child(b)
		var row := preload("res://scripts/ui/star_row.gd").new()
		row.set("stars", stars)
		row.custom_minimum_size = Vector2(0, 54)
		row.scale = Vector2(0.45, 0.45)
		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(0, 50)
		wrap.add_child(row)
		wrap.resized.connect(func() -> void:
			row.size = wrap.size / 0.45
			row.position = Vector2(0, -6))
		holder.add_child(wrap)
		grid.add_child(holder)
		UIKit.pop_in(holder, 0.04 * i)


func on_back() -> void:
	main.goto("menu")
