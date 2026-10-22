@tool
extends Control
## Affiche les vies du roi sous forme de cœurs (dessinés par code, pas besoin d'image).

@export var vies := 3:
	set(v):
		vies = v
		queue_redraw()
@export var vies_max := 3:
	set(v):
		vies_max = v
		custom_minimum_size = Vector2(vies_max * (taille + ecart), taille)
		queue_redraw()
@export var taille := 54.0
@export var ecart := 14.0
@export var couleur_pleine := Color(0.86, 0.12, 0.16)
@export var couleur_vide := Color(0.2, 0.15, 0.15, 0.6)
@export var couleur_contour := Color(0.12, 0.05, 0.02)

var _pulsation := 0.0  # petit grossissement du cœur qui vient d'être perdu

func definir(v: int, v_max: int) -> void:
	if v < vies:
		_pulsation = 1.0
	vies_max = v_max
	vies = v

func _process(delta: float) -> void:
	if _pulsation > 0.0:
		_pulsation = maxf(_pulsation - delta * 2.0, 0.0)
		queue_redraw()

func _draw() -> void:
	for i in vies_max:
		var centre := Vector2(i * (taille + ecart) + taille * 0.5, taille * 0.5)
		var echelle := 1.0
		if i == vies and _pulsation > 0.0:
			echelle = 1.0 + 0.5 * _pulsation
		var pts := _forme_coeur(centre, taille * 0.5 * echelle)
		var contour := _forme_coeur(centre, taille * 0.5 * echelle + 3.0)
		draw_colored_polygon(contour, couleur_contour)
		draw_colored_polygon(pts, couleur_pleine if i < vies else couleur_vide)

func _forme_coeur(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 48:
		var t := TAU * k / 48.0
		# Courbe de cœur classique, normalisée à peu près dans [-1, 1].
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(c + Vector2(x, -y - 2.5) * (r / 16.5))
	return pts
