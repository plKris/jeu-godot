extends Node3D

# On utilise load() au lieu de preload() pour éviter que la scène se boucle sur elle-même
var scene_croisement = load("res://Scenes/Chateau/croisement.tscn")

var bonne_porte = 0
var deja_genere = false # Sécurité pour ne générer qu'une seule fois

func _ready():
	bonne_porte = randi_range(1, 3)

func _on_porte_gauche_body_entered(body):
	if body.name == "CharacterBody3D":
		verifier_choix(1, $MarkerGauche)

func _on_porte_face_body_entered(body):
	if body.name == "CharacterBody3D":
		verifier_choix(2, $MarkerFace) # Vérifie bien le nom de ton marqueur ici !

func _on_porte_droite_body_entered(body):
	if body.name == "CharacterBody3D":
		verifier_choix(3, $MarkerDroite)

func verifier_choix(porte_choisie, marqueur):
	if porte_choisie == bonne_porte:
		if not deja_genere:
			deja_genere = true
			print("Bon chemin ! Création de la suite...")
			var nouveau_bloc = scene_croisement.instantiate()
			get_tree().current_scene.add_child(nouveau_bloc)
			nouveau_bloc.global_transform = marqueur.global_transform
	else:
		print("Aïe ! Des paysans ! -1 Vie")
