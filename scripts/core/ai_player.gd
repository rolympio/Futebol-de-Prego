class_name AIPlayer
extends RefCounted
## IA que testa chutes candidatos com a MESMA física do jogo (a mesma que
## alimenta a mira assistida do jogador) e escolhe um plausível.
## Não há aleatoriedade oculta no mundo, então a IA não sabe nada que o
## jogador não possa descobrir. O erro humano vem de ruído na mira e na força.

const LEVELS := [
	{"nome": "Iniciante", "angles": 20, "powers": [0.35, 0.6, 0.85], "pick_top": 6,
		"ang_noise": 9.0, "pow_noise": 0.22},
	{"nome": "Intermediário", "angles": 40, "powers": [0.3, 0.5, 0.7, 0.9], "pick_top": 3,
		"ang_noise": 3.5, "pow_noise": 0.09},
	{"nome": "Avançado", "angles": 72, "powers": [0.25, 0.42, 0.58, 0.74, 0.9, 1.0], "pick_top": 1,
		"ang_noise": 0.9, "pow_noise": 0.03},
]

var rng := RandomNumberGenerator.new()


## Corrotina: distribui o cálculo em vários quadros (não trava a tela).
## Retorna {"dir": Vector2, "power": float}
func choose_shot(base: CoinSim, team: int, level: int, continue_own: bool, tree: SceneTree) -> Dictionary:
	var cfg: Dictionary = LEVELS[clampi(level, 0, 2)]
	var n_ang: int = cfg["angles"]
	var results: Array = []
	var budget_start := Time.get_ticks_usec()
	var offset := rng.randf() * TAU / n_ang
	for a in n_ang:
		var ang := offset + TAU * a / n_ang
		var dir := Vector2.from_angle(ang)
		for p: float in cfg["powers"]:
			var s := base.clone()
			s.vel = dir * CoinSim.launch_speed(p)
			s.reset_touch()
			var r := s.run_until_stop(6.0)
			results.append({"dir": dir, "power": p, "score": _score(r, team, continue_own)})
			if Time.get_ticks_usec() - budget_start > 7000:
				await tree.process_frame
				budget_start = Time.get_ticks_usec()
	results.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["score"] > y["score"])
	var top: int = mini(cfg["pick_top"], results.size())
	var pick: Dictionary = results[rng.randi_range(0, top - 1)]
	var dir2: Vector2 = pick["dir"].rotated(deg_to_rad(rng.randfn(0.0, cfg["ang_noise"])))
	var pw := clampf(pick["power"] * (1.0 + rng.randfn(0.0, cfg["pow_noise"])), 0.12, 1.0)
	return {"dir": dir2, "power": pw}


static func _score(r: Dictionary, team: int, continue_own: bool) -> float:
	var goal: int = r["goal"]
	if goal == team:
		return 10000.0 - r["time"] * 10.0
	if goal >= 0:
		return -10000.0
	var p: Vector2 = r["pos"]
	# time 0 ataca o gol de cima (y negativo); time 1 ataca o de baixo
	var adv := -p.y if team == 0 else p.y
	var score := adv
	# perigo: deixar a moeda perto do próprio gol para o adversário
	var own_goal := Vector2(0, FieldData.HH if team == 0 else -FieldData.HH)
	var danger := p.distance_to(own_goal)
	if danger < 320.0:
		score -= (320.0 - danger) * 2.0
	# perto do gol adversário e centralizado = ótimo
	var opp_goal := Vector2(0, -FieldData.HH if team == 0 else FieldData.HH)
	var near := p.distance_to(opp_goal)
	if near < 300.0:
		score += (300.0 - near) * 0.8 - absf(p.x) * 0.3
	if continue_own:
		var mine := 1 << team
		var other := 1 << (1 - team)
		var mask: int = r["mask"]
		if (mask & mine) != 0 and (mask & other) == 0:
			score += 260.0
	return score
