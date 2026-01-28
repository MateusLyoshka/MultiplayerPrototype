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
		PacketTypeClass.PACKET_TYPE.START_ROOM:
			start_room(peer)
		PacketTypeClass.PACKET_TYPE.JOIN_ROOM:
			pass
		PacketTypeClass.PACKET_TYPE.QUIT_ROOM:
			pass
		PacketTypeClass.PACKET_TYPE.REFRESH:
			pass
		PacketTypeClass.PACKET_TYPE.REFRESH_REQUEST:
			send_refresh(peer)

func start_room(peer: ENetPacketPeer) -> void:
	if num_room.is_empty():
		print("Error: maximum rooms limit exceded!")
		return
	var room_id = num_room.pop_back()
	var members: Array[ENetPacketPeer] = [peer]
	created_rooms_id.append(room_id)
	rooms[room_id] = members
	StartRoomClass.create(room_id).send(peer)
	
func send_refresh(peer: ENetPacketPeer) -> void:
	RefreshClass.create(created_rooms_id).send(peer)
