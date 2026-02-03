extends CharacterBody2D

const SPEED: float = 500

var owner_id: int

func _physics_process(_delta: float) -> void:
	if owner_id != ClientPacketHandler.client_id: return
	
	velocity = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * SPEED
	
	move_and_slide()
