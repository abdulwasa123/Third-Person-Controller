extends CharacterBody3D

# 1. ENEMY STATS
var max_health = 30
var current_health = 30

var is_dead = false

@onready var anim_player = $Superhero_Male_FullBody/AnimationPlayer
@onready var collision_shape = $CollisionShape3D

func _ready():
	current_health = max_health
	# Connect the animation signal so we know when the "Hit" animation finishes
	anim_player.animation_finished.connect(_on_animation_finished)
	
	# Start in the Idle state
	anim_player.play("UAL1_Standard/Idle") # Replace with your exact Idle animation name

# 2. THE DAMAGE FUNCTION
# The player's fist automatically calls this function when it touches the enemy
func take_damage(damage_amount: int):
	# If the enemy is already dead, ignore the punch
	if is_dead:
		return
		
	current_health -= damage_amount
	print("Enemy got hit! Health left: ", current_health)
	
	# Check if the enemy should die
	if current_health <= 0:
		die()
	else:
		# If they are still alive, play the hit reaction
		anim_player.play("UAL1_Standard/Hit_Chest") # Replace with your exact Hit animation name

# 3. THE DEATH LOGIC
func die():
	is_dead = true
	anim_player.play("UAL1_Standard/Death01") # Replace with your exact Death animation name
	
	# Optional: Turn off the enemy's collision so the player can walk over the dead body
	# We use set_deferred because Godot doesn't like turning off physics during a collision check
	collision_shape.set_deferred("disabled", true)

# 4. RESETTING TO IDLE
func _on_animation_finished(anim_name: String):
	# If the enemy is dead, let them stay dead! Don't go back to Idle.
	if is_dead:
		return
		
	# If the hit animation just finished, go back to standing around
	if anim_name == "UAL1_Standard/Hit_Chest":
		anim_player.play("UAL1_Standard/Idle")
