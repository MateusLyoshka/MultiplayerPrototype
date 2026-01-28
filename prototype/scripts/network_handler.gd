extends Node

# Server signals
signal from_server_packet(data: PackedByteArray)

# Client signals
signal from_client_packet(peer: ENetPacketPeer, data: PackedByteArray)

# Client Server variables
var server_connection: ENetConnection

# Server variables
var is_server: bool
var avaliable_peer_ids: Array = range(255, -1, -1)
var peers_connected: Dictionary[int, ENetPacketPeer]

# Client variables
var server_peer: ENetPacketPeer

func _ready() -> void:
	var args = OS.get_cmdline_args()
	
	if "--server" in args:
		print("Initianlizing dedicated server")
		start_server()

func _process(_delta: float) -> void:
	if server_connection == null: return
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
				if is_server:
					peer_connected(peer_sender)
				else:
					client_connection()
			ENetConnection.EVENT_DISCONNECT:
				if is_server:
					peer_disconnected(peer_sender)
				else:
					client_disconnection()
			ENetConnection.EVENT_RECEIVE:
				if is_server:
					#print("Packet received")
					from_client_packet.emit(peer_sender ,peer_sender.get_packet())
				else:
					from_server_packet.emit(peer_sender.get_packet())
					
		packet_event = server_connection.service()
		event_type = packet_event[0]

func start_server(ip_address: String = "127.0.0.1", port: int = 42069) -> void:
	server_connection = ENetConnection.new()
	var error: Error = server_connection.create_host_bound(ip_address, port)
	if error:
		print("Host bound creation error: ", error)
		return
	else:
		print("Server started!")
		is_server = true

func peer_connected(peer: ENetPacketPeer) -> void:
	var peer_id: int = avaliable_peer_ids.pop_back()
	peer.set_meta("id", peer_id)
	print("Peer: ", peer_id, " succesfully connected")
	PeerId.create(peer_id).send(peer)

func peer_disconnected(peer: ENetPacketPeer) -> void:
	var peer_id: int = peer.get_meta("id")
	avaliable_peer_ids.push_back(peer_id)
	
	print("Peer: ", peer_id, " succesfully disconnected")

func start_client(ip_address: String, port: int) -> void:
	server_connection = ENetConnection.new()
	var error: Error = server_connection.create_host(1)
	if error:
		print("Host creation erro: ", error)
		return
	server_peer = server_connection.connect_to_host(ip_address, port)

func client_connection() -> void:
	#print("Peer connected (peer side)")
	return

func client_disconnection() -> void:
	print("Peer soccesfully disconnected from server!")
	server_connection = null
