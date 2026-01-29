class_name JoinRequestClass extends PacketTypeClass

var room: int
var client: int

static func create(room_id: int, client_id: int) -> JoinRequestClass:
	var packet: JoinRequestClass = JoinRequestClass.new(PacketTypeClass.PACKET_TYPE.JOIN_REQUEST, ENetPacketPeer.FLAG_RELIABLE)
	packet.room = room_id
	packet.client = client_id
	return packet

static func create_from_data(data: PackedByteArray) -> JoinRequestClass:
	var new_class: JoinRequestClass = JoinRequestClass.new(PacketTypeClass.PACKET_TYPE.JOIN_REQUEST, ENetPacketPeer.FLAG_RELIABLE)
	new_class.decode(data)
	return new_class

func encode() -> PackedByteArray:
	var new_array: PackedByteArray = super.encode()
	new_array.resize(3)
	new_array.encode_u8(1, client)
	new_array.encode_u8(2, room)
	return new_array

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	client = data.decode_u8(1)
	room = data.decode_u8(2)
