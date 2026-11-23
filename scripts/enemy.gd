extends StaticBody3D
class_name BlackthornOathEnemy

const SENTINEL_MODEL_PATH := "res://assets/models/t1-sentinel.glb"

enum EnemyType { HOLLOW_GUARD, BLOODHOUND, EXECUTIONER }

var archetype: int = EnemyType.HOLLOW_GUARD
var health := 2
var attack_timer := 0.0
var attack_interval := 1.35
var damage := 1
var player: BlackthornOathPlayer
var is_dead := false
var visual_root: Node3D
var flash_materials: Array[StandardMaterial3D] = []
var base_colors: Array[Color] = []
var hit_flash := 0.0
var attack_windup := 0.0
var body_root: Node3D
var imported_model: Node3D
var imported_animation: AnimationPlayer
var death_timer := 0.0
var animation_return_timer := 0.0

func configure(kind: int) -> void:
	archetype = clampi(kind, 0, 2)
	match archetype:
		EnemyType.BLOODHOUND:
			health = 1
			attack_interval = 0.85
		EnemyType.EXECUTIONER:
			health = 3
			attack_interval = 1.75
		_:
			health = 2
			attack_interval = 1.3

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 0
	var body_hitbox := CollisionShape3D.new()
	body_hitbox.name = "EnemyBodyHitbox"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 2.25
	body_hitbox.shape = capsule
	body_hitbox.position.y = 1.125
	add_child(body_hitbox)
	_build_enemy()
	player = get_tree().get_first_node_in_group("player") as BlackthornOathPlayer

func _process(delta: float) -> void:
	if is_dead:
		death_timer -= delta
		if death_timer <= 0.0:
			queue_free()
		return
	if not is_instance_valid(player) or player.dead:
		return
	if animation_return_timer > 0.0:
		animation_return_timer = maxf(0.0, animation_return_timer - delta)
		if animation_return_timer <= 0.0:
			_play_enemy_animation("idle")
	attack_timer = maxf(0.0, attack_timer - delta)
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		if hit_flash == 0.0:
			_set_flash(false)

	var target := Vector3(player.global_position.x, global_position.y, player.global_position.z + 0.01)
	look_at(target, Vector3.UP)
	var distance_z := absf(global_position.z - player.global_position.z)
	var distance_x := absf(global_position.x - player.global_position.x)
	attack_windup = maxf(0.0, attack_windup - delta)
	if distance_z < 1.9 and distance_x < 1.05 and attack_timer <= 0.0:
		if attack_windup <= 0.0:
			attack_windup = 0.3
			_play_enemy_animation("sword_attack")
		elif attack_windup < 0.12:
			player.take_damage(damage)
			attack_timer = attack_interval
			attack_windup = 0.0
			animation_return_timer = 0.48
	elif distance_z >= 1.9:
		attack_windup = 0.0

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("play_sfx"):
		scene.call("play_sfx", "impact", global_position)
	health -= amount
	hit_flash = 0.13
	_set_flash(true)
	if health <= 0:
		is_dead = true
		_play_enemy_animation("death")
		death_timer = 0.9
		var main := get_tree().current_scene
		if main and main.has_method("add_kill"):
			main.add_kill()
	else:
		_play_enemy_animation("hit_chest")
		animation_return_timer = 0.38

func _build_enemy() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)
	if ResourceLoader.exists(SENTINEL_MODEL_PATH):
		var packed := load(SENTINEL_MODEL_PATH) as PackedScene
		if packed != null:
			imported_model = packed.instantiate() as Node3D
			if imported_model != null:
				imported_model.name = "AnimatedHollowSentinel"
				visual_root.add_child(imported_model)
				_fit_imported_model(imported_model, 2.15)
				var animation_nodes := imported_model.find_children("*", "AnimationPlayer", true, false)
				if not animation_nodes.is_empty():
					imported_animation = animation_nodes[0] as AnimationPlayer
				_play_enemy_animation("idle")
				return
	var armor := _mat(Color(0.11, 0.095, 0.10), 0.7, 0.55)
	var dark := _mat(Color(0.035, 0.03, 0.04), 0.55, 0.8)
	var bone := _mat(Color(0.48, 0.43, 0.36), 0.05, 0.9)
	var rust := _mat(Color(0.35, 0.075, 0.04), 0.5, 0.6)
	var eye := _mat(Color(0.9, 0.035, 0.012), 0.05, 0.25, Color(0.95, 0.02, 0.004))

	match archetype:
		EnemyType.BLOODHOUND:
			_build_bloodhound(armor, dark, bone, eye)
		EnemyType.EXECUTIONER:
			_build_executioner(armor, dark, rust, eye)
		_:
			_build_hollow_guard(armor, dark, bone, rust, eye)

	for node in visual_root.find_children("*", "MeshInstance3D", true, false):
		if node.material_override is StandardMaterial3D:
			var material := node.material_override as StandardMaterial3D
			flash_materials.append(material)
			base_colors.append(material.albedo_color)

func _build_hollow_guard(armor: Material, dark: Material, bone: Material, rust: Material, eye: Material) -> void:
	_capsule(visual_root, Vector3(0, 1.0, 0), 0.35, 1.35, dark)
	_box(visual_root, Vector3(0, 1.18, -0.03), Vector3(0.78, 0.68, 0.43), armor)
	_sphere(visual_root, Vector3(0, 1.85, 0), Vector3(0.45, 0.42, 0.4), bone)
	_box(visual_root, Vector3(0, 1.73, -0.2), Vector3(0.28, 0.055, 0.04), dark)
	_sphere(visual_root, Vector3(-0.12, 1.82, -0.205), Vector3(0.075, 0.07, 0.04), eye)
	_sphere(visual_root, Vector3(0.12, 1.82, -0.205), Vector3(0.075, 0.07, 0.04), eye)
	for side in [-1.0, 1.0]:
		_sphere(visual_root, Vector3(side * 0.46, 1.45, 0), Vector3(0.3, 0.26, 0.3), armor)
		_capsule(visual_root, Vector3(side * 0.48, 0.93, 0), 0.12, 0.72, bone)
		_capsule(visual_root, Vector3(side * 0.18, 0.35, 0), 0.14, 0.65, dark)
	_box(visual_root, Vector3(0.62, 1.0, -0.12), Vector3(0.09, 0.72, 0.08), rust)
	_box(visual_root, Vector3(0.62, 0.54, -0.12), Vector3(0.3, 0.08, 0.11), rust)

func _build_bloodhound(armor: Material, dark: Material, bone: Material, eye: Material) -> void:
	_sphere(visual_root, Vector3(0, 0.72, 0.02), Vector3(0.56, 0.48, 1.0), dark)
	_sphere(visual_root, Vector3(0, 0.82, -0.5), Vector3(0.42, 0.37, 0.47), armor)
	_sphere(visual_root, Vector3(0, 0.69, -0.78), Vector3(0.28, 0.22, 0.32), bone)
	_sphere(visual_root, Vector3(-0.15, 0.91, -0.78), Vector3(0.085, 0.08, 0.05), eye)
	_sphere(visual_root, Vector3(0.15, 0.91, -0.78), Vector3(0.085, 0.08, 0.05), eye)
	for side in [-1.0, 1.0]:
		for front_back in [-0.45, 0.42]:
			_capsule(visual_root, Vector3(side * 0.29, 0.32, front_back), 0.105, 0.65, armor)
	_capsule(visual_root, Vector3(0, 1.0, 0.55), 0.08, 0.62, dark)
	_sphere(visual_root, Vector3(0, 1.3, 0.78), Vector3(0.1, 0.1, 0.1), eye)

func _build_executioner(armor: Material, dark: Material, rust: Material, eye: Material) -> void:
	_box(visual_root, Vector3(0, 1.35, 0), Vector3(1.02, 1.15, 0.55), dark)
	_box(visual_root, Vector3(0, 1.53, -0.06), Vector3(1.12, 0.48, 0.64), armor)
	_sphere(visual_root, Vector3(0, 2.1, 0), Vector3(0.42, 0.42, 0.4), dark)
	_box(visual_root, Vector3(0, 2.08, -0.25), Vector3(0.37, 0.07, 0.04), rust)
	_sphere(visual_root, Vector3(-0.12, 2.1, -0.27), Vector3(0.08, 0.07, 0.04), eye)
	_sphere(visual_root, Vector3(0.12, 2.1, -0.27), Vector3(0.08, 0.07, 0.04), eye)
	for side in [-1.0, 1.0]:
		_box(visual_root, Vector3(side * 0.61, 1.58, 0), Vector3(0.42, 0.42, 0.48), armor)
		_capsule(visual_root, Vector3(side * 0.24, 0.42, 0), 0.19, 0.82, dark)
	_box(visual_root, Vector3(0.82, 1.0, -0.1), Vector3(0.16, 1.25, 0.16), rust)
	_box(visual_root, Vector3(0.82, 1.2, -0.1), Vector3(0.72, 0.36, 0.15), armor)

func _play_enemy_animation(animation_name: String) -> void:
	if imported_animation == null or not imported_animation.has_animation(animation_name):
		return
	if imported_animation.current_animation != animation_name:
		imported_animation.play(animation_name)

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
		return
	var fit_scale: float = target_height / combined.size.y
	model.scale = Vector3.ONE * fit_scale
	model.position.y = -combined.position.y * fit_scale

func _set_flash(active: bool) -> void:
	for i in range(flash_materials.size()):
		var material := flash_materials[i]
		if is_instance_valid(material):
			material.albedo_color = Color(0.95, 0.08, 0.055) if active else base_colors[i]

func _mat(color: Color, metallic: float, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.0
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)

func _sphere(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	node.mesh = mesh
	node.scale = size
	node.position = pos
	node.material_override = material
	parent.add_child(node)

func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
