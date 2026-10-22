extends Camera3D

@export var cible: Node3D
@export var decalage := Vector3(0.0, 2.5, 4.0)
@export var hauteur_visee := 1.4
@export var douceur := 4.0

var _secousse := 0.0

func _ready() -> void:
	top_level = true
	if cible:
		global_position = cible.global_position + cible.global_transform.basis * decalage
		look_at(cible.global_position + Vector3.UP * hauteur_visee)

func secouer(force: float) -> void:
	_secousse = maxf(_secousse, force)

func _process(delta: float) -> void:
	if cible == null:
		return
	
	var position_ideale = cible.global_position + cible.global_transform.basis * decalage
	global_position = global_position.lerp(position_ideale, 1.0 - exp(-douceur * delta))
	look_at(cible.global_position + Vector3.UP * hauteur_visee)
	
	if _secousse > 0.0:
		_secousse = maxf(_secousse - delta * 0.8, 0.0)
		h_offset = randf_range(-1.0, 1.0) * _secousse
		v_offset = randf_range(-1.0, 1.0) * _secousse
	else:
		h_offset = 0.0
		v_offset = 0.0
