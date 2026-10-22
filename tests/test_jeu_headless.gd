extends Node
## Test automatique du jeu (sans écran) : le roi est piloté par code dans Monde.tscn.
## Lancer : godot --headless --path . res://tests/test_jeu_headless.tscn
## Vérifie : mauvais couloir = -1 vie + paysans qui restent dans leur couloir,
## bon couloir = croisement suivant, dernier croisement = victoire.

var monde: Node3D
var roi: RoiPorte
var ok := true

func _ready() -> void:
	Partie.objectif = 2
	monde = load("res://Scenes/Monde.tscn").instantiate()
	monde.scene_victoire = ""  # le test reste dans Monde (pas d'écran de fin)
	monde.scene_game_over = ""
	add_child(monde)
	roi = monde.get_node("RoiPorte")
	await _attendre(0.5)
	var c1: Node3D = monde.get_node("Croisement1")
	_verifier(Partie.vies == 3, "3 vies au départ")
	var mauvais := _mauvais_couloir(c1)
	var noms_indices := []
	var joue_avant := false
	for n in c1.get_children():
		if n is AudioStreamPlayer3D and n.name.begins_with("Indice"):
			noms_indices.append(n.name)
			joue_avant = joue_avant or n.playing
	_verifier(joue_avant, "indice : la foule cachée s'entend avant le choix")
	_verifier(noms_indices.size() == 2 and not noms_indices.has("Indice" + c1.COULOIRS[c1.bonne_porte]["nom"]),
			"nœuds de son de foule dans les 2 mauvais couloirs seulement %s" % [noms_indices])
	# 1) Aller dans un mauvais couloir.
	print("[TEST] bon couloir = %d, on essaie d'abord le %d" % [c1.bonne_porte, mauvais])
	await _aller(c1, Vector3(1, 0, -9))
	await _aller(c1, _point_couloir(mauvais, 3.0 + c1.recul_declenchement))
	await _attendre(0.3)
	_verifier(Partie.vies == 2, "mauvais couloir : une vie perdue (vies=%d)" % Partie.vies)
	var foule := c1.get_node_or_null("Paysans" + c1.COULOIRS[mauvais]["nom"])
	_verifier(foule != null and foule.paysans.size() == c1.nb_paysans, "des paysans ont surgi")
	var son := c1.get_node_or_null("Indice" + c1.COULOIRS[mauvais]["nom"]) as AudioStreamPlayer3D
	_verifier(son != null and son.playing, "on entend la foule du mauvais couloir")
	# 2) Demi-tour vers le croisement, les paysans doivent rester dans leur couloir.
	await _aller(c1, Vector3(1, 0, -9), 3.0)
	await _attendre(3.0)
	var zone: AABB = c1.COULOIRS[mauvais]["zone"]
	var dedans := true
	for p in foule.paysans:
		var l := c1.to_local(p.global_position)
		if l.x < zone.position.x - 0.05 or l.x > zone.end.x + 0.05 or l.z < zone.position.z - 0.05 or l.z > zone.end.z + 0.05:
			dedans = false
			print("[TEST]   paysan hors zone : ", l)
	_verifier(dedans, "les paysans restent dans leur couloir")
	_verifier(Partie.vies == 2, "au croisement, les paysans ne touchent pas le roi (vies=%d)" % Partie.vies)
	# 3) Bon couloir -> croisement suivant.
	await _aller(c1, _point_couloir(c1.bonne_porte, 5.0))
	await _attendre(0.2)
	var c2: Node3D = monde.get_node_or_null("Croisement2")
	_verifier(c2 != null, "bon couloir : le croisement 2 est construit")
	_verifier(Partie.reussis == 1, "progression 1 / 2")
	# 4) Traverser jusqu'au croisement 2, puis bon couloir (dernier) -> sortie -> victoire.
	await _aller(c1, _point_couloir(c1.bonne_porte, 12.0), 8.0)
	await _aller(c2, Vector3(1, 0, -3), 8.0)
	await _aller(c2, Vector3(1, 0, -9), 8.0)
	_verifier(c2.to_local(roi.global_position).distance_to(Vector3(1, c2.to_local(roi.global_position).y, -9)) < 1.0, "le roi atteint le croisement 2")
	var gagne := [false]
	Partie.partie_gagnee.connect(func(): gagne[0] = true)
	await _aller(c2, _point_couloir(c2.bonne_porte, 13.0), 8.0)
	await _attendre(0.3)
	_verifier(gagne[0], "dernier bon couloir : victoire")
	# 4bis) Gardes : nouvelle partie, le roi appelle ses gardes -> un mauvais couloir est barré.
	monde.queue_free()
	await _attendre(0.2)
	monde = load("res://Scenes/Monde.tscn").instantiate()
	monde.scene_victoire = ""
	monde.scene_game_over = ""
	add_child(monde)
	roi = monde.get_node("RoiPorte")
	await _attendre(0.3)
	c1 = monde.get_node("Croisement1")
	await _aller(c1, Vector3(1, 0, -8.5))
	var charges_avant := Partie.charges_gardes
	_verifier(Partie.appeler_gardes(), "appel des gardes accepté")
	_verifier(Partie.charges_gardes == charges_avant - 1, "une charge de gardes utilisée")
	_verifier(not Partie.appeler_gardes(), "un seul couloir barré par croisement")
	var barre: int = c1._couloirs_bloques.keys()[0]
	_verifier(barre != c1.bonne_porte, "les gardes barrent un MAUVAIS couloir")
	await _attendre(2.5)
	await _aller(c1, _point_couloir(barre, 5.0), 3.0)
	_verifier(Partie.vies == 3 and not c1._couloirs_punis.has(barre), "le roi ne peut pas entrer dans le couloir barré")
	# 5) Nouvelle partie : rester dans un mauvais couloir -> les paysans attrapent le roi -> défaite.
	monde.queue_free()
	await _attendre(0.2)
	monde = load("res://Scenes/Monde.tscn").instantiate()
	monde.scene_victoire = ""  # le test reste dans Monde (pas d'écran de fin)
	monde.scene_game_over = ""
	add_child(monde)
	roi = monde.get_node("RoiPorte")
	await _attendre(0.3)
	_verifier(Partie.vies == 3 and not Partie.terminee, "nouvelle partie remise à zéro")
	c1 = monde.get_node("Croisement1")
	var perdu := [false]
	Partie.partie_perdue.connect(func(): perdu[0] = true)
	await _aller(c1, Vector3(1, 0, -9))
	await _aller(c1, _point_couloir(_mauvais_couloir(c1), 4.0))
	var t := 0.0
	while not perdu[0] and t < 12.0:
		await _attendre(0.5)
		t += 0.5
	_verifier(perdu[0], "rattrapé par les paysans : défaite après %.1f s" % t)
	_verifier(not roi.controle_actif, "le roi ne bouge plus après la défaite")
	print("[TEST] BILAN ok=%s vies=%d reussis=%d" % [ok, Partie.vies, Partie.reussis])
	get_tree().quit(0 if ok else 1)

func _verifier(cond: bool, texte: String) -> void:
	print("[TEST] %s %s" % ["OK  " if cond else "ÉCHEC", texte])
	if not cond:
		ok = false

func _mauvais_couloir(c: Node3D) -> int:
	for k in [1, 2, 3]:
		if k != c.bonne_porte:
			return k
	return 0

## Point au milieu du couloir k, à `d` mètres après le croisement (repère du croisement).
func _point_couloir(k: int, d: float) -> Vector3:
	match k:
		1: return Vector3(-0.5 - d, 0, -9)
		2: return Vector3(1, 0, -10.5 - d)
		_: return Vector3(2.5 + d, 0, -9)

## Pilote le roi vers un point (repère du croisement c), comme avec le sceptre.
func _aller(c: Node3D, cible_locale: Vector3, delai_max := 6.0) -> void:
	var t := 0.0
	while t < delai_max:
		var cible := c.to_global(cible_locale)
		var d := cible - roi.global_position
		d.y = 0
		if d.length() < 0.4:
			break
		var dir := d.normalized()
		roi.entree_externe = Vector2(dir.x, dir.z)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	roi.entree_externe = Vector2.ZERO
	print("[TEST]   roi en ", c.to_local(roi.global_position).snapped(Vector3.ONE * 0.1), " (repère %s)" % c.name)

func _attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout
