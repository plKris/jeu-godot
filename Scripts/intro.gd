extends Control

func _ready() -> void:
	# Lance l'animation dès que la scène s'ouvre
	$AnimationPlayer.play("lancer_intro")

# Connecte le signal "animation_finished" de l'AnimationPlayer ici :
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "lancer_intro":
		# Change vers ta scène principale (salle du trône + jeu)
		# Remplace par le chemin exact de ton fichier de scène principale
		get_tree().change_scene_to_file("res://Scenes/tronesalle.tscn")


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/tronesalle.tscn")
