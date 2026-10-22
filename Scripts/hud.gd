extends CanvasLayer
## Interface du jeu : vies, progression, messages, pause (Échap), écrans de défaite et de victoire.

## Scène du menu principal (bouton « Menu »).
@export_file("*.tscn") var scene_menu := "res://Menu/menu_principal.tscn"
## Durée d'affichage d'un message, en secondes.
@export var duree_message := 2.5

@onready var _coeurs = %Coeurs
@onready var _progression: Label = %Progression
@onready var _message: Label = %Message
@onready var _flash: ColorRect = %Flash
@onready var _panneau: Control = %Panneau
@onready var _titre: Label = %Titre
@onready var _sous_titre: Label = %SousTitre
@onready var _bouton_reprendre: Button = %BoutonReprendre
@onready var _bouton_rejouer: Button = %BoutonRejouer
@onready var _bouton_menu: Button = %BoutonMenu

var _tween_message: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # le HUD marche aussi pendant la pause
	_panneau.visible = false
	_message.modulate.a = 0.0
	_flash.color.a = 0.0
	Partie.vies_changees.connect(_sur_vies)
	Partie.progression_changee.connect(_sur_progression)
	Partie.message.connect(afficher_message)
	Partie.vie_perdue.connect(_sur_vie_perdue)
	Partie.partie_perdue.connect(_sur_defaite)
	Partie.partie_gagnee.connect(_sur_victoire)
	_bouton_reprendre.pressed.connect(_reprendre)
	_bouton_rejouer.pressed.connect(_rejouer)
	_bouton_menu.pressed.connect(_menu)
	_sur_vies(Partie.vies, Partie.vies_max)
	_sur_progression(Partie.reussis, Partie.objectif)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not Partie.terminee:
		if get_tree().paused:
			_reprendre()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func afficher_message(texte: String, couleur := Color.WHITE) -> void:
	_message.text = texte
	_message.add_theme_color_override("font_color", couleur)
	if _tween_message:
		_tween_message.kill()
	_message.modulate.a = 0.0
	_tween_message = create_tween()
	_tween_message.tween_property(_message, "modulate:a", 1.0, 0.15)
	_tween_message.tween_interval(duree_message)
	_tween_message.tween_property(_message, "modulate:a", 0.0, 0.6)

func _sur_vies(vies: int, vies_max: int) -> void:
	_coeurs.definir(vies, vies_max)

func _sur_progression(reussis: int, objectif: int) -> void:
	_progression.text = "Croisement %d / %d" % [mini(reussis + 1, objectif), objectif]

func _sur_vie_perdue() -> void:
	_flash.color.a = 0.45
	create_tween().tween_property(_flash, "color:a", 0.0, 0.6)

func _sur_defaite() -> void:
	await get_tree().create_timer(1.2).timeout
	_ouvrir_panneau("Le roi est capturé !",
			"Les paysans ont eu raison de Sa Majesté.\nCroisements franchis : %d / %d" % [Partie.reussis, Partie.objectif],
			false)

func _sur_victoire() -> void:
	_ouvrir_panneau("Le roi s'est échappé !",
			"Sa Majesté a trouvé la sortie du château\navec %d vie(s) restante(s)." % Partie.vies,
			false)

func _pause() -> void:
	get_tree().paused = true
	_ouvrir_panneau("Pause", "Échap pour reprendre", true)

func _reprendre() -> void:
	get_tree().paused = false
	_panneau.visible = false

func _ouvrir_panneau(titre: String, sous_titre: String, avec_reprendre: bool) -> void:
	_titre.text = titre
	_sous_titre.text = sous_titre
	_bouton_reprendre.visible = avec_reprendre
	_panneau.visible = true
	_panneau.modulate.a = 0.0
	create_tween().tween_property(_panneau, "modulate:a", 1.0, 0.4)
	if avec_reprendre:
		_bouton_reprendre.grab_focus()
	else:
		_bouton_rejouer.grab_focus()

func _rejouer() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_menu)
