@icon("res://Assets/Sprites/Ball Sprite.png")
class_name Ball2D
extends RigidBody2D

#region Exports and Configuration
@export_group("Ball Physics")
@export var bounciness: float = 0.9
@export var max_speed: float = 1200.0
@export var velocity_retained_on_hit: float = 1.1

@export_group("Visuals")
@export var rotation_speed_multiplier: float = 0.05
#endregion

#region Node References
@onready var sprite: Sprite2D = $BallSprite
#endregion

#region Internal State
var _needs_respawn: bool = false
var _respawn_position: Vector2 = Vector2.ZERO
#endregion

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = bounciness
	physics_material.friction = 0.1
	physics_material_override = physics_material
	
	linear_damp = 0.5
	angular_damp = 0.5

func _physics_process(_delta: float) -> void:
	if sprite:
		sprite.rotation += linear_velocity.x * rotation_speed_multiplier * _delta
	
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# 1. Handle Respawning securely via the Physics State
	if _needs_respawn:
		state.transform.origin = _respawn_position
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		_needs_respawn = false
		return # Skip normal collision physics for this exact frame
		
	# 2. Normal collision logic
	# Note: It's better to modify state.linear_velocity here rather than just linear_velocity
	if state.get_contact_count() > 0:
		state.linear_velocity *= velocity_retained_on_hit

#region Public API
func call_respawn(body: Node2D, safe_position: Vector2 = Vector2(576, -20)):
	if body == self or body.is_in_group("Ball"):
		print("Ball Respawn Called")
		# Queue the respawn for the next physics frame instead of doing it instantly
		_respawn_position = safe_position
		_needs_respawn = true
		
#endregion
