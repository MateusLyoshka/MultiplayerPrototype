extends Area2D

const MINIGAME_SCENE := "res://prototype/scenes/in_game_reusables/minigame_quiz.tscn"
const REQUIRED_PLAYERS := 4

@onready var prompt: Label = $Prompt

var player_inside: Node = null

func _ready() -> void:
	prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.get("is_authority") and GamePacketHandler.is_host:
		player_inside = body
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body == player_inside:
		player_inside = null
		prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_inside == null:
		return
	if not event.is_action_pressed("interact"):
		return
	if not GamePacketHandler.is_host:
		return
	if ClientPacketHandler.spawned_ids.size() < REQUIRED_PLAYERS:
		push_warning("Minigame requer %d jogadores conectados." % REQUIRED_PLAYERS)
		return
	SceneForcePacket.create(MINIGAME_SCENE).broadcast(GamePacketHandler.host_connection)
	GameManager.goto_scene(MINIGAME_SCENE)
