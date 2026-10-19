class_name Hitbox
extends Area2D
## A head, body or leg hit zone. Projectiles find these with a raycast along their path.

var fighter: Fighter
## Rules.HEAD, Rules.BODY or Rules.LEGS.
var part: StringName = Rules.BODY
