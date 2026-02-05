extends Node

# Server signals
signal from_host_packet(data: PackedByteArray)

# Client signals
signal from_player_packet(peer: ENetPacketPeer, data: PackedByteArray)

# Client Server variables
var host_connection: ENetConnection

# Server variables
var is_host: bool
var avaliable_player_ids: Array = range(3, -1, -1)

# Client variables
var host_peer: ENetPacketPeer

func _process(_delta: float) -> void:
	if host_connection == null: return
	handle_events()

func handle_events() -> void:
	var packet_event: Array = host_connection.service()
	var event_type: ENetConnection.EventType = packet_event[0]
	while event_type != ENetConnection.EventType.EVENT_NONE:
		var peer_sender: ENetPacketPeer = packet_event[1]
		match event_type:
			ENetConnection.EVENT_ERROR:
				print("Packet received error")
			ENetConnection.EVENT_CONNECT:
				if is_host:
					player_connected(peer_sender)
				else:
					player_connection()
			ENetConnection.EVENT_DISCONNECT:
				if is_host:
					peer_disconnected(peer_sender)
				else:
					host_disconnection()
					return
			ENetConnection.EVENT_RECEIVE:
				if is_host:
					from_player_packet.emit(peer_sender, peer_sender.get_packet())
				else:
					from_host_packet.emit(peer_sender.get_packet())
					
		packet_event = host_connection.service()
		event_type = packet_event[0]

func start_host(ip_address: String = "127.0.0.1", port: int = 42069) -> void:
	host_connection = ENetConnection.new()
	var error: Error = host_connection.create_host_bound(ip_address, port)
	if error:
		print("Host bound creation error: ", error)
		return
	else:
		print("Host started!")
		is_host = true

func player_connected(_peer: ENetPacketPeer) -> void:
	print("New player connected")

func peer_disconnected(peer: ENetPacketPeer) -> void:
	var player_id: int = peer.get_meta("id")
	avaliable_player_ids.push_back(player_id)
	
	print("Peer: ", player_id, " succesfully disconnected")

func start_player(ip_address: String, port: int) -> void:
	host_connection = ENetConnection.new()
	var error: Error = host_connection.create_host(1)
	if error:
		print("Host creation erro: ", error)
		return
	host_peer = host_connection.connect_to_host(ip_address, port)
	print("Host peer and my id: ", host_peer, ClientPacketHandler.client_id)

func player_connection() -> void:
	#print("Peer connected (peer side)")
	return

func host_disconnection() -> void:
	print("Host disconnected")
	host_connection = null
