class_name FieldData
extends RefCounted
## Dimensões do campo, formações, desafios, temas e cores.
## Coordenadas com origem no centro do campo; y negativo = gol de cima.

const HW := 300.0        # meia-largura do campo
const HH := 500.0        # meia-altura do campo
const GW := 66.0         # meia-abertura do gol (gol = 132 ≈ 3 moedas, 22% da largura)
const GD := 60.0         # profundidade da rede
const CHAMFER := 34.0
const MIN_NAIL_GAP := 70.0

# ---------------------------------------------------------------- formações
# Posições do time 0 (defende o gol de BAIXO, y > 0). O time 1 é espelhado.
const FORMATIONS := {
	"piramide": {
		"nome": "Pirâmide 2-3-5 (clássica)",
		"pts": [Vector2(0, 440),
			Vector2(-95, 330), Vector2(95, 330),
			Vector2(-185, 200), Vector2(0, 220), Vector2(185, 200),
			Vector2(-225, -90), Vector2(-112, -115), Vector2(0, -135), Vector2(112, -115), Vector2(225, -90)],
	},
	"442": {
		"nome": "Retranca 4-4-2",
		"pts": [Vector2(0, 440),
			Vector2(-200, 320), Vector2(-68, 345), Vector2(68, 345), Vector2(200, 320),
			Vector2(-215, 165), Vector2(-72, 190), Vector2(72, 190), Vector2(215, 165),
			Vector2(-85, -115), Vector2(85, -115)],
	},
	"433": {
		"nome": "Ataque 4-3-3",
		"pts": [Vector2(0, 440),
			Vector2(-200, 320), Vector2(-68, 345), Vector2(68, 345), Vector2(200, 320),
			Vector2(-150, 175), Vector2(0, 200), Vector2(150, 175),
			Vector2(-195, -110), Vector2(0, -150), Vector2(195, -110)],
	},
}
const FORMATION_ORDER := ["piramide", "442", "433"]


## Monta os pregos dos dois times, garantindo espaço mínimo entre eles
## e mantendo a boca do gol livre.
static func build_nails(form0: String, form1: String) -> Dictionary:
	var pts := PackedVector2Array()
	var teams := PackedInt32Array()
	for p: Vector2 in FORMATIONS[form0]["pts"]:
		pts.append(p)
		teams.append(0)
	for p: Vector2 in FORMATIONS[form1]["pts"]:
		pts.append(Vector2(-p.x, -p.y))
		teams.append(1)
	pts = _separate(pts)
	return {"pts": pts, "teams": teams}


static func _separate(pts: PackedVector2Array) -> PackedVector2Array:
	for _it in 24:
		var moved := false
		for i in pts.size():
			for j in range(i + 1, pts.size()):
				var d := pts[j] - pts[i]
				var dist := d.length()
				if dist < MIN_NAIL_GAP:
					var dir := d / dist if dist > 0.01 else Vector2.RIGHT
					var push := (MIN_NAIL_GAP - dist) * 0.5 + 0.5
					pts[i] -= dir * push
					pts[j] += dir * push
					moved = true
		for i in pts.size():
			pts[i] = _clamp_nail(pts[i])
		if not moved:
			break
	return pts


static func _clamp_nail(p: Vector2) -> Vector2:
	p.x = clampf(p.x, -HW + 60.0, HW - 60.0)
	p.y = clampf(p.y, -HH + 70.0, HH - 70.0)
	return p


# ---------------------------------------------------------------- desafios
# Todos atacam o gol de CIMA. Pregos do desafio pertencem ao "time 1" (defesa).
const CHALLENGES := [
	{"nome": "Primeiro chute", "dica": "Puxe para baixo e solte: a moeda sobe.",
		"coin": Vector2(0, 260), "shots": 2, "pts": []},
	{"nome": "Passe o goleiro", "dica": "Mire num dos cantos do gol.",
		"coin": Vector2(0, 200), "shots": 2, "pts": [Vector2(0, -440)]},
	{"nome": "Barreira", "dica": "Contorne a barreira.",
		"coin": Vector2(0, 250), "shots": 3,
		"pts": [Vector2(-60, -250), Vector2(0, -250), Vector2(60, -250), Vector2(0, -440)]},
	{"nome": "Tabela na lateral", "dica": "Use a borda para tabelar.",
		"coin": Vector2(-180, 300), "shots": 3,
		"pts": [Vector2(-150, -120), Vector2(-75, -120), Vector2(0, -120), Vector2(75, -120),
			Vector2(150, -120), Vector2(0, -440)]},
	{"nome": "Zigue-zague", "dica": "Força média resolve.",
		"coin": Vector2(0, 380), "shots": 3,
		"pts": [Vector2(-90, 180), Vector2(90, 180), Vector2(0, 40), Vector2(-150, -60),
			Vector2(150, -60), Vector2(-70, -220), Vector2(70, -220), Vector2(0, -440)]},
	{"nome": "Corredor", "dica": "Passe pelo corredor sem raspar.",
		"coin": Vector2(0, 420), "shots": 2,
		"pts": [Vector2(-55, 200), Vector2(55, 200), Vector2(-55, 60), Vector2(55, 60),
			Vector2(-55, -80), Vector2(55, -80), Vector2(-55, -220), Vector2(55, -220)]},
	{"nome": "Muralha", "dica": "Procure a brecha.",
		"coin": Vector2(120, 330), "shots": 3,
		"pts": [Vector2(-215, -200), Vector2(-145, -200), Vector2(-75, -200),
			Vector2(75, -200), Vector2(145, -200), Vector2(215, -200),
			Vector2(-115, -330), Vector2(115, -330), Vector2(0, -440)]},
	{"nome": "Tiro de longe", "dica": "Do seu gol até o deles.",
		"coin": Vector2(0, 450), "shots": 3, "formation": "piramide"},
]


static func challenge_nails(idx: int) -> Dictionary:
	var c: Dictionary = CHALLENGES[idx]
	var pts := PackedVector2Array()
	var teams := PackedInt32Array()
	if c.has("formation"):
		for p: Vector2 in FORMATIONS[c["formation"]]["pts"]:
			pts.append(Vector2(-p.x, -p.y))
			teams.append(1)
	else:
		for p: Vector2 in c["pts"]:
			pts.append(p)
			teams.append(1)
	return {"pts": pts, "teams": teams}


# ---------------------------------------------------------------- visual
const TEAM_COLORS := [
	{"nome": "Azul", "c": Color("1d4ed8")},
	{"nome": "Amarelo", "c": Color("facc15")},
	{"nome": "Vermelho", "c": Color("ef4444")},
	{"nome": "Roxo", "c": Color("a855f7")},
	{"nome": "Turquesa", "c": Color("14b8a6")},
	{"nome": "Laranja", "c": Color("f97316")},
	{"nome": "Rosa", "c": Color("ec4899")},
	{"nome": "Branco", "c": Color("e5e7eb")},
]

const THEMES := {
	"campinho": {
		"nome": "Campinho", "stripe_a": Color("3fbf4a"), "stripe_b": Color("37b043"),
		"line": Color(1, 1, 1, 0.95), "frame": Color("d9a86c"), "frame_edge": Color("b98247"),
		"frame_top": Color("ecc48f"), "net": Color(1, 1, 1, 0.55), "goal_fill": Color(0, 0, 0, 0.30),
	},
	"noturna": {
		"nome": "Arena noturna", "stripe_a": Color("27235f"), "stripe_b": Color("221e55"),
		"line": Color("67e8f9"), "frame": Color("1e1b4b"), "frame_edge": Color("0b0a26"),
		"frame_top": Color("4338ca"), "net": Color(0.4, 0.9, 1.0, 0.55), "goal_fill": Color(0, 0, 0, 0.4),
	},
	"madeira": {
		"nome": "Tábua de madeira", "stripe_a": Color("e3ac70"), "stripe_b": Color("dba366"),
		"line": Color("5b3417"), "frame": Color("8b4a22"), "frame_edge": Color("5e2f13"),
		"frame_top": Color("a9602f"), "net": Color(1, 1, 1, 0.5), "goal_fill": Color(0.15, 0.07, 0, 0.35),
	},
}
const THEME_ORDER := ["campinho", "madeira", "noturna"]

## Aparência da "bola". Física idêntica para todas (partidas justas).
const COINS := {
	"real": {"nome": "Moeda dourada", "rim": Color("b7791f"), "face": Color("f6c445"),
		"mark": Color("d69e2e"), "shine": Color("fff3c4")},
	"prata": {"nome": "Moeda prateada", "rim": Color("6b7280"), "face": Color("d1d5db"),
		"mark": Color("9ca3af"), "shine": Color("ffffff")},
	"cobre": {"nome": "Moeda de cobre", "rim": Color("7c2d12"), "face": Color("d97745"),
		"mark": Color("b45309"), "shine": Color("ffd7b5")},
	"ficha": {"nome": "Ficha telefônica", "rim": Color("713f12"), "face": Color("b08d57"),
		"mark": Color("7c5a2a"), "shine": Color("f0deb5"), "ficha": true},
}
const COIN_ORDER := ["real", "prata", "cobre", "ficha"]
