extends Node3D
## Scène de jeu : le roi porté doit traverser les croisements du château.
## Lance une nouvelle partie, bloque le roi à la fin et secoue la caméra quand il perd une vie.

@export var roi: RoiPorte
@export var camera: Camera3D
## Foule qui hurle derrière la porte d'entrée (décor : elle ne poursuit pas le roi).
@export var foule_entree: FoulePaysans

@export_group("Fin de partie")
## Écran affiché quand le roi n'a plus de vie.
@export_file("*.tscn") var scene_game_over := "res://Scenes/game_over.tscn"
## Écran affiché quand le roi atteint la sortie.
@export_file("*.tscn") var scene_victoire := "res://Scenes/victoire.tscn"
## Temps (s) pendant lequel on voit encore le jeu avant l'écran de fin.
@export var delai_ecran_fin := 1.5

func _ready() -> void:
	Partie.nouvelle_partie()
	Partie.partie_perdue.connect(_fin_de_partie.bind(false))
	Partie.partie_gagnee.connect(_fin_de_partie.bind(true))
	Partie.vie_perdue.connect(_sur_vie_perdue)
	if camera:
		camera.make_current()
	var arduino := get_node_or_null("/root/ArduinoManager")
	if arduino:
		arduino.button_changed.connect(_sur_bouton_sceptre)
	if foule_entree:
		foule_entree.automatique = false
		foule_entree.calmer()
	await get_tree().create_timer(0.6).timeout
	Partie.message.emit("Fuyez ! Trouvez le bon couloir…", Color(1.0, 0.93, 0.75))

## G (action « appeler_gardes ») ou bouton du sceptre : le roi lève son sceptre et appelle ses gardes.
func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("appeler_gardes") and event.is_action_pressed("appeler_gardes"):
		_appeler_gardes()

func _sur_bouton_sceptre(appuye: bool) -> void:
	if appuye:
		_appeler_gardes()

func _appeler_gardes() -> void:
	if roi == null or not roi.controle_actif:
		return
	if Partie.appeler_gardes():
		roi.saluer()

func _fin_de_partie(gagne: bool) -> void:
	if roi:
		roi.controle_actif = false
		roi.entree_externe = Vector2.ZERO
	await get_tree().create_timer(delai_ecran_fin).timeout
	var ecran := scene_victoire if gagne else scene_game_over
	if is_inside_tree() and ecran != "":
		get_tree().change_scene_to_file(ecran)

func _sur_vie_perdue() -> void:
	if camera and camera.has_method("secouer"):
		camera.secouer(0.35)
