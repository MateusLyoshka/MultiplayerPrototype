class_name PacketTypeClass

enum PACKET_TYPE {
	PEER_ID = 0,
	START_ROOM = 10,
	JOIN_REQUEST = 15,
	JOIN_ROOM = 20,
	QUIT_ROOM = 30,
	REFRESH = 40,
	REFRESH_REQUEST = 50
}

var packet_type: PACKET_TYPE
var flag: int

func encode() -> PackedByteArray:
	var data: PackedByteArray
	data.resize(1)
	data.encode_u8(0, packet_type)
	return data

func decode(data: PackedByteArray) -> void:
	data.decode_u8(0)

func send(target: ENetPacketPeer) -> void:
	target.send(0, encode(), flag)

func broadcast(server: ENetConnection) -> void:
	server.broadcast(0, encode(), flag)
