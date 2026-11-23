extends CharacterBody3D
class_name BlackthornOathPlayer

const SILVER_KNIGHT_PATH := "res://assets/models/silver-knight.glb"

signal health_changed(value: int)
signal died

@export var forward_speed := 0.0
@export var lane_width := 2.6
@export var jump_velocity := 10.2

var lane := 1
var health := 3
var dead := false
var invulnerability := 0.0
var attack_cooldown := 0.0
var attack_animation := 0.0
var attack_hit_timer := 0.0
var attack_hit_pending := false
var slide_timer := 0.0

var hit_shape: CollisionShape3D
var visual_root: Node3D
var imported_model: Node3D
var imported_animation: AnimationPlayer
var using_imported_model := false
var torso: MeshInstance3D
var sword_pivot: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var body_material: StandardMaterial3D
var run_clock := 0.0
var footstep_timer := 0.0
var standing_height := 1.85
var sliding_height := 0.95

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 3 # world geometry + enemy bodies
	floor_snap_length = 0.18
	safe_margin = 0.035
	_build_character()
	_add_character_lighting()
	hit_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = standing_height
	hit_shape.shape = capsule
	hit_shape.position.y = standing_height * 0.5
	add_child(hit_shape)

func _physics_process(delta: float) -> void:
	if dead:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if attack_hit_pending:
		attack_hit_timer = maxf(0.0, attack_hit_timer - delta)
		if attack_hit_timer <= 0.0:
			attack_hit_pending = false
			_resolve_attack_hits()
	if slide_timer > 0.0:
		slide_timer = maxf(0.0, slide_timer - delta)
		if slide_timer == 0.0:
			_set_sliding(false)
	if Input.is_action_just_pressed("lane_left"):
		move_lane(-1)
	if Input.is_action_just_pressed("lane_right"):
		move_lane(1)
	if Input.is_action_just_pressed("jump"):
		jump()
	if Input.is_action_just_pressed("slide"):
		slide()
	if Input.is_action_just_pressed("attack"):
		attack()

	# Lane changes must go through the physics solver. Directly assigning X lets
	# the knight tunnel through walls and enemies even while Z uses move_and_slide.
	var target_x := float(lane - 1) * lane_width
	var lane_error := target_x - global_position.x
	velocity.x = clampf(lane_error * 13.0, -12.0, 12.0)
	if absf(lane_error) < 0.025:
		velocity.x = 0.0
	velocity.z = -forward_speed
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()

	if forward_speed > 0.1 and is_on_floor() and slide_timer <= 0.0:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_timer = clampf(0.42 - forward_speed * 0.012, 0.22, 0.38)
			_play_game_sfx("footstep")
	else:
		footstep_timer = 0.0

	if using_imported_model:
		_update_imported_animation(delta)
	else:
		if forward_speed > 0.0 and is_on_floor() and slide_timer <= 0.0:
			run_clock += delta * minf(forward_speed, 16.0)
			var swing := sin(run_clock * 1.55) * 0.52
			left_leg.rotation.x = swing
			right_leg.rotation.x = -swing
			if attack_animation <= 0.0:
				left_arm.rotation.x = -swing * 0.7
				right_arm.rotation.x = swing * 0.7
			visual_root.position.y = absf(sin(run_clock * 3.1)) * 0.055
		else:
			left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, delta * 8.0)
			right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, delta * 8.0)
			visual_root.position.y = move_toward(visual_root.position.y, 0.0, delta * 0.5)

		if attack_animation > 0.0:
			attack_animation = maxf(0.0, attack_animation - delta)
			var phase := 1.0 - attack_animation / 0.32
			right_arm.rotation.x = -1.5 + sin(phase * PI) * 2.5
			sword_pivot.rotation.z = -0.85 + sin(phase * PI) * 1.7
		else:
			right_arm.rotation.x = lerpf(right_arm.rotation.x, 0.0, delta * 10.0)
			sword_pivot.rotation.z = lerpf(sword_pivot.rotation.z, -0.85, delta * 10.0)

	var visible_now := invulnerability <= 0.0 or int(Time.get_ticks_msec() / 85) % 2 == 0
	visual_root.visible = visible_now

func _add_character_lighting() -> void:
	var front_fill := OmniLight3D.new()
	front_fill.name = "KnightFrontFill"
	front_fill.position = Vector3(0.0, 2.0, -2.4)
	front_fill.light_color = Color(0.70, 0.79, 1.0)
	front_fill.light_energy = 7.2
	front_fill.omni_range = 12.0
	front_fill.shadow_enabled = false
	visual_root.add_child(front_fill)

	var warm_rim := OmniLight3D.new()
	warm_rim.name = "KnightWarmRim"
	warm_rim.position = Vector3(1.4, 1.6, 1.0)
	warm_rim.light_color = Color(1.0, 0.26, 0.12)
	warm_rim.light_energy = 2.0
	warm_rim.omni_range = 7.0
	warm_rim.shadow_enabled = false
	visual_root.add_child(warm_rim)

func _build_character() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)

	if ResourceLoader.exists(SILVER_KNIGHT_PATH):
		var knight_scene: PackedScene = load(SILVER_KNIGHT_PATH) as PackedScene
		if knight_scene != null:
			imported_model = knight_scene.instantiate() as Node3D
			if imported_model != null:
				imported_model.name = "SilverKnightRigged"
				visual_root.add_child(imported_model)
				_fit_imported_model(imported_model, 1.9)
				using_imported_model = true
				face_for_cinematic()
				var animation_nodes := imported_model.find_children("*", "AnimationPlayer", true, false)
				if not animation_nodes.is_empty():
					imported_animation = animation_nodes[0] as AnimationPlayer
					_copy_shared_combat_animations()
				# The rigged asset already carries its own weapon. Do not add a second
				# unrigged blade at world scale; it detached from the hand in the review.
				sword_pivot = null
				_play_imported_animation("idle")
				return

	_build_procedural_character()

func face_for_cinematic() -> void:
	if using_imported_model and imported_model != null:
		# The reveal camera is ahead of the runner on -Z.
		imported_model.rotation.y = PI

func face_for_menu() -> void:
	if using_imported_model and imported_model != null:
		# The title camera is behind the start line on +Z.
		imported_model.rotation.y = 0.0

func face_for_run() -> void:
	if using_imported_model and imported_model != null:
		# The chase camera sits behind the runner; the road is -Z.
		imported_model.rotation.y = PI

func _fit_imported_model(model: Node3D, target_height: float) -> void:
	var combined := AABB()
	var has_bounds := false
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := item as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform: Transform3D = model.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = mesh_instance.get_aabb() * relative_transform
		if has_bounds:
			combined = combined.merge(mesh_bounds)
		else:
			combined = mesh_bounds
			has_bounds = true
	if not has_bounds or combined.size.y <= 0.001:
		model.scale = Vector3.ONE
		return
	var fit_scale: float = target_height / combined.size.y
	model.scale = Vector3.ONE * fit_scale
	model.position.y = -combined.position.y * fit_scale

func _copy_shared_combat_animations() -> void:
	if imported_animation == null:
		return
	var sources := get_tree().get_nodes_in_group("shared_combat_animation_source")
	if sources.is_empty():
		push_warning("No shared combat animation source found for player rig.")
		return
	var source := sources[0] as AnimationPlayer
	if source == null:
		return
	var library := AnimationLibrary.new()
	for animation_name in ["sword_attack", "sword_block"]:
		if source.has_animation(animation_name):
			# Both assets use the same Mixamo OurRig/Skeleton3D bone paths,
			# verified by the Godot CI rig-track diagnostics.
			var animation_copy := source.get_animation(animation_name).duplicate(true) as Animation
			var error := library.add_animation(animation_name, animation_copy)
			if error != OK:
				push_warning("Could not import shared combat animation %s" % animation_name)
	if not library.get_animation_list().is_empty():
		if imported_animation.has_animation_library("combat"):
			imported_animation.remove_animation_library("combat")
		imported_animation.add_animation_library("combat", library)

func _build_imported_sword() -> void:
	# A separate blade sits against the right hand and is animated during strikes.
	var steel := _mat(Color(0.56, 0.63, 0.72), 0.94, 0.2)
	var bronze := _mat(Color(0.54, 0.31, 0.11), 0.82, 0.28)
	var leather := _mat(Color(0.075, 0.033, 0.025), 0.1, 0.82)
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.52, 0.94, -0.18)
	sword_pivot.rotation.z = -0.68
	visual_root.add_child(sword_pivot)
	_capsule(sword_pivot, Vector3(0, 0.02, 0), 0.045, 0.3, leather)
	_sphere(sword_pivot, Vector3(0, -0.13, 0), Vector3(0.09, 0.09, 0.09), bronze)
	_box(sword_pivot, Vector3(0, 0.18, 0), Vector3(0.36, 0.075, 0.1), bronze)
	_box(sword_pivot, Vector3(0, 0.65, 0), Vector3(0.12, 0.88, 0.04), steel)
	_sphere(sword_pivot, Vector3(0, 1.12, 0), Vector3(0.06, 0.12, 0.04), steel)

func _resolve_imported_animation(preferred: String) -> StringName:
	if imported_animation == null:
		return &""
	var candidates: Array[String] = []
	match preferred:
		"sprint_loop":
			candidates = ["run", "sprint", "jog", "walk"]
		"attack":
			candidates = ["attack", "slash", "sword", "melee", "combo"]
		"jump":
			candidates = ["jump", "leap", "fall"]
		_:
			candidates = ["idle", "stand", "breath"]
	var names := imported_animation.get_animation_list()
	for keyword in candidates:
		for animation_name in names:
			var normalized := String(animation_name).to_lower().replace("_", "").replace("-", "").replace(" ", "")
			if normalized.contains(keyword.replace("_", "")):
				return animation_name
	return &""

func _play_imported_animation(preferred: String) -> void:
	if imported_animation == null:
		return
	var resolved := _resolve_imported_animation(preferred)
	if resolved == &"":
		# Keep the last valid pose rather than silently playing idle while moving.
		if preferred == "sprint_loop":
			push_warning("No run/sprint/walk clip found in imported knight rig. Available: %s" % [imported_animation.get_animation_list()])
		return
	if imported_animation.current_animation != resolved:
		imported_animation.play(resolved)
	if preferred == "sprint_loop":
		# Match the cycle rate to forward velocity; the root body owns translation.
		imported_animation.speed_scale = clampf(forward_speed / 3.6, 0.85, 2.25)
	elif preferred == "attack":
		imported_animation.speed_scale = 1.25
	else:
		imported_animation.speed_scale = 1.0

func _update_imported_animation(delta: float) -> void:
	var desired := "idle"
	if slide_timer <= 0.0 and not is_on_floor():
		desired = "jump"
	elif slide_timer <= 0.0 and forward_speed > 0.1:
		desired = "sprint_loop"
	if attack_animation > 0.0:
		_play_imported_animation("attack")
		attack_animation = maxf(0.0, attack_animation - delta)
	else:
		_play_imported_animation(desired)
	if sword_pivot != null:
		if attack_animation > 0.0:
			var phase := 1.0 - attack_animation / 0.32
			sword_pivot.rotation.z = -0.68 + sin(phase * PI) * 1.95
		else:
			sword_pivot.rotation.z = lerpf(sword_pivot.rotation.z, -0.68, delta * 10.0)

func _build_procedural_character() -> void:
	var armor := _mat(Color(0.105, 0.12, 0.15), 0.82, 0.35)
	var dark_steel := _mat(Color(0.035, 0.045, 0.06), 0.92, 0.3)
	var leather := _mat(Color(0.13, 0.055, 0.035), 0.1, 0.8)
	var crimson := _mat(Color(0.24, 0.018, 0.035), 0.05, 0.78)
	var bronze := _mat(Color(0.55, 0.29, 0.09), 0.78, 0.35)
	var blade_mat := _mat(Color(0.68, 0.74, 0.82), 0.95, 0.2)
	var glow := _mat(Color(0.75, 0.06, 0.025), 0.1, 0.25, Color(0.9, 0.025, 0.005))

	# Layered torso and waist.
	torso = _box(visual_root, Vector3(0, 1.18, 0), Vector3(0.76, 0.78, 0.43), armor)
	_box(visual_root, Vector3(0, 1.38, -0.02), Vector3(0.7, 0.34, 0.47), dark_steel)
	_box(visual_root, Vector3(0, 0.72, 0), Vector3(0.58, 0.22, 0.38), leather)
	_box(visual_root, Vector3(0, 0.72, -0.22), Vector3(0.6, 0.09, 0.07), bronze)

	# Helmet, face slit, brow and side guards.
	_sphere(visual_root, Vector3(0, 1.92, 0), Vector3(0.29, 0.34, 0.27), dark_steel)
	_box(visual_root, Vector3(0, 1.91, -0.235), Vector3(0.35, 0.1, 0.045), bronze)
	_box(visual_root, Vector3(0, 1.81, -0.26), Vector3(0.25, 0.035, 0.035), glow)
	_box(visual_root, Vector3(0, 2.18, 0.015), Vector3(0.1, 0.24, 0.11), bronze)
	_box(visual_root, Vector3(-0.31, 1.88, 0), Vector3(0.08, 0.32, 0.26), armor)
	_box(visual_root, Vector3(0.31, 1.88, 0), Vector3(0.08, 0.32, 0.26), armor)

	# Shoulder plates and articulated arms.
	_sphere(visual_root, Vector3(-0.46, 1.48, 0), Vector3(0.28, 0.24, 0.28), dark_steel)
	_sphere(visual_root, Vector3(0.46, 1.48, 0), Vector3(0.28, 0.24, 0.28), dark_steel)
	left_arm = Node3D.new()
	left_arm.position = Vector3(-0.48, 1.42, 0)
	visual_root.add_child(left_arm)
	_capsule(left_arm, Vector3(0, -0.3, 0), 0.14, 0.65, armor)
	_box(left_arm, Vector3(0, -0.62, -0.01), Vector3(0.2, 0.19, 0.22), bronze)
	right_arm = Node3D.new()
	right_arm.position = Vector3(0.48, 1.42, 0)
	visual_root.add_child(right_arm)
	_capsule(right_arm, Vector3(0, -0.3, 0), 0.14, 0.65, armor)
	_box(right_arm, Vector3(0, -0.62, -0.01), Vector3(0.2, 0.19, 0.22), bronze)

	# Legs and plated greaves.
	left_leg = Node3D.new()
	left_leg.position = Vector3(-0.2, 0.64, 0)
	visual_root.add_child(left_leg)
	_capsule(left_leg, Vector3(0, -0.27, 0), 0.15, 0.63, dark_steel)
	_box(left_leg, Vector3(0, -0.48, -0.1), Vector3(0.28, 0.27, 0.38), leather)
	right_leg = Node3D.new()
	right_leg.position = Vector3(0.2, 0.64, 0)
	visual_root.add_child(right_leg)
	_capsule(right_leg, Vector3(0, -0.27, 0), 0.15, 0.63, dark_steel)
	_box(right_leg, Vector3(0, -0.48, -0.1), Vector3(0.28, 0.27, 0.38), leather)

	# Heavy split cape.
	_box(visual_root, Vector3(0, 1.08, 0.29), Vector3(0.64, 0.98, 0.12), crimson).rotation.x = deg_to_rad(-8)
	_box(visual_root, Vector3(0, 0.59, 0.3), Vector3(0.62, 0.16, 0.13), leather)

	# Sword: pommel, wrapped grip, crossguard and tapered steel blade.
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.53, 1.0, -0.08)
	sword_pivot.rotation.z = -0.85
	right_arm.add_child(sword_pivot)
	_capsule(sword_pivot, Vector3(0, 0.12, 0), 0.045, 0.33, leather)
	_sphere(sword_pivot, Vector3(0, -0.06, 0), Vector3(0.09, 0.09, 0.09), bronze)
	_box(sword_pivot, Vector3(0, 0.3, 0), Vector3(0.39, 0.085, 0.1), bronze)
	_box(sword_pivot, Vector3(0, 0.83, 0), Vector3(0.16, 1.0, 0.045), blade_mat)
	var blade_tip := _sphere(sword_pivot, Vector3(0, 1.36, 0), Vector3(0.07, 0.16, 0.045), blade_mat)
	blade_tip.rotation.z = 0.0

	# Small ember mark on the chest.
	_sphere(visual_root, Vector3(0, 1.17, -0.25), Vector3(0.085, 0.11, 0.035), glow)

func _mat(color: Color, metal: float, rough: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.0
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	node.mesh = mesh
	node.scale = size
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

func move_lane(direction: int) -> void:
	lane = clampi(lane + direction, 0, 2)

func jump() -> void:
	if is_on_floor() and slide_timer <= 0.0:
		velocity.y = jump_velocity

func slide() -> void:
	if is_on_floor() and slide_timer <= 0.0:
		slide_timer = 0.78
		_set_sliding(true)

func _set_sliding(enabled: bool) -> void:
	var capsule := hit_shape.shape as CapsuleShape3D
	capsule.height = sliding_height if enabled else standing_height
	hit_shape.position.y = capsule.height * 0.5
	visual_root.scale.y = 0.62 if enabled else 1.0
	if using_imported_model:
		if sword_pivot != null:
			sword_pivot.visible = not enabled
		if enabled:
			_play_imported_animation("idle")
		return
	left_arm.visible = not enabled
	right_arm.visible = not enabled
	left_leg.visible = not enabled
	right_leg.visible = not enabled
	sword_pivot.visible = not enabled

func attack() -> void:
	if attack_cooldown > 0.0 or slide_timer > 0.0 or dead:
		return
	attack_cooldown = 0.58
	attack_animation = 0.62 if using_imported_model else 0.32
	# Separate the weapon wind-up from the damage frame. The hit lands after
	# the blade has started moving, not on the input frame.
	attack_hit_timer = 0.19 if using_imported_model else 0.11
	attack_hit_pending = true
	_play_game_sfx("sword")

func _resolve_attack_hits() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var d: Vector3 = enemy.global_position - global_position
		# Three-lane combat: same lane only, and only in the forward sword arc.
		if absf(d.x) < 1.5 and d.z > -3.2 and d.z < 0.8:
			enemy.take_damage(1)

func _play_game_sfx(kind: String) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("play_sfx"):
		scene.call("play_sfx", kind, global_position)

func take_damage(amount: int = 1) -> void:
	if dead or invulnerability > 0.0:
		return
	_play_game_sfx("impact")
	health = maxi(0, health - amount)
	invulnerability = 1.0
	health_changed.emit(health)
	if health <= 0:
		dead = true
		died.emit()
