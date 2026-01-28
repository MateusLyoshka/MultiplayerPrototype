class_name JoinRequestClass extends IDAssignment

static func create(room_id: int) -> JoinRequestClass:
	var packet: JoinRequestClass = JoinRequestClass.new()
	packet.packet_type = PACKET_TYPE.JOIN_REQUEST
	packet.flag = ENetPacketPeer.FLAG_RELIABLE
	packet.id = room_id
	return packet

static func create_from_data(data: PackedByteArray) -> JoinRequestClass:
	var new_class: JoinRequestClass = JoinRequestClass.new()
	new_class.decode(data)
	return new_class
