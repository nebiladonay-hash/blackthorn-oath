extends Node3D
class_name BlackthornOathEnemy

var health := 2
var attack_timer := 0.0
var player: BlackthornOathPlayer
var is_dead := false

func _ready() -> void:
	add_to_group("enemies")
	_build_enemy()
	player = get_tree().get_first_node_in_group("player") as BlackthornOathPlayer

func _process(delta: float) -> void:
	if is_dead or not is_instance_valid(player) or player.dead:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	if absf(global_position.z - player.global_position.z) < 1.65 and absf(global_position.x - player.global_position.x) < 1.0 and attack_timer <= 0.0:
		player.take_damage(1)
		attack_timer = 1.35

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		is_dead = true
		queue_free()
		var main := get_tree().current_scene
		if main and main.has_method("add_kill"):
			main.add_kill()

func _build_enemy() -> void:
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 1.8
	body.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.09, 0.11)
	material.metallic = 0.6
	body.material_override = material
	body.position.y = 0.9
	add_child(body)
