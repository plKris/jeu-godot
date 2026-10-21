extends Node
# Called when the node enters the scene tree for the first time.
@onready var fade_overlay = %FadeOverlay
@onready var StatusDot = %StatusDot
@onready var StatusLabel = %StatusLabel
@onready var PlayButton = %PlayButton


func _ready() -> void:
	ArduinoManager.arduino_connected.connect(_on_arduino_connected)
	ArduinoManager.arduino_disconnected.connect(_on_arduino_disconnected)
	
	StatusDot.modulate = Color.RED
	StatusLabel.text = "Arduino Pas Connectée"
	PlayButton.disabled = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _on_arduino_connected():
	StatusDot.modulate = Color.GREEN
	StatusLabel.text = "Arduino Connecté"
	PlayButton.disabled = false
	
func _on_arduino_disconnected():
	StatusDot.modulate = Color.RED
	StatusLabel.text = "Déconnecté"
	PlayButton.disabled = true

func _on_play_button_pressed() -> void:
	fade_overlay.modulate.a = 1
	get_tree().change_scene_to_file("res://Scenes/intro.tscn")
