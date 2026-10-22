class_name RoiPorte
extends CharacterBody3D

##  flèches ou ZQSD 
## Espace (action « my_action » si elle existe, sinon ui_accept) pour que le roi lève son sceptre.


## Pour piloter  roi.entree_externe = Vector2(x, y)
## avec x = droite/gauche et y = bas/haut de l'écran, chaque valeur entre -1 et 1.

signal salut_termine

@export_group("Déplacement")
@export var vitesse := 3.0
@export var multiplicateur_course := 1.8

@export var acceleration := 6.0
@export var vitesse_rotation := 5.0
@export var relatif_camera := true

@export_group("Animation")
## Pas des gardes : radians de cycle par mètre parcouru.
@export var cadence := 5.5
## Rebond du palanquin en marchant, en mètres.
@export var rebond_palanquin := 0.04
## Roulis du palanquin en marchant, en degrés.
@export var roulis := 1.5
## Nom de l'action qui déclenche le salut du roi.
@export var action_salut := "my_action"

@export_group("Son des pas")
## Coupe/active les bruits de pas.
@export var sons_actifs := true
## Volume des pas en dB (0 = volume d'origine).
@export_range(-40.0, 12.0, 0.5) var volume_pas_db := 0.0
## Volume en plus (dB) quand le cortège marche sur le tapis (+6 dB = nettement plus fort).
@export_range(0.0, 24.0, 0.5) var bonus_tapis_db := 3.0
## Variation aléatoire de hauteur entre deux pas (1.0 = aucune, 1.1 = ±10 %).
@export_range(1.0, 1.5, 0.01) var variation_hauteur := 1.08
## Sons joués sur la pierre (choisis au hasard à chaque pas). Rempli automatiquement si vide.
@export var sons_pierre: Array[AudioStream] = []
## Sons joués sur le tapis. Rempli automatiquement si vide.
@export var sons_tapis: Array[AudioStream] = []
## Événement FMOD (optionnel). S'il est rempli ET trouvé dans une banque chargée, FMOD est utilisé
## à la place des fichiers .wav ci-dessus. Vide = sons Godot (dossier res://Roi/sons/pas/).
@export var evenement_pas := ""
## Paramètre FMOD (facultatif) qui reçoit la vitesse : 0 = arrêt, 1 = marche, 1,8 = course.
## Laisse vide si ton événement n'a pas de paramètre.
@export var parametre_vitesse := ""
## Vrai : un son par garde (4 sons à chaque pas, légèrement décalés).
## Faux : un seul son pour tout le groupe, placé au centre du cortège.
@export var un_son_par_garde := false
## Décalage aléatoire maximum entre les pas des gardes, en secondes.
@export var decalage_max_pas := 0.06
## En dessous de cette intensité de marche, aucun pas n'est joué.
@export var seuil_pas := 0.25
## Le tapis (un MeshInstance3D, ex. TapisRouge). Sur le tapis, les pas utilisent le son « Tapis ».
@export var tapis: MeshInstance3D
## Paramètre FMOD à étiquettes qui choisit le sol : valeur 0 = Pierre, 1 = Tapis.
@export var parametre_surface := "Surface"

@export_group("Sceptre Arduino (gyroscope)")
## Pilote le roi avec l'inclinaison du sceptre (trame DIR: envoyée par l'Arduino).
@export var utiliser_sceptre := true
## Inverse avant/arrière si le sceptre est tenu dans l'autre sens.
@export var inverser_avant_arriere := false
## Inverse gauche/droite si le capteur est monté à l'envers.
@export var inverser_gauche_droite := false
## Le bouton du sceptre fait saluer le roi (lève le sceptre).
@export var bouton_sceptre_salue := true

## Entrée fournie par un autre script ; remplace le clavier tant qu'elle n'est pas nulle.
var entree_externe := Vector2.ZERO
## Vrai pendant que le cortège avance.
var en_mouvement := false
## Faux = le roi n'obéit plus (fin de partie, pause…) ; il s'arrête doucement.
var controle_actif := true

@onready var _visuel: Node3D = $Visuel
@onready var _palanquin: Node3D = $Visuel/Palanquin
@onready var _roi = $Visuel/Palanquin/Roi
@onready var _gardes: Array[Node] = $Visuel/Gardes.get_children()

var _phase := 0.0
var _intensite := 0.0
var _temps := 0.0
var _salut := 0.0
var _tween_salut: Tween
var _palanquin_y := 0.0
var _avertissement_pas := false

var _arduino: Node  # l'autoload ArduinoManager, s'il existe

const DOSSIER_PAS := "res://Roi/sons/pas/"
const NB_VARIANTES_PAS := 6
var _alea_pierre: AudioStreamRandomizer
var _alea_tapis: AudioStreamRandomizer
## Pour chaque point d'émission (palanquin ou garde) : [lecteur pierre, lecteur tapis].
var _lecteurs := {}

func _ready() -> void:
	_palanquin_y = _palanquin.position.y
	_preparer_sons_pas()
	_arduino = get_node_or_null("/root/ArduinoManager")
	if _arduino and utiliser_sceptre:
		_arduino.direction_changed.connect(_sur_direction_sceptre)
		_arduino.button_changed.connect(_sur_bouton_sceptre)
		_arduino.arduino_disconnected.connect(func(): entree_externe = Vector2.ZERO)

## Inclinaison du sceptre → déplacement du roi (le clavier reste utilisable quand le sceptre est à plat).
func _sur_direction_sceptre(dir: Vector2) -> void:
	if inverser_gauche_droite:
		dir.x = -dir.x
	if inverser_avant_arriere:
		dir.y = -dir.y
	entree_externe = dir

func _sur_bouton_sceptre(appuye: bool) -> void:
	if appuye and bouton_sceptre_salue:
		saluer()

func _physics_process(delta: float) -> void:
	_temps += delta
	var entree := entree_externe if entree_externe != Vector2.ZERO else _lire_clavier()
	if not controle_actif:
		entree = Vector2.ZERO
	var direction := Vector3(entree.x, 0.0, entree.y)
	if relatif_camera:
		var cam := get_viewport().get_camera_3d()
		if cam:
			direction = direction.rotated(Vector3.UP, cam.global_rotation.y)

	var v_max := vitesse * (multiplicateur_course if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var cible := direction * v_max
	var k := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, cible.x, k)
	velocity.z = lerpf(velocity.z, cible.z, k)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	if direction.length() > 0.05:
		_visuel.rotation.y = lerp_angle(_visuel.rotation.y, atan2(direction.x, direction.z),
				1.0 - exp(-vitesse_rotation * delta))

	var v_sol := Vector2(velocity.x, velocity.z).length()
	en_mouvement = v_sol > 0.1
	_intensite = lerpf(_intensite, clampf(v_sol / vitesse, 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	var ancienne_phase := _phase
	_phase = fmod(_phase + v_sol * cadence * delta, TAU)
	# Un pied touche le sol quand la jambe est au bout de son balancement (phase = 90° et 270°),
	# c'est aussi le moment où le palanquin est au plus bas.
	if _franchit(ancienne_phase, _phase, PI * 0.5) or _franchit(ancienne_phase, _phase, PI * 1.5):
		_jouer_pas(v_sol / vitesse)
	_animer()

func _unhandled_input(event: InputEvent) -> void:
	var action: String = action_salut if InputMap.has_action(action_salut) else "ui_accept"
	if controle_actif and event.is_action_pressed(action):
		saluer()

##lève le sceptre puis le redescend.
func saluer() -> void:
	if _tween_salut and _tween_salut.is_running():
		return
	_tween_salut = create_tween()
	_tween_salut.tween_property(self, "_salut", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_salut.tween_interval(0.6)
	_tween_salut.tween_property(self, "_salut", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	_tween_salut.tween_callback(salut_termine.emit)

## Vrai si la phase est passée par `seuil` entre a et b (en tenant compte du retour à 0 après TAU).
func _franchit(a: float, b: float, seuil: float) -> bool:
	if b >= a:
		return a < seuil and b >= seuil
	return a < seuil or b >= seuil

## Charge les .wav de res://Roi/sons/pas/ et crée les lecteurs 3D (un au palanquin, un par garde).
func _preparer_sons_pas() -> void:
	if sons_pierre.is_empty():
		sons_pierre = _charger_variantes("pierre")
	if sons_tapis.is_empty():
		sons_tapis = _charger_variantes("tapis")
	if sons_tapis.is_empty():
		sons_tapis = sons_pierre
	_alea_pierre = _creer_aleatoire(sons_pierre)
	_alea_tapis = _creer_aleatoire(sons_tapis)
	var points: Array[Node] = [_palanquin]
	points.append_array(_gardes)
	for p in points:
		_lecteurs[p] = [_creer_lecteur(p, _alea_pierre), _creer_lecteur(p, _alea_tapis)]

func _charger_variantes(sol: String) -> Array[AudioStream]:
	var liste: Array[AudioStream] = []
	for i in range(1, NB_VARIANTES_PAS + 1):
		var chemin := "%s%s_%d.wav" % [DOSSIER_PAS, sol, i]
		if ResourceLoader.exists(chemin):
			liste.append(load(chemin))
	if liste.is_empty():
		push_warning("Son des pas : aucun fichier %s_*.wav trouvé dans %s" % [sol, DOSSIER_PAS])
	return liste

func _creer_aleatoire(sons: Array[AudioStream]) -> AudioStreamRandomizer:
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS if sons.size() > 1 \
			else AudioStreamRandomizer.PLAYBACK_RANDOM
	r.random_pitch = variation_hauteur
	r.random_volume_offset_db = 1.5
	for s in sons:
		r.add_stream(-1, s)
	return r

func _creer_lecteur(parent: Node, flux: AudioStream) -> AudioStreamPlayer3D:
	var l := AudioStreamPlayer3D.new()
	l.name = "SonPas"
	l.stream = flux
	l.volume_db = volume_pas_db
	l.unit_size = 12.0
	l.max_polyphony = 4
	parent.add_child.call_deferred(l)
	return l

func _jouer_pas(vitesse_relative: float) -> void:
	if not sons_actifs or _intensite < seuil_pas:
		return
	if evenement_pas == "" or not FmodServer.check_event_path(evenement_pas):
		if evenement_pas != "" and not _avertissement_pas:
			_avertissement_pas = true
			push_warning("Son des pas : événement FMOD %s introuvable, utilisation des .wav Godot" % evenement_pas)
		_jouer_pas_godot()
		return
	if not un_son_par_garde:
		FmodServer.play_one_shot_attached_with_params(evenement_pas, _palanquin,
				_params_pas(vitesse_relative, _palanquin.global_position))
		return
	for g in _gardes:
		var params := _params_pas(vitesse_relative, (g as Node3D).global_position)
		var d := randf() * decalage_max_pas
		if d > 0.005:
			get_tree().create_timer(d).timeout.connect(func():
				if is_instance_valid(g):
					FmodServer.play_one_shot_attached_with_params(evenement_pas, g, params))
		else:
			FmodServer.play_one_shot_attached_with_params(evenement_pas, g, params)

## Pas joués avec les .wav (pierre ou tapis selon le sol sous le point d'émission).
func _jouer_pas_godot() -> void:
	if not un_son_par_garde:
		_jouer_au_point(_palanquin)
		return
	for g in _gardes:
		var d := randf() * decalage_max_pas
		if d > 0.005:
			get_tree().create_timer(d).timeout.connect(func():
				if is_instance_valid(g):
					_jouer_au_point(g))
		else:
			_jouer_au_point(g)

func _jouer_au_point(point: Node3D) -> void:
	var paire: Array = _lecteurs.get(point, [])
	if paire.is_empty():
		return
	var sur_tapis := tapis != null and _sur_tapis(point.global_position)
	var l: AudioStreamPlayer3D = paire[1] if sur_tapis else paire[0]
	if not l.is_inside_tree() or (l.stream as AudioStreamRandomizer).streams_count == 0:
		return
	l.volume_db = volume_pas_db + (bonus_tapis_db if sur_tapis else 0.0)
	l.play()

func _params_pas(vitesse_relative: float, position_pied: Vector3) -> Dictionary:
	var params := {}
	if parametre_vitesse != "":
		params[parametre_vitesse] = vitesse_relative
	if parametre_surface != "" and tapis != null:
		params[parametre_surface] = 1.0 if _sur_tapis(position_pied) else 0.0
	return params

## Vrai si le point (vu de dessus) est sur le tapis.
func _sur_tapis(p: Vector3) -> bool:
	if tapis.mesh == null:
		return false
	var local := tapis.global_transform.affine_inverse() * p
	var boite := tapis.mesh.get_aabb()
	return local.x >= boite.position.x and local.x <= boite.end.x \
			and local.z >= boite.position.z and local.z <= boite.end.z

func _lire_clavier() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D): v.x += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A): v.x -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S): v.y += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W): v.y -= 1.0
	return v.limit_length(1.0)

func _animer() -> void:
	var i := _intensite
	var repos := 1.0 - i
	var s := sin(_phase)
	for g in _gardes:
		g.animer(_phase, i, _temps)

	# suit le rebond des gardes
	_palanquin.position.y = _palanquin_y + (absf(cos(_phase)) - 1.0) * rebond_palanquin * i \
			+ sin(_temps * 2.0) * 0.004 * repos
	_palanquin.rotation.z = deg_to_rad(roulis) * s * i

	# regarde autour de lui à l'arrêt, lève son sceptre pour saluer.
	_roi.poser(_temps, _phase, i, _salut)
