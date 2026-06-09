extends Control

var array: Array[int]
const ROOM = preload("uid://5bwjrpxewel")
@onready var room_list_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/VBoxContainer
@onready var ip_line: LineEdit = $Panel/VBoxContainer/IpRow/IpLine
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel

func _ready() -> void:
	ClientPacketHandler.created_room.connect(create_join_room)
	ClientPacketHandler.room_refresh.connect(refresh_rooms)
	ip_line.text = ClientPacketHandler.get_ipv4()

func _on_back_to_menu_button_down() -> void:
	get_tree().change_scene_to_file("res://prototype/scenes/main_menu.tscn")

	#send a room creation packet to server_packet_handler when the new room button is pressed
func _on_new_room_button_down() -> void:
	var ip: String = ip_line.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Informe o IP da sua maquina antes de criar a sala."
		return
	if ip.count(".") != 3:
		status_label.text = "IP invalido. Use formato IPv4 (ex.: 192.168.0.10)."
		return
	status_label.text = ""
	ClientPacketHandler.my_ip = ip
	RoomRequestClass.create(ClientPacketHandler.my_id).send(ProtNetworkHandler.server_peer)
	return

	#send a refresh packet which returns a list of rooms in the refresh request packet
func _on_refresh_button_down() -> void:
	RefreshRequestClass.create().send(ProtNetworkHandler.server_peer)

func refresh_rooms(summaries: Array[RoomSummary]) -> void:
	for child in room_list_container.get_children():
		child.queue_free()
	for summary in summaries:
		add_room_to_list(summary)

func create_join_room(room_id: int) -> void:
	var summary: RoomSummary = RoomSummary.new()
	summary.id = room_id
	summary.player_count = 1
	summary.player_names = [ClientPacketHandler.temporary_player_name]
	var room_item: RoomItem = ROOM.instantiate()
	room_list_container.add_child(room_item)
	room_item.setup_room(summary)
	room_item.auto_join()

func add_room_to_list(summary: RoomSummary) -> void:
	var room_item: RoomItem = ROOM.instantiate()
	room_list_container.add_child(room_item)
	room_item.setup_room(summary)
