class_name MenuPrincipal
extends Control

## Menu principal : fond château, musique du lobby, boutons Jouer et Quitter.
## Pour l'instant « Jouer » n'est relié à aucune scène : renseigne `scene_jeu` dans l'inspecteur
## (ou écoute le signal `jouer_demande`) quand le jeu sera prêt.

signal jouer_demande

## Scène lancée par le bouton Jouer (laisse vide tant que rien n'est prêt).
@export_file("*.tscn") var scene_jeu := ""

@export_group("Musique")
@export_range(-40.0, 6.0, 0.5) var volume_musique_db := -4.0
## Durée de la montée du son au démarrage, en secondes.
@export var fondu_entree := 1.5
## Durée de la baisse du son quand on quitte le menu, en secondes.
@export var fondu_sortie := 0.6

@onready var _musique: AudioStreamPlayer = $Musique
@onready var _bouton_jouer: Button = %BoutonJouer
@onready var _bouton_quitter: Button = %BoutonQuitter
@onready var _voile: ColorRect = $Voile

var _en_sortie := false

func _ready() -> void:
	_bouton_jouer.pressed.connect(_sur_jouer)
	_bouton_quitter.pressed.connect(_sur_quitter)
	_bouton_jouer.grab_focus()  # navigation au clavier / manette possible tout de suite

	# Musique en boucle, avec une montée douce.
	if _musique.stream is AudioStreamOggVorbis:
		(_musique.stream as AudioStreamOggVorbis).loop = true
	_musique.volume_db = -60.0
	_musique.play()
	create_tween().tween_property(_musique, "volume_db", volume_musique_db, fondu_entree)

	# L'écran apparaît depuis le noir.
	_voile.color.a = 1.0
	create_tween().tween_property(_voile, "color:a", 0.0, 0.8)

func _sur_jouer() -> void:
	if _en_sortie:
		return
	jouer_demande.emit()
	if scene_jeu == "":
		print("[Menu] Jouer : aucune scène reliée pour l'instant (propriété « scene_jeu »).")
		return
	_en_sortie = true
	await _fondu_vers_noir()
	get_tree().change_scene_to_file(scene_jeu)

func _sur_quitter() -> void:
	if _en_sortie:
		return
	_en_sortie = true
	await _fondu_vers_noir()
	get_tree().quit()

func _fondu_vers_noir() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(_voile, "color:a", 1.0, fondu_sortie)
	t.tween_property(_musique, "volume_db", -60.0, fondu_sortie)
	await t.finished
