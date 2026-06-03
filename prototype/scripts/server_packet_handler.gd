extends Node

var num_room: Array = range(255, -1, -1)
var created_rooms_id: Array[int]
var rooms: Dictionary[int, RoomStorage]
# Respostas do minigame por sala, recebidas do host quando as 2 duplas
# concluem. Estrutura: { room_id: { teams: Array (mesma forma do pacote),
# received_at: int (Time.get_ticks_msec) } }. Consumido pela UI do professor
# (passo futuro).
var minigame_submissions: Dictionary[int, Dictionary] = {}

func _ready() -> void:
	ProtNetworkHandler.from_client_packet.connect(client_packet_handler)
	var refresh_timer: Timer = Timer.new()
	refresh_timer.wait_time = 5.0
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(_on_refresh_tick)
	add_child(refresh_timer)

func _on_refresh_tick() -> void:
	for peer in ProtNetworkHandler.peers_connected.values():
		if not peer.get_meta("in_room", false):
			send_refresh(peer)

func client_packet_handler(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var packet_type: int = int(data.decode_u8(0))
	match packet_type:
		PacketTypeClass.PACKET_TYPE.ROOM_REQUEST:
			room_request(peer, data)
		PacketTypeClass.PACKET_TYPE.JOIN_REQUEST:
			join_request(peer, data)
		PacketTypeClass.PACKET_TYPE.QUIT_ROOM_REQUEST:
			quit_room_request(peer, data)
		PacketTypeClass.PACKET_TYPE.REFRESH_REQUEST:
			send_refresh(peer)
		PacketTypeClass.PACKET_TYPE.ROOM_INFO:
			save_room_info(peer, data)
		PacketTypeClass.PACKET_TYPE.MINIGAME_SUBMISSION:
			save_minigame_submission(peer, data)

func save_room_info(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var room_packet: RoomInfoClass = RoomInfoClass.create_from_data(data)
	var room_id: int = room_packet.room_id
	var new_room: RoomStorage = RoomStorage.new(room_packet.host_ip, room_packet.room_port, peer)
	new_room.add_player(peer)
	new_room.add_player_id(room_packet.player_id)
	new_room.add_player_name(room_packet.player_name)
	peer.set_meta("name", room_packet.player_name)
	created_rooms_id.append(room_id)
	rooms[room_id] = new_room
	peer.set_meta("in_room", true)
	print("(Server handler) info saved: ", rooms)

func save_minigame_submission(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var packet: MinigameSubmissionPkt = MinigameSubmissionPkt.create_from_data(data)
	var room_id: int = packet.room_id
	# Só aceita do host da sala (impede client malicioso de injetar).
	if not rooms.has(room_id) or rooms[room_id].host_peer != peer:
		print("(Server handler) submission ignorada — peer não é host da sala ", room_id)
		return
	minigame_submissions[room_id] = {
		"teams": packet.teams,
		"received_at": Time.get_ticks_msec()
	}
	print("(Server handler) minigame submission room=", room_id, " teams=", packet.teams)

func send_refresh(peer: ENetPacketPeer) -> void:
	RefreshClass.create(rooms, created_rooms_id).send(peer)

func join_request(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var request: JoinRequestClass = JoinRequestClass.create_from_data(data)
	var room: int = request.room
	if (!created_rooms_id.has(room)):
		print("This room does not exist anymore, please refresh the page!")
		return
	if (rooms[room].current_players.size() > 4):
		print("The room is full!")
		return
	rooms[room].add_player(peer)
	rooms[room].add_player_id(request.player_id)
	rooms[room].add_player_name(request.player_name)
	peer.set_meta("name", request.player_name)
	peer.set_meta("in_room", true)
	JoinRoomClass.create(room, rooms[room].port, rooms[room].host_ip, rooms[room].current_players_id).send(peer)
	for i in range(rooms[room].current_players_id.size()):
		if rooms[room].current_players[i] != peer:
			HasJoinedPkt.create(rooms[room].current_players_id).send(rooms[room].current_players[i])
	print("(Server handler) All players in the room: ", rooms[room].current_players_id)

func room_request(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var request: RoomRequestClass = RoomRequestClass.create_from_data(data)
	var requester_id: int = request.id
	if num_room.is_empty():
		print("Error: maximum rooms limit exceded!")
		return
	var room_id = num_room.pop_back()
	StartRoomClass.create(room_id, requester_id).send(peer)

func quit_room_request(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var quit_request: QuitRequestClass = QuitRequestClass.create_from_data(data)
	var room_req_id = quit_request.room_id
	print("(Server handle) quitting room: ", quit_request.room_id)
	if not rooms.has(room_req_id):
		return

	var room: RoomStorage = rooms[room_req_id]
	if peer == room.host_peer:
		for current_peer in room.current_players.duplicate():
			current_peer.set_meta("in_room", false)
			QuitRoomClass.create().send(current_peer)
		rooms.erase(room_req_id)
		created_rooms_id.erase(room_req_id)
		num_room.append(room_req_id)
		num_room.sort()
		return

	room.remove_player(peer)
	room.remove_player_id(peer.get_meta("id"))
	room.remove_player_name(peer.get_meta("name", ""))
	peer.set_meta("in_room", false)
	QuitRoomClass.create().send(peer)
	for current_peer in room.current_players:
		HasQuittedPkt.create(room.current_players_id).send(current_peer)

#func is_peer_owner(room_id: int, peer: ENetPacketPeer) -> bool:
	#if not rooms.has(room_id) or rooms[room_id].is_empty():
		#return false
	#return rooms[room_id][0] == peer
