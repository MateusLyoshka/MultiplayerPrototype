extends Node

# Mesmo papel do network_handler do client: este projeto so existe como
# cliente especial (professor) do server central. Sem branch de server.

signal from_server_packet(data: PackedByteArray)
signal on_peer_connected
signal on_connection_error

var server_connection: ENetConnection
var server_peer: ENetPacketPeer

# [TCC eval] log periodico de RTT/perda em user://enet_stats_professor_<unix>.csv.
const _STATS_INTERVAL_S: float = 1.0
var _stats_file: FileAccess
var _stats_accum: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if server_connection == null:
		return
	handle_events()
	if server_peer != null:
		_stats_tick(delta, [server_peer])

func handle_events() -> void:
	var packet_event: Array = server_connection.service()
	var event_type: ENetConnection.EventType = packet_event[0]
	while event_type != ENetConnection.EventType.EVENT_NONE:
		var peer_sender: ENetPacketPeer = packet_event[1]
		match event_type:
			ENetConnection.EVENT_ERROR:
				print("Packet received error")
			ENetConnection.EVENT_CONNECT:
				_stats_open("professor")
				on_peer_connected.emit()
				peer_sender.set_timeout(0, 10000, 10000)
			ENetConnection.EVENT_DISCONNECT:
				client_disconnection()
				return
			ENetConnection.EVENT_RECEIVE:
				from_server_packet.emit(peer_sender.get_packet())
		packet_event = server_connection.service()
		event_type = packet_event[0]

func start_client(ip_address: String, port: int) -> void:
	server_connection = ENetConnection.new()
	var error: Error = server_connection.create_host(1)
	if error:
		print("Host creation erro: ", error)
		return
	server_peer = server_connection.connect_to_host(ip_address, port)

func client_disconnection() -> void:
	print("Professor desconectado do server")
	server_peer = null
	server_connection = null
	_stats_file = null
	on_connection_error.emit()

# [TCC eval] abre arquivo de estatisticas para o papel atual.
func _stats_open(role: String) -> void:
	var path := "user://enet_stats_%s_%d.csv" % [role, int(Time.get_unix_time_from_system())]
	_stats_file = FileAccess.open(path, FileAccess.WRITE)
	if _stats_file == null:
		push_error("[stats] open failed: %s" % path)
		return
	_stats_file.store_line("timestamp,peer,rtt_ms,packet_loss_pct,packets_sent,packets_lost")
	print("[stats] gravando em ", ProjectSettings.globalize_path(path))

# [TCC eval] amostra a cada _STATS_INTERVAL_S segundos.
# PEER_PACKET_LOSS escala 0..65535 (=100%); normalizamos para porcentagem.
func _stats_tick(delta: float, peers: Array) -> void:
	if _stats_file == null:
		return
	_stats_accum += delta
	if _stats_accum < _STATS_INTERVAL_S:
		return
	_stats_accum = 0.0
	var ts := int(Time.get_unix_time_from_system())
	for peer in peers:
		if peer == null:
			continue
		if peer.get_state() != ENetPacketPeer.STATE_CONNECTED:
			continue
		var label := str(peer.get_meta("id")) if peer.has_meta("id") else "peer"
		var rtt := peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		var loss := peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)
		var sent := peer.get_statistic(ENetPacketPeer.PEER_PACKETS_SENT)
		var lost := peer.get_statistic(ENetPacketPeer.PEER_PACKETS_LOST)
		_stats_file.store_line("%d,%s,%.1f,%.4f,%d,%d" % [
			ts, label, rtt, (loss / 65535.0) * 100.0, int(sent), int(lost)
		])
	_stats_file.flush()
