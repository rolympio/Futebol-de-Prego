extends Node
## Efeitos sonoros sintetizados em tempo de execução (sem arquivos de áudio
## de terceiros). Todos podem ser desligados nas configurações.

const RATE := 22050
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["nail"] = _make(0.16, func(t: float) -> float:
		var e := exp(-t * 38.0)
		return e * (0.55 * sin(TAU * 1760.0 * t) + 0.3 * sin(TAU * 2637.0 * t) + 0.15 * sin(TAU * 4100.0 * t)))
	_streams["wall"] = _make(0.14, func(t: float) -> float:
		var e := exp(-t * 30.0)
		return e * (0.7 * sin(TAU * (190.0 - 300.0 * t) * t) + 0.3 * (randf() * 2.0 - 1.0) * exp(-t * 80.0)))
	_streams["launch"] = _make(0.22, func(t: float) -> float:
		var e := sin(PI * t / 0.22)
		return 0.35 * e * (randf() * 2.0 - 1.0) * (0.4 + t * 3.0))
	_streams["click"] = _make(0.06, func(t: float) -> float:
		return exp(-t * 90.0) * sin(TAU * 900.0 * t) * 0.6)
	_streams["goal"] = _make(1.1, func(t: float) -> float:
		var notes := PackedFloat32Array([523.25, 659.25, 783.99, 1046.5])
		var idx := mini(int(t / 0.12), 3)
		var lt := t - idx * 0.12
		var tone := sin(TAU * notes[idx] * t) * exp(-lt * 6.0) * 0.45
		var crowd := (randf() * 2.0 - 1.0) * 0.22 * minf(t * 4.0, 1.0) * exp(-maxf(t - 0.6, 0.0) * 5.0)
		return tone + crowd)
	_streams["whistle"] = _make(0.45, func(t: float) -> float:
		var trill := 1.0 + 0.04 * sin(TAU * 28.0 * t)
		return 0.35 * sin(TAU * 2300.0 * trill * t) * minf(t * 30.0, 1.0) * minf((0.45 - t) * 20.0, 1.0))
	_streams["lose"] = _make(0.7, func(t: float) -> float:
		return 0.4 * sin(TAU * (420.0 - 220.0 * t) * t) * exp(-t * 2.5))


func _make(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(fn.call(float(i) / RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func play(name: String, volume := 1.0, pitch := 1.0) -> void:
	if not Save.settings["sound"] or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = linear_to_db(clampf(volume, 0.05, 1.0))
	p.pitch_scale = pitch
	p.play()
