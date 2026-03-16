@icon("res://Assets/Godot Editor Icons/Bunny Sleep.png")
class_name Bunny
extends CharacterBody2D

#region Exports and Configuration
@export var speed: float = 80.0
@export var gravity_multiplier: float = 1.0 
@export var jump_velocity: float = -250.0 
@export var roll_speed: float = 180.0

@export_group("Ice Physics")
@export var acceleration: float = 600.0
@export var friction: float = 200.0
@export var air_acceleration: float = 400.0
@export var air_friction: float = 100.0

@export_group("Dash Tuning")
@export var dash_speed: float = 360.0
@export var max_dash_count: int = 2
@export var dash_horizontal_multiplier: float = 0.9
@export var dash_vertical_multiplier: float = 1.4

@export_group("Jump Tuning")
@export var coyote_time: float = 0.2
@export var jump_buffer_time: float = 0.1

@export_category("Animatable")
@export var allow_physics = false
@export var force_call_jump = false
@export var has_jumped_once = false
#endregion

#region Node References
@onready var roll_anim_loop_timer: Timer = $RollAnimLoop
@onready var animated_sprite: AnimatedSprite2D = $Bunny_Sprite
@onready var left_wall_raycast: RayCast2D = $LeftRay
@onready var right_wall_raycast: RayCast2D = $RightRay
#endregion

#region State Variables
var _can_jump: bool = true
var _jump_buffer_active: bool = false
var _is_dashing: bool = false
var _dashes_available: int = max_dash_count
var _can_dash: bool = true
var _is_rolling: bool = false
var _is_roll_colliding_wall: bool = false
var _roll_direction: int = 1
var _in_roll_loop: bool = false

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
#endregion

func _ready() -> void:
	gravity = gravity * gravity_multiplier
	if animated_sprite:
		if allow_physics:
			animated_sprite.play("Idle")
		else:
			animated_sprite.play("Jump")

func _physics_process(delta: float) -> void:
	if force_call_jump: call_jump_once()
	
	if velocity.y < 0 and not _is_dashing:
		$Collision.disabled = true
	else:
		$Collision.disabled = false
	
	if not allow_physics:
		return
	if not is_on_floor(): velocity.y += gravity * delta

	_handle_movement(delta)
	_handle_jump()
	_handle_dash()
	_handle_roll()

	move_and_slide()
	_handle_animation()

#region Internal Logic Handlers
func _handle_movement(delta: float) -> void:
	var direction = Input.get_axis("a", "d")

	if direction and animated_sprite:
		animated_sprite.flip_h = direction < 0
		_roll_direction = int(direction)

	if _is_dashing or _is_rolling:
		return

	var accel = acceleration if is_on_floor() else air_acceleration
	var fric = friction if is_on_floor() else air_friction

	if direction:
		velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, fric * delta)

func _handle_jump() -> void:
	if is_on_floor():
		_can_jump = true

	if not is_on_floor() and velocity.y > 0 and _can_jump:
		get_tree().create_timer(coyote_time, false).timeout.connect(func(): _can_jump = false)

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("enter"):
		if is_on_floor() or _can_jump:
			_perform_jump()
		else:
			_jump_buffer_active = true
			get_tree().create_timer(jump_buffer_time, false).timeout.connect(func(): _jump_buffer_active = false)
	
	if _jump_buffer_active and is_on_floor():
		_perform_jump()
		_jump_buffer_active = false

func _perform_jump(multiplier = 0.0) -> void:
	if multiplier == 0: velocity.y = jump_velocity
	else: velocity.y = jump_velocity * multiplier
	_can_jump = false

func _handle_dash() -> void:
	if is_on_floor():
		_dashes_available = max_dash_count
		_can_dash = true

	if not Input.is_action_just_pressed("dash") or not _can_dash or _dashes_available <= 0 or _is_rolling:
		return

	_is_dashing = true
	_dashes_available -= 1
	if _dashes_available == 0:
		_can_dash = false

	var dash_vector = Input.get_vector("a", "d", "w", "s").normalized()
	velocity.x = dash_vector.x * dash_speed * (dash_horizontal_multiplier / (2.0 if is_on_floor() else 1.0))
	velocity.y = dash_vector.y * dash_speed * dash_vertical_multiplier

	get_tree().create_timer(0.3, false).timeout.connect(func(): 
		_is_dashing = false
	)

func _handle_roll() -> void:
	if Input.is_action_just_released("roll") and _is_rolling:
		_stop_roll()

	if is_on_floor() and Input.is_action_pressed("roll") and not _is_rolling:
		_is_rolling = true
		_can_dash = false
		if roll_anim_loop_timer:
			roll_anim_loop_timer.start()

	if _is_rolling:
		velocity.x = _roll_direction * roll_speed
		if left_wall_raycast and right_wall_raycast:
			_is_roll_colliding_wall = right_wall_raycast.is_colliding() or left_wall_raycast.is_colliding()

func _stop_roll() -> void:
	if roll_anim_loop_timer:
		roll_anim_loop_timer.stop()
	_is_rolling = false
	_in_roll_loop = false
	_can_dash = true
	if animated_sprite:
		animated_sprite.play("RollLoopEnd")
		await animated_sprite.animation_finished
		if not _is_rolling:
			animated_sprite.play("Idle")

func _handle_animation() -> void:
	if not animated_sprite: 
		return

	if _is_dashing:
		return

	if _is_rolling:
		if _is_roll_colliding_wall and velocity.x == 0:
			animated_sprite.play("Idle")
		elif _in_roll_loop:
			animated_sprite.play("RollLoop")
		else:
			animated_sprite.play("Roll")
		return

	if not is_on_floor():
		animated_sprite.play("Jump")
		return

	if velocity.x != 0:
		animated_sprite.play("Run")
	else:
		animated_sprite.play("Idle")

func _on_roll_anim_loop_timeout() -> void:
	if _is_rolling:
		_in_roll_loop = true
#endregion

func call_death(body: Node2D, safe_position: Vector2 = Vector2(576, -20)):
	if body == self:
		global_position = safe_position

func call_jump_once():
	if not has_jumped_once:
		_perform_jump(2.0)
		if OS.has_feature("editor"):
			print("Player: Force Called 1 Jump")
		has_jumped_once = true

func call_scene_change(next_scene = "res://Scenes + Scripts/Editor/Loading/Editor Loading Scene.tscn"):
	var target_path = "user://Data/Configs/"
	
	# Check if the directory already exists
	if not DirAccess.dir_exists_absolute(target_path):
		var error = DirAccess.make_dir_recursive_absolute(target_path)
		
		if error == OK:
			print("Successfully created: ", target_path)
		else:
			push_error("Could not create directory. Error: ", error)
	else:
		print("Directory already exists: ", target_path)
	
	get_tree().change_scene_to_file(next_scene)
