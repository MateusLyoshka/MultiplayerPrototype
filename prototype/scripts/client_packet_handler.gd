extends Node

signal created_room(room_id: int)
signal room_refresh(rooms_id: Array[int])
signal join_room(room_id: int)
signal quit_room()
signal spawn_player_signal(player_id: int)

var my_ip: String
var room_port: int

var my_id: int = -1
var temporary_player_name: String = "player"
var current_room_id: int
var spawned_ids: Array[int]
func _ready() -> void:
	ProtNetworkHandler.from_server_packet.connect(packet_handler)

func packet_handler(data: PackedByteArray) -> void:
	var packet_type: int = int(data.decode_u8(0))
	match packet_type:
		PacketTypeClass.PACKET_TYPE.PEER_ID:
			var peer_id: PeerId = PeerId.create_from_data(data)
			my_id = peer_id.id
			temporary_player_name = "player_%d" % my_id
		PacketTypeClass.PACKET_TYPE.START_ROOM:
			start_room(data)
		PacketTypeClass.PACKET_TYPE.JOIN_ROOM:
			join_manager(data)
		PacketTypeClass.PACKET_TYPE.QUIT_ROOM:
			current_room_id = -1
			quit_room.emit()
		PacketTypeClass.PACKET_TYPE.REFRESH:
			var refresh: RefreshClass = RefreshClass.create_from_data(data)
			var rooms_id: Array[int] = refresh.rooms_id
			rooms_id.pop_front()
			room_refresh.emit(rooms_id)
		PacketTypeClass.PACKET_TYPE.HAS_JOINED:
			var has_joined: HasJoinedPkt = HasJoinedPkt.create_from_data(data)
			manage_spawns(has_joined.remote_ids)

func join_manager(data: PackedByteArray) -> void:
	var join_packet: JoinRoomClass = JoinRoomClass.create_from_data(data)
	current_room_id = join_packet.room_id
	GamePacketHandler.start_player(join_packet.host_ip, join_packet.room_port)
	join_room.emit(join_packet.room_id)
	manage_spawns(join_packet.remote_ids)
	#print("id and remote ids: ", my_id, join_packet.remote_ids)

func start_room(data: PackedByteArray) -> void:
	var room_packet: StartRoomClass = StartRoomClass.create_from_data(data)
	
	current_room_id = room_packet.room
	created_room.emit(room_packet.room)
	my_ip = get_ipv4()
	room_port = get_random_port()
	
	RoomInfoClass.create(ClientPacketHandler.my_id, current_room_id, room_port, my_ip).send(ProtNetworkHandler.server_peer)
	GamePacketHandler.start_host(my_ip, room_port)
	spawn_player(my_id)
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

func manage_spawns(others_id: Array[int]) -> void:
	for i in others_id:
		if i not in spawned_ids:
			#print(i,"my id: ", my_id)
			spawn_player(i)

func spawn_player(spawn_id: int) -> void:
	spawn_player_signal.emit(spawn_id)
	spawned_ids.append(spawn_id)
