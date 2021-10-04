extends Node2D

enum GameState { PLAYING, GAME_OVER }

export(float) var distance_for_map_update = 10

onready var _map = $Map
onready var _player = $Map/Player

var _last_map_update_position: Vector2
var _lava_collision_layer
var _game_state
var _game_duration

# Called when the node enters the scene tree for the first time.
func _ready():
	OS.set_window_maximized(true)
	_player.connect("on_tile_collision", self, "_on_player_tile_collision")
	begin_game()

func begin_game():
	_lava_collision_layer = Layers.get_layer("lava")
	_player.position = $Map/PlayerStartPosition.position
	_map.init()
	_player.reset()
	_last_map_update_position = _player.position
	_game_state = GameState.PLAYING
	_game_duration = 0

func _process(delta):
	match _game_state:
		GameState.PLAYING:
			_game_duration += delta
			_map_update()
			$UI/RestartBox.visible = false
			$UI/AliveTime.text = "Lifetime: %.1f" % _game_duration
		GameState.GAME_OVER:
			$UI/RestartBox.visible = true
			$UI/RestartBox/LifetimeLabel.text = "You survived for %.1f seconds" % _game_duration
			if Input.is_action_just_pressed("restart"):
				begin_game()


func _map_update():
	if _player.position.distance_to(_last_map_update_position) > distance_for_map_update:
		var camera = _player.get_node("Camera2D")
		var visible_area = camera.get_viewport_rect()
		visible_area.size *= camera.zoom * 0.5
		visible_area.position = _player.position - visible_area.size / 2
		_map.generate_area(visible_area)
		_last_map_update_position = _player.position

func _on_player_tile_collision(layer):
	if _game_state != GameState.PLAYING:
		return
	if layer == _lava_collision_layer:
		_map.overlay_ground_below_position(_player.position)
		_map.stop_updating()
		_player.fall_to_death()
		_game_state = GameState.GAME_OVER
