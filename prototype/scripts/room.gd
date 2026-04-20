extends PanelContainer
class_name RoomItem

@export_file("*.tscn") var room_scene_path: String = "res://prototype/scenes/legacy/chat.tscn"
var id: int = -1

func _init() -> void:
	ClientPacketHandler.join_room.connect(join_room)

#Send a join request packet to the server
func _on_join_button_down() -> void:
	#print(("Room"),id, ClientPacketHandler.client_id)
	JoinRequestClass.create(id, ClientPacketHandler.my_id).send(ProtNetworkHandler.server_peer)
	#print("(Room) ID: ", id)

#Room receive its respective id
func setup_room(room_id: int) -> void:
	id = room_id

func join_room(room_id: int) -> void:
	if room_id == id:
		auto_join()

func auto_join() -> void:
	get_tree().change_scene_to_file(room_scene_path)
