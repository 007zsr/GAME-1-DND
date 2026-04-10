extends RefCounted
class_name GameLayers

const PLAYER_ENTITY := 1
const ENEMY_ENTITY := 2
const WALL := 3
const ENEMY_DETECT := 4
const ENEMY_ATTACK := 5
const PLAYER_ATTACK := 6

const Z_BACKGROUND := -50
const Z_ROOM_FLOOR := -20
const Z_ENTITIES := 0
const Z_WALL_FOREGROUND := 20
const Z_EFFECTS := 40
const Z_UI := 100


static func bit(layer_index: int) -> int:
	return 1 << (layer_index - 1)
