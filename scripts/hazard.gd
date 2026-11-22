extends Area3D

var already_hit := false

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if already_hit:
		return
	if body is BlackthornOathPlayer:
		already_hit = true
		body.take_damage(1)
