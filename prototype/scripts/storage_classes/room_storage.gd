class_name RoomStorage

var host_ip: String
var port: int
var host_peer: ENetPacketPeer
var current_players: Array[ENetPacketPeer]

func _init(_ip: String, _port: int, _peer: ENetPacketPeer):
	host_ip = _ip
	port = _port
	host_peer = _peer
	add_player(_peer)

func add_player(player_peer: ENetPacketPeer) -> void:
	current_players.append(player_peer)

func remove_player(player_peer: ENetPacketPeer) -> void:
	current_players.erase(player_peer)
