extends Node3D

# Assure-toi que le nom correspond à ton nœud de porte (par exemple wall_doorway2 dans ton arborescence)
@onready var porte = $wall_doorway2/wall_doorway/wall_doorway_door 

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Vérifie si c'est bien ton Roi qui entre dans l'Area3D de la porte
	if body.name == "Roi" or body.is_in_group("joueur"):
		ouvrir_porte_et_fuir()

func ouvrir_porte_et_fuir() -> void:
	print("Le Roi s'enfuit ! Ouverture de la porte...")
	
	# Effet Tween pour ouvrir la porte en douceur
	var tween = create_tween()
	tween.tween_property(porte, "rotation_degrees:y", 90.0, 1.0)
	
	# Attend la fin de l'animation avant de charger la suite
	await tween.finished
	
	# Charge le premier croisement du labyrinthe
	get_tree().change_scene_to_file("res://Scenes/Monde.tscn")
