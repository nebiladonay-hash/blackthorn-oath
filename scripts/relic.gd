extends Area3D
class_name BlackthornOathRelic

var collected := false

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.62
	collision.shape = sphere
	add_child(collision)
	var mesh_node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.18
	mesh.outer_radius = 0.42
	mesh.rings = 8
	mesh.ring_segments = 12
	mesh_node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.42, 0.08)
	material.metallic = 0.72
	material.emission_enabled = true
	material.emission = Color(0.35, 0.12, 0.015)
	mesh_node.material_override = material
	mesh_node.rotation.x = deg_to_rad(90)
	add_child(mesh_node)

func _process(delta: float) -> void:
	rotate_y(delta * 2.4)
	position.y = 1.15 + sin(Time.get_ticks_msec() / 260.0) * 0.12

func _on_body_entered(body: Node3D) -> void:
	if collected or not body is BlackthornOathPlayer:
		return
	collected = true
	var main := get_tree().current_scene
	if main and main.has_method("add_relic"):
		main.add_relic()
	queue_free()
