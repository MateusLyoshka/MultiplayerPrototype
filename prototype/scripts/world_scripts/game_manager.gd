extends Node

# Armazena o caminho da cena atual (ex: "res://maps/floresta.tscn")
var current_scene_path: String = ""
 
func _ready() -> void:
	# Define a cena inicial assim que o jogo começa
	current_scene_path = get_tree().current_scene.scene_file_path

func goto_scene(path: String) -> void:
	# Esta função será chamada pela porta
	call_deferred("_deferred_goto_scene", path)

func _deferred_goto_scene(path: String) -> void:
	ClientPacketHandler.players_scenes[ClientPacketHandler.my_id] = path
	current_scene_path = path
	get_tree().change_scene_to_file(path)
	if GamePacketHandler.is_host:
		SceneSyncPacket.create(ClientPacketHandler.my_id, path).broadcast(GamePacketHandler.host_connection)
	else:
		SceneSyncPacket.create(ClientPacketHandler.my_id, path).send(GamePacketHandler.host_peer)
