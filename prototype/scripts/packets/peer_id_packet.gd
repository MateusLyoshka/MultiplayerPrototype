class_name PeerId extends IDAssignment

static func create(client_id: int) -> PeerId:
	var packet: PeerId = PeerId.new()
	packet.packet_type = PACKET_TYPE.PEER_ID
	packet.flag = ENetPacketPeer.FLAG_RELIABLE
	packet.id = client_id
	return packet

static func create_from_data(data: PackedByteArray) -> PeerId:
	var new_class: PeerId = PeerId.new()
	new_class.decode(data)
	return new_class
