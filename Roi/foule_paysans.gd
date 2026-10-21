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

var en_charge := false
var paysans: Array[Paysan] = []

func _ready() -> void:
	for c in get_children():
		if c is Paysan:
			paysans.append(c)
			c.cible = cible
			c.joueur_atteint.connect(joueur_atteint.emit)

func _physics_process(_delta: float) -> void:
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
