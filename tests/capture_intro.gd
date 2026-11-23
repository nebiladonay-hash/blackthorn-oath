extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const OUTPUT_DIR := "res://build/visual_review"

func _initialize() -> void:
	call_deferred("_capture_intro")

func _print_rig_report(scene: Node3D, node_name: String, label: String) -> void:
	var owner := scene.find_child(node_name, true, false)
	if owner == null:
		print(label, "_RIG_MISSING")
		return
	var model: Node3D = null
	if label == "PLAYER":
		model = owner.get("imported_model") as Node3D
	else:
		model = owner.find_child("RiggedBellWarden", true, false) as Node3D
	if model == null:
		print(label, "_MODEL_MISSING")
		return
	for animation_node in model.find_children("*", "AnimationPlayer", true, false):
		var animation_player := animation_node as AnimationPlayer
		print(label, "_RIG_ANIMATIONS ", animation_player.get_animation_list())
		var diagnostic_names := ["sprint", "walk", "sword_attack", "sword_block"]
		for diagnostic_name in diagnostic_names:
			if animation_player.has_animation(diagnostic_name):
				var clip := animation_player.get_animation(diagnostic_name)
				var paths := PackedStringArray()
				for track_index in range(mini(clip.get_track_count(), 8)):
					paths.append(str(clip.track_get_path(track_index)))
				print(label, "_TRACK_PATHS ", diagnostic_name, " ", paths)
	for skeleton_node in model.find_children("*", "Skeleton3D", true, false):
		var skeleton := skeleton_node as Skeleton3D
		var names := PackedStringArray()
		for bone_index in range(skeleton.get_bone_count()):
			names.append(skeleton.get_bone_name(bone_index))
		print(label, "_RIG_BONES ", names)
	var bounds := AABB()
	var has_bounds := false
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var transform: Transform3D = model.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = mesh_instance.get_aabb() * transform
		if has_bounds:
			bounds = bounds.merge(mesh_bounds)
		else:
			bounds = mesh_bounds
			has_bounds = true
	if has_bounds:
		print(label, "_RIG_BOUNDS ", bounds.size)

func _capture_intro() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))

	var packed_scene: PackedScene = load(MAIN_SCENE) as PackedScene
	var scene: Node3D = packed_scene.instantiate()
	get_root().add_child(scene)
	current_scene = scene
	# Bypass the real-time intro fade so every QA still shows the actual scene.
	scene.fade_overlay.modulate.a = 0.0
	scene.fade_overlay.hide()
	_print_rig_report(scene, "OathboundKnight", "PLAYER")
	_print_rig_report(scene, "TheBellWarden", "WARDEN")

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
	for sample in samples:
		var capture_time: float = float(sample["at"])
		# Advance the intro deterministically instead of waiting wall-clock seconds.
		scene.intro_elapsed = capture_time
		scene._update_cinematic(0.0)
		if capture_time >= 18.0 and scene.intro_complete:
			scene._idle_camera(0.5)
			# Let the actual menu fade finish before capturing its final state.
			await create_timer(0.75).timeout
			scene.menu_panel.modulate.a = 1.0
		await process_frame
		await RenderingServer.frame_post_draw
		var viewport: Viewport = get_root()
		var image: Image = viewport.get_texture().get_image()
		var filename: String = str(sample["name"])
		var target_path: String = output_absolute.path_join(filename)
		var save_error: Error = image.save_png(target_path)
		if save_error != OK:
			push_error("Failed to save visual capture %s: %s" % [filename, error_string(save_error)])
			scene.queue_free()
			await process_frame
			quit(3)
			return
		print("VISUAL_CAPTURE_OK ", filename, " ", image.get_width(), "x", image.get_height())

	# Capture a real in-run frame after the intro/menu, not just cinematic stills.
	scene._start_run()
	for frame_index in range(24):
		await process_frame
		await RenderingServer.frame_post_draw
	var gameplay_image: Image = get_root().get_texture().get_image()
	var gameplay_path: String = output_absolute.path_join("05-gameplay-runner.png")
	if gameplay_image.save_png(gameplay_path) != OK:
		push_error("Failed to save gameplay runner screenshot")
		scene.queue_free()
		await process_frame
		quit(4)
		return
	print("VISUAL_CAPTURE_OK 05-gameplay-runner.png ", gameplay_image.get_width(), "x", gameplay_image.get_height())
	print("VISUAL_REVIEW_COMPLETE")
	var soundtrack := scene.get_node_or_null("OriginalDarkFantasyScore") as AudioStreamPlayer
	if soundtrack != null:
		soundtrack.stop()
	scene.queue_free()
	await process_frame
	quit(0)
