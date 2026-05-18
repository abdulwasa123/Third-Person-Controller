extends CharacterBody3D

@export var can_freefly : bool = false
@export var freefly_speed : float = 25.0

var freeflying : bool = false

const SPEED = 4.0
const JUMP_VELOCITY = 4.5
const ROTATION_SPEED = 10.0

var sens_horizontal = 0.2
var sens_vertical = 0.2

@onready var camera_mount: Node3D = $CameraMount
@onready var visual_mesh = $MeshRoot
@onready var anim_player = $MeshRoot/Superhero_Female_FullBody/AnimationPlayer
@onready var collider: CollisionShape3D = $CollisionShape3D

var is_attacking = false
var punch_right_next = true 
var is_landing = false

# --- NEW: Variables for procedural turn-in-place ---
var is_turning_in_place = false
var turn_threshold = deg_to_rad(60.0) # Character swivels when camera goes past 60 degrees

func _ready():
	anim_player.animation_finished.connect(_on_animation_finished)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventMouseMotion:
		# Calculate the horizontal mouse movement
		var cam_rot_y = deg_to_rad(-event.relative.x * sens_horizontal)
		
		# Rotate the whole body horizontally 
		rotate_y(cam_rot_y)
		
		# THE MAGIC TRICK: Counter-rotate the visual mesh so it stays put!
		# (We only do this trick if we are walking normally, not flying)
		if not freeflying:
			visual_mesh.rotation.y -= cam_rot_y
			# Keep the math clean so it doesn't spin wildly after multiple turns
			visual_mesh.rotation.y = wrapf(visual_mesh.rotation.y, -PI, PI)
		
		# Rotate the camera mount vertically
		camera_mount.rotate_x(deg_to_rad(-event.relative.y * sens_vertical))
		# Clamp the camera so it can't do backflips
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-80), deg_to_rad(30))
		
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed("ctrl"):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()
			
func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var motion := (camera_mount.global_basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
		
	if not is_on_floor():
		velocity += get_gravity() * delta

	# The alternating attack logic
	if Input.is_action_just_pressed("attack") and not is_attacking and is_on_floor() and not is_landing:
		is_attacking = true
		is_turning_in_place = false # Cancel the swivel if we throw a punch
		
		if punch_right_next == true:
			anim_player.play("UAL1_Standard/Punch_Cross")
			punch_right_next = false 
		else:
			anim_player.play("UAL1_Standard/Punch_Jab")
			punch_right_next = true 

	# Jump logic 
	if not is_attacking and not is_landing:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Movement & Turning
	if not is_attacking and not is_landing:
		if direction:
			is_turning_in_place = false # Stop swiveling if we start walking
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			
			var target_angle = atan2(-input_dir.x, -input_dir.y)
			visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, target_angle, ROTATION_SPEED * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			
			# --- THE SWIVEL LOGIC ---
			# 1. Check if we twisted the camera too far
			if abs(visual_mesh.rotation.y) > turn_threshold:
				is_turning_in_place = true
				
			# 2. Smoothly catch up to the camera
			if is_turning_in_place:
				visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, 0.0, ROTATION_SPEED * delta)
				
				# 3. Stop turning when we are facing forward again
				if abs(visual_mesh.rotation.y) < 0.05:
					is_turning_in_place = false
					visual_mesh.rotation.y = 0.0
	else:
		# Hard stop when attacking or landing
		velocity.x = 0
		velocity.z = 0
		# If punching or landing, smoothly realign to center so actions go straight forward
		visual_mesh.rotation.y = lerp_angle(visual_mesh.rotation.y, 0.0, ROTATION_SPEED * delta)

	var was_in_air = not is_on_floor()

	move_and_slide()

	if was_in_air and is_on_floor() and not is_attacking:
		is_landing = true
		anim_player.play("UAL1_Standard/Jump_Land")

	# Standard Animations 
	if not is_attacking and not is_landing:
		if not is_on_floor():
			anim_player.play("UAL1_Standard/Jump_Start")
		elif velocity.x != 0 or velocity.z != 0:
			anim_player.play("UAL1_Standard/Sprint")
		elif is_turning_in_place:
			# Optional: If you ever get a 'Turn' animation, play it here!
			# For now, it will just smoothly slide their feet using the Idle animation
			anim_player.play("UAL1_Standard/Idle")
		else:
			anim_player.play("UAL1_Standard/Idle")


func _on_animation_finished(anim_name: String):
	if anim_name == "UAL1_Standard/Punch_Cross" or anim_name == "UAL1_Standard/Punch_Jab": 
		is_attacking = false
	elif anim_name == "UAL1_Standard/Jump_Land":
		is_landing = false

func _on_right_hitbox_body_entered(body: Node3D) -> void:
	if not is_attacking:
		return
		
	if body.is_in_group("Enemy"):
		print("Right hand hit the enemy!")
		if body.has_method("take_damage"):
			body.take_damage(10) 

func _on_left_hitbox_body_entered(body: Node3D) -> void:
	if not is_attacking:
		return
		
	if body.is_in_group("Enemy"):
		print("Left hand hit the enemy!")
		if body.has_method("take_damage"):
			body.take_damage(10)

func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO
	is_turning_in_place = false
	visual_mesh.rotation.y = 0.0 # Snap the mesh forward so it doesn't look weird while flying

func disable_freefly():
	collider.disabled = false
	freeflying = false
