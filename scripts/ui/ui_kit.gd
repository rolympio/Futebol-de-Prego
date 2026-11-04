class_name UIKit
extends RefCounted
## Componentes de interface: botões arredondados com "afundar" ao toque,
## rótulos, seletores segmentados, cartões e diálogos de confirmação.

const BOLD := preload("res://assets/fonts/Baloo2-ExtraBold.woff2")
const INK := Color("1e1b4b")
const BG_TOP := Color("312e81")
const BG_BOTTOM := Color("0f0c29")
const ACCENT := Color("facc15")
const GREEN := Color("22c55e")
const BLUE := Color("3b82f6")
const PINK := Color("ec4899")
const ORANGE := Color("f97316")
const PURPLE := Color("8b5cf6")
const CARD := Color(1, 1, 1, 0.08)


static func fs(base: int) -> int:
	return int(base * (1.18 if Save.settings["big_text"] else 1.0))


static func box(color: Color, radius := 26, shadow := 0, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.5)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	return sb


static func button(text: String, color: Color, cb: Callable, font_size := 34, min_h := 92) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", fs(font_size))
	var dark := color.darkened(0.35)
	var txt := INK if color.get_luminance() > 0.6 else Color.WHITE
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, txt)
	var normal := box(color, 28, 0)
	normal.border_width_bottom = 8
	normal.border_color = dark
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.08)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_width_bottom = 2
	pressed.border_width_top = 6
	pressed.border_color = color.darkened(0.15)
	pressed.bg_color = color.darkened(0.08)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", box(Color(0.5, 0.5, 0.6, 0.5), 28))
	b.pressed.connect(func() -> void:
		Sfx.play("click", 0.6)
		Save.vibrate(6)
		cb.call())
	return b


static func icon_button(text: String, color: Color, cb: Callable, size := 84) -> Button:
	var b := button(text, color, cb, 38, size)
	b.custom_minimum_size = Vector2(size, size)
	for k in ["normal", "hover", "pressed"]:
		var sb := b.get_theme_stylebox(k) as StyleBoxFlat
		sb.set_corner_radius_all(int(size / 2.0))
		sb.content_margin_left = 0
		sb.content_margin_right = 0
	return b


static func label(text: String, size := 30, color := Color.WHITE, bold := false, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", BOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func outlined(l: Label, outline := 10, color := INK) -> Label:
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", color)
	return l


## Seletor segmentado. options: Array de textos. Retorna o HBox.
static func segmented(options: Array, current: int, cb: Callable, color := BLUE, font_size := 26) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var btns: Array[Button] = []
	for i in options.size():
		var b := Button.new()
		b.text = str(options[i])
		b.toggle_mode = true
		b.button_pressed = i == current
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 70)
		b.clip_text = true
		b.add_theme_font_override("font", BOLD)
		b.add_theme_font_size_override("font_size", fs(font_size))
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", INK if color.get_luminance() > 0.6 else Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", INK if color.get_luminance() > 0.6 else Color.WHITE)
		b.add_theme_stylebox_override("normal", box(Color(1, 1, 1, 0.1), 20))
		b.add_theme_stylebox_override("hover", box(Color(1, 1, 1, 0.16), 20))
		var on := box(color, 20)
		on.border_width_bottom = 5
		on.border_color = color.darkened(0.35)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btns.append(b)
		h.add_child(b)
	for i in btns.size():
		btns[i].pressed.connect(func() -> void:
			for j in btns.size():
				btns[j].set_pressed_no_signal(j == i)
			Sfx.play("click", 0.5)
			Save.vibrate(5)
			cb.call(i))
	return h


static func card(sep := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(CARD, 30, 0, 2, Color(1, 1, 1, 0.1))
	sb.set_content_margin_all(24)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.name = "V"
	p.add_child(v)
	return p


static func section_title(text: String) -> Label:
	return label(text, 24, Color(1, 1, 1, 0.65), true, HORIZONTAL_ALIGNMENT_LEFT)


## Diálogo modal simples. Retorna o nó (para testes).
static func confirm(parent: Control, text: String, yes_text: String, on_yes: Callable, no_text := "Cancelar") -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.1, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var sb := box(Color("1e1b4b"), 34, 24, 3, Color(1, 1, 1, 0.15))
	sb.set_content_margin_all(34)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	panel.add_child(v)
	v.add_child(label(text, 32, Color.WHITE, true))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var no := button(no_text, Color("475569"), func() -> void: dim.queue_free(), 28, 80)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := button(yes_text, Color("ef4444"), func() -> void:
		dim.queue_free()
		on_yes.call(), 28, 80)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(no)
	h.add_child(yes)
	parent.add_child(dim)
	pop_in(panel)
	return dim


static func pop_in(c: Control, delay := 0.0) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.85, 0.85)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.18).set_delay(delay)
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5, CONNECT_ONE_SHOT)


## Margens da área segura (entalhe/câmera) em coordenadas da viewport.
static func safe_margins(vp: Viewport) -> Dictionary:
	var out := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if not OS.has_feature("mobile"):
		return out
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0:
		return out
	var vs := vp.get_visible_rect().size
	var k := vs.y / float(win.y)
	out["top"] = maxf(0.0, safe.position.y) * k
	out["bottom"] = maxf(0.0, win.y - safe.end.y) * k
	out["left"] = maxf(0.0, safe.position.x) * k
	out["right"] = maxf(0.0, win.x - safe.end.x) * k
	return out
