extends Camera3D
## Caméra qui suit doucement une cible (le roi) avec un décalage fixe.

@export var cible: Node3D
## Position de la caméra par rapport à la cible.
@export var decalage := Vector3(0.0, 5.5, 7.5)
## Point visé au-dessus de la cible.
@export var hauteur_visee := 1.6
## Plus c'est grand, plus la caméra colle à la cible.
@export var douceur := 4.0

func _ready() -> void:
	top_level = true
	if cible:
		global_position = cible.global_position + decalage
		look_at(cible.global_position + Vector3.UP * hauteur_visee)

func _process(delta: float) -> void:
	if cible == null:
		return
	global_position = global_position.lerp(cible.global_position + decalage, 1.0 - exp(-douceur * delta))
	look_at(cible.global_position + Vector3.UP * hauteur_visee)
