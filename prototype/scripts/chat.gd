extends Control

@onready var display: RichTextLabel = $Panel/VBoxContainer/Display
@onready var input_line: LineEdit = $Panel/VBoxContainer/HBoxContainer/InputLine
@onready var send: Button = $Panel/VBoxContainer/HBoxContainer/Send

var is_host: bool

func _ready() -> void:
	is_host = GamePacketHandler.is_host
	if is_host:
		# Host receives text packets from players via player_text_signal.
		PlayerHostPacketHandler.player_text_signal.connect(host_text)
		#printerr(PlayerHostPacketHandler.is_connected("player_text_signal", host_text))
	else:
		# Players receive text packets from host via host_text_signal.
		PlayerHostPacketHandler.host_text_signal.connect(player_text)
		#printerr(PlayerHostPacketHandler.is_connected("host_text_signal", player_text))

func _on_send_pressed() -> void:
	var raw_text = input_line.text
	if !raw_text.is_empty():
		if is_host:
			#print("(Chat) host sending: ",raw_text)
			append_message(raw_text) 
			ChatTextClass.create(raw_text).broadcast(GamePacketHandler.host_connection)
		else:
			#print("(Chat) player sending: ",raw_text)
			ChatTextClass.create(raw_text).send(GamePacketHandler.host_peer)
		input_line.clear()

func player_text(data: PackedByteArray) -> void:
	var text_packet: ChatTextClass = ChatTextClass.create_from_data(data) 
	#print("(Chat) player received: ",text_packet.text)
	append_message(text_packet.text) 

func host_text(data: PackedByteArray) -> void:
	var text_packet: ChatTextClass = ChatTextClass.create_from_data(data) 
	#print("(Chat) player received: ",text_packet.text)
	append_message(text_packet.text) 
	ChatTextClass.create(text_packet.text).broadcast(GamePacketHandler.host_connection)

func append_message(msg: String) -> void:
	display.text += msg + "\n"
	display.scroll_to_line(display.get_line_count())
