extends CharacterBody3D
class_name BlackthornOathPlayer

signal health_changed(value: int)
signal died

@export var forward_speed := 12.0
@export var lane_width := 2.6
@export var jump_velocity := 10.5
var lane := 1
var health := 3
var dead := false
var invulnerability := 0.0
var attack_cooldown := 0.0
var attack_animation := 0.0
var slide_timer := 0.0
var hit_shape: CollisionShape3D
var visual_body: MeshInstance3D
var sword_pivot: Node3D
var armor_material: StandardMaterial3D
var standing_height := 1.7
var sliding_height := 0.9

func _ready() -> void:
	add_to_group("player")
	_build_character()
	hit_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = standing_height
	hit_shape.shape = capsule
	hit_shape.position.y = standing_height * 0.5
	add_child(hit_shape)

func _physics_process(delta: float) -> void:
	if dead:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if attack_animation > 0.0:
		attack_animation = maxf(0.0, attack_animation - delta)
		var phase := 1.0 - attack_animation / 0.24
		sword_pivot.rotation.z = lerpf(-0.95, 1.15, sin(phase * PI))
	else:
		sword_pivot.rotation.z = lerpf(sword_pivot.rotation.z, -0.95, delta * 12.0)
	if slide_timer > 0.0:
		slide_timer = maxf(0.0, slide_timer - delta)
		if slide_timer == 0.0:
			_set_sliding(false)
	if Input.is_action_just_pressed("slide"):
		slide()
	if Input.is_action_just_pressed("lane_left"):
		move_lane(-1)
	if Input.is_action_just_pressed("lane_right"):
		move_lane(1)
	if Input.is_action_just_pressed("jump"):
		jump()
	if Input.is_action_just_pressed("attack"):
		attack()
	global_position.x = move_toward(global_position.x, float(lane - 1) * lane_width, 13.0 * delta)
	velocity.z = -forward_speed
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	move_and_slide()
	var character_visible := invulnerability <= 0.0 or int(Time.get_ticks_msec() / 90) % 2 == 0
	visual_body.visible = character_visible
	for child in get_children():
		if child is MeshInstance3D and child != visual_body:
			child.visible = character_visible and slide_timer <= 0.0
	sword_pivot.visible = character_visible and slide_timer <= 0.0

func _build_character() -> void:
	armor_material = StandardMaterial3D.new()
	armor_material.albedo_color = Color(0.12, 0.095, 0.12)
	armor_material.metallic = 0.75
	visual_body = MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = standing_height
	visual_body.mesh = body_mesh
	visual_body.material_override = armor_material
	visual_body.position.y = standing_height * 0.5
	add_child(visual_body)

	var chest := MeshInstance3D.new()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.68, 0.72, 0.43)
	chest.mesh = chest_mesh
	chest.position = Vector3(0, 1.08, -0.015)
	chest.material_override = _material(Color(0.055, 0.06, 0.075), 0.9)
	add_child(chest)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.23
	head_mesh.height = 0.46
	head.mesh = head_mesh
	head.position = Vector3(0, 1.83, 0)
	head.material_override = _material(Color(0.16, 0.12, 0.12), 0.2)
	add_child(head)

	var helm := MeshInstance3D.new()
	var helm_mesh := BoxMesh.new()
	helm_mesh.size = Vector3(0.5, 0.18, 0.48)
	helm.mesh = helm_mesh
	helm.position = Vector3(0, 2.0, 0)
	helm.material_override = _material(Color(0.045, 0.05, 0.065), 0.95)
	add_child(helm)

	var cape := MeshInstance3D.new()
	var cape_mesh := BoxMesh.new()
	cape_mesh.size = Vector3(0.52, 0.9, 0.1)
	cape.mesh = cape_mesh
	cape.position = Vector3(0, 1.05, 0.29)
	cape.rotation.x = deg_to_rad(-8)
	cape.material_override = _material(Color(0.16, 0.018, 0.028), 0.05)
	add_child(cape)

	for side in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := SphereMesh.new()
		shoulder_mesh.radius = 0.22
		shoulder_mesh.height = 0.3
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(side * 0.43, 1.35, 0)
		shoulder.material_override = _material(Color(0.075, 0.08, 0.095), 0.9)
		add_child(shoulder)

	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.52, 1.08, -0.12)
	add_child(sword_pivot)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.12, 0.82, 0.055)
	blade.mesh = blade_mesh
	blade.position.y = 0.48
	blade.material_override = _material(Color(0.55, 0.59, 0.66), 0.92)
	sword_pivot.add_child(blade)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.42, 0.09, 0.13)
	guard.mesh = guard_mesh
	guard.position.y = 0.08
	guard.material_override = _material(Color(0.52, 0.29, 0.09), 0.8)
	sword_pivot.add_child(guard)
	var grip := MeshInstance3D.new()
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.055
	grip_mesh.bottom_radius = 0.055
	grip_mesh.height = 0.27
	grip.mesh = grip_mesh
	grip.position.y = -0.09
	grip.material_override = _material(Color(0.12, 0.055, 0.035), 0.1)
	sword_pivot.add_child(grip)
	sword_pivot.rotation.z = -0.95

func _material(color: Color, metal: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.42
	return material

func move_lane(direction: int) -> void:
	lane = clampi(lane + direction, 0, 2)

func jump() -> void:
	if is_on_floor() and slide_timer <= 0.0:
		velocity.y = jump_velocity

func slide() -> void:
	if is_on_floor() and slide_timer <= 0.0:
		slide_timer = 0.72
		_set_sliding(true)

func _set_sliding(enabled: bool) -> void:
	var capsule := hit_shape.shape as CapsuleShape3D
	capsule.height = sliding_height if enabled else standing_height
	hit_shape.position.y = capsule.height * 0.5
	visual_body.scale.y = 0.58 if enabled else 1.0
	for child in get_children():
		if child is MeshInstance3D and child != visual_body:
			child.visible = not enabled
	sword_pivot.visible = not enabled

func attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.48
	attack_animation = 0.24
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var d: Vector3 = enemy.global_position - global_position
			if absf(d.x) < 1.5 and d.z > -3.0 and d.z < 1.0:
				enemy.take_damage(1)

func take_damage(amount: int = 1) -> void:
	if dead or invulnerability > 0.0:
		return
	health = maxi(0, health - amount)
	invulnerability = 1.0
	health_changed.emit(health)
	if health == 0:
		dead = true
		died.emit()
