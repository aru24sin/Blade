extends Node3D
## SmokeBomb - Creates a vision-blocking smoke cloud

@export var duration: float = 5.0
@export var radius: float = 5.0
@export var owner_id: int = 0

var time_remaining: float = 0.0

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var fog_volume: FogVolume = $FogVolume

func _ready() -> void:
	time_remaining = duration

	# Scale fog to radius
	if fog_volume:
		fog_volume.size = Vector3(radius * 2, radius, radius * 2)

func _process(delta: float) -> void:
	time_remaining -= delta

	if time_remaining <= 0:
		# Fade out
		if particles:
			particles.emitting = false

		# Wait for particles to fade
		await get_tree().create_timer(2.0).timeout
		queue_free()

func setup(bomb_owner_id: int) -> void:
	owner_id = bomb_owner_id
