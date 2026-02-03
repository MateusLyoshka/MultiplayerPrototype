class_name RefreshClass extends PacketTypeClass

var rooms_id: Array[int]

static func create(rooms: Array[int]) -> RefreshClass:
	var refresh: RefreshClass = RefreshClass.new(PacketTypeClass.PACKET_TYPE.REFRESH, ENetPacketPeer.FLAG_RELIABLE)
	refresh.rooms_id = rooms
	return refresh

static func create_from_data(data: PackedByteArray) -> RefreshClass:
	var refresh: RefreshClass = RefreshClass.new(PacketTypeClass.PACKET_TYPE.REFRESH, ENetPacketPeer.FLAG_RELIABLE)
	refresh.decode(data)
	return refresh

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	var new_rooms: Array[int]
	#print(data.size())
	for i in range(1, data.size()):
		new_rooms.append(data.decode_u8(i))
	rooms_id = new_rooms

func encode() -> PackedByteArray:
	var new_packet: PackedByteArray = super.encode()
	new_packet.resize(2 + rooms_id.size())
	for i in rooms_id.size():
		new_packet.encode_u8(2 + i, rooms_id[i])
	return new_packet
