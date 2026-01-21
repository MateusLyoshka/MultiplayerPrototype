extends Control

const MULTIJOGADOR = preload("uid://cg3be3tn5ksqa")

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://prototype/scenes/multijogador.tscn")
	ProtNetworkHandler.start_client("127.0.0.1", 42069)


func _on_exit_button_down() -> void:
	get_tree().quit()
