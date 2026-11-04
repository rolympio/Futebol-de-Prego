extends Control
## Como jogar / regras.

var main: Control
var params := {}

const SECTIONS := [
	["O CHUTE (ESTILINGUE)", "Toque em qualquer lugar do campo e PUXE PARA TRÁS. A moeda é lançada para o lado OPOSTO ao seu dedo, como um estilingue. Quanto mais longe você puxa, mais forte o chute (o anel e a seta mudam de verde para vermelho). Para cancelar, volte o dedo ao ponto inicial e solte."],
	["OBJETIVO", "Faça a moeda passar INTEIRA pela linha do gol adversário. Quem joga embaixo ataca o gol de cima; quem joga em cima ataca o gol de baixo."],
	["TURNOS", "Cada jogador dá um chute por vez. A próxima jogada começa quando a moeda para. Depois de um gol, quem sofreu sai jogando do centro."],
	["PREGOS E BORDAS", "Os pregos são os jogadores: a moeda quica neles. As bordas de madeira também rebatem a moeda, então não existe bola fora: use as tabelas!"],
	["REGRAS RÁPIDAS", "Vence quem fizer 3 gols, ou quem estiver na frente após 3 minutos. Empate no fim do tempo = gol de ouro."],
	["REGRAS CLÁSSICAS", "Você escolhe gols para vencer, tempo e a regra \"prego do próprio time\": se a moeda tocar SÓ em pregos do seu time, você joga de novo (até 2 vezes seguidas)."],
	["CPU", "A CPU usa a mesma física que você vê na mira assistida e erra como gente: o Iniciante erra bastante, o Avançado quase nunca."],
]


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
	head.add_child(UIKit.icon_button("<", Color("475569"), func() -> void: main.goto("menu"), 76))
	var title := UIKit.label("COMO JOGAR", 48, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
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
	v.add_theme_constant_override("separation", 16)
	scroll.add_child(v)
	var cols := [UIKit.ACCENT, UIKit.GREEN, UIKit.BLUE, UIKit.ORANGE, UIKit.PINK, UIKit.PURPLE, Color("14b8a6")]
	for i in SECTIONS.size():
		var c := UIKit.card(8)
		c.get_node("V").add_child(UIKit.label(SECTIONS[i][0], 28, cols[i % cols.size()], true, HORIZONTAL_ALIGNMENT_LEFT))
		c.get_node("V").add_child(UIKit.label(SECTIONS[i][1], 25, Color(1, 1, 1, 0.85), false, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(c)
	root.add_child(UIKit.button("PRATICAR NO TREINO", UIKit.ORANGE, func() -> void: main.goto("match", {"mode": "training"}), 32, 96))


func on_back() -> void:
	main.goto("menu")
