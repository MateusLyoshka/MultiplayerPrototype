class_name RefreshRequestClass extends PacketTypeClass

static func create() -> RefreshRequestClass:
	var refresh_req: RefreshRequestClass = RefreshRequestClass.new()
	refresh_req.packet_type = PACKET_TYPE.REFRESH_REQUEST
	refresh_req.flag = ENetPacketPeer.FLAG_RELIABLE
	return refresh_req

static func create_from_data(data: PackedByteArray) -> RefreshRequestClass:
	var new_refresh_req: RefreshRequestClass = RefreshRequestClass.new()
	new_refresh_req.decode(data)
	return new_refresh_req
