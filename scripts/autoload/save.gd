extends Node
## Salvamento local (sem internet, sem cadastro): configurações,
## progresso dos desafios e estatísticas.

const PATH := "user://futebol_de_prego.cfg"

var settings := {
	"sound": true,
	"vibration": true,
	"aim_assist": true,
	"high_contrast": false,
	"big_text": false,
	"theme": "campinho",
	"coin": "real",
	"tutorial_seen": false,
}
var match_cfg := {
	"difficulty": 1,          # 0 iniciante, 1 intermediário, 2 avançado
	"rules": "rapida",        # rapida | classica
	"goals": 3,               # 0 = sem limite
	"time": 180,              # segundos; 0 = sem tempo
	"continue_own": false,    # tocar só em prego do próprio time = nova jogada
	"name0": "Azul",
	"name1": "Amarelo",
	"color0": 0,
	"color1": 1,
	"form0": "piramide",
	"form1": "piramide",
}
var challenge_stars: Array = []
var stats := {"matches": 0, "wins_cpu": 0, "losses_cpu": 0, "goals": 0}


func _ready() -> void:
	challenge_stars.resize(FieldData.CHALLENGES.size())
	challenge_stars.fill(0)
	load_all()


func load_all() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = cf.get_value("settings", k, settings[k])
	for k in match_cfg.keys():
		match_cfg[k] = cf.get_value("match", k, match_cfg[k])
	for k in stats.keys():
		stats[k] = cf.get_value("stats", k, stats[k])
	var st: Array = cf.get_value("progress", "stars", [])
	for i in mini(st.size(), challenge_stars.size()):
		challenge_stars[i] = int(st[i])
	# validação defensiva
	if not FieldData.THEMES.has(settings["theme"]):
		settings["theme"] = "campinho"
	if not FieldData.COINS.has(settings["coin"]):
		settings["coin"] = "real"
	for k in ["form0", "form1"]:
		if not FieldData.FORMATIONS.has(match_cfg[k]):
			match_cfg[k] = "piramide"
	for k in ["color0", "color1"]:
		match_cfg[k] = clampi(int(match_cfg[k]), 0, FieldData.TEAM_COLORS.size() - 1)


func save_all() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	for k in match_cfg.keys():
		cf.set_value("match", k, match_cfg[k])
	for k in stats.keys():
		cf.set_value("stats", k, stats[k])
	cf.set_value("progress", "stars", challenge_stars)
	cf.save(PATH)


func challenge_unlocked(i: int) -> bool:
	return i == 0 or challenge_stars[i - 1] > 0


func team_color(t: int) -> Color:
	return FieldData.TEAM_COLORS[int(match_cfg["color%d" % t])]["c"]


func vibrate(ms: int) -> void:
	if settings["vibration"]:
		Input.vibrate_handheld(ms)
