class_name StartRoomClass extends PacketTypeClass

var id: int

static func create(room_id: int) -> StartRoomClass:
	var new_packet: StartRoomClass = StartRoomClass.new()
	new_packet.packet_type = PACKET_TYPE.START_ROOM
	new_packet.flag = ENetPacketPeer.FLAG_RELIABLE
	new_packet.id = room_id
	return new_packet

static func create_from_data(data: PackedByteArray) -> StartRoomClass:
	var new_packet: StartRoomClass = StartRoomClass.new()
	new_packet.decode(data)
	return new_packet

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	id = data.decode_u8(1)

func encode() -> PackedByteArray:
	var new_packed: PackedByteArray = super.encode()
	new_packed.resize(2)
	new_packed.encode_u8(1, id)
	return new_packed
