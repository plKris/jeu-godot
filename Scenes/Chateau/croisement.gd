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
## Affiche le bon couloir dans la console (pour tester).
@export var afficher_solution := false

@export_group("Indice sonore")
## Dans les mauvais couloirs, on entend la foule cachée derrière le brouillard (étouffée).
@export var indice_sonore := true
## Son de la foule cachée. Vide = res://Roi/sons/foule/foule_villageois.wav.
@export var son_indice: AudioStream
## Volume de l'indice (dB) : bien plus bas que la foule qui charge.
@export_range(-40.0, 6.0, 0.5) var volume_indice_db := -12.0
## Étouffement : plus la valeur est basse, plus le son est sourd (comme derrière un mur).
@export_range(200.0, 20000.0, 50.0) var etouffement_hz := 900.0
## Distance (m) à laquelle l'indice garde son volume plein ; au-delà il diminue.
@export var portee_indice := 4.0

const CHEMIN_CROISEMENT := "res://Scenes/Chateau/croisement.tscn"
const SCENE_PAYSAN := preload("res://Roi/paysan.tscn")

## Géométrie de chaque couloir, dans le repère du croisement (mesurée sur le GridMap, cases de 2 m).
##  entree     : zone qui détecte que le roi s'engage dans le couloir (avant le brouillard)
##  zone       : là où les paysans ont le droit d'aller (ils ne sortent pas de leur couloir)
##  apparition : là où les paysans apparaissent (derrière le brouillard)
##  fond       : mur invisible au bout du couloir (retiré quand le croisement suivant est construit)
const COULOIRS := {
	Couloir.GAUCHE: {
		"nom": "Gauche", "marqueur": "MarkerGauche", "porte": "PorteGauche",
		"entree": AABB(Vector3(-3.25, 0, -10.5), Vector3(1.5, 4, 3)),
		"zone": AABB(Vector3(-12.5, -10, -10.1), Vector3(9.7, 20, 2.2)),
		"apparition": AABB(Vector3(-12.2, 1.2, -10.0), Vector3(3.2, 0, 2.0)),
		"fond": AABB(Vector3(-13.9, 0, -10.7), Vector3(0.6, 4, 3.4)),
	},
	Couloir.FACE: {
		"nom": "Face", "marqueur": "MarkerFace", "porte": "PorteFace",
		"entree": AABB(Vector3(-0.5, 0, -13.25), Vector3(3, 4, 1.5)),
		"zone": AABB(Vector3(-0.1, -10, -22.5), Vector3(2.2, 20, 9.7)),
		"apparition": AABB(Vector3(0.0, 1.2, -21.5), Vector3(2.0, 0, 3.2)),
		"fond": AABB(Vector3(-0.7, 0, -23.9), Vector3(3.4, 4, 0.6)),
	},
	Couloir.DROITE: {
		"nom": "Droite", "marqueur": "MarkerDroite", "porte": "PorteDroite",
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
var _indices := {}  # couloir -> AudioStreamPlayer3D de la foule cachée

func _ready() -> void:
	bonne_porte = [Couloir.GAUCHE, Couloir.FACE, Couloir.DROITE].pick_random()
	if afficher_solution:
		print("[Croisement %d] bon couloir : %s" % [numero, COULOIRS[bonne_porte]["nom"]])
	for c in COULOIRS:
		var infos: Dictionary = COULOIRS[c]
		_creer_zone("Entree" + infos["nom"], infos["entree"], _sur_entree_couloir.bind(c))
		_murs_fond[c] = _creer_mur("Fond" + infos["nom"], infos["fond"])
		if indice_sonore and c != bonne_porte:
			_creer_indice_sonore(c)
	_creer_zone("Arrivee", ZONE_ARRIVEE, _sur_arrivee)
	_mur_entree = _creer_mur("MurEntree", MUR_ENTREE)
	# Le premier croisement est fermé derrière le roi dès le départ.
	_activer_mur(_mur_entree, precedent == null)

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
	# On libère les croisements trop loin derrière (ils pourraient chevaucher les suivants).
	if precedent and is_instance_valid(precedent):
		var ancien: Node = precedent.get("precedent")
		if ancien and is_instance_valid(ancien):
			ancien.queue_free()

## Fait apparaître une foule de paysans derrière le brouillard du couloir, qui charge le roi.
func _faire_surgir_paysans(couloir: Couloir, roi: Node3D) -> void:
	var infos: Dictionary = COULOIRS[couloir]
	# La foule sort du brouillard : l'indice étouffé laisse place au vrai brouhaha.
	if _indices.has(couloir):
		var indice: AudioStreamPlayer3D = _indices[couloir]
		_indices.erase(couloir)
		var t := create_tween()
		t.tween_property(indice, "volume_db", -60.0, 0.4)
		t.tween_callback(indice.queue_free)
	var foule := FoulePaysans.new()
	foule.name = "Paysans" + infos["nom"]
	foule.automatique = false
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

## Brouhaha étouffé, en boucle, derrière le brouillard d'un mauvais couloir.
func _creer_indice_sonore(couloir: Couloir) -> void:
	if son_indice == null and ResourceLoader.exists(FoulePaysans.SON_FOULE_DEFAUT):
		son_indice = load(FoulePaysans.SON_FOULE_DEFAUT)
	if son_indice == null:
		return
	var app: AABB = COULOIRS[couloir]["apparition"]
	var lecteur := AudioStreamPlayer3D.new()
	lecteur.name = "Indice" + COULOIRS[couloir]["nom"]
	lecteur.stream = son_indice
	lecteur.volume_db = volume_indice_db
	lecteur.unit_size = portee_indice
	lecteur.attenuation_filter_cutoff_hz = etouffement_hz
	lecteur.attenuation_filter_db = -24.0
	lecteur.pitch_scale = randf_range(0.92, 1.0)
	lecteur.position = app.get_center() + Vector3.UP * 1.5
	lecteur.finished.connect(lecteur.play)  # en boucle
	add_child(lecteur)
	# Départ à un endroit différent du fichier pour que deux couloirs ne soient pas synchronisés.
	lecteur.play(randf() * son_indice.get_length() * 0.8)
	_indices[couloir] = lecteur

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
