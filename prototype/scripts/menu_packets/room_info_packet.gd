class_name RoomInfoClass extends PacketTypeClass

var room_id: int
var room_port: int
var host_ip: String

static func create(room: int, port: int, ip: String) -> RoomInfoClass:
	var new_packet: RoomInfoClass = RoomInfoClass.new(PACKET_TYPE.ROOM_INFO)
	new_packet.room_id = room
	new_packet.room_port = port
	new_packet.host_ip = ip
	return new_packet

static func create_from_data(data: PackedByteArray) -> RoomInfoClass:
	var new_packet: RoomInfoClass = RoomInfoClass.new(PACKET_TYPE.ROOM_INFO)
	new_packet.decode(data)
	return new_packet

func decode(data: PackedByteArray) -> void:
	super.decode(data)
	room_id = data.decode_u8(1)
	room_port = data.decode_u16(2)
	var string_data = data.slice(4) 
	host_ip = string_data.get_string_from_utf8()

func encode() -> PackedByteArray:
	var new_array: PackedByteArray = super.encode()
	new_array.append(room_id)
	new_array.append(room_port)
	new_array.append_array(host_ip.to_utf8_buffer())
	return new_array
	
	
