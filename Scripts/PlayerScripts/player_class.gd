class_name Player extends CharacterBody3D

#Refrences
@export_group("Refrences")
@export var head:Node3D
@export var cam:Camera3D
@export var look_cast:RayCast3D
@export var inventory:Inventory
@export var cam_rig:Node3D
@export var spring_arm:SpringArm3D
@export var ground_normal_ray:RayCast3D
@export var vault_cast:ShapeCast3D
@export var collision:CollisionShape3D
@export var anim_plr:AnimationPlayer


@onready var jump_buff:SceneTreeTimer
@onready var coyote_timer:SceneTreeTimer
@onready var jump_debounce:SceneTreeTimer
@onready var slide_time:SceneTreeTimer

#Stats
@export_category("Speed")
@export var walk_speed:float
@export var sprint_speed:float
@export_category("Jump")
@export var jump_power:float
@export var jump_boost:float
@export_category("Vault")
#Vault Vars
var vault_momentum:float
@export var vault_height:float = 8
@export var vault_boost:float = 6
@export var vault_decay:float = 2
@export var vault_growth:float = 4
@export var vault_boost_stack:bool = false
@export var vault_clip_time:float = 0.14
@export_category("Physics")
#Ground Physics
@export var ground_acel:float = 30
@export var ground_decel:float = 60
#Air Strafing
@export var air_control:float = 30.0
@export var air_speed:float = 15.0
@export var fall_speed:float = 30
#Sliding
@export var slide_control:float
@export var slide_speed:float
@export var gravity:float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export_category("Timers")
@export var jump_cool:float
@export var jump_buff_amount:float
@export var coyote_amount:float
@export_category("Camera")
@export var sens := 0.1
@export_group("Bob")
@export var bob_freq := 2.5
@export var bob_amp := 0.1
@export_group("FOV")
@export var base_FOV:= 80.0
@export var FOV_change := 1.5

#Refrences
@onready var speed_gui = globals.game.gui.get_child(0)

#Movement
var speed:Vector3
var boost:Vector3
var input_dir:Vector2
var dir:Vector3
var ground_dir:Vector3
var real_vel:Vector3
var coyote:bool = false
var clamped_velocity:float
#Cam Shake
var current_rotation:Vector3
var target_rotation:Vector3
#Cam Shake Settings
var snap:float
var return_speed:float
var shake_strength:Vector3
#Bob Variables
var bob_time:float = 0.0
var smoothed_amp:float
var bob_pos:Vector3
#Slide Vars
var can_slide_boost := true

#States Enum
enum states {walk, run, air, slide}

#Lock Mouse
func _ready():
	#Capture Mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#Timer Setup
	jump_buff = get_tree().create_timer(0)
	coyote_timer = get_tree().create_timer(0)
	jump_debounce = get_tree().create_timer(0)
	slide_time = get_tree().create_timer(0)

#Inputs
func _input(event):
	#Quitting
	if event.is_action_pressed("quit"):
		get_tree().quit()
	#Character Rotation
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sens))
		head.rotate_x (deg_to_rad(-event.relative.y * sens))
		head.rotation.x = clamp(head.rotation.x,deg_to_rad(-89),deg_to_rad(89))

#Movement
func _physics_process(delta:float) -> void:
	#Get Direction
	input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	dir = transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	ground_dir = transform.basis * Vector3(input_dir.x if input_dir.y < 0 else input_dir.x * 0.8 , 0, input_dir.y if input_dir.y < 0 else input_dir.y * 0.8)
	#Movement
	update(delta)
	#Jumping
	up(delta)
	#FOV
	clamped_velocity = min(velocity.length(), sprint_speed*2)
	var target_fov = base_FOV + FOV_change * clamped_velocity
	cam.fov = lerp(cam.fov, target_fov, delta * 8.0)
	#Headbob
	headbob(delta)

	#Update Speed GUI


#Jump Action
func up(delta):
	vault_momentum = move_toward(vault_momentum, 0, vault_decay * delta)
	speed_gui.text = str(round(vault_momentum))
	boost = dir * vault_momentum
	#Detection
	if Input.is_action_just_pressed("jump"):
		jump_buff = get_tree().create_timer(jump_buff_amount)
	if jump_buff.time_left > 0:
		#Vaulting
		if vault_cast.is_colliding():
			var vault_normal := vault_cast.get_collision_normal(0)
			if vault_normal.dot(Vector3.UP) > 0:
				anim_plr.play("Vault")
				var vault_length:float = max(0, vault_cast.get_collision_point(0).y - global_position.y)
				var height:float = vault_height + vault_length * vault_growth
				speed.y = height
				if vault_boost_stack:
					vault_momentum += vault_boost
				else:
					vault_momentum = vault_boost
				jump_buff = get_tree().create_timer(0)
				jump_debounce = get_tree().create_timer(jump_cool)
				#Handle Conllisions
				collision.scale = Vector3(0.5, 0.5, 0.5)
				collision.disabled = true
				await get_tree().create_timer(vault_clip_time).timeout
				collision.disabled = false
				collision.scale = Vector3(1, 1, 1)
			elif is_on_floor():
				if jump_debounce.time_left <= 0:
					var real_power:float = clamp(jump_power * velocity.length(), jump_power, jump_power*1.2)
					speed = Vector3(speed.x * jump_boost, max(0, get_real_velocity().y) + real_power, speed.z * jump_boost)
					coyote = false
					jump_buff = get_tree().create_timer(0)
					jump_debounce = get_tree().create_timer(jump_cool)
		#Jumping
		elif is_on_floor() or (coyote and coyote_timer.time_left > 0):
			if jump_debounce.time_left <= 0:
				var real_power:float = clamp(jump_power * velocity.length(), jump_power, jump_power*1.2)
				speed = Vector3(speed.x * jump_boost, max(0, get_real_velocity().y) + real_power, speed.z * jump_boost)
				coyote = false
				jump_buff = get_tree().create_timer(0)
				jump_debounce = get_tree().create_timer(jump_cool)


#Update Trimp Boost
func trimp(delta):
	var boosty:Vector3 = get_slope() * velocity.dot(get_slope()) * clamp(abs(velocity.y), 1, 10) / 100
	speed += boosty

#Update Head Bob
func headbob(delta) -> void:
	#Smoothing The Sine Waves Position
	var smoothed_pos:Vector3 = lerp(spring_arm.transform.origin, bob_pos * clamped_velocity * float(is_on_floor()) if dir else Vector3.ZERO, 0.01)
	#Sine Wave
	smoothed_amp = move_toward(smoothed_amp, bob_amp/10, delta/2) * float(is_on_floor())
	bob_pos.y = sin(bob_time * bob_freq) * smoothed_amp
	bob_pos.x = cos(bob_time * bob_freq/2) * smoothed_amp
	#Process
	bob_time += delta * velocity.length()
	spring_arm.transform.origin = smoothed_pos

#Returns The Slope
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
		if Input.is_action_pressed("sprint"):
			return states.slide
		else:
			return states.walk
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
		states.walk:
			can_slide_boost = true
			var moving = true if dir or not is_equal_approx(speed.length(), 0) or not dir.dot(get_real_velocity()) <= 0 else false
			speed = speed.move_toward(ground_dir * walk_speed, (ground_acel if moving else ground_decel) * delta)
			#Coyote Time Reset
			if speed.y > 0:
				coyote = false
			else:
				coyote = true
		#Midair
		states.air:
			can_slide_boost = true
			#Gravity
			speed.y = move_toward(speed.y, -fall_speed, gravity * delta)
			#Air Strafing
			speed.x = move_toward(speed.x, dir.x * air_speed, air_control * delta)
			speed.z = move_toward(speed.z, dir.z * air_speed, air_control * delta)
		#Midair
		states.slide:
			if can_slide_boost:
				speed *= 1.5
				can_slide_boost = false
			var cur_speed := speed.dot(dir)
			var booster := clampf(slide_speed - cur_speed, 0, slide_control * delta)
			speed = get_real_velocity() + booster * dir






#func _process(delta:float) -> void:
	#target_rotation = target_rotation.slerp(Vector3.ZERO, return_speed * delta)
	#current_rotation = current_rotation.slerp(target_rotation, snap * delta)
	##Set Camera Controllers Rotation
	#cam_rig.rotation = current_rotation
	##Fix Z Shake
	#if shake_strength.z == 0:
		#cam_rig.global_rotation.z = 0
