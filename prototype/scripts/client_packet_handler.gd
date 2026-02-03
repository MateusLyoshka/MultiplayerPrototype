extends Node

signal created_room(room_id: int)
signal room_refresh(rooms_id: Array[int])
signal join_room(room_id: int)
signal quit_room()
signal spawn_player_signal(player_id: int)

var my_ip: String
var room_port: int

var client_id: int
var current_room: int

func _ready() -> void:
	ProtNetworkHandler.from_server_packet.connect(packet_handler)

func packet_handler(data: PackedByteArray) -> void:
	var packet_type: int = int(data.decode_u8(0))
	match packet_type:
		PacketTypeClass.PACKET_TYPE.PEER_ID:
			var peer_id: PeerId = PeerId.create_from_data(data)
			client_id = peer_id.id
		PacketTypeClass.PACKET_TYPE.START_ROOM:
			start_room(data)
		PacketTypeClass.PACKET_TYPE.JOIN_ROOM:
			var join_packet: JoinRoomClass = JoinRoomClass.create_from_data(data)
			current_room = join_packet.room_id
			join_room.emit(join_packet.room_id)
			spawn_player()
			print("(Client handler) request granted for room: ", join_packet.room_id)
		PacketTypeClass.PACKET_TYPE.QUIT_ROOM:
			current_room = -1
			quit_room.emit()
		PacketTypeClass.PACKET_TYPE.REFRESH:
			var refresh: RefreshClass = RefreshClass.create_from_data(data)
			var rooms_id: Array[int] = refresh.rooms_id
			rooms_id.pop_front()
			room_refresh.emit(rooms_id)

func start_room(data: PackedByteArray) -> void:
	var room_packet: StartRoomClass = StartRoomClass.create_from_data(data)
	current_room = room_packet.room
	my_ip = get_ipv4()
	room_port = get_random_port()
	#print("(Client handler) my ip: ", my_ip)
	created_room.emit(room_packet.room)
	RoomInfoClass.create(current_room, room_port, my_ip).send(ProtNetworkHandler.server_peer)
	HostPacketHandler.start_host(my_ip, room_port)
	spawn_player()
	print("(Client handler) room id: ", room_packet.room)

func get_random_port() -> int:
	var temp_udp = PacketPeerUDP.new()
	if temp_udp.bind(0) == OK:
		var port = temp_udp.get_local_port() 
		temp_udp.close() 
		return port
	return 0 

func get_ipv4() -> String:
	var ip_list = IP.get_local_addresses()
	for ip in ip_list:
		if ip.count(".") == 3:
			if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
				return ip  
	return "127.0.0.1"

func spawn_player() -> void:
	spawn_player_signal.emit(client_id)
