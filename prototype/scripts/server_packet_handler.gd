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
			print("pacote IP")
		PacketTypeClass.PACKET_TYPE.ROOM_REQUEST:
			room_request(peer, data)
		PacketTypeClass.PACKET_TYPE.JOIN_ROOM:
			pass
		PacketTypeClass.PACKET_TYPE.JOIN_REQUEST:
			join_request(peer, data)
		PacketTypeClass.PACKET_TYPE.QUIT_ROOM:
			pass
		PacketTypeClass.PACKET_TYPE.REFRESH:
			pass
		PacketTypeClass.PACKET_TYPE.REFRESH_REQUEST:
			send_refresh(peer)
	
func send_refresh(peer: ENetPacketPeer) -> void:
	RefreshClass.create(created_rooms_id).send(peer)

func join_request(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var request: JoinRequestClass = JoinRequestClass.create_from_data(data)
	var room: int = request.room
	if(rooms[room].size() > 4): 
		print("The room is full!")
		return
	elif(rooms[room].size() == 0):
		print("The room was closed!")
		return
	rooms[room].append(peer)
	print("All rooms: ", rooms)

func room_request(peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var request: RoomRequestClass = RoomRequestClass.create_from_data(data)
	var requester_id: int = request.id
	if num_room.is_empty():
		print("Error: maximum rooms limit exceded!")
		return
	var room_id = num_room.pop_back()
	var members: Array[ENetPacketPeer] = [peer]
	created_rooms_id.append(room_id)
	rooms[room_id] = members
	StartRoomClass.create(room_id, requester_id).send(peer)
	
