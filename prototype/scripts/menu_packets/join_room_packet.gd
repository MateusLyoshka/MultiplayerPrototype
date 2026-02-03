class_name JoinRoomClass extends PacketTypeClass

var room_id: int

static func create(room_id_: int) -> JoinRoomClass:
	var new_packet: JoinRoomClass = JoinRoomClass.new(PACKET_TYPE.JOIN_ROOM)
	new_packet.room_id = room_id_
	return new_packet

static func create_from_data(data: PackedByteArray) -> JoinRoomClass:
	var new_packet: JoinRoomClass = JoinRoomClass.new(PACKET_TYPE.JOIN_ROOM)
	new_packet.decode(data)
	return new_packet

func encode() -> PackedByteArray:
	var new_array: PackedByteArray = super.encode()
	new_array.resize(2)
	new_array.encode_u8(1, room_id)
	return new_array

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	room_id = data.decode_u8(1)
