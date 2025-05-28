extends Node3D

var game_timer := 0.0
var is_game_start = false

var objects: Dictionary = {
    # Player
    "ObjPlayer": preload("res://scenes/obj_player.tscn"),

    # Enemies

    # Movables

    # Barriers
    "ObjBarrier": preload("res://scenes/obj_cube.tscn")
}

func round_time(time: float, precision: int = 2) -> float:
    var factor := pow(10, precision)
    return round(time * factor) / factor

func _ready() -> void:
    # Initialize game scene
    var player = objects["ObjPlayer"].instantiate()
    add_child(player)

func _process(delta: float) -> void:
    # Update timer
    if (get_node("ObjPlayer") != null):
        if (!is_game_start):
            is_game_start = true
        else:
            game_timer += delta
        game_timer = round_time(game_timer, 2)
        #print("Game Timer: ", game_timer)


