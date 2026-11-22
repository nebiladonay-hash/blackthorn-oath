extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const OUTPUT_DIR := "res://build/visual_review"

func _initialize() -> void:
	call_deferred("_capture_intro")

func _capture_intro() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))

	var scene := load(MAIN_SCENE).instantiate()
	get_root().add_child(scene)
	current_scene = scene

	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_error("Could not create visual review output directory: %s" % dir_error)
		quit(2)
		return

	var samples: Array[Dictionary] = [
		{"at": 2.7, "name": "01-cathedral-aerial.png"},
		{"at": 7.25, "name": "02-bell-warden-gate-reveal.png"},
		{"at": 13.2, "name": "03-knight-reveal.png"},
		{"at": 19.2, "name": "04-title-and-start-screen.png"}
	]
	var previous_time: float = 0.0
	for sample in samples:
		var capture_time: float = float(sample["at"])
		await create_timer(maxf(0.0, capture_time - previous_time), false).timeout
		previous_time = capture_time
		await process_frame
		await process_frame
		var viewport: Viewport = get_root()
		var image: Image = viewport.get_texture().get_image()
		var filename: String = str(sample["name"])
		var target_path: String = output_absolute.path_join(filename)
		var save_error: Error = image.save_png(target_path)
		if save_error != OK:
			push_error("Failed to save visual capture %s: %s" % [filename, error_string(save_error)])
			quit(3)
			return
		print("VISUAL_CAPTURE_OK ", filename, " ", image.get_width(), "x", image.get_height())

	print("VISUAL_REVIEW_COMPLETE")
	quit()
