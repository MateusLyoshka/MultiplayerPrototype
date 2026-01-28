class_name IDAssignment extends PacketTypeClass

var id: int

func encode() -> PackedByteArray:
	var new_packet: PackedByteArray = super.encode()
	new_packet.resize(2)
	new_packet.encode_u8(1, id)
	return new_packet

func decode(packet: PackedByteArray) -> void:
	super.decode(packet)
	id = packet.decode_u8(1)
