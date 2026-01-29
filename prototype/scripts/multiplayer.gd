extends Control

var array: Array[int]
const ROOM = preload("uid://5bwjrpxewel")
@onready var room_list_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/VBoxContainer

func _ready() -> void:
	ClientPacketHandler.created_room.connect(add_room_to_list)
	ClientPacketHandler.room_refresh.connect(refresh_rooms)

func _on_back_to_menu_button_down() -> void:
	get_tree().change_scene_to_file("res://prototype/scenes/main_menu.tscn")

func _on_new_room_button_down() -> void:
	RoomRequestClass.create(ClientPacketHandler.client_id).send(ProtNetworkHandler.server_peer)
	return
	#print(ProtNetworkHandler.server_peer)
	#StartRoomClass.create(get_meta("id")).send(ProtNetworkHandler.server_peer)

func add_room_to_list(owner_id: int, room_id: int) -> void:
	var room_item: RoomItem = ROOM.instantiate()
	room_list_container.add_child(room_item)
	room_item.setup_room(room_id)
	#print("room instanciated")

func _on_refresh_button_down() -> void:
	RefreshRequestClass.create().send(ProtNetworkHandler.server_peer)

func refresh_rooms(rooms_id: Array[int]) -> void:
	for child in room_list_container.get_children():
		child.queue_free()
	for i in rooms_id.size():
		add_room_to_list(rooms_id[i])
