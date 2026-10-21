@tool
extends Node3D


const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK


@export var decalage_sceptre := Vector3(0.0, 0.0, 0.02)

var _squelette: Skeleton3D
var _sceptre: Node3D
var _main := -1

func _ready() -> void:
	_squelette = find_child("Skeleton3D", true, false)
	_sceptre = get_node_or_null("Sceptre")
	if _squelette:
		_main = _squelette.find_bone("hand.R")
	poser(0.0, 0.0, 0.0, 0.0)


##  0 = immobile, 1 = en marche ; salut : 0 = repos, 1 = sceptre levé.
func poser(temps: float, phase: float, intensite: float, salut: float) -> void:
	if _squelette == null:
		return
	var repos := 1.0 - intensite
	var s := sin(phase)
	var balance := sin(phase * 2.0) * 6.0 * intensite
	var r := {
		# animations
		"thigh.L": PoseOs.rot(X, -88.0) * PoseOs.rot(Y, -6.0),
		"thigh.R": PoseOs.rot(X, -88.0) * PoseOs.rot(Y, 6.0),
		"shin.L": PoseOs.rot(X, 80.0 + balance),
		"shin.R": PoseOs.rot(X, 80.0 - balance),
		"spine.002": PoseOs.rot(X, sin(temps * 1.7) * 2.0 * repos) * PoseOs.rot(Z, -s * 3.0 * intensite),
		"spine.005": PoseOs.rot(Y, sin(temps * 0.6) * 25.0 * repos) * PoseOs.rot(X, sin(phase * 2.0) * 3.0 * intensite),
		"upper_arm.L": PoseOs.rot(X, -15.0) * PoseOs.rot(Z, -70.0),
		"forearm.L": PoseOs.rot(X, -75.0),
		"upper_arm.R": PoseOs.rot(X, lerpf(-20.0, 30.0, salut)) * PoseOs.rot(Z, lerpf(72.0, -40.0, salut)),
		"forearm.R": PoseOs.rot(X, lerpf(-70.0, 25.0, salut)) * PoseOs.rot(Z, lerpf(0.0, -20.0, salut)),
	}
	var poses := PoseOs.appliquer(_squelette, r, self)
	_placer_sceptre(poses)

func _placer_sceptre(poses: Dictionary) -> void:
	if _sceptre == null or not poses.has(_main):
		return
	var t := Transform3D.IDENTITY
	var n: Node = _squelette
	while n is Node3D and n != self:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	_sceptre.position = (t * (poses[_main] as Transform3D)).origin + decalage_sceptre
