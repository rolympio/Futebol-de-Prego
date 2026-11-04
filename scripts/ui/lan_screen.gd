extends Control
## "Jogar no Wi-Fi": criar sala (servidor local) ou entrar com código.
## Convite pelo WhatsApp abre o app com a mensagem pronta (wa.me).

const WHATSAPP := Color("25d366")

var main: Control
var params := {}

var _body: VBoxContainer
var _status: Label
var _code_edit: LineEdit
var _rooms_box: VBoxContainer
var _rooms := {}
var _rules := "rapida"
var _mode := "choose"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if str(Save.settings["net_name"]).strip_edges() == "":
		Save.settings["net_name"] = "Jogador"
	_rules = str(Save.match_cfg["rules"])
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
	head.add_child(UIKit.icon_button("<", Color("475569"), on_back, 76))
	var title := UIKit.label("JOGAR NO WI-FI", 46, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	root.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 18)
	scroll.add_child(_body)

	Net.peer_joined.connect(_on_peer_joined)
	Net.connected_to_host.connect(_on_connected)
	Net.connection_failed.connect(_on_failed)
	Net.message.connect(_on_msg)
	Net.room_found.connect(_on_room_found)
	_show_choose()


func _exit_tree() -> void:
	Net.stop_discovery()


func _clear() -> void:
	for c in _body.get_children():
		c.queue_free()
	_status = null
	_rooms_box = null


# ------------------------------------------------------------------ telas
func _show_choose() -> void:
	_mode = "choose"
	Net.leave()
	_clear()
	var ip := Net.local_ip()
	var info := UIKit.card(10)
	info.get_node("V").add_child(UIKit.label("Os dois celulares precisam estar no MESMO Wi-Fi. Sem roteador? Um celular liga o \"roteador Wi-Fi\" (ponto de acesso) e o outro se conecta nele. Não usa internet.", 23, Color(1, 1, 1, 0.8), false, HORIZONTAL_ALIGNMENT_LEFT))
	if ip == "":
		info.get_node("V").add_child(UIKit.label("Sem rede Wi-Fi detectada.", 26, Color("f87171"), true, HORIZONTAL_ALIGNMENT_LEFT))
	_body.add_child(info)

	var me := UIKit.card(12)
	me.get_node("V").add_child(UIKit.section_title("SEU NOME E COR"))
	var le := LineEdit.new()
	le.text = str(Save.settings["net_name"])
	le.max_length = 12
	le.custom_minimum_size = Vector2(0, 76)
	le.add_theme_font_size_override("font_size", UIKit.fs(30))
	le.add_theme_stylebox_override("normal", UIKit.box(Color(0, 0, 0, 0.25), 18, 0, 2, Color(1, 1, 1, 0.15)))
	le.add_theme_stylebox_override("focus", UIKit.box(Color(0, 0, 0, 0.3), 18, 0, 3, UIKit.ACCENT))
	le.text_changed.connect(func(s: String) -> void: Save.settings["net_name"] = s)
	me.get_node("V").add_child(le)
	me.get_node("V").add_child(_swatches())
	_body.add_child(me)

	var b1 := UIKit.button("CRIAR SALA", UIKit.GREEN, _create, 38, 108)
	var b2 := UIKit.button("ENTRAR NA SALA", UIKit.BLUE, _show_join, 38, 108)
	_body.add_child(b1)
	_body.add_child(b2)
	UIKit.pop_in(b1)
	UIKit.pop_in(b2, 0.05)


func _swatches() -> HBoxContainer:
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	var sw: Array[Button] = []
	for i in FieldData.TEAM_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(60, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col: Color = FieldData.TEAM_COLORS[i]["c"]
		b.add_theme_stylebox_override("normal", UIKit.box(col, 30))
		b.add_theme_stylebox_override("hover", UIKit.box(col.lightened(0.1), 30))
		b.add_theme_stylebox_override("pressed", UIKit.box(col, 30, 0, 6, Color.WHITE))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.toggle_mode = true
		b.button_pressed = i == int(Save.settings["net_color"])
		sw.append(b)
		grid.add_child(b)
	for i in sw.size():
		sw[i].pressed.connect(func() -> void:
			Save.settings["net_color"] = i
			for j in sw.size():
				sw[j].set_pressed_no_signal(j == i))
	return grid


func _create() -> void:
	_sanitize()
	Save.save_all()
	var err := Net.host_room(Save.settings["net_name"])
	if err != OK:
		_show_choose()
		UIKit.confirm(self, "Não consegui abrir a sala (erro %d). Feche outros jogos e tente de novo." % err, "OK", func() -> void: pass, "Voltar")
		return
	_mode = "hosting"
	_clear()
	var ip := Net.host_ip
	var code := Net.code_from_ip(ip)
	var c := UIKit.card(10)
	c.get_node("V").add_child(UIKit.section_title("SALA CRIADA  •  CÓDIGO"))
	var code_lbl := UIKit.outlined(UIKit.label(code if code != "" else "--", 120, UIKit.ACCENT, true), 14)
	c.get_node("V").add_child(code_lbl)
	c.get_node("V").add_child(UIKit.label("IP %s  •  porta %d" % [ip if ip != "" else "desconhecido", Net.GAME_PORT], 22, Color(1, 1, 1, 0.55)))
	_status = UIKit.label("Aguardando adversário entrar...", 28, Color.WHITE, true)
	c.get_node("V").add_child(_status)
	_body.add_child(c)
	UIKit.pop_in(c)

	var r := UIKit.card(10)
	r.get_node("V").add_child(UIKit.section_title("REGRAS"))
	r.get_node("V").add_child(UIKit.segmented(["Rápida", "Clássica"], 0 if _rules == "rapida" else 1,
		func(i: int) -> void: _rules = "rapida" if i == 0 else "classica", UIKit.ORANGE))
	r.get_node("V").add_child(UIKit.label("Clássica usa as opções escolhidas em \"2 Jogadores\".", 22, Color(1, 1, 1, 0.6), false, HORIZONTAL_ALIGNMENT_LEFT))
	_body.add_child(r)

	var wa := UIKit.button("CONVIDAR NO WHATSAPP", WHATSAPP, func() -> void: _invite(code), 34, 100)
	_body.add_child(wa)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var cp := UIKit.button("COPIAR CÓDIGO", UIKit.BLUE, func() -> void:
		DisplayServer.clipboard_set(code)
		_set_status("Código copiado!"), 28, 84)
	var cancel := UIKit.button("CANCELAR", Color("475569"), _show_choose, 28, 84)
	for b in [cp, cancel]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_body.add_child(row)


func _show_join() -> void:
	_sanitize()
	Save.save_all()
	_mode = "joining"
	Net.leave()
	_clear()
	var c := UIKit.card(12)
	c.get_node("V").add_child(UIKit.section_title("CÓDIGO DA SALA"))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "ex.: 1061"
	_code_edit.max_length = 15
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_code_edit.custom_minimum_size = Vector2(0, 110)
	_code_edit.add_theme_font_override("font", UIKit.BOLD)
	_code_edit.add_theme_font_size_override("font_size", UIKit.fs(64))
	_code_edit.add_theme_stylebox_override("normal", UIKit.box(Color(0, 0, 0, 0.25), 22, 0, 2, Color(1, 1, 1, 0.15)))
	_code_edit.add_theme_stylebox_override("focus", UIKit.box(Color(0, 0, 0, 0.3), 22, 0, 3, UIKit.ACCENT))
	_code_edit.text_submitted.connect(func(_t: String) -> void: _join_code())
	c.get_node("V").add_child(_code_edit)
	c.get_node("V").add_child(UIKit.button("ENTRAR", UIKit.GREEN, _join_code, 36, 100))
	_status = UIKit.label("Peça o código para quem criou a sala.", 24, Color(1, 1, 1, 0.75))
	c.get_node("V").add_child(_status)
	_body.add_child(c)
	UIKit.pop_in(c)

	var f := UIKit.card(10)
	f.get_node("V").add_child(UIKit.section_title("SALAS ENCONTRADAS NA REDE"))
	_rooms_box = VBoxContainer.new()
	_rooms_box.add_theme_constant_override("separation", 10)
	_rooms_box.add_child(UIKit.label("Procurando...", 22, Color(1, 1, 1, 0.5)))
	f.get_node("V").add_child(_rooms_box)
	_body.add_child(f)
	_body.add_child(UIKit.button("VOLTAR", Color("475569"), _show_choose, 28, 84))
	_rooms.clear()
	Net.start_discovery()


func _join_code() -> void:
	var raw := _code_edit.text if _code_edit else ""
	var ip := Net.ip_from_code(raw)
	if ip == "":
		_set_status("Código inválido. Use só números (ex.: 1061)." if Net.local_ip() != "" or raw.count(".") == 3 else "Conecte-se ao Wi-Fi primeiro.", true)
		return
	_join_ip(ip)


func _join_ip(ip: String) -> void:
	_set_status("Conectando...")
	var err := Net.join_room(ip)
	if err != OK:
		_set_status("Não consegui conectar (erro %d)." % err, true)


func _invite(code: String) -> void:
	var text := "⚽ Bora jogar Futebol de Prego?\nAbra o jogo → Jogar no Wi-Fi → Entrar na sala e digite o código: *%s*\n(precisa estar no mesmo Wi-Fi que eu)" % code
	OS.shell_open("https://wa.me/?text=" + text.uri_encode())


func _set_status(t: String, error := false) -> void:
	if _status:
		_status.text = t
		_status.add_theme_color_override("font_color", Color("f87171") if error else Color.WHITE)


func _sanitize() -> void:
	var n := str(Save.settings["net_name"]).strip_edges().left(12)
	Save.settings["net_name"] = n if n != "" else "Jogador"


# ------------------------------------------------------------------ rede
func _on_peer_joined() -> void:
	if _mode == "hosting":
		_set_status("Adversário conectando...")


func _on_connected() -> void:
	_set_status("Conectado! Entrando na partida...")
	Net.send("hello", {"proto": Net.PROTOCOL, "name": Save.settings["net_name"], "color": int(Save.settings["net_color"])})


func _on_failed(reason: String) -> void:
	_set_status(reason, true)


func _on_room_found(info: Dictionary) -> void:
	if _rooms_box == null or _rooms.has(info["ip"]):
		return
	if _rooms.is_empty():
		for c in _rooms_box.get_children():
			c.queue_free()
	_rooms[info["ip"]] = info
	var ip: String = info["ip"]
	var b := UIKit.button("%s  •  sala %s" % [str(info["name"]).left(12), info["code"]], UIKit.PURPLE, func() -> void: _join_ip(ip), 28, 84)
	_rooms_box.add_child(b)
	UIKit.pop_in(b)


func _on_msg(type: String, d: Dictionary) -> void:
	match type:
		"hello":
			if not Net.is_host or _mode != "hosting":
				return
			if int(d.get("proto", -1)) != Net.PROTOCOL:
				Net.send("reject", {"reason": "Versões diferentes do jogo. Atualizem os dois celulares."})
				_set_status("O adversário tem outra versão do jogo.", true)
				return
			var cfg := build_cfg(_rules, d)
			Net.send("start", {"cfg": cfg})
			main.goto("match", {"mode": "lan", "net_cfg": cfg})
		"start":
			if Net.is_host:
				return
			var cfg: Dictionary = d.get("cfg", {})
			if cfg.is_empty():
				return
			main.goto("match", {"mode": "lan", "net_cfg": cfg, "resume": d.get("resume", {})})
		"reject":
			_set_status(str(d.get("reason", "Entrada recusada.")), true)
			Net.leave(false)


## Configuração da partida montada pelo servidor (fonte única da verdade).
static func build_cfg(rules: String, hello: Dictionary) -> Dictionary:
	var c: Dictionary = Save.match_cfg.duplicate()
	c["rules"] = rules
	c["name0"] = str(Save.settings["net_name"]).left(12)
	c["color0"] = clampi(int(Save.settings["net_color"]), 0, FieldData.TEAM_COLORS.size() - 1)
	var nm := str(hello.get("name", "Convidado")).strip_edges().left(12)
	c["name1"] = nm if nm != "" else "Convidado"
	var col := clampi(int(hello.get("color", 1)), 0, FieldData.TEAM_COLORS.size() - 1)
	if col == c["color0"]:
		col = 1 if c["color0"] != 1 else 0
	c["color1"] = col
	c["theme"] = Save.settings["theme"]
	return c


func on_back() -> void:
	if _mode == "choose":
		Net.leave()
		main.goto("menu")
	else:
		_show_choose()
