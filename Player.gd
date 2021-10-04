extends KinematicBody2D

signal on_tile_collision(layer)

onready var _sprite = $AnimatedSprite
onready var _tween = $Tween
onready var _smoke_particles = $SmokeParticles

export(int) var speed = 200
export(float) var jump_duration = 0.4
export(float) var animation_jump_height = 20
export(float) var fall_speed = 400
export(float) var death_duration = 0.1

var _velocity = Vector2()
var _jump_timeout = 0
var _jumping = false
var _input_enabled = true;
var _original_parent

func _ready():
	_original_parent = get_parent()

func reset():
	_input_enabled = true

func attach_to_platform(platform):
	_original_parent.remove_child(self)
	platform.add_child(self)

func detach_from_platform():
	get_parent().remove_child(self)
	_original_parent.add_child(self)

func fall_to_death():
	_input_enabled = false
	_velocity = Vector2.DOWN * fall_speed
	yield(get_tree().create_timer(death_duration), "timeout")
	_velocity = Vector2.ZERO
	_smoke_particles.emitting = true

func _get_input():
	_velocity = Vector2()
	if Input.is_action_pressed("right"):
		_velocity.x += 1
	if Input.is_action_pressed("left"):
		_velocity.x -= 1
	if Input.is_action_pressed("down"):
		_velocity.y += 1
	if Input.is_action_pressed("up"):
		_velocity.y -= 1
	_velocity = _velocity.normalized() * speed
	if not _jumping and Input.is_action_just_pressed("jump"):
		_jump_timeout = jump_duration
		_jumping = true
		_jumping_animation()

func _process(delta):
	if _jumping and _jump_timeout > 0:
		_sprite.animation = "jumping"
		_jump_timeout -= delta
		if _jump_timeout <= 0:
			_jumping = false
			_sprite.animation = "default"

func _physics_process(_delta):
	if _input_enabled:
		_get_input()
	_velocity = move_and_slide(_velocity)
	if not _jumping:
		_check_collision()

func _check_collision():
	# NOTE - we can't use raycast for reliable tilemap collision atm. See https://github.com/godotengine/godot/issues/44003
	# Use this work-around:
	var space = get_world_2d().get_direct_space_state()
	var results_left = space.intersect_point($LeftFoot.global_position, 1, [], Layers.get_layer("lava"))
	var results_right = space.intersect_point($RightFoot.global_position, 1, [], Layers.get_layer("lava"))
	if results_left and results_right:
		if results_left[0].collider == results_right[0].collider and results_left[0].collider is TileMap:
			emit_signal("on_tile_collision", results_left[0].collider.collision_layer)

func _jumping_animation():
	var initial_position = $AnimatedSprite.position.y
	var top_position = initial_position - animation_jump_height
	_tween.interpolate_property($AnimatedSprite, "position:y", initial_position, top_position, 
		jump_duration * 0.5, Tween.TRANS_QUART, Tween.EASE_IN_OUT)
	_tween.start()
	yield(_tween, "tween_completed")
	_tween.interpolate_property($AnimatedSprite, "position:y", top_position, initial_position, 
		jump_duration * 0.5, Tween.TRANS_QUINT, Tween.EASE_IN)
	_tween.start()
