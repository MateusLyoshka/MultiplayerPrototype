extends Area2D

# No Inspetor, você arrasta o arquivo .tscn para cá
@export_file("*.tscn") var target_scene: String

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if target_scene == "":
			push_warning("Porta sem destino definido!")
			return
			
		teleport()

func teleport() -> void:
	GameManager.goto_scene(target_scene)
