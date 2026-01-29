extends PanelContainer
class_name RoomItem

var id: int = -1

func setup_room(room_id: int) -> void:
	id = room_id

func _on_join_button_down() -> void:
	auto_join()
	print("(Room) ID: ", id)

func auto_join() -> void:
	get_tree().change_scene_to_file("res://prototype/scenes/leaving_room.tscn")
	JoinRequestClass.create(id, ClientPacketHandler.client_id).send(ProtNetworkHandler.server_peer)
