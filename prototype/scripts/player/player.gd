extends CharacterBody2D

@onready var animation: AnimatedSprite2D = $Animation

const SPEED: float = 150.0
var movement_direction: Vector2
var current_anim: String

var network_tick_rate: float = 0.05 
var time_since_last_packet: float = 0.0
var last_sent_position: Vector2
#var last_sent_animation: String

var is_authority: bool:
	get: return !ProtNetworkHandler.is_server && owner_id == ClientPacketHandler.client_id
var owner_id: int

func _ready() -> void:
	if GamePacketHandler.is_host:
		GamePacketHandler.from_player_packet.connect(host_packet_handler)
	else:
		GamePacketHandler.from_host_packet.connect(player_packet_handler)

func _physics_process(_delta: float) -> void:
	if !is_authority: return
	movement_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = movement_direction * SPEED
	
	move_and_slide()
	animate()
	
	time_since_last_packet += _delta
	if time_since_last_packet >= network_tick_rate:
		time_since_last_packet = 0
		if !GamePacketHandler.is_host:
			PlayerDataPacket.create(owner_id, global_position, animation.animation).send(GamePacketHandler.host_peer)
		else:
			PlayerDataPacket.create(owner_id, global_position, animation.animation).broadcast(GamePacketHandler.host_connection)

func animate() -> void:
	var direction_key = movement_direction.round()
	
	match direction_key:
		Vector2.UP:
			animation.play("walk_up")
		Vector2.DOWN:
			animation.play("walk_down")
		Vector2.LEFT:
			animation.play("walk_left")
		Vector2.RIGHT:
			animation.play("walk_right")
		Vector2.ZERO:
			animation.play("idle")
	
func host_packet_handler(_peer: ENetPacketPeer, data: PackedByteArray) -> void:
	if !GamePacketHandler.is_host and !is_authority: return
	var packet: PlayerDataPacket = PlayerDataPacket.create_from_data(data)
	if packet.id != owner_id:
		return
	global_position = packet.position
	if packet.animation_name != "":
		animation.play(packet.animation_name)
	packet.broadcast(GamePacketHandler.host_connection)
	
func player_packet_handler(data: PackedByteArray) -> void:
	if is_authority: 
		return
	var packet: PlayerDataPacket = PlayerDataPacket.create_from_data(data)
	
	if packet.id != owner_id:
		return
	global_position = packet.position
	animation.play(packet.animation_name)
