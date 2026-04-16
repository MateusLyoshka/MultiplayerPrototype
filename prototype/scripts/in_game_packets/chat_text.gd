class_name ChatTextClass extends InGameTypeClass

var sender_name: String
var text: String

static func create(_sender_name: String, _text: String) -> ChatTextClass:
	var new_packet: ChatTextClass = ChatTextClass.new(PACKET_TYPE.TEXT_PACKET, ENetPacketPeer.FLAG_RELIABLE)
	new_packet.sender_name = _sender_name
	new_packet.text = _text
	return new_packet

static func create_from_data(data: PackedByteArray) -> ChatTextClass:
	var new_packet: ChatTextClass = ChatTextClass.new(PACKET_TYPE.TEXT_PACKET, ENetPacketPeer.FLAG_RELIABLE)
	new_packet.decode(data)
	return new_packet

func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode()
	var sender_name_data: PackedByteArray = sender_name.to_ascii_buffer()
	var text_data: PackedByteArray = text.to_ascii_buffer()
	data.append(sender_name_data.size())
	data.append_array(sender_name_data)
	data.append_array(text_data)
	return data

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	var sender_name_size: int = data.decode_u8(1)
	sender_name = data.slice(2, 2 + sender_name_size).get_string_from_ascii()
	text = data.slice(2 + sender_name_size).get_string_from_ascii()
