extends Node

signal from_client_packet(peer: ENetPacketPeer, data: PackedByteArray)

var server_connection: ENetConnection
var avaliable_peer_ids: Array = range(255, -1, -1)
var peers_connected: Dictionary[int, ENetPacketPeer]

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
				peer_connected(peer_sender)
				# Debug timeout — mesmo valor de antes para testes longos.
				peer_sender.set_timeout(0, 10000, 10000)
			ENetConnection.EVENT_DISCONNECT:
				peer_disconnected(peer_sender)
			ENetConnection.EVENT_RECEIVE:
				from_client_packet.emit(peer_sender, peer_sender.get_packet())
		packet_event = server_connection.service()
		event_type = packet_event[0]

func start_server(ip_address: String, port: int = 42069) -> bool:
	server_connection = ENetConnection.new()
	var error: Error = server_connection.create_host_bound(ip_address, port)
	if error != OK:
		printerr("ERRO FATAL AO CRIAR HOST: ", error)
		server_connection = null
		return false
	print("Server started at ", ip_address, ":", port)
	return true

func peer_connected(peer: ENetPacketPeer) -> void:
	var peer_id: int = avaliable_peer_ids.pop_back()
	peer.set_meta("id", peer_id)
	peers_connected[peer_id] = peer
	PeerId.create(peer_id).send(peer)
	ServerPacketHandler.send_refresh(peer)
	print("(Server network) Peer: ", peer_id, " successfully connected")

func peer_disconnected(peer: ENetPacketPeer) -> void:
	var peer_id: int = peer.get_meta("id")
	avaliable_peer_ids.push_back(peer_id)
	peers_connected.erase(peer_id)
	print("Peer: ", peer_id, " successfully disconnected")
