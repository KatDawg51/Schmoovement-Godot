class_name Player extends CharacterBody3D

##Refrences
@export_group("Refrences")
@export var head:Node3D
@export var cam:Camera3D
@export var look_cast:RayCast3D
@export var cam_rig:Node3D
@export var spring_arm:SpringArm3D
@export var ground_normal_ray:RayCast3D
@export var vault_cast:ShapeCast3D
@export var collision:CollisionShape3D
@export var anim_plr:AnimationPlayer
@export var particles:GPUParticles3D
#Timers
@onready var jump_buff:SceneTreeTimer
@onready var coyote_timer:SceneTreeTimer
@onready var jump_debounce:SceneTreeTimer
@onready var slide_time:SceneTreeTimer
#Speed GUI
@onready var speed_gui = globals.game.gui.get_child(0)

##Stats
@export_category("Speed")
@export var ground_speed:float = 10
@export var air_speed:float = 8
@export_category("Jump and Vault")
@export_group("Jump")
@export var base_jump_power:float = 8
@export var max_jump_power:float = 10
@export var jump_speed_multi:float = 1.2
@export_group("Vault")
@export var vault_power:float = 5
@export var vault_power_growth:float = 4
@export var vault_boost:float = 4
@export var vault_boost_decay:float = 2
#Values below 1 give more control cuz speed and boost are separate
@export var vault_speed_multi:float = 01
#End
@export var vault_clip_time:float = 0.2
@export var vault_boost_stack:bool = false
@export_group("Both")
@export var jump_vault_cool:float = 0.3
@export var jump_vault_buff_amount:float = 0.1
@export var coyote_amount:float = 0.5
@export_category("Physics")
@export var ground_acel:float = 50
@export var ground_decel:float = 60
@export var air_control:float = 20
@export var fall_speed:float = 50
@export var gravity:float = 25
@export_category("Camera")
@export var sens := 0.02
@export_group("Bob")
@export var bob_freq:float = 2.2
@export var bob_amp:float = 1
@export_group("FOV")
@export var base_FOV:float = 80.0
@export var FOV_change:float = 2

##Trackers
#Velocity = Speed + Boost
var speed:Vector3
var boost:Vector3
#Direct Input and Input Relative to Character
var input_dir:Vector2
var dir:Vector3
#Relative Input with Slower Strafe Speed
var ground_dir:Vector3
#Allow Coyote Timer to Begin
var coyote:bool = false
#Clamped Velocity for Headbob and FOV
var clamped_velocity:float
#Headbob Variables
var bob_time:float = 0.0
var smoothed_amp:float
var bob_pos:Vector3
#Vault Boost Tracker
var vault_momentum:float
#Real Horizontel Velocity Length
var hv:float

#States Enum for "State Machine"
enum states {ground, run, air}

#Lock Mouse
func _ready() -> void:
	#Lock Mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	#Timer Setup
	jump_buff = get_tree().create_timer(0)
	coyote_timer = get_tree().create_timer(0)
	jump_debounce = get_tree().create_timer(0)
	slide_time = get_tree().create_timer(0)


#Inputs
func _input(event) -> void:
	#Quitting
	if event.is_action_pressed("quit"):
		get_tree().quit()

	#Handle Character Rotation
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens))
		head.rotate_x (deg_to_rad(-event.relative.y * sens))
		head.rotation.x = clamp(head.rotation.x,deg_to_rad(-89),deg_to_rad(89))

#Runs Ever Physics Frame
func _physics_process(delta:float) -> void:
	#Run Functions
	set_input_dirs()
	FOV(delta)
	headbob(delta)
	update(delta)
	vault_jump(delta)

	if round(hv) >= ground_speed:
		particles.emitting = true
	else:
		particles.emitting = false

	speed_gui.text = str(round(hv))

	particles.global_position.x = velocity.normalized().x * 0.3 + global_position.x
	particles.global_position.z = velocity.normalized().z * 0.3 + global_position.z

	#HV
	hv = Vector2(velocity.x, velocity.z).length()

#Jump Action
func vault_jump(delta:float):
	#Gegagedigedagedago
	vault_momentum = move_toward(vault_momentum, 0, vault_boost_decay * delta)
	#gigigtyttrgrgrgggg
	boost = dir * vault_momentum
	#Detection
	if Input.is_action_just_pressed("jump"):
		jump_buff = get_tree().create_timer(jump_vault_buff_amount)

	#Jump or Vault
	if jump_buff.time_left > 0:
		#Vaulting
		if vault_cast.is_colliding():
			var vault_normal := vault_cast.get_collision_normal(0)
			if vault_normal.dot(Vector3.UP) > 0:
				#Vars Idek
				var vault_diff := vault_cast.get_collision_point(0) - global_position
				var height:float = vault_power + vault_diff.y * vault_power_growth

				#Vertical Boost
				speed.y = height
				speed.x *= vault_speed_multi
				speed.z *= vault_speed_multi
				#Stacking?
				if vault_boost_stack:
					vault_momentum += vault_boost
				else:
					vault_momentum = vault_boost

				#Reset Buffer and Add Cooldown
				jump_buff = get_tree().create_timer(0)
				jump_debounce = get_tree().create_timer(jump_vault_cool)

				#Handle Conllisions
				if dir.dot(Vector3(vault_diff.x, 0 , vault_diff.z).normalized()) > 0:
					anim_plr.play("Vault")
					collision.scale = Vector3(0.5, 0.5, 0.5)
					collision.disabled = true
					await get_tree().create_timer(vault_clip_time).timeout
					collision.disabled = false
					collision.scale = Vector3(1, 1, 1)

			#Jump If Shapecast Is False Detecting
			elif is_on_floor():
				if jump_debounce.time_left <= 0:
					var real_power:float = clamp(base_jump_power * velocity.length() / (ground_speed/2), base_jump_power, max_jump_power)
					speed = Vector3(speed.x * jump_speed_multi, max(0, get_real_velocity().y) + real_power, speed.z * jump_speed_multi)
					coyote = false
					jump_buff = get_tree().create_timer(0)
					jump_debounce = get_tree().create_timer(jump_vault_cool)
		#Jumping
		elif is_on_floor() or (coyote and coyote_timer.time_left > 0):
			if jump_debounce.time_left <= 0:
				var real_power:float = clamp(base_jump_power * velocity.length() / (ground_speed/2), base_jump_power, max_jump_power)
				speed = Vector3(speed.x * jump_speed_multi, max(0, get_real_velocity().y) + real_power, speed.z * jump_speed_multi)
				coyote = false
				jump_buff = get_tree().create_timer(0)
				jump_debounce = get_tree().create_timer(jump_vault_cool)

func set_input_dirs() -> void:
	input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	dir = transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	ground_dir = transform.basis * Vector3(input_dir.x if input_dir.y < 0 else input_dir.x * 0.8 , 0, input_dir.y if input_dir.y < 0 else input_dir.y * 0.8)

func FOV(delta:float) -> void:
	clamped_velocity = min(velocity.length(), ground_speed*2)
	var target_fov = base_FOV + FOV_change * clamped_velocity
	cam.fov = lerp(cam.fov, target_fov, delta * 8.0)

#Update Head Bob
func headbob(delta:float) -> void:
	#Smoothing The Sine Waves Position
	var smoothed_pos:Vector3 = lerp(spring_arm.transform.origin, bob_pos * clamped_velocity * float(is_on_floor()) if dir else Vector3.ZERO, 0.01)
	#Sine Wave
	smoothed_amp = move_toward(smoothed_amp, bob_amp/10, delta/2) * float(is_on_floor())
	bob_pos.y = sin(bob_time * bob_freq) * smoothed_amp
	bob_pos.x = cos(bob_time * bob_freq/2) * smoothed_amp
	#Process
	bob_time += delta * velocity.length()
	spring_arm.transform.origin = smoothed_pos

#UNUSED: Returns Slope Using GroundNormalRay
func get_slope() -> Vector3:
	var normal:Vector3
	if ground_normal_ray.is_colliding():
		normal = ground_normal_ray.get_collision_normal()
	if not normal.is_equal_approx(Vector3.UP) and not normal.is_equal_approx(Vector3.UP):
		var tangent = normal.cross(Vector3.DOWN)
		var slope = normal.cross(tangent)
		return abs(slope.normalized())
	else:
		return Vector3.ZERO

#Coyote Timeout
func coyote_timeout():
	await coyote_timer.timeout
	coyote = false

#Returns The Current State
func state() -> states:
	#Ground Stats
	if is_on_floor():
		return states.ground
	else:
		return states.air

#Update Velocity
func update(delta:float) -> void:
	velocity = speed + boost
	if coyote and coyote_timer.time_left <= 0:
		coyote_timer = get_tree().create_timer(coyote_amount)
	coyote_timeout()
	move_and_slide()

	#Match States
	match state():
		#Walking
		states.ground:
			var moving = true if dir or not is_equal_approx(speed.length(), 0) or not dir.dot(get_real_velocity()) <= 0 else false
			speed = speed.move_toward(ground_dir * ground_speed, (ground_acel if moving else ground_decel) * delta)
			#Coyote Time Reset
			if speed.y > 0:
				coyote = false
			else:
				coyote = true
		#Midair
		states.air:
			#Gravity
			speed.y = move_toward(get_real_velocity().y, -fall_speed, gravity * delta)
			#Air Strafing
			speed.x = move_toward(speed.x, dir.x * air_speed, air_control * delta)
			speed.z = move_toward(speed.z, dir.z * air_speed, air_control * delta)

#https://www.youtube.com/watch?v=sidnx5kXn1k
