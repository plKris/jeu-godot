extends Camera3D
## Caméra qui suit doucement une cible (le roi) avec un décalage fixe.

@export var cible: Node3D
## Position de la caméra par rapport à la cible.
@export var decalage := Vector3(0.0, 5.5, 7.5)
## Point visé au-dessus de la cible.
@export var hauteur_visee := 1.6
## Plus c'est grand, plus la caméra colle à la cible.
@export var douceur := 4.0

var _secousse := 0.0

func _ready() -> void:
	top_level = true
	if cible:
		global_position = cible.global_position + decalage
		look_at(cible.global_position + Vector3.UP * hauteur_visee)

## Fait trembler la caméra (force en mètres, diminue toute seule).
func secouer(force: float) -> void:
	_secousse = maxf(_secousse, force)

func _process(delta: float) -> void:
	if cible == null:
		return
	global_position = global_position.lerp(cible.global_position + decalage, 1.0 - exp(-douceur * delta))
	look_at(cible.global_position + Vector3.UP * hauteur_visee)
	if _secousse > 0.0:
		_secousse = maxf(_secousse - delta * 0.8, 0.0)
		h_offset = randf_range(-1.0, 1.0) * _secousse
		v_offset = randf_range(-1.0, 1.0) * _secousse
	else:
		h_offset = 0.0
		v_offset = 0.0
