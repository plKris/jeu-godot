extends Node3D


@onready var _foule: FoulePaysans = $FoulePaysans

func _ready() -> void:
	_foule.joueur_atteint.connect(func(p): print("Le roi est rattrapé par ", p.name, " !"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		_foule.automatique = false  # on reprend la main
		if _foule.en_charge:
			_foule.calmer()
		else:
			_foule.charger()
