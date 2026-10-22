extends Node
## État de la partie (autoload « Partie ») : vies du roi, croisements réussis, fin de partie.
##
## Les croisements appellent mauvais_couloir() / bon_couloir() / roi_rattrape() ;
## le HUD et le monde écoutent les signaux pour afficher et réagir.

signal vies_changees(vies: int, vies_max: int)
signal progression_changee(reussis: int, objectif: int)
signal message(texte: String, couleur: Color)
signal vie_perdue
signal partie_perdue
signal partie_gagnee
signal charges_gardes_changees(charges: int, charges_max: int)

## Nombre de vies au début de la partie.
@export var vies_max := 3
## Nombre de bons couloirs à trouver pour que le roi s'échappe du château.
@export var objectif := 5
## Après avoir perdu une vie, le roi est intouchable pendant ce temps (secondes).
@export var duree_invincibilite := 2.0
## Nombre de fois par partie où le roi peut appeler ses gardes pour bloquer un mauvais couloir.
@export var charges_gardes_max := 2

var vies := 3
var reussis := 0
var terminee := false
var charges_gardes := 2
## Croisement où se trouve le roi (mis à jour par croisement.gd).
var croisement_actuel: Node

var _invincible_jusqua := 0.0

func nouvelle_partie() -> void:
	vies = vies_max
	reussis = 0
	terminee = false
	_invincible_jusqua = 0.0
	charges_gardes = charges_gardes_max
	get_tree().paused = false
	vies_changees.emit(vies, vies_max)
	progression_changee.emit(reussis, objectif)
	charges_gardes_changees.emit(charges_gardes, charges_gardes_max)

## Le roi appelle ses gardes : ils bloquent un mauvais couloir du croisement actuel.
## Renvoie vrai si une charge a été utilisée.
func appeler_gardes() -> bool:
	if terminee or charges_gardes <= 0:
		return false
	if croisement_actuel == null or not is_instance_valid(croisement_actuel):
		return false
	if not croisement_actuel.has_method("bloquer_un_mauvais_couloir"):
		return false
	if not croisement_actuel.bloquer_un_mauvais_couloir():
		return false
	charges_gardes -= 1
	charges_gardes_changees.emit(charges_gardes, charges_gardes_max)
	return true

## Vrai quand le prochain bon couloir mène à la sortie.
func dernier_croisement() -> bool:
	return reussis >= objectif - 1

func bon_couloir() -> void:
	if terminee:
		return
	reussis += 1
	progression_changee.emit(reussis, objectif)

func mauvais_couloir() -> void:
	if terminee:
		return
	_perdre_vie(true)

## Un paysan a attrapé le roi.
func roi_rattrape() -> void:
	if terminee:
		return
	_perdre_vie(false)

func victoire() -> void:
	if terminee:
		return
	terminee = true
	partie_gagnee.emit()

func est_invincible() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _invincible_jusqua

## Renvoie vrai si une vie a vraiment été retirée.
func _perdre_vie(forcer: bool) -> bool:
	if not forcer and est_invincible():
		return false
	vies = maxi(vies - 1, 0)
	_invincible_jusqua = Time.get_ticks_msec() / 1000.0 + duree_invincibilite
	vies_changees.emit(vies, vies_max)
	vie_perdue.emit()
	var arduino := get_node_or_null("/root/ArduinoManager")
	if arduino and arduino.get("_paired") == true:
		arduino.send_blink(3)  # la LED du sceptre clignote
	if vies <= 0:
		terminee = true
		partie_perdue.emit()
	return true
