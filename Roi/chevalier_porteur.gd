@tool
extends Node3D

##animation guarde
enum Cote { GAUCHE, DROITE }

const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK

@export var bras_porteur: Cote = Cote.DROITE:
	set(v):
		bras_porteur = v
		if is_node_ready():
			animer(0.0, 0.0, 0.0)
@export var amplitude_jambes := 32.0
@export var amplitude_bras := 25.0
@export var rebond := 0.04

var _squelette: Skeleton3D
var _corps: Node3D
var _corps_y := 0.0

func _ready() -> void:
	_corps = get_node_or_null("Corps")
	_squelette = find_child("Skeleton3D", true, false)
	if _corps:
		_corps_y = _corps.position.y
	animer(0.0, 0.0, 0.0)

func animer(phase: float, intensite: float, temps: float) -> void:
	if _squelette == null:
		return
	var s := sin(phase)
	var aj := amplitude_jambes * intensite
	var genou_g := maxf(0.0, sin(phase + 1.2)) * 45.0 * intensite
	var genou_d := maxf(0.0, sin(phase + PI + 1.2)) * 45.0 * intensite
	var porte_droite := bras_porteur == Cote.DROITE
	var bras_libre := -amplitude_bras * s * intensite
	var r := {
		"thigh.L": PoseOs.rot(X, -aj * s),
		"thigh.R": PoseOs.rot(X, aj * s),
		"shin.L": PoseOs.rot(X, genou_g),
		"shin.R": PoseOs.rot(X, genou_d),
		"spine.002": PoseOs.rot(Y, s * 4.0 * intensite),
		"spine.005": PoseOs.rot(Y, sin(temps * 0.5 + position.x) * 10.0 * (1.0 - intensite)),
	}
	if porte_droite:
		r["upper_arm.R"] = PoseOs.rot(X, 5.0) * PoseOs.rot(Y, 90.0)
		r["forearm.R"] = PoseOs.rot(X, -55.0)
		r["upper_arm.L"] = PoseOs.rot(X, bras_libre) * PoseOs.rot(Z, -75.0)
		r["forearm.L"] = PoseOs.rot(X, -15.0)
	else:
		r["upper_arm.L"] = PoseOs.rot(X, 5.0) * PoseOs.rot(Y, -90.0)
		r["forearm.L"] = PoseOs.rot(X, -55.0)
		r["upper_arm.R"] = PoseOs.rot(X, -bras_libre) * PoseOs.rot(Z, 75.0)
		r["forearm.R"] = PoseOs.rot(X, -15.0)
	PoseOs.appliquer(_squelette, r, self)
	if _corps:
		var respiration := sin(temps * 2.0 + position.z) * 0.005 * (1.0 - intensite)
		_corps.position.y = _corps_y + (absf(cos(phase)) - 1.0) * rebond * intensite + respiration
