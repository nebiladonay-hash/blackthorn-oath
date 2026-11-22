extends Node3D
class_name BlackthornOathEnemy

enum EnemyType { HOLLOW_GUARD, BLOODHOUND, EXECUTIONER }

var archetype: int = EnemyType.HOLLOW_GUARD
var health := 2
var attack_timer := 0.0
var attack_interval := 1.35
var damage := 1
var player: BlackthornOathPlayer
var is_dead := false
var body_visual: MeshInstance3D
var hit_flash := 0.0
var base_color := Color(0.12, 0.09, 0.11)

func configure(kind: int) -> void:
	archetype = clampi(kind, 0, 2)
	match archetype:
		EnemyType.BLOODHOUND:
			health = 1
			attack_interval = 0.8
		EnemyType.EXECUTIONER:
			health = 3
			attack_interval = 1.7
			damage = 1
		_:
			health = 2
			attack_interval = 1.35

func _ready() -> void:
	add_to_group("enemies")
	_build_enemy()
	player = get_tree().get_first_node_in_group("player") as BlackthornOathPlayer

func _process(delta: float) -> void:
	if is_dead or not is_instance_valid(player) or player.dead:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		if hit_flash == 0.0 and is_instance_valid(body_visual):
			(body_visual.material_override as StandardMaterial3D).albedo_color = base_color
	if is_instance_valid(player):
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	var distance_z := absf(global_position.z - player.global_position.z)
	var distance_x := absf(global_position.x - player.global_position.x)
	if distance_z < 1.65 and distance_x < 1.0 and attack_timer <= 0.0:
		player.take_damage(damage)
		attack_timer = attack_interval

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	health -= amount
	hit_flash = 0.12
	if is_instance_valid(body_visual):
		(body_visual.material_override as StandardMaterial3D).albedo_color = Color(0.9, 0.08, 0.055)
	if health <= 0:
		is_dead = true
		var main := get_tree().current_scene
		if main and main.has_method("add_kill"):
			main.add_kill()
		queue_free()

func _build_enemy() -> void:
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	var material := StandardMaterial3D.new()
	match archetype:
		EnemyType.BLOODHOUND:
			mesh.radius = 0.32
			mesh.height = 1.05
			body.scale = Vector3(1.0, 0.78, 1.25)
			material.albedo_color = Color(0.23, 0.035, 0.025)
			material.emission_enabled = true
			material.emission = Color(0.12, 0.012, 0.008)
		EnemyType.EXECUTIONER:
			mesh.radius = 0.52
			mesh.height = 2.1
			body.scale = Vector3(1.12, 1.12, 1.0)
			material.albedo_color = Color(0.075, 0.065, 0.085)
			material.metallic = 0.85
		_:
			mesh.radius = 0.38
			mesh.height = 1.8
			material.albedo_color = Color(0.12, 0.09, 0.11)
			material.metallic = 0.6
	body.mesh = mesh
	body.material_override = material
	body_visual = body
	base_color = material.albedo_color
	body.position.y = mesh.height * 0.5
	add_child(body)
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.075
	eye_mesh.height = 0.15
	eye.mesh = eye_mesh
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color(0.9, 0.12, 0.035)
	eye_material.emission_enabled = true
	eye_material.emission = Color(0.8, 0.035, 0.01)
	eye.material_override = eye_material
	eye.position = Vector3(0, mesh.height * 0.68, -0.34)
	add_child(eye)
