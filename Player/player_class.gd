class_name Player extends CharacterBody3D

##Refrences
@export_group("Refrences")
@export var head:Node3D
@export var cam:Camera3D
@export var vault_cast:ShapeCast3D
@export var collision:CollisionShape3D
@export var anim_plr:AnimationPlayer
#Timers
@onready var jump_buff:SceneTreeTimer
@onready var coyote_timer:SceneTreeTimer
@onready var jump_debounce:SceneTreeTimer
#Speed GUI
@onready var speed_gui = globals.game.gui.get_child(0)

##Stats
@export_category("Ground")
@export var auto_sprint:bool = true
@export var sprint_speed:float = 10
@export var walk_speed:float = 8
@export var ground_acel:float = 50
@export var ground_decel:float = 60
@export_category("Midair")
@export var air_speed:float = 8
@export var air_control:float = 25
@export var fall_speed:float = 50
@export var gravity:float = 30
@export_category("Jump and Vault")
@export_group("Jump")
@export var base_jump_power:float = 8
#Relative to sprint speed!
@export var max_jump_power:float = 10
@export var jump_speed_multi:float = 1.2
@export var coyote_time:float = 0.2
@export_group("Vault")
@export var vault_power:float = 8
@export var vault_power_growth:float = 2
@export var vault_boost:float = 4
@export var vault_boost_decay:float = 2
@export var vault_speed_multi:float = 0.8
@export var vault_clip_time:float = 0.25
@export var vault_boost_stack:bool = false
@export_group("Both")
@export var jv_vault_cool:float = 0.3
@export var jv_buff_time:float = 0.1
@export_category("Camera")
@export var sens := 0.02
@export_group("Bob")
@export var bob_freq:float = 2.2
@export var bob_amp:float = 1
@export_group("FOV")
@export var base_FOV:float = 80.0
@export var FOV_change:float = 2

#velocity = speed + boost
var speed:Vector3
var boost:Vector3
#Direct input and input relative to character
var input_dir:Vector2
var dir:Vector3
#Headbob vars
var bob_time:float = 0.0
var smoothed_amp:float
var bob_pos:Vector3
#Vault momentum tracker
var vault_momentum:float
#Horizontal velocity
var hori_vel:Vector2

#State Enum for the statemachine
enum states {walk, sprint, air}

#Setup timers and lock mouse
func _ready() -> void:
	#Lock Mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	#Timer Setup
	jump_buff = get_tree().create_timer(0)
	coyote_timer = get_tree().create_timer(0)
	jump_debounce = get_tree().create_timer(0)


#Called every input
func _input(event) -> void:
	#Quitting
	if event.is_action_pressed("quit"):
		get_tree().quit()

	#Handle Character Rotation
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens))
		head.rotate_x (deg_to_rad(-event.relative.y * sens))
		head.rotation.x = clamp(head.rotation.x,deg_to_rad(-89),deg_to_rad(89))

#Runs every physics frame
func _physics_process(delta:float) -> void:
	#Run Functions
	set_input_dirs()
	headbob(delta)
	update(delta)
	jv(delta)
	FOV()

	#HV and gui
	hori_vel = Vector2(velocity.x, velocity.z)
	speed_gui.text = str(roundf(hori_vel.length()))

#Jump vault
func jv(delta:float):
	#Update boost after vault
	vault_momentum = move_toward(vault_momentum, 0, vault_boost_decay * delta)
	if vault_momentum:
		boost = dir * vault_momentum

	#Detection
	if Input.is_action_just_pressed("jump"):
		jump_buff = get_tree().create_timer(jv_buff_time)

	#Jump or vault
	if jump_buff.time_left > 0:
		#Vaulting
		if vault_cast.is_colliding():
			if Vector3.UP.dot(vault_cast.get_collision_normal(0)) > 0:
				#Update timers
				jump_buff = get_tree().create_timer(0)
				jump_debounce = get_tree().create_timer(jv_vault_cool)
				#Local vars
				var vault_diff := vault_cast.get_collision_point(0) - global_position
				var height:float = vault_power + vault_diff.y * vault_power_growth
				#Apply impulses
				speed.y = height
				speed.x *= vault_speed_multi
				speed.z *= vault_speed_multi
				#Stacking?
				if vault_boost_stack:
					vault_momentum += vault_boost
				else:
					vault_momentum = vault_boost
				#Handle Conllisions
				if dir.dot(Vector3(vault_diff.x, 0 , vault_diff.z).normalized()) > 0:
					anim_plr.play("Vault")
					collision.disabled = true
					await get_tree().create_timer(vault_clip_time).timeout
					collision.disabled = false
				#Return to prevent jump
				return

		#Jumping
		if is_on_floor() or coyote_timer.time_left > 0:
			if jump_debounce.time_left <= 0:
				var speed_inverse = clamp(inverse_lerp(0, sprint_speed, velocity.length()), 0, 1)
				var real_power = lerp(base_jump_power, max_jump_power, speed_inverse)
				speed = Vector3(speed.x * jump_speed_multi, max(0, get_real_velocity().y) + real_power, speed.z * jump_speed_multi)
				#Update timers
				coyote_timer = get_tree().create_timer(0)
				jump_buff = get_tree().create_timer(0)
				jump_debounce = get_tree().create_timer(jv_vault_cool)

func set_input_dirs() -> void:
	input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	dir = transform.basis * Vector3(input_dir.x, 0, input_dir.y)

func FOV() -> void:
	var clamped_velocity = min(hori_vel.length(), sprint_speed*2)
	var target_fov = base_FOV + FOV_change * clamped_velocity
	cam.fov = lerp(cam.fov, target_fov, 0.01)

#Update Head Bob
func headbob(delta:float) -> void:
	#Smoothing The Sine Waves Position
	var smoothed_pos:Vector3 = lerp(cam.position, bob_pos if dir else Vector3.ZERO, 0.01)
	#Sine Wave
	smoothed_amp = move_toward(smoothed_amp, bob_amp, delta) * float(is_on_floor())
	bob_pos.y = sin(bob_time * bob_freq) * smoothed_amp
	bob_pos.x = cos(bob_time * bob_freq/2) * smoothed_amp
	#Process
	bob_time += delta * get_real_velocity().length()
	cam.position = smoothed_pos

#Returns The Current State
func state() -> states:
	#Ground States
	if is_on_floor():
		if Input.is_action_pressed("sprint") or auto_sprint:
			return states.sprint if input_dir.dot(Vector2.UP) > 0 else states.walk
		else:
			return states.walk
	#Midair States
	else:
		return states.air

#Update Velocity
func update(delta:float) -> void:
	velocity = speed + boost
	move_and_slide()

	#Match States
	match state():
		#Walking
		states.walk:
			#Check if you should accel or deccel
			var moving = true if dir.dot(get_real_velocity()) > 0 else false
			#Moves player at walk speed
			speed = speed.move_toward(dir * walk_speed, (ground_acel if moving else ground_decel) * delta)
			#Coyote bool reset
			coyote_timer = get_tree().create_timer(0) if speed.y > 0 else get_tree().create_timer(coyote_time)

		#Sprinting
		states.sprint:
			#Check if you should accel or deccel
			var moving = true if dir.dot(get_real_velocity()) > 0 else false
			#Moves player at sprint speed
			speed = speed.move_toward(dir * sprint_speed, (ground_acel if moving else ground_decel) * delta)
			#Coyote bool reset
			coyote_timer = get_tree().create_timer(0) if speed.y > 0 else get_tree().create_timer(coyote_time)

		#Midair
		states.air:
			#Set up smooth horizontel air movement
			var goal = Vector2(speed.x, speed.z)
			var flat_dir = Vector2(dir.x, dir.z)
			goal = goal.move_toward(flat_dir * air_speed, air_control * delta)
			#Gravity
			speed.y = move_toward(get_real_velocity().y, -fall_speed, gravity * delta)
			#Air Strafing
			speed.x = goal.x
			speed.z = goal.y
