extends Control
## Ajustes: som, vibração, mira, acessibilidade, moeda e estatísticas.

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
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(UIKit.icon_button("<", Color("475569"), _back, 76))
	var title := UIKit.label("AJUSTES", 48, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(title)
	root.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 18)
	scroll.add_child(v)

	var c1 := UIKit.card()
	_toggle(c1, "Sons", "sound")
	_toggle(c1, "Vibração", "vibration")
	_toggle(c1, "Mira assistida (prévia curta da trajetória)", "aim_assist")
	v.add_child(c1)

	var c2 := UIKit.card()
	c2.get_node("V").add_child(UIKit.section_title("ACESSIBILIDADE"))
	_toggle(c2, "Texto grande", "big_text", true)
	_toggle(c2, "Alto contraste (linhas e pregos reforçados)", "high_contrast")
	c2.get_node("V").add_child(UIKit.label("Os times também se diferenciam por formato: o time de cima tem anel branco nos pregos.", 22, Color(1, 1, 1, 0.6), false, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(c2)

	var c3 := UIKit.card()
	c3.get_node("V").add_child(UIKit.section_title("BOLA"))
	var names: Array = ["Dourada", "Prata", "Cobre", "Ficha"]
	c3.get_node("V").add_child(UIKit.segmented(names, FieldData.COIN_ORDER.find(Save.settings["coin"]),
		func(i: int) -> void: Save.settings["coin"] = FieldData.COIN_ORDER[i], UIKit.ACCENT, 24))
	c3.get_node("V").add_child(UIKit.label("Todas têm a mesma física: só muda a aparência. São objetos do jogo, sem valor real.", 22, Color(1, 1, 1, 0.6), false, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(c3)

	var c4 := UIKit.card()
	c4.get_node("V").add_child(UIKit.section_title("CAMPO PADRÃO"))
	c4.get_node("V").add_child(UIKit.segmented(["Campinho", "Madeira", "Noturna"], FieldData.THEME_ORDER.find(Save.settings["theme"]),
		func(i: int) -> void: Save.settings["theme"] = FieldData.THEME_ORDER[i], UIKit.PURPLE, 24))
	v.add_child(c4)

	var st := Save.stats
	var c5 := UIKit.card()
	c5.get_node("V").add_child(UIKit.section_title("ESTATÍSTICAS"))
	c5.get_node("V").add_child(UIKit.label("Partidas: %d   •   Gols: %d\nVitórias x CPU: %d   •   Derrotas: %d" % [st["matches"], st["goals"], st["wins_cpu"], st["losses_cpu"]], 26, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT))
	c5.get_node("V").add_child(UIKit.button("REVER TUTORIAL", Color("475569"), func() -> void:
		Save.settings["tutorial_seen"] = false
		Save.save_all()
		main.goto("match", {"mode": "training"}), 26, 76))
	v.add_child(c5)


func _toggle(c: Control, text: String, key: String, rebuild := false) -> void:
	var h := HBoxContainer.new()
	var l := UIKit.label(text, 26, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var seg := UIKit.segmented(["Não", "Sim"], 1 if Save.settings[key] else 0, func(i: int) -> void:
		Save.settings[key] = i == 1
		Save.save_all()
		if rebuild:
			main.goto("settings"), UIKit.GREEN, 24)
	seg.custom_minimum_size = Vector2(220, 0)
	seg.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(seg)
	c.get_node("V").add_child(h)


func _back() -> void:
	Save.save_all()
	main.goto("menu")


func on_back() -> void:
	_back()
