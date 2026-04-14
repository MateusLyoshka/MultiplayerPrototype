class_name ChatTextClass extends InGameTypeClass

var text: String

static func create(_text: String) -> ChatTextClass:
	var new_packet: ChatTextClass = ChatTextClass.new(PACKET_TYPE.TEXT_PACKET, ENetPacketPeer.FLAG_RELIABLE)
	new_packet.text = _text
	return new_packet

static func create_from_data(data: PackedByteArray) -> ChatTextClass:
	var new_packet: ChatTextClass = ChatTextClass.new(PACKET_TYPE.TEXT_PACKET, ENetPacketPeer.FLAG_RELIABLE)
	new_packet.decode(data)
	return new_packet

func encode() -> PackedByteArray:
	var data: PackedByteArray = super.encode() 
	data.append_array(text.to_ascii_buffer())
	return data

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	text = data.slice(1).get_string_from_ascii()
