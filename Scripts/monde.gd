extends Node3D
## Scène de jeu : le roi porté doit traverser les croisements du château.
## Lance une nouvelle partie, bloque le roi à la fin et secoue la caméra quand il perd une vie.

@export var roi: RoiPorte
@export var camera: Camera3D
## Foule qui hurle derrière la porte d'entrée (décor : elle ne poursuit pas le roi).
@export var foule_entree: FoulePaysans

func _ready() -> void:
	Partie.nouvelle_partie()
	Partie.partie_perdue.connect(_fin_de_partie)
	Partie.partie_gagnee.connect(_fin_de_partie)
	Partie.vie_perdue.connect(_sur_vie_perdue)
	if camera:
		camera.make_current()
	if foule_entree:
		foule_entree.automatique = false
		foule_entree.calmer()
	await get_tree().create_timer(0.6).timeout
	Partie.message.emit("Fuyez ! Trouvez le bon couloir…", Color(1.0, 0.93, 0.75))

func _fin_de_partie() -> void:
	if roi:
		roi.controle_actif = false
		roi.entree_externe = Vector2.ZERO

func _sur_vie_perdue() -> void:
	if camera and camera.has_method("secouer"):
		camera.secouer(0.35)
