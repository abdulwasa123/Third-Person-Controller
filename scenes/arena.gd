extends Node3D

func _on_reset_area_body_entered(body: Node3D) -> void:
	get_tree().reload_current_scene()
