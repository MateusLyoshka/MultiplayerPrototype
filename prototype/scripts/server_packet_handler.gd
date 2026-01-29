extends Node

var rooms: Dictionary[int, Array]
var num_room: Array = range(255, -1, -1)
var created_rooms_id: Array[int]

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
	
func send_refresh(peer: ENetPacketPeer) -> void:
	RefreshClass.create(created_rooms_id).send(peer)

func join_request(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var request: JoinRequestClass = JoinRequestClass.create_from_data(data)
	var room: int = request.room
	if(!created_rooms_id.has(room)):
		print("This room does not exist anymore, please refresh the page!")
		return
	if(rooms[room].size() > 4): 
		print("The room is full!")
		return
	elif(!is_peer_owner(room, peer) and rooms[room].is_empty()):
		print("The room was closed!")
		return
	JoinRoomClass.create(room).send(peer)
	rooms[room].append(peer)
	print("(Server handler) All rooms: ", rooms)

func room_request(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var request: RoomRequestClass = RoomRequestClass.create_from_data(data)
	var requester_id: int = request.id
	if num_room.is_empty():
		print("Error: maximum rooms limit exceded!")
		return
	var room_id = num_room.pop_back()
	created_rooms_id.append(room_id)
	rooms[room_id] = [] as Array[ENetPacketPeer]
	rooms[room_id].append(peer)
	StartRoomClass.create(room_id, requester_id).send(peer)

func quit_room_request(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var quit_request: QuitRequestClass = QuitRequestClass.create_from_data(data)
	var room_req_id = quit_request.room_id
	print("(Server handle) quiting room: ", quit_request.room_id)
	rooms[room_req_id].erase(peer)
	if rooms[room_req_id].is_empty():
		rooms.erase(room_req_id)
		created_rooms_id.erase(room_req_id)
		num_room.push_back(room_req_id)
	QuitRoomClass.create().send(peer)

func is_peer_owner(room_id: int, peer: ENetPacketPeer) -> bool:
	if not rooms.has(room_id) or rooms[room_id].is_empty():
		return false
	return rooms[room_id][0] == peer
