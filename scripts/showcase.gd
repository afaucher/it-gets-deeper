extends Node3D

func _ready():
	# Make sure mouse isn't captured for easier screenshotting if needed
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event):
	if event.is_action_pressed("ui_cancel"): # ESC by default
		get_tree().quit()
