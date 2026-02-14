extends Node

@export var delay_seconds: float = 1.0
@export var output_path: String = "res://docs/screenshots"

func _ready():
	for i in range(3):
		await get_tree().create_timer(delay_seconds).timeout
		take_screenshot()
	get_tree().quit()

func take_screenshot():
	var image = get_viewport().get_texture().get_image()
	var time = Time.get_datetime_dict_from_system()
	var filename = "capture_%02d_%02d_%02d_%02d_%02d_%02d.png" % [time.year, time.month, time.day, time.hour, time.minute, time.second]
	
	# Handle paths
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("docs"):
		dir.make_dir("docs")
	if not dir.dir_exists("docs/screenshots"):
		dir.make_dir("docs/screenshots")
		
	var global_path = ProjectSettings.globalize_path(output_path + "/")
	var final_path = global_path + filename
	
	image.save_png(final_path)
	print("Screenshot saved to: " + final_path)
