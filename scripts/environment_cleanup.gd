extends Node3D

func _process(_delta):
	if global_position.z < GlobalStatus.player_z - 100:
		queue_free()
