@tool
class_name PoseOs
extends RefCounted
## Petit utilitaire pour poser un squelette par code (sans AnimationPlayer).
##
## Les rotations sont exprimées dans le repère du personnage (le nœud « racine ») :
## X = droite, Y = haut, Z = arrière (Vector3.BACK). Chaque rotation tourne l'os autour
## de sa propre origine, par-dessus sa pose de repos, et entraîne ses os enfants.
##
## Utilisé par roi.gd et chevalier_porteur.gd :
##   var r := { "thigh.L": PoseOs.rot(X, -88.0) * PoseOs.rot(Y, -6.0), ... }
##   var poses := PoseOs.appliquer(squelette, r, self)


## Rotation de `degres` autour de `axe` (dans le repère du personnage).
## Se combine avec * : rot(X, a) * rot(Z, b) applique d'abord b autour de Z, puis a autour de X.
static func rot(axe: Vector3, degres: float) -> Basis:
	return Basis(axe.normalized(), deg_to_rad(degres))


## Applique les rotations { nom_os: Basis } au squelette.
## Les os absents du dictionnaire reprennent leur pose de repos.
## Renvoie { indice_os: Transform3D } : la pose globale de chaque os, dans le repère du squelette.
static func appliquer(squelette: Skeleton3D, rotations: Dictionary, racine: Node3D = null) -> Dictionary:
	var poses := {}
	if squelette == null:
		return poses

	# Passage repère personnage -> repère squelette (seulement l'orientation, sans l'échelle).
	var vers_racine := Basis.IDENTITY
	var n: Node = squelette
	while racine != null and n is Node3D and n != racine:
		vers_racine = (n as Node3D).transform.basis * vers_racine
		n = n.get_parent()
	vers_racine = vers_racine.orthonormalized()
	var vers_squelette := vers_racine.inverse()

	# Rotations converties dans le repère du squelette, indexées par os.
	var rot_os := {}
	for nom in rotations:
		var i := squelette.find_bone(nom)
		if i >= 0:
			rot_os[i] = vers_squelette * (rotations[nom] as Basis) * vers_racine

	for i in squelette.get_bone_count():
		_calculer(squelette, i, rot_os, poses)

	# Écrit les poses locales dans le squelette.
	for i in squelette.get_bone_count():
		var parent := squelette.get_bone_parent(i)
		var globale: Transform3D = poses[i]
		var locale := globale if parent < 0 else (poses[parent] as Transform3D).affine_inverse() * globale
		squelette.set_bone_pose_position(i, locale.origin)
		squelette.set_bone_pose_rotation(i, locale.basis.get_rotation_quaternion())
		squelette.set_bone_pose_scale(i, locale.basis.get_scale())
	return poses


static func _calculer(squelette: Skeleton3D, i: int, rot_os: Dictionary, poses: Dictionary) -> Transform3D:
	if poses.has(i):
		return poses[i]
	var parent := squelette.get_bone_parent(i)
	var g := squelette.get_bone_rest(i)
	if parent >= 0:
		g = _calculer(squelette, parent, rot_os, poses) * g
	if rot_os.has(i):
		# Tourne autour de l'origine de l'os, dans le repère du squelette.
		g.basis = (rot_os[i] as Basis) * g.basis
	poses[i] = g
	return g
