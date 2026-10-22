@tool
class_name Garde
extends Node3D
## Un garde du roi (modèle Knight Free) : il accourt jusqu'à l'entrée d'un couloir,
## puis se met en barrage, bras écartés, pour empêcher le roi d'y entrer.
## Animation par code (PoseOs), comme les porteurs du palanquin.

## Vitesse de course (m/s).
@export var vitesse := 4.0
@export var amplitude_jambes := 40.0
@export var amplitude_bras := 35.0

const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

var _squelette: Skeleton3D
var _corps: Node3D
var _corps_y := 0.0
var _cible := Vector3.ZERO
var _regard := Vector3.ZERO  # direction regardée une fois arrivé
var _en_route := false
var _phase := 0.0
var _course := 0.0     # 0 = immobile, 1 = course
var _barrage := 0.0    # 0 = bras le long du corps, 1 = bras écartés
var _t := 0.0

func _ready() -> void:
	_corps = get_node_or_null("Corps")
	_squelette = find_child("Skeleton3D", true, false)
	if _corps:
		_corps_y = _corps.position.y
	_t = randf() * 10.0
	_poser()

## Fait courir le garde jusqu'au point `cible` (global), puis il se tourne vers `regard`.
func accourir(cible: Vector3, regard: Vector3) -> void:
	_cible = cible
	_regard = regard
	_en_route = true

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var v := 0.0
	if _en_route:
		var vers := _cible - global_position
		vers.y = 0.0
		if vers.length() < 0.05:
			_en_route = false
		else:
			var pas := minf(vitesse * delta, vers.length())
			global_position += vers.normalized() * pas
			v = vitesse
			global_rotation.y = lerp_angle(global_rotation.y, atan2(vers.x, vers.z), 1.0 - exp(-12.0 * delta))
	elif _regard != Vector3.ZERO:
		global_rotation.y = lerp_angle(global_rotation.y, atan2(_regard.x, _regard.z), 1.0 - exp(-6.0 * delta))
	_course = lerpf(_course, 1.0 if v > 0.0 else 0.0, 1.0 - exp(-10.0 * delta))
	_barrage = move_toward(_barrage, 0.0 if _en_route else 1.0, delta * 3.0)
	_phase = fmod(_phase + v * 3.2 * delta, TAU)
	_poser()

func _poser() -> void:
	if _squelette == null:
		return
	var c := _course
	var b := _barrage
	var s := sin(_phase)
	var aj := amplitude_jambes * c
	var genou_g := maxf(0.0, sin(_phase + 1.2)) * 60.0 * c
	var genou_d := maxf(0.0, sin(_phase + PI + 1.2)) * 60.0 * c
	var ab := amplitude_bras * c
	# Bras : le long du corps en courant (Z ±75°), écartés à l'horizontale en barrage (Z ±10°).
	var bras_z := lerpf(75.0, 8.0, b)
	var respire := sin(_t * 2.0) * 3.0 * (1.0 - c)
	var r := {
		"thigh.L": PoseOs.rot(X, -aj * s) * PoseOs.rot(Z, -8.0 * b),
		"thigh.R": PoseOs.rot(X, aj * s) * PoseOs.rot(Z, 8.0 * b),
		"shin.L": PoseOs.rot(X, genou_g),
		"shin.R": PoseOs.rot(X, genou_d),
		"spine.002": PoseOs.rot(X, 12.0 * c),  # penché en avant en courant
		"spine.005": PoseOs.rot(X, respire),
		"upper_arm.L": PoseOs.rot(X, ab * s) * PoseOs.rot(Z, -bras_z),
		"upper_arm.R": PoseOs.rot(X, -ab * s) * PoseOs.rot(Z, bras_z),
		"forearm.L": PoseOs.rot(X, lerpf(-40.0 * c, -10.0, b)),
		"forearm.R": PoseOs.rot(X, lerpf(-40.0 * c, -10.0, b)),
	}
	PoseOs.appliquer(_squelette, r, self)
	if _corps:
		_corps.position.y = _corps_y + absf(cos(_phase)) * 0.06 * c
