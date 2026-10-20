extends CharacterBody3D

const WALK_SPEED = 5.0
const RUN_SPEED = 9.0

@onready var animation_player = $"Root Scene"/AnimationPlayer
@onready var pivot_camera = $PivotCamera
@onready var camera = $PivotCamera/Camera3D

var clic_droit_enfonce = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		clic_droit_enfonce = event.pressed
		if clic_droit_enfonce:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and clic_droit_enfonce:
		rotate_y(deg_to_rad(-event.relative.x * 0.2))
		pivot_camera.rotate_x(deg_to_rad(-event.relative.y * 0.2))
		pivot_camera.rotation.x = clamp(pivot_camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var est_en_sprint = Input.is_action_pressed("sprint")
	var vitesse_actuelle = RUN_SPEED if est_en_sprint else WALK_SPEED

	var input_dir := Input.get_vector("gauche", "droite", "avant", "arriere")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * vitesse_actuelle
		velocity.z = direction.z * vitesse_actuelle
		
		if input_dir.y < 0:
			if est_en_sprint:
				animation_player.play("CharacterArmature|Run")
			else:
				animation_player.play("CharacterArmature|Walk")
		elif input_dir.y > 0:
			animation_player.play("CharacterArmature|Run_Back")
		elif input_dir.x < 0:
			animation_player.play("CharacterArmature|Run_Left")
		elif input_dir.x > 0:
			animation_player.play("CharacterArmature|Run_Right")
	else:
		velocity.x = move_toward(velocity.x, 0, vitesse_actuelle)
		velocity.z = move_toward(velocity.z, 0, vitesse_actuelle)
		animation_player.play("CharacterArmature|Idle")

	move_and_slide()
