extends Control
## Configuração da partida: dificuldade, regras, times, formação e campo.

var main: Control
var params := {}
var cfg: Dictionary
var _rules_box: VBoxContainer
var _preview: Control
var _refreshers: Array[Callable] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cfg = Save.match_cfg
	var mode: String = params.get("mode", "cpu")
	var sm := UIKit.safe_margins(get_viewport())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_top = 24 + sm["top"]
	root.offset_bottom = -20 - sm["bottom"]
	root.offset_left = 32
	root.offset_right = -32
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(UIKit.icon_button("<", Color("475569"), func() -> void: main.goto("menu"), 76))
	var title := UIKit.label("CONTRA A CPU" if mode == "cpu" else "2 JOGADORES", 44, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
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

	if mode == "cpu":
		var c := UIKit.card()
		c.get_node("V").add_child(UIKit.section_title("DIFICULDADE"))
		c.get_node("V").add_child(UIKit.segmented(["Iniciante", "Médio", "Avançado"], int(cfg["difficulty"]),
			func(i: int) -> void: cfg["difficulty"] = i, UIKit.GREEN))
		v.add_child(c)

	# regras
	var rc := UIKit.card()
	rc.get_node("V").add_child(UIKit.section_title("REGRAS"))
	rc.get_node("V").add_child(UIKit.segmented(["Rápida", "Clássica"], 0 if cfg["rules"] == "rapida" else 1,
		func(i: int) -> void:
			cfg["rules"] = "rapida" if i == 0 else "classica"
			_build_rules(), UIKit.ORANGE))
	_rules_box = VBoxContainer.new()
	_rules_box.add_theme_constant_override("separation", 12)
	rc.get_node("V").add_child(_rules_box)
	v.add_child(rc)
	_build_rules()

	# times
	for t in 2:
		v.add_child(_team_card(t, mode))

	# prévia + campo
	var pc := UIKit.card()
	pc.get_node("V").add_child(UIKit.section_title("CAMPO E FORMAÇÕES"))
	_preview = preload("res://scripts/ui/formation_preview.gd").new()
	_preview.custom_minimum_size = Vector2(0, 520)
	pc.get_node("V").add_child(_preview)
	var tnames: Array = ["Campinho", "Madeira", "Noturna"]
	pc.get_node("V").add_child(UIKit.segmented(tnames, FieldData.THEME_ORDER.find(Save.settings["theme"]),
		func(i: int) -> void:
			Save.settings["theme"] = FieldData.THEME_ORDER[i]
			_preview.queue_redraw(), UIKit.PURPLE))
	v.add_child(pc)

	var play := UIKit.button("COMEÇAR!", UIKit.GREEN, func() -> void:
		_sanitize_names()
		Save.save_all()
		main.goto("match", {"mode": mode}), 42, 112)
	root.add_child(play)


func _build_rules() -> void:
	for c in _rules_box.get_children():
		c.queue_free()
	if cfg["rules"] == "rapida":
		_rules_box.add_child(UIKit.label("3 gols ou 3 minutos. A vez passa a cada chute. Empate no tempo = gol de ouro.", 24, Color(1, 1, 1, 0.8), false, HORIZONTAL_ALIGNMENT_LEFT))
		return
	var goals := [3, 5, 7, 0]
	_rules_box.add_child(UIKit.label("Gols para vencer", 22, Color(1, 1, 1, 0.7), false, HORIZONTAL_ALIGNMENT_LEFT))
	_rules_box.add_child(UIKit.segmented(["3", "5", "7", "Livre"], maxi(0, goals.find(int(cfg["goals"]))),
		func(i: int) -> void: cfg["goals"] = goals[i], UIKit.ORANGE))
	var times := [0, 180, 300, 600]
	_rules_box.add_child(UIKit.label("Tempo de partida", 22, Color(1, 1, 1, 0.7), false, HORIZONTAL_ALIGNMENT_LEFT))
	_rules_box.add_child(UIKit.segmented(["Sem", "3 min", "5 min", "10 min"], maxi(0, times.find(int(cfg["time"]))),
		func(i: int) -> void: cfg["time"] = times[i], UIKit.ORANGE))
	_rules_box.add_child(UIKit.label("Tocou só em prego do seu time? Joga de novo (máx. 2 extras)", 22, Color(1, 1, 1, 0.7), false, HORIZONTAL_ALIGNMENT_LEFT))
	_rules_box.add_child(UIKit.segmented(["Não", "Sim"], 1 if cfg["continue_own"] else 0,
		func(i: int) -> void: cfg["continue_own"] = i == 1, UIKit.ORANGE))
	if int(cfg["goals"]) == 0 and int(cfg["time"]) == 0:
		cfg["time"] = 300


func _team_card(t: int, mode: String) -> Control:
	var c := UIKit.card(12)
	var who := "VOCÊ (embaixo, ataca para cima)" if t == 0 else ("CPU (em cima)" if mode == "cpu" else "JOGADOR 2 (em cima, ataca para baixo)")
	c.get_node("V").add_child(UIKit.section_title(who))
	var le := LineEdit.new()
	le.text = str(cfg["name%d" % t])
	le.max_length = 12
	le.placeholder_text = "Nome do time"
	le.custom_minimum_size = Vector2(0, 76)
	le.add_theme_font_size_override("font_size", UIKit.fs(30))
	le.add_theme_stylebox_override("normal", UIKit.box(Color(0, 0, 0, 0.25), 18, 0, 2, Color(1, 1, 1, 0.15)))
	le.add_theme_stylebox_override("focus", UIKit.box(Color(0, 0, 0, 0.3), 18, 0, 3, UIKit.ACCENT))
	le.text_changed.connect(func(s: String) -> void: cfg["name%d" % t] = s)
	c.get_node("V").add_child(le)
	# cores
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	var sw: Array[Button] = []
	for i in FieldData.TEAM_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col: Color = FieldData.TEAM_COLORS[i]["c"]
		b.add_theme_stylebox_override("normal", UIKit.box(col, 31))
		b.add_theme_stylebox_override("hover", UIKit.box(col.lightened(0.1), 31))
		b.add_theme_stylebox_override("pressed", UIKit.box(col, 31, 0, 6, Color.WHITE))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.toggle_mode = true
		b.tooltip_text = FieldData.TEAM_COLORS[i]["nome"]
		sw.append(b)
		grid.add_child(b)
	var refresh := func() -> void:
		for i in sw.size():
			sw[i].set_pressed_no_signal(i == int(cfg["color%d" % t]))
			sw[i].disabled = i == int(cfg["color%d" % (1 - t)])
			sw[i].modulate.a = 0.25 if sw[i].disabled else 1.0
	for i in sw.size():
		sw[i].pressed.connect(func() -> void:
			cfg["color%d" % t] = i
			for r: Callable in _refreshers:
				r.call()
			if _preview:
				_preview.queue_redraw())
	refresh.call()
	_refreshers.append(refresh)
	c.get_node("V").add_child(grid)
	var fnames: Array = []
	for k: String in FieldData.FORMATION_ORDER:
		fnames.append(FieldData.FORMATIONS[k]["nome"].split(" ")[1] if k != "piramide" else "2-3-5")
	c.get_node("V").add_child(UIKit.label("Formação", 22, Color(1, 1, 1, 0.7), false, HORIZONTAL_ALIGNMENT_LEFT))
	c.get_node("V").add_child(UIKit.segmented(fnames, FieldData.FORMATION_ORDER.find(cfg["form%d" % t]),
		func(i: int) -> void:
			cfg["form%d" % t] = FieldData.FORMATION_ORDER[i]
			if _preview:
				_preview.queue_redraw(), UIKit.BLUE))
	return c


func _sanitize_names() -> void:
	for t in 2:
		var n := str(cfg["name%d" % t]).strip_edges().left(12)
		if n.is_empty():
			n = FieldData.TEAM_COLORS[int(cfg["color%d" % t])]["nome"]
		cfg["name%d" % t] = n


func on_back() -> void:
	main.goto("menu")
