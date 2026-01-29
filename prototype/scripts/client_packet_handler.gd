extends Node

signal created_room(room_id: int)
signal room_refresh(rooms_id: Array[int])

var client_id: int

func _ready() -> void:
	ProtNetworkHandler.from_server_packet.connect(packet_handler)

func packet_handler(data: PackedByteArray) -> void:
	var packet_type: int = int(data.decode_u8(0))
	match packet_type:
		PacketTypeClass.PACKET_TYPE.PEER_ID:
			var peer_id: PeerId = PeerId.create_from_data(data)
			client_id = peer_id.id
			print(peer_id.id)
		PacketTypeClass.PACKET_TYPE.START_ROOM:
			var start_room: StartRoomClass = StartRoomClass.create_from_data(data)
			created_room.emit(start_room.requester, start_room.room)
			print("(Client handler) room id: ", start_room.id)
		PacketTypeClass.PACKET_TYPE.JOIN_ROOM:
			pass
		PacketTypeClass.PACKET_TYPE.JOIN_REQUEST:
			print("Join request packet")
		PacketTypeClass.PACKET_TYPE.QUIT_ROOM:
			pass
		PacketTypeClass.PACKET_TYPE.REFRESH:
			var refresh: RefreshClass = RefreshClass.create_from_data(data)
			var rooms_id: Array[int] = refresh.rooms_id
			rooms_id.pop_front()
			room_refresh.emit(rooms_id)
		PacketTypeClass.PACKET_TYPE.REFRESH_REQUEST:
			pass
