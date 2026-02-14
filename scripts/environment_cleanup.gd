extends Node3D

func _process(_delta):
	var p = get_tree().get_first_node_in_group("player")
	if p:
		if global_position.z < p.global_position.z - 100:
			queue_free()
	elif global_position.z < -100:
		queue_free()
