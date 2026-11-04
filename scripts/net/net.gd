extends Node
## Multijogador local (mesma rede Wi-Fi ou ponto de acesso do celular).
## - O criador da sala é o servidor AUTORITATIVO (decide gols, placar, vez).
## - Só trafegam jogadas (direção + força) e "fotos" do estado ao fim de cada lance.
## - Código da sala = 2 últimos números do IP do servidor (o convidado completa
##   com os 2 primeiros do próprio IP). Ex.: 192.168.4.37 -> código 1061.
## - Descoberta automática por broadcast UDP (melhor esforço; alguns Androids bloqueiam).
## Sem internet, sem cadastro, sem coleta de dados.

signal peer_joined
signal peer_left
signal connected_to_host
signal connection_failed(reason: String)
signal message(type: String, data: Dictionary)
signal room_found(info: Dictionary)

const PROTOCOL := 1
const GAME_PORT := 27620
const DISCOVERY_PORT := 27621
const BEACON_TAG := "PREGO1"

var is_host := false
var online := false
var host_ip := ""
var peer_ok := false            # há um adversário conectado e validado
var _peer: ENetMultiplayerPeer
var _beacon: PacketPeerUDP
var _listen: PacketPeerUDP
var _beacon_t := 0.0
var _beacon_name := ""
var _join_deadline := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _fail("Não consegui conectar à sala."))
	multiplayer.server_disconnected.connect(_on_server_gone)


# ------------------------------------------------------------------ endereços
static func local_ip() -> String:
	var best := ""
	var best_rank := 99
	for a in IP.get_local_addresses():
		if a.count(".") != 3 or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		var p := a.split(".")
		var rank := 99
		if a.begins_with("192.168."):
			rank = 0
		elif a.begins_with("10."):
			rank = 1
		elif p[0] == "172" and int(p[1]) >= 16 and int(p[1]) <= 31:
			rank = 2
		else:
			rank = 3   # último recurso: outra faixa IPv4 (ex.: redes de teste)
		if rank < best_rank:
			best_rank = rank
			best = a
	return best


static func code_from_ip(ip: String) -> String:
	var p := ip.split(".")
	if p.size() != 4:
		return ""
	return str(int(p[2]) * 256 + int(p[3]))


## Aceita o código numérico ou um IP completo. Retorna "" se inválido.
static func ip_from_code(code: String, my_ip := "") -> String:
	code = code.strip_edges().replace(" ", "").replace("-", "")
	if code.count(".") == 3:
		for part in code.split("."):
			if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
				return ""
		return code
	if not code.is_valid_int():
		return ""
	var n := int(code)
	if n <= 0 or n > 65535:
		return ""
	if my_ip == "":
		my_ip = local_ip()
	if my_ip == "":
		return ""
	var p := my_ip.split(".")
	return "%s.%s.%d.%d" % [p[0], p[1], n / 256, n % 256]


# ------------------------------------------------------------------ sala
func host_room(player_name: String) -> Error:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(GAME_PORT, 1)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	is_host = true
	online = true
	host_ip = local_ip()
	_beacon_name = player_name
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	return OK


func join_room(ip: String) -> Error:
	leave(false)
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, GAME_PORT)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	is_host = false
	online = true
	host_ip = ip
	_join_deadline = Time.get_ticks_msec() + 7000
	return OK


func leave(stop_listen := true) -> void:
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	is_host = false
	peer_ok = false
	_join_deadline = 0.0
	if _beacon:
		_beacon.close()
		_beacon = null
	if stop_listen:
		stop_discovery()


func close_room_to_new_players() -> void:
	if _peer and is_host:
		_peer.refuse_new_connections = true


func open_room() -> void:
	if _peer and is_host:
		_peer.refuse_new_connections = false


# ------------------------------------------------------------------ descoberta
func start_discovery() -> void:
	stop_discovery()
	_listen = PacketPeerUDP.new()
	if _listen.bind(DISCOVERY_PORT) != OK:
		_listen = null


func stop_discovery() -> void:
	if _listen:
		_listen.close()
		_listen = null


# ------------------------------------------------------------------ mensagens
func send(type: String, data := {}) -> void:
	if not online or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if is_host and multiplayer.get_peers().is_empty():
		return
	_msg.rpc(type, data)


@rpc("any_peer", "call_remote", "reliable")
func _msg(type: String, data: Dictionary) -> void:
	# servidor só aceita mensagens do seu cliente; cliente só do servidor (id 1)
	var sender := multiplayer.get_remote_sender_id()
	if not is_host and sender != 1:
		return
	if typeof(type) != TYPE_STRING or type.length() > 24:
		return
	message.emit(type, data)


# ------------------------------------------------------------------ eventos ENet
func _on_peer_connected(id: int) -> void:
	if is_host:
		var p := _peer.get_peer(id)
		if p:
			p.set_timeout(32, 4000, 9000)
		peer_ok = true
		peer_joined.emit()


func _on_peer_disconnected(_id: int) -> void:
	if is_host:
		peer_ok = false
		peer_left.emit()


func _on_connected() -> void:
	_join_deadline = 0.0
	peer_ok = true
	var p := _peer.get_peer(1)
	if p:
		p.set_timeout(32, 4000, 9000)
	connected_to_host.emit()


func _on_server_gone() -> void:
	peer_ok = false
	online = false
	peer_left.emit()


func _fail(reason: String) -> void:
	_join_deadline = 0.0
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	connection_failed.emit(reason)


func _process(delta: float) -> void:
	if _join_deadline > 0.0 and Time.get_ticks_msec() > _join_deadline:
		_fail("Sala não encontrada. Confira o código e se vocês estão no mesmo Wi-Fi.")
	if _beacon and is_host and not peer_ok:
		_beacon_t -= delta
		if _beacon_t <= 0.0:
			_beacon_t = 1.0
			var msg := "%s|%s|%s" % [BEACON_TAG, code_from_ip(host_ip), _beacon_name.left(12)]
			_beacon.put_packet(msg.to_utf8_buffer())
	if _listen:
		while _listen.get_available_packet_count() > 0:
			var pkt := _listen.get_packet().get_string_from_utf8()
			var ip := _listen.get_packet_ip()
			var parts := pkt.split("|")
			if parts.size() == 3 and parts[0] == BEACON_TAG and ip != "":
				room_found.emit({"ip": ip, "code": parts[1], "name": parts[2]})
