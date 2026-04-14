extends Node

# player signal
signal player_movement_signal(data: PackedByteArray)
signal player_text_signal(data: PackedByteArray)

# host signal
signal host_movement_signal(data: PackedByteArray)
signal host_text_signal(data: PackedByteArray)

var is_host: bool

func setup_packet_handler() -> void:
	is_host = GamePacketHandler.is_host
	if is_host:
		GamePacketHandler.from_player_packet.connect(player_packet_handler)
	else :
		GamePacketHandler.from_host_packet.connect(host_packet_handler)

func player_packet_handler(_peer: ENetPacketPeer, data: PackedByteArray) -> void:
	var packet_type = data.decode_u8(0)
	match packet_type:
		InGameTypeClass.PACKET_TYPE.PLAYER_PACKET:
			player_movement_signal.emit(data)
		InGameTypeClass.PACKET_TYPE.TEXT_PACKET:
			player_text_signal.emit(data)

func host_packet_handler(data: PackedByteArray) -> void:
	var packet_type = data.decode_u8(0)
	match packet_type:
		InGameTypeClass.PACKET_TYPE.PLAYER_PACKET:
			host_movement_signal.emit(data)
		InGameTypeClass.PACKET_TYPE.TEXT_PACKET:
			host_text_signal.emit(data)
			
