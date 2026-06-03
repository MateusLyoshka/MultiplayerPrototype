extends Node

# Mesmo papel do network_handler do client: este projeto so existe como
# cliente especial (professor) do server central. Sem branch de server.

signal from_server_packet(data: PackedByteArray)
signal on_peer_connected
signal on_connection_error

var server_connection: ENetConnection
var server_peer: ENetPacketPeer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if server_connection == null:
		return
	handle_events()

func handle_events() -> void:
	var packet_event: Array = server_connection.service()
	var event_type: ENetConnection.EventType = packet_event[0]
	while event_type != ENetConnection.EventType.EVENT_NONE:
		var peer_sender: ENetPacketPeer = packet_event[1]
		match event_type:
			ENetConnection.EVENT_ERROR:
				print("Packet received error")
			ENetConnection.EVENT_CONNECT:
				on_peer_connected.emit()
				peer_sender.set_timeout(0, 3600000, 3600000)
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
	on_connection_error.emit()
