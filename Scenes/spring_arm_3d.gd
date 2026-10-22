extends SpringArm3D

@export var cible: CharacterBody3D
@export var hauteur_visee := 1.5
@export var vitesse_rotation := 4.0

func _ready() -> void:
	top_level = true
	if cible:
		if cible is CollisionObject3D:
			add_excluded_object(cible.get_rid())
		# Réactive les contrôles de jeu d'aventure standard
		cible.set("relatif_camera", true)
		
	var cam := get_child(0) as Camera3D
	if cam:
		cam.position = Vector3.ZERO
		cam.rotation = Vector3.ZERO

func _process(delta: float) -> void:
	if cible == null:
		return
		
	# Suit la position du roi
	global_position = cible.global_position + Vector3(0, hauteur_visee, 0)
	
	# Isole la vitesse au sol (ignore les sauts/chutes)
	var vitesse_sol := Vector3(cible.velocity.x, 0.0, cible.velocity.z)
	
	if vitesse_sol.length() > 0.5:
		var direction := vitesse_sol.normalized()
		var camera_avant := -global_transform.basis.z
		camera_avant.y = 0.0
		camera_avant = camera_avant.normalized()
		
		# Vérifie si le roi avance (on ignore les demi-tours stricts face à la caméra)
		if direction.dot(camera_avant) > -0.2:
			var angle_cible := atan2(direction.x, direction.z) + PI
			global_rotation.y = lerp_angle(global_rotation.y, angle_cible, delta * vitesse_rotation)
			
	# Maintient l'inclinaison plongeante fixe
	global_rotation.x = deg_to_rad(-15.0)
