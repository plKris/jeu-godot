class_name Paysan
extends CharacterBody3D


signal joueur_atteint(paysan: Paysan)

enum Etat { COLERE, COURSE }

@export var etat: Etat = Etat.COLERE

@export var cible: Node3D

@export var direction_course := Vector3.FORWARD
@export var vitesse := 2.0
@export var distance_arret := 2.6
@export var espace_personnel := 1.05
## Tant qu'il touche la cible, le paysan renvoie joueur_atteint toutes les N secondes.
@export var intervalle_attaque := 1.0

@export_group("Animation")
@export var tempo := 1.0
@export var amplitude_course := 50.0

var _modele: Node3D
var _corps: Node3D
var _torse: Node3D
var _tete: Node3D
var _bras_g: Node3D
var _bras_d: Node3D
var _jambe_g: Node3D
var _jambe_d: Node3D
var _corps_y := 0.0

var _t := 0.0
var _phase := 0.0
var _course := 0.0  # 0 = colère, 1 = course (mélange des deux animations)
var _decalage := 0.0
var _variation := 1.0
var _delai := 0.0
var _a_atteint := false
var _recharge_attaque := 0.0

## Zone (boîte dans le repère de `repere_zone`) dont le paysan ne sort jamais :
## sert à garder les paysans dans leur couloir. Sans repère, le paysan va partout.
var repere_zone: Node3D
var zone := AABB()

func limiter_a(repere: Node3D, boite: AABB) -> void:
	repere_zone = repere
	zone = boite

func _ready() -> void:
	add_to_group("paysans")
	_modele = $Modele
	_corps = $Modele/Corps
	_torse = $Modele/Corps/Torse
	_tete = $Modele/Corps/Torse/Tete
	_bras_g = $Modele/Corps/Torse/BrasGauche
	_bras_d = $Modele/Corps/Torse/BrasDroit
	_jambe_g = $Modele/Corps/JambeGauche
	_jambe_d = $Modele/Corps/JambeDroite
	_corps_y = _corps.position.y
	# Chaque paysan est un peu différent : la foule n'est pas synchronisée.
	_decalage = randf() * TAU
	_variation = randf_range(0.85, 1.15)
	_t = randf() * 10.0
	_modele.scale = Vector3.ONE * randf_range(0.93, 1.07)

func colere() -> void:
	etat = Etat.COLERE

func courir() -> void:
	if etat != Etat.COURSE:
		_delai = randf_range(0.0, 0.5)
	etat = Etat.COURSE

func _physics_process(delta: float) -> void:
	_t += delta * tempo * _variation
	var dir := Vector3.ZERO
	var regard := Vector3.ZERO
	if etat == Etat.COURSE:
		_delai -= delta
		if cible:
			var vers := cible.global_position - global_position
			vers.y = 0.0
			regard = vers
			# Point visé : la cible, ou le bord de la zone le plus proche si la cible en est sortie.
			var vers_but := _dans_zone(cible.global_position) - global_position
			vers_but.y = 0.0
			if vers.length() <= distance_arret:
				# Tant que le paysan est collé au roi, il « frappe » toutes les intervalle_attaque secondes.
				_recharge_attaque -= delta
				if not _a_atteint or _recharge_attaque <= 0.0:
					_a_atteint = true
					_recharge_attaque = intervalle_attaque
					joueur_atteint.emit(self)
			else:
				_a_atteint = false
				if vers_but.length() > 0.3:
					dir = vers_but.normalized()
		else:
			dir = direction_course.normalized()
			regard = dir
		if _delai > 0.0:
			dir = Vector3.ZERO
	elif cible:
		regard = cible.global_position - global_position
		regard.y = 0.0

	if dir != Vector3.ZERO:
		dir = (dir + _separation() * 1.5).normalized()
	var v := dir * vitesse * _variation
	var k := 1.0 - exp(-8.0 * delta)
	velocity.x = lerpf(velocity.x, v.x, k)
	velocity.z = lerpf(velocity.z, v.z, k)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	if repere_zone:
		var p := _dans_zone(global_position)
		global_position.x = p.x
		global_position.z = p.z

	if regard.length() > 0.1:
		_modele.rotation.y = lerp_angle(_modele.rotation.y, atan2(regard.x, regard.z), 1.0 - exp(-8.0 * delta))
	var v_sol := Vector2(velocity.x, velocity.z).length()
	_course = lerpf(_course, clampf(v_sol / vitesse, 0.0, 1.0), 1.0 - exp(-6.0 * delta))
	_phase = fmod(_phase + v_sol * 2.7 * delta, TAU)
	_animer()

## Ramène un point global dans la zone autorisée (inchangé s'il n'y a pas de zone).
func _dans_zone(p: Vector3) -> Vector3:
	if repere_zone == null or not is_instance_valid(repere_zone):
		return p
	var l := repere_zone.to_local(p)
	l.x = clampf(l.x, zone.position.x, zone.end.x)
	l.z = clampf(l.z, zone.position.z, zone.end.z)
	var g := repere_zone.to_global(l)
	g.y = p.y
	return g

func _separation() -> Vector3:
	var pousse := Vector3.ZERO
	for p in get_tree().get_nodes_in_group("paysans"):
		if p == self:
			continue
		var d: Vector3 = global_position - (p as Node3D).global_position
		d.y = 0.0
		var l := d.length()
		if l < espace_personnel and l > 0.001:
			pousse += d / l * (1.0 - l / espace_personnel)
	return pousse

func _animer() -> void:
	var c := _course
	var a := 1.0 - c
	var t := _t * 6.0 + _decalage
	var s := sin(_phase + _decalage)
	var poing := maxf(0.0, sin(t))          # coups de fourche vers le ciel
	var pietine := sin(t * 0.5)

	var jg_c := Vector3(pietine * 12.0, 0, 0)
	var jd_c := Vector3(-pietine * 12.0, 0, 0)
	var torse_c := Vector3(6.0 + poing * 6.0, sin(t * 0.35) * 12.0, 0)
	var tete_c := Vector3(-10.0, sin(t * 1.3) * 18.0, 0)
	var bras_g_c := Vector3(-150.0 + sin(t * 1.7) * 15.0, 0, -15.0)
	var bras_d_c := Vector3(-10.0 - poing * 25.0, 0, -poing * 20.0)
	var y_c := poing * 0.07

	var jg_r := Vector3(-amplitude_course * s, 0, 0)
	var jd_r := Vector3(amplitude_course * s, 0, 0)
	var torse_r := Vector3(18.0, s * 8.0, 0)
	var tete_r := Vector3(-12.0, 0, 0)
	var bras_g_r := Vector3(45.0 * s, 0, 0)
	var bras_d_r := Vector3(-35.0 + sin(_phase * 2.0) * 8.0, 0, 0)
	var y_r := absf(cos(_phase + _decalage)) * 0.1

	_jambe_g.rotation_degrees = jg_c * a + jg_r * c
	_jambe_d.rotation_degrees = jd_c * a + jd_r * c
	_torse.rotation_degrees = torse_c * a + torse_r * c
	_tete.rotation_degrees = tete_c * a + tete_r * c
	_bras_g.rotation_degrees = bras_g_c * a + bras_g_r * c
	_bras_d.rotation_degrees = bras_d_c * a + bras_d_r * c
	_corps.position.y = _corps_y + y_c * a + y_r * c
