class_name MenuPrincipal
extends Control

## Menu principal : fond château, musique du lobby, boutons Jouer et Quitter.
## « Jouer » lance `scene_jeu` (l'intro, puis la salle du trône, puis le labyrinthe).
## En bas à droite : état du sceptre Arduino (le jeu se joue aussi au clavier).

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
@onready var _etat_sceptre: Label = %EtatSceptre

var _en_sortie := false

func _ready() -> void:
	_bouton_jouer.pressed.connect(_sur_jouer)
	_bouton_quitter.pressed.connect(_sur_quitter)
	_bouton_jouer.grab_focus()  # navigation au clavier / manette possible tout de suite
	_suivre_sceptre()

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

## Affiche si le sceptre (Arduino) est branché.
func _suivre_sceptre() -> void:
	var arduino := get_node_or_null("/root/ArduinoManager")
	if arduino == null:
		_etat_sceptre.visible = false
		return
	arduino.arduino_connected.connect(_maj_sceptre.bind(true))
	arduino.arduino_disconnected.connect(_maj_sceptre.bind(false))
	_maj_sceptre(arduino.get("_paired") == true)

func _maj_sceptre(connecte: bool) -> void:
	_etat_sceptre.text = "Sceptre : connecté" if connecte else "Sceptre : non connecté (clavier)"
	_etat_sceptre.modulate = Color(0.6, 1.0, 0.6) if connecte else Color(1, 1, 1, 0.8)
