extends CharacterBody3D
class_name BlackthornOathPlayer

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
var slide_timer := 0.0

var hit_shape: CollisionShape3D
var visual_root: Node3D
var torso: MeshInstance3D
var sword_pivot: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var body_material: StandardMaterial3D
var run_clock := 0.0
var standing_height := 1.85
var sliding_height := 0.95

func _ready() -> void:
	add_to_group("player")
	_build_character()
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

	global_position.x = move_toward(global_position.x, float(lane - 1) * lane_width, 14.0 * delta)
	velocity.z = -forward_speed
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()

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

func _build_character() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)

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
	visual_root.scale.y = 0.58 if enabled else 1.0
	left_arm.visible = not enabled
	right_arm.visible = not enabled
	left_leg.visible = not enabled
	right_leg.visible = not enabled
	sword_pivot.visible = not enabled

func attack() -> void:
	if attack_cooldown > 0.0 or slide_timer > 0.0:
		return
	attack_cooldown = 0.58
	attack_animation = 0.32
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var d: Vector3 = enemy.global_position - global_position
		if absf(d.x) < 1.5 and d.z > -3.2 and d.z < 0.8:
			enemy.take_damage(1)

func take_damage(amount: int = 1) -> void:
	if dead or invulnerability > 0.0:
		return
	health = maxi(0, health - amount)
	invulnerability = 1.0
	health_changed.emit(health)
	if health <= 0:
		dead = true
		died.emit()
