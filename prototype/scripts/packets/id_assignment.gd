class_name IdClass extends PacketTypeClass

var id: int
var room_peers_id: Array[int]

static func create(peer_id: int, peers_id: Array[int]) -> IdClass:
	var info: IdClass = IdClass.new()
	info.packet_type = PACKET_TYPE.PEER_ID
	info.flag = ENetPacketPeer.FLAG_RELIABLE
	info.id = peer_id
	info.room_peers_id = peers_id
	return info

static func create_from_data(data: PackedByteArray) -> IdClass:
	var info: IdClass = IdClass.new()
	info.decode(data)
	return info
	
func decode(data: PackedByteArray) -> void:
	super.decode(data)
	id = data.decode_u8(1)
	for i in range(2, data.size()):
		room_peers_id.append(data.decode_u8(i))

func encode() -> PackedByteArray:
	var packet_array: PackedByteArray = super.encode()
	packet_array.resize(2 + room_peers_id.size())
	packet_array.encode_u8(1, id)
	for i in range(2, packet_array.size()):
		packet_array.encode_u8(i, room_peers_id[i])
	return packet_array
