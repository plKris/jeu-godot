extends Control
## Écran de fin de partie (Game Over ou Victoire), affiché par Monde quand la partie se termine.
## Le titre se règle dans la scène ; le texte du dessous est rempli avec les chiffres de la partie.

## Vrai pour l'écran de victoire, faux pour le Game Over.
@export var victoire := false
## Scène relancée par « Rejouer ».
@export_file("*.tscn") var scene_jeu := "res://Scenes/Monde.tscn"
## Scène du bouton « Menu principal ».
@export_file("*.tscn") var scene_menu := "res://Menu/menu_principal.tscn"

@onready var _sous_titre: Label = %SousTitre
@onready var _bouton_rejouer: Button = %BoutonRejouer
@onready var _bouton_menu: Button = %BoutonMenu
@onready var _contenu: Control = %Contenu
@onready var _noir: ColorRect = %Noir

var _en_sortie := false

func _ready() -> void:
	get_tree().paused = false
	if victoire:
		_sous_titre.text = "Sa Majesté a trouvé la sortie du château\navec %d vie(s) restante(s)." % Partie.vies
	else:
		_sous_titre.text = "Les paysans ont eu raison de Sa Majesté.\nCroisements franchis : %d / %d" % [Partie.reussis, Partie.objectif]
	_bouton_rejouer.pressed.connect(_aller_a.bind(scene_jeu))
	_bouton_menu.pressed.connect(_aller_a.bind(scene_menu))
	_bouton_rejouer.grab_focus()
	# Apparition : fondu depuis le noir, puis le texte descend doucement.
	_noir.color.a = 1.0
	_contenu.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_noir, "color:a", 0.0, 0.8)
	t.tween_property(_contenu, "modulate:a", 1.0, 0.6)

func _aller_a(scene: String) -> void:
	if _en_sortie:
		return
	_en_sortie = true
	var t := create_tween()
	t.tween_property(_noir, "color:a", 1.0, 0.5)
	await t.finished
	get_tree().change_scene_to_file(scene)
