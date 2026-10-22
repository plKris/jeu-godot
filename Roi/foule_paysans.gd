class_name FoulePaysans
extends Node3D


signal joueur_atteint(paysan: Paysan)
signal charge_commencee
signal charge_terminee

@export var cible: Node3D
## Gestion automatique selon la distance. Désactive-la pour tout piloter avec charger() / calmer().
@export var automatique := true
@export var distance_detection := 15.0
@export var distance_abandon := 28.0

@export_group("Son de la foule")
## Coupe/active le bruit de la foule.
@export var son_actif := true
## Son joué en boucle au centre de la foule. Vide = res://Roi/sons/foule/foule_villageois.wav.
@export var son_foule: AudioStream
## Volume quand la foule charge le roi (dB). Le reste du temps, la foule est silencieuse.
@export_range(-40.0, 12.0, 0.5) var volume_charge_db := 2.0
## Hauteur du son pendant la charge (1.0 = normale ; un peu plus haut = plus agité).
@export_range(0.8, 1.3, 0.01) var hauteur_charge := 1.06
## Distance (m) à laquelle le son garde son volume plein ; au-delà il diminue.
@export var portee_son := 10.0
## Vitesse du fondu d'entrée/sortie du son (2 = une demi-seconde).
@export var vitesse_fondu := 2.0

const SON_FOULE_DEFAUT := "res://Roi/sons/foule/foule_villageois.wav"

var en_charge := false
var paysans: Array[Paysan] = []

var _lecteur_foule: AudioStreamPlayer3D
var _excitation := 0.0  # 0 = calme, 1 = charge (fondu progressif)

func _ready() -> void:
	for c in get_children():
		if c is Paysan:
			paysans.append(c)
			c.cible = cible
			c.joueur_atteint.connect(joueur_atteint.emit)
	_preparer_son_foule()

func _physics_process(delta: float) -> void:
	_mettre_a_jour_son(delta)
	if not automatique or cible == null or paysans.is_empty():
		return
	var d := _centre().distance_to(cible.global_position)
	if not en_charge and d < distance_detection:
		charger()
	elif en_charge and d > distance_abandon:
		calmer()

func charger() -> void:
	en_charge = true
	for p in paysans:
		p.cible = cible
		p.courir()
	charge_commencee.emit()

func calmer() -> void:
	en_charge = false
	for p in paysans:
		p.colere()
	charge_terminee.emit()

func _centre() -> Vector3:
	var c := Vector3.ZERO
	for p in paysans:
		c += p.global_position
	return c / paysans.size()

## Crée le lecteur 3D qui joue le brouhaha de la foule en boucle.
func _preparer_son_foule() -> void:
	if son_foule == null and ResourceLoader.exists(SON_FOULE_DEFAUT):
		son_foule = load(SON_FOULE_DEFAUT)
	if son_foule == null:
		push_warning("Son de la foule : fichier %s introuvable" % SON_FOULE_DEFAUT)
		return
	_lecteur_foule = AudioStreamPlayer3D.new()
	_lecteur_foule.name = "SonFoule"
	_lecteur_foule.stream = son_foule
	_lecteur_foule.unit_size = portee_son
	# Rejoue le son à la fin pour qu'il tourne en boucle tant que la charge dure.
	_lecteur_foule.finished.connect(func():
		if son_actif and _excitation > 0.0:
			_lecteur_foule.play())
	add_child(_lecteur_foule)

func _mettre_a_jour_son(delta: float) -> void:
	if _lecteur_foule == null:
		return
	if not son_actif:
		if _lecteur_foule.playing:
			_lecteur_foule.stop()
		return
	_excitation = move_toward(_excitation, 1.0 if en_charge else 0.0, vitesse_fondu * delta)
	# Le son ne joue que pendant la charge : il démarre avec elle et s'éteint en fondu après.
	if _excitation <= 0.0:
		if _lecteur_foule.playing:
			_lecteur_foule.stop()
		return
	if not _lecteur_foule.playing:
		_lecteur_foule.play(randf() * son_foule.get_length() * 0.8)
	if not paysans.is_empty():
		_lecteur_foule.global_position = _centre() + Vector3.UP * 1.5
	# Fondu en volume linéaire (pas en dB) pour une montée et une descente naturelles.
	_lecteur_foule.volume_db = volume_charge_db + linear_to_db(maxf(_excitation, 0.001))
	_lecteur_foule.pitch_scale = lerpf(1.0, hauteur_charge, _excitation)
