extends Node

var num_room: Array = range(255, -1, -1)
var created_rooms_id: Array[int]
var rooms: Dictionary[int, RoomStorage]

func _ready() -> void:
	ProtNetworkHandler.from_client_packet.connect(client_packet_handler)

func client_packet_handler(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var packet_type: int = int(data.decode_u8(0))
	match packet_type:
		PacketTypeClass.PACKET_TYPE.PEER_ID:
			pass
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

func save_room_info(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var room_packet: RoomInfoClass = RoomInfoClass.create_from_data(data)
	var room_id: int = room_packet.room_id
	var new_room: RoomStorage = RoomStorage.new(room_packet.host_ip, room_packet.room_port, peer)
	new_room.add_player_id(room_packet.player_id)
	new_room.add_player(peer)
	created_rooms_id.append(room_id)
	rooms[room_id] = new_room
	print("(Server handler) info saved: ", rooms)

func send_refresh(peer: ENetPacketPeer) -> void:
	RefreshClass.create(created_rooms_id).send(peer)

func join_request(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var request: JoinRequestClass = JoinRequestClass.create_from_data(data)
	var room: int = request.room
	if(!created_rooms_id.has(room)):
		print("This room does not exist anymore, please refresh the page!")
		return
	if(rooms[room].current_players.size() > 4): 
		print("The room is full!")
		return
	RoomInfoClass.create(0, room, rooms[room].port, rooms[room].host_ip, rooms[room].current_players_id).send(peer)
	rooms[room].add_player(peer)
	print("(Server handler) All rooms: ", rooms)

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
	print("(Server handle) quiting room: ", quit_request.room_id)
	if peer == rooms[room_req_id].host_peer:
		rooms.erase(room_req_id)
		created_rooms_id.erase(room_req_id)
	QuitRoomClass.create().send(peer)

#func is_peer_owner(room_id: int, peer: ENetPacketPeer) -> bool:
	#if not rooms.has(room_id) or rooms[room_id].is_empty():
		#return false
	#return rooms[room_id][0] == peer
