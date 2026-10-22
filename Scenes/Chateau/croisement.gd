extends Node3D
## Un croisement du château : on arrive par le sud, puis trois couloirs (gauche, face, droite).
## Un seul est le bon (tiré au hasard).
##  - Mauvais couloir : des paysans surgissent de derrière le brouillard et chargent le roi,
##    il perd une vie et doit faire demi-tour. Les paysans restent dans LEUR couloir.
##  - Bon couloir : le croisement suivant est construit au bout (ou la sortie si c'était le dernier).
##
## La partie (vies, progression) est gérée par l'autoload « Partie » (Scripts/partie.gd).

enum Couloir { AUCUN, GAUCHE, FACE, DROITE }

## Nombre de paysans qui surgissent dans un mauvais couloir.
@export var nb_paysans := 5
## Vitesse des paysans (le roi marche à 3 m/s, court à 5,4 m/s avec Maj).
@export var vitesse_paysans := 2.6
## Taille des paysans (le roi porté est à l'échelle 0,5 dans Monde).
@export var echelle_paysans := 0.8
## Recule le déclenchement de la charge (mauvais couloir) plus loin dans le couloir, en mètres.
## 0 = juste à l'entrée du couloir ; 2,5 = au bord du brouillard.
@export_range(0.0, 6.0, 0.25) var recul_declenchement := 2.5
## Affiche le bon couloir dans la console (pour tester).
@export var afficher_solution := false

@export_group("Son de la foule")
## Le son vient des nœuds AudioStreamPlayer3D « IndiceGauche », « IndiceFace » et « IndiceDroite »
## de croisement.tscn (fichier = stream, volume maximum = volume_db). Le nœud du bon couloir est
## supprimé : seuls les mauvais couloirs font du bruit.
##  - avant le choix : foule cachée, étouffée, de plus en plus forte quand le roi s'approche ;
##  - quand les paysans surgissent : foule pleine et claire ;
##  - après le bon choix : le bruit s'éteint.
@export var son_foule := true
## Faux : on n'entend rien avant d'entrer dans un mauvais couloir (pas d'indice).
@export var indice_avant_choix := true
## Au-delà de cette distance (m) de l'entrée d'un mauvais couloir, l'indice ne s'entend plus.
@export var distance_indice := 14.0
## Forme de la montée : 1 = régulière, 3 = discrète de loin puis très forte tout près.
@export_range(0.5, 5.0, 0.1) var courbe_indice := 3.0
## Volume en plus (dB) tout près de l'entrée d'un mauvais couloir (accentue l'approche).
@export_range(0.0, 12.0, 0.5) var bonus_proche_db := 4.0
## Indice de loin : son sourd (plus la valeur est basse, plus il est étouffé).
@export_range(200.0, 20000.0, 50.0) var etouffement_hz := 700.0
## Indice tout près de l'entrée : le son s'éclaircit jusqu'à cette valeur.
@export_range(200.0, 20000.0, 50.0) var clair_hz := 5000.0
## Quand le roi prend le bon couloir, le bruit des mauvais couloirs s'éteint en ce temps (s).
@export var duree_extinction := 1.5

@export_group("Gardes")
## Nombre de gardes qui viennent barrer un mauvais couloir quand le roi les appelle.
@export var nb_gardes := 3
## Taille des gardes (les paysans sont à 0,8 ; les porteurs du palanquin à 0,5).
@export var echelle_gardes := 0.85
## Vrai : les gardes ne bloquent qu'un couloir par croisement (le joueur doit encore choisir).
@export var un_seul_barrage_par_croisement := true

const CHEMIN_CROISEMENT := "res://Scenes/Chateau/croisement.tscn"
const SCENE_GARDE := preload("res://Roi/garde.tscn")
const SCENE_PAYSAN := preload("res://Roi/paysan.tscn")

## Géométrie de chaque couloir, dans le repère du croisement (mesurée sur le GridMap, cases de 2 m).
##  entree     : zone qui détecte que le roi s'engage dans le couloir (avant le brouillard)
##  zone       : là où les paysans ont le droit d'aller (ils ne sortent pas de leur couloir)
##  apparition : là où les paysans apparaissent (derrière le brouillard)
##  fond       : mur invisible au bout du couloir (retiré quand le croisement suivant est construit)
const COULOIRS := {
	Couloir.GAUCHE: {
		"nom": "Gauche", "direction": Vector3.LEFT, "marqueur": "MarkerGauche", "porte": "PorteGauche",
		"entree": AABB(Vector3(-3.25, 0, -10.5), Vector3(1.5, 4, 3)),
		"zone": AABB(Vector3(-12.5, -10, -10.1), Vector3(9.7, 20, 2.2)),
		"apparition": AABB(Vector3(-12.2, 1.2, -10.0), Vector3(3.2, 0, 2.0)),
		"fond": AABB(Vector3(-13.9, 0, -10.7), Vector3(0.6, 4, 3.4)),
	},
	Couloir.FACE: {
		"nom": "Face", "direction": Vector3.FORWARD, "marqueur": "MarkerFace", "porte": "PorteFace",
		"entree": AABB(Vector3(-0.5, 0, -13.25), Vector3(3, 4, 1.5)),
		"zone": AABB(Vector3(-0.1, -10, -22.5), Vector3(2.2, 20, 9.7)),
		"apparition": AABB(Vector3(0.0, 1.2, -21.5), Vector3(2.0, 0, 3.2)),
		"fond": AABB(Vector3(-0.7, 0, -23.9), Vector3(3.4, 4, 0.6)),
	},
	Couloir.DROITE: {
		"nom": "Droite", "direction": Vector3.RIGHT, "marqueur": "MarkerDroite", "porte": "PorteDroite",
		"entree": AABB(Vector3(3.75, 0, -10.5), Vector3(1.5, 4, 3)),
		"zone": AABB(Vector3(4.8, -10, -10.1), Vector3(9.7, 20, 2.2)),
		"apparition": AABB(Vector3(11.0, 1.2, -10.0), Vector3(3.2, 0, 2.0)),
		"fond": AABB(Vector3(15.3, 0, -10.7), Vector3(0.6, 4, 3.4)),
	},
}
## Le roi est entré dans ce croisement (un peu après la porte d'entrée).
const ZONE_ARRIVEE := AABB(Vector3(-0.5, 0, -4.75), Vector3(3, 4, 1.5))
## Mur invisible derrière le roi, fermé quand il est arrivé (on ne revient pas en arrière).
const MUR_ENTREE := AABB(Vector3(-0.7, 0, 1.15), Vector3(3.4, 4, 0.6))

## Croisement d'où l'on vient (null pour le premier).
var precedent: Node3D
## Numéro du croisement (1 = premier).
var numero := 1
var bonne_porte: Couloir = Couloir.AUCUN

var _deja_genere := false
var _sortie := false  # vrai si le bon couloir de ce croisement mène dehors
var _couloirs_punis := {}
var _murs_fond := {}
var _mur_entree: StaticBody3D
var _couloirs_bloques := {}  # couloir -> true quand des gardes le barrent
var _indices := {}  # couloir -> AudioStreamPlayer3D de la foule (seulement les mauvais couloirs)
var _volumes_max := {}  # couloir -> volume_db réglé dans l'éditeur
var _bus_indices := {}  # couloir -> nom du bus audio (filtre passe-bas propre au couloir)
var _surgis := {}  # couloir -> true quand les paysans en sont sortis (foule pleine)
var _extinction := 0.0  # 0 = normal, 1 = bon couloir pris : la foule s'est tue
var _roi_son: Node3D

func _ready() -> void:
	bonne_porte = [Couloir.GAUCHE, Couloir.FACE, Couloir.DROITE].pick_random()
	if afficher_solution:
		print("[Croisement %d] bon couloir : %s" % [numero, COULOIRS[bonne_porte]["nom"]])
	for c in COULOIRS:
		var infos: Dictionary = COULOIRS[c]
		var entree: AABB = infos["entree"]
		entree.position += (infos["direction"] as Vector3) * recul_declenchement
		_creer_zone("Entree" + infos["nom"], entree, _sur_entree_couloir.bind(c))
		_murs_fond[c] = _creer_mur("Fond" + infos["nom"], infos["fond"])
		_preparer_indice_sonore(c)
	_creer_zone("Arrivee", ZONE_ARRIVEE, _sur_arrivee)
	_mur_entree = _creer_mur("MurEntree", MUR_ENTREE)
	# Le premier croisement est fermé derrière le roi dès le départ.
	_activer_mur(_mur_entree, precedent == null)
	if precedent == null:
		Partie.croisement_actuel = self

# --- Signaux des portes du bout des couloirs (connectés dans croisement.tscn) ---------------

func _on_porte_gauche_body_entered(body: Node3D) -> void:
	_sur_bout_couloir(body, Couloir.GAUCHE)

func _on_porte_face_body_entered(body: Node3D) -> void:
	_sur_bout_couloir(body, Couloir.FACE)

func _on_porte_droite_body_entered(body: Node3D) -> void:
	_sur_bout_couloir(body, Couloir.DROITE)

# --- Logique ------------------------------------------------------------------------------

func _est_roi(body: Node) -> bool:
	return body is RoiPorte or body.is_in_group("joueur")

func _sur_entree_couloir(body: Node3D, couloir: Couloir) -> void:
	if not _est_roi(body) or Partie.terminee:
		return
	if couloir == bonne_porte:
		_bon_couloir()
	elif not _couloirs_punis.has(couloir):
		_couloirs_punis[couloir] = true
		_faire_surgir_paysans(couloir, body)
		Partie.mauvais_couloir()

func _bon_couloir() -> void:
	if _deja_genere:
		return
	_deja_genere = true
	# Bon choix : le bruit des mauvais couloirs s'éteint.
	create_tween().tween_property(self, "_extinction", 1.0, duree_extinction)
	_sortie = Partie.dernier_croisement()
	Partie.bon_couloir()
	if _sortie:
		_creer_sortie(bonne_porte)
		return
	var infos: Dictionary = COULOIRS[bonne_porte]
	var marqueur: Node3D = get_node(infos["marqueur"])
	var suivant: Node3D = load(CHEMIN_CROISEMENT).instantiate()
	suivant.precedent = self
	suivant.numero = numero + 1
	suivant.name = "Croisement%d" % (numero + 1)
	suivant.transform = transform * marqueur.transform
	get_parent().add_child(suivant)
	# Le bout du bon couloir s'ouvre sur le croisement suivant.
	_activer_mur(_murs_fond[bonne_porte], false)

func _sur_bout_couloir(body: Node3D, couloir: Couloir) -> void:
	if _sortie and couloir == bonne_porte and _est_roi(body):
		Partie.victoire()

func _sur_arrivee(body: Node3D) -> void:
	if not _est_roi(body):
		return
	_activer_mur(_mur_entree, true)
	Partie.croisement_actuel = self
	# On libère les croisements trop loin derrière (ils pourraient chevaucher les suivants).
	if precedent and is_instance_valid(precedent):
		var ancien: Node = precedent.get("precedent")
		if ancien and is_instance_valid(ancien):
			ancien.queue_free()

## Fait apparaître une foule de paysans derrière le brouillard du couloir, qui charge le roi.
func _faire_surgir_paysans(couloir: Couloir, roi: Node3D) -> void:
	var infos: Dictionary = COULOIRS[couloir]
	# La foule sort du brouillard : on l'entend pleinement (nœud Indice du couloir).
	if _indices.has(couloir):
		_surgis[couloir] = true
		var lecteur: AudioStreamPlayer3D = _indices[couloir]
		if not lecteur.playing:
			lecteur.play()
	var foule := FoulePaysans.new()
	foule.name = "Paysans" + infos["nom"]
	foule.automatique = false
	foule.son_actif = not _indices.has(couloir)  # pas de son en double avec le nœud Indice
	foule.cible = roi
	var app: AABB = infos["apparition"]
	for i in nb_paysans:
		var p: Paysan = SCENE_PAYSAN.instantiate()
		p.name = "Paysan%d" % (i + 1)
		p.vitesse = vitesse_paysans
		p.scale = Vector3.ONE * echelle_paysans
		p.position = app.position + Vector3(randf() * app.size.x, 0.0, randf() * app.size.z)
		foule.add_child(p)
	add_child(foule)
	for p in foule.paysans:
		p.limiter_a(self, infos["zone"])
	foule.joueur_atteint.connect(func(_p): Partie.roi_rattrape())
	foule.charger()

## Au bout du dernier bon couloir : la lumière du jour (la sortie du château).
func _creer_sortie(couloir: Couloir) -> void:
	var fond: AABB = COULOIRS[couloir]["fond"]
	var centre := fond.get_center()
	var lumiere := OmniLight3D.new()
	lumiere.name = "LumiereSortie"
	lumiere.light_color = Color(1.0, 0.9, 0.65)
	lumiere.light_energy = 4.0
	lumiere.omni_range = 9.0
	lumiere.position = centre + Vector3(0, 1.0, 0)
	add_child(lumiere)
	var porte := MeshInstance3D.new()
	porte.name = "PorteSortie"
	var boite := BoxMesh.new()
	boite.size = fond.size * Vector3(1, 0.9, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.6)
	mat.emission_energy_multiplier = 3.0
	boite.material = mat
	porte.mesh = boite
	porte.position = centre
	add_child(porte)

## Prépare le nœud « Indice<Couloir> » du couloir. Le nœud du bon couloir est supprimé.
func _preparer_indice_sonore(couloir: Couloir) -> void:
	var lecteur := get_node_or_null("Indice" + COULOIRS[couloir]["nom"]) as AudioStreamPlayer3D
	if lecteur == null:
		return
	lecteur.stop()
	if not son_foule or couloir == bonne_porte or lecteur.stream == null:
		lecteur.queue_free()
		return
	_indices[couloir] = lecteur
	_volumes_max[couloir] = lecteur.volume_db
	lecteur.volume_db = -80.0  # réglé à chaque image (_process)
	lecteur.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	lecteur.attenuation_filter_cutoff_hz = 20500.0
	lecteur.bus = _creer_bus(couloir)
	if not lecteur.finished.is_connected(lecteur.play):
		lecteur.finished.connect(lecteur.play)  # en boucle
	if indice_avant_choix:
		# Départ à un endroit différent du fichier pour que deux couloirs ne soient pas synchronisés.
		lecteur.play(randf() * lecteur.stream.get_length() * 0.8)

## Bus audio propre au couloir, avec un filtre passe-bas (son sourd ↔ son clair).
func _creer_bus(couloir: Couloir) -> StringName:
	var nom := "Foule_%d_%s" % [get_instance_id(), COULOIRS[couloir]["nom"]]
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, nom)
	AudioServer.set_bus_send(i, &"Master")
	var filtre := AudioEffectLowPassFilter.new()
	filtre.cutoff_hz = etouffement_hz
	AudioServer.add_bus_effect(i, filtre)
	_bus_indices[couloir] = nom
	return nom

func _exit_tree() -> void:
	for c in _bus_indices:
		var i := AudioServer.get_bus_index(_bus_indices[c])
		if i > 0:
			AudioServer.remove_bus(i)
	_bus_indices.clear()

## Volume et clarté de chaque mauvais couloir selon la distance du roi à son entrée.
func _process(_delta: float) -> void:
	if _indices.is_empty():
		return
	if _roi_son == null or not is_instance_valid(_roi_son):
		_roi_son = _trouver_roi_croisement()
		if _roi_son == null:
			return
	for c in _indices:
		var lecteur: AudioStreamPlayer3D = _indices[c]
		if not is_instance_valid(lecteur):
			continue
		var entree := to_global((COULOIRS[c]["entree"] as AABB).get_center())
		var d := Vector2(entree.x - _roi_son.global_position.x, entree.z - _roi_son.global_position.z).length()
		var proche := pow(clampf(1.0 - d / distance_indice, 0.0, 1.0), courbe_indice)
		var vol: float
		var coupure: float
		if _surgis.has(c):
			# Les paysans chargent : foule pleine, qui baisse un peu quand le roi s'éloigne.
			vol = _volumes_max[c] + bonus_proche_db + linear_to_db(clampf(1.0 - d / (distance_indice * 1.5), 0.3, 1.0))
			coupure = 20000.0
		else:
			vol = _volumes_max[c] + linear_to_db(maxf(proche, 0.0001)) + bonus_proche_db * proche
			coupure = lerpf(etouffement_hz, clair_hz, proche)
		vol -= 50.0 * _extinction
		coupure = lerpf(coupure, 300.0, _extinction)
		lecteur.volume_db = vol
		var i := AudioServer.get_bus_index(_bus_indices.get(c, ""))
		if i > 0:
			var filtre := AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
			if filtre:
				filtre.cutoff_hz = coupure

# --- Gardes -------------------------------------------------------------------------------

## Appelé quand le roi utilise une charge de gardes : des gardes accourent et barrent l'entrée
## d'un mauvais couloir (un seul). Renvoie faux s'il n'y a plus rien à bloquer ici.
func bloquer_un_mauvais_couloir() -> bool:
	if _deja_genere:
		return false  # le bon couloir est déjà trouvé
	if un_seul_barrage_par_croisement and not _couloirs_bloques.is_empty():
		return false
	var roi := _trouver_roi_croisement()
	var possibles := []
	for c in COULOIRS:
		if c == bonne_porte or _couloirs_punis.has(c) or _couloirs_bloques.has(c):
			continue
		if roi and _roi_dans_couloir(roi, c):
			continue  # on n'enferme pas le roi dans le couloir
		possibles.append(c)
	if possibles.is_empty():
		return false
	var couloir: Couloir = possibles.pick_random()
	_couloirs_bloques[couloir] = true
	var infos: Dictionary = COULOIRS[couloir]
	var dir: Vector3 = infos["direction"]
	var entree: AABB = infos["entree"]
	var bouche := entree.get_center()
	bouche.y = 0.0
	# Mur invisible à l'entrée du couloir (le roi ne peut plus y aller).
	var travers := Vector3(absf(dir.z), 0, absf(dir.x))  # axe en travers du couloir
	var taille := travers * 3.4 + Vector3(absf(dir.x), 0, absf(dir.z)) * 0.6 + Vector3(0, 4, 0)
	_creer_mur("Barrage" + infos["nom"], AABB(bouche + Vector3(0, 2, 0) - taille / 2.0, taille))
	# Les gardes sortent du fond du couloir et courent se placer en ligne à l'entrée.
	for i in nb_gardes:
		var g: Garde = SCENE_GARDE.instantiate()
		g.name = "Garde%s%d" % [infos["nom"], i + 1]
		g.scale = Vector3.ONE * echelle_gardes
		var decalage := (float(i) - (nb_gardes - 1) / 2.0) * (2.0 / maxf(nb_gardes - 1, 1))
		var arrivee := bouche + travers * decalage + Vector3(0, 1.05, 0)
		g.position = arrivee + dir * (6.0 + randf() * 1.5)
		add_child(g)
		g.accourir(to_global(arrivee), global_transform.basis * -dir)
	return true

func _roi_dans_couloir(roi: Node3D, c: Couloir) -> bool:
	var l := to_local(roi.global_position)
	var bouche := (COULOIRS[c]["entree"] as AABB).get_center()
	var dir: Vector3 = COULOIRS[c]["direction"]
	return (l - bouche).dot(dir) > -1.2

func _trouver_roi_croisement() -> Node3D:
	for n in get_parent().get_children():
		if n is RoiPorte:
			return n
	return null

# --- Outils -------------------------------------------------------------------------------

func _creer_zone(nom: String, boite: AABB, rappel: Callable) -> Area3D:
	var zone := Area3D.new()
	zone.name = nom
	zone.monitorable = false
	zone.position = boite.get_center()
	var forme := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = boite.size
	forme.shape = b
	zone.add_child(forme)
	add_child(zone)
	zone.body_entered.connect(rappel)
	return zone

func _creer_mur(nom: String, boite: AABB) -> StaticBody3D:
	var mur := StaticBody3D.new()
	mur.name = nom
	mur.position = boite.get_center()
	var forme := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = boite.size
	forme.shape = b
	mur.add_child(forme)
	add_child(mur)
	return mur

func _activer_mur(mur: StaticBody3D, actif: bool) -> void:
	if mur == null:
		return
	var forme: CollisionShape3D = mur.get_child(0)
	forme.set_deferred("disabled", not actif)
