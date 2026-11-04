class_name CoinSim
extends RefCounted
## Física própria da moeda: determinística, com sub-passos para nunca
## atravessar pregos ou paredes. A mesma simulação é usada pelo jogo,
## pela prévia de mira e pela IA (que portanto não "trapaceia").

const COIN_R := 21.0
const NAIL_R := 12.5
const E_NAIL := 0.80          # restituição nos pregos (quique vivo)
const E_WALL := 0.62          # restituição nas bordas
const WALL_TANGENT_KEEP := 0.96
const FRICTION_K := 1.05      # atrito proporcional (desliza suave)
const FRICTION_LIN := 150.0   # atrito constante (para naturalmente)
const STOP_SPEED := 12.0
const MIN_LAUNCH := 260.0
const MAX_LAUNCH := 2150.0
const DT := 1.0 / 120.0

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var rot := 0.0
var nails := PackedVector2Array()
var nail_team := PackedInt32Array()
var seg_a := PackedVector2Array()
var seg_b := PackedVector2Array()
var hw := FieldData.HW
var hh := FieldData.HH
var gw := FieldData.GW
var gd := FieldData.GD

## Eventos do último passo: {"t": "nail"|"wall", "i": idx, "s": velocidade, "p": ponto}
var hits: Array = []
var record_hits := true
## Bits dos times cujos pregos foram tocados desde o último reset_touch()
var touched_mask := 0
var travelled := 0.0


func setup(nail_list: PackedVector2Array, teams: PackedInt32Array) -> void:
	nails = nail_list
	nail_team = teams
	_build_walls()


func _build_walls() -> void:
	seg_a = PackedVector2Array()
	seg_b = PackedVector2Array()
	var c := FieldData.CHAMFER
	for s: float in [-1.0, 1.0]:
		var y: float = hh * s
		var yn: float = (hh + gd) * s
		# linha de fundo (com abertura do gol)
		_seg(Vector2(-hw + c, y), Vector2(-gw, y))
		_seg(Vector2(gw, y), Vector2(hw - c, y))
		# cantos chanfrados (evitam moeda presa no canto)
		_seg(Vector2(-hw, y - c * s), Vector2(-hw + c, y))
		_seg(Vector2(hw - c, y), Vector2(hw, y - c * s))
		# rede do gol
		_seg(Vector2(-gw, y), Vector2(-gw, yn))
		_seg(Vector2(-gw, yn), Vector2(gw, yn))
		_seg(Vector2(gw, yn), Vector2(gw, y))
	# laterais
	_seg(Vector2(-hw, -hh + c), Vector2(-hw, hh - c))
	_seg(Vector2(hw, -hh + c), Vector2(hw, hh - c))


func _seg(a: Vector2, b: Vector2) -> void:
	seg_a.append(a)
	seg_b.append(b)


func clone() -> CoinSim:
	var s := CoinSim.new()
	s.nails = nails
	s.nail_team = nail_team
	s.seg_a = seg_a
	s.seg_b = seg_b
	s.pos = pos
	s.vel = vel
	return s


static func launch_speed(power: float) -> float:
	return lerpf(MIN_LAUNCH, MAX_LAUNCH, pow(clampf(power, 0.0, 1.0), 1.12))


func is_moving() -> bool:
	return vel != Vector2.ZERO


func reset_touch() -> void:
	touched_mask = 0
	travelled = 0.0


## -1 = sem gol; 0 = gol do time 0 (gol de cima); 1 = gol do time 1 (gol de baixo)
func goal_state() -> int:
	if pos.y < -hh - COIN_R and absf(pos.x) < gw:
		return 0
	if pos.y > hh + COIN_R and absf(pos.x) < gw:
		return 1
	return -1


func step() -> void:
	if record_hits:
		hits.clear()
	var speed := vel.length()
	if speed <= 0.0:
		return
	var n := clampi(ceili(speed * DT / (COIN_R * 0.35)), 1, 48)
	var h := DT / float(n)
	for _i in n:
		pos += vel * h
		_collide()
	travelled += speed * DT
	rot += speed * DT / COIN_R * 0.35
	speed = vel.length()
	var ns := speed * exp(-FRICTION_K * DT) - FRICTION_LIN * DT
	if ns <= STOP_SPEED:
		vel = Vector2.ZERO
	else:
		vel *= ns / speed


func _collide() -> void:
	var rr := COIN_R + NAIL_R
	var rr2 := rr * rr
	for j in nails.size():
		var d := pos - nails[j]
		var d2 := d.length_squared()
		if d2 < rr2:
			var dist := sqrt(d2)
			var nrm := d / dist if dist > 0.0001 else Vector2.UP
			pos = nails[j] + nrm * rr
			var vn := vel.dot(nrm)
			if vn < 0.0:
				vel -= (1.0 + E_NAIL) * vn * nrm
				var t := nail_team[j]
				if t >= 0:
					touched_mask |= (1 << t)
				if record_hits:
					hits.append({"t": "nail", "i": j, "s": -vn, "p": nails[j] + nrm * NAIL_R})
	var r2 := COIN_R * COIN_R
	for k in seg_a.size():
		var a := seg_a[k]
		var ab := seg_b[k] - a
		var t2 := clampf((pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * t2
		var d := pos - q
		var d2 := d.length_squared()
		if d2 < r2:
			var dist := sqrt(d2)
			var nrm := d / dist if dist > 0.0001 else Vector2.UP
			pos = q + nrm * COIN_R
			var vn := vel.dot(nrm)
			if vn < 0.0:
				var vt := vel - vn * nrm
				vel = vt * WALL_TANGENT_KEEP - E_WALL * vn * nrm
				if record_hits:
					hits.append({"t": "wall", "i": k, "s": -vn, "p": q})


## Roda até parar (ou gol). Usado pela IA e pelos testes.
func run_until_stop(max_time := 6.0) -> Dictionary:
	var was := record_hits
	record_hits = false
	var steps := int(max_time / DT)
	var goal := -1
	var t := 0
	while t < steps:
		step()
		goal = goal_state()
		if goal >= 0 or vel == Vector2.ZERO:
			break
		t += 1
	record_hits = was
	return {"goal": goal, "pos": pos, "mask": touched_mask, "time": t * DT}


## Prévia curta: trajeto até a 1ª colisão + um pequeno trecho após o quique.
## Não revela o resultado de múltiplas colisões.
func preview(from: Vector2, v: Vector2, after_bounce := 70.0) -> PackedVector2Array:
	var s := clone()
	s.pos = from
	s.vel = v
	s.record_hits = true
	var pts := PackedVector2Array([from])
	var bounced := false
	var extra := 0.0
	for _i in 600:
		var before := s.pos
		s.step()
		pts.append(s.pos)
		if bounced:
			extra += before.distance_to(s.pos)
			if extra >= after_bounce:
				break
		elif not s.hits.is_empty():
			bounced = true
		if s.vel == Vector2.ZERO or s.goal_state() >= 0:
			break
	return pts
