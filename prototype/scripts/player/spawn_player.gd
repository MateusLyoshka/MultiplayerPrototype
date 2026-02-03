extends Node

const PLAYER = preload("uid://qynwjxu3m3a0")

func _init() -> void:
	ClientPacketHandler.spawn_player_signal.connect(player_spawner)

func player_spawner(id: int) -> void:
	var player_instance: Node = PLAYER.instantiate()
	player_instance.owner_id = id

	call_deferred("add_child", player_instance)
