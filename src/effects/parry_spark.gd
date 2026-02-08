class_name ParrySpark
extends Node3D
## ParrySpark - Golden burst effect for successful parries

@export var particle_count: int = 24
@export var spark_speed: float = 8.0
@export var spark_lifetime: float = 0.25
@export var spark_color: Color = Color(1.0, 0.9, 0.4, 1.0)  # Golden

var particles: Array = []
var time_alive: float = 0.0
var mesh_instance: MeshInstance3D

func _ready() -> void:
	# Create mesh instance for rendering
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.emission_enabled = true
	mat.emission = spark_color
	mat.emission_energy_multiplier = 3.0
	mesh_instance.material_override = mat

	# Create particles
	_spawn_particles()

func _spawn_particles() -> void:
	for i in range(particle_count):
		var angle = randf() * TAU
		var elevation = randf_range(-0.5, 0.5)
		var speed = spark_speed * randf_range(0.6, 1.4)

		var direction = Vector3(
			cos(angle) * cos(elevation),
			sin(elevation) + randf_range(0.2, 0.6),  # Bias upward
			sin(angle) * cos(elevation)
		).normalized()

		particles.append({
			"pos": Vector3.ZERO,
			"vel": direction * speed,
			"size": randf_range(0.03, 0.08),
			"age": 0.0
		})

func _process(delta: float) -> void:
	time_alive += delta

	# Update particles
	for p in particles:
		p.age += delta
		p.vel.y -= 15.0 * delta  # Gravity
		p.pos += p.vel * delta

	# Rebuild mesh
	_rebuild_mesh()

	# Auto-cleanup
	if time_alive > spark_lifetime * 1.5:
		queue_free()

func _rebuild_mesh() -> void:
	if particles.is_empty():
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var cam = get_viewport().get_camera_3d()
	if not cam:
		return

	for p in particles:
		if p.age > spark_lifetime:
			continue

		var alpha = 1.0 - (p.age / spark_lifetime)
		alpha = pow(alpha, 0.5)  # Slower fade

		var size = p.size * alpha
		var color = Color(spark_color.r, spark_color.g, spark_color.b, alpha)

		# Billboard quad
		var to_cam = (cam.global_position - global_position - p.pos).normalized()
		var right = to_cam.cross(Vector3.UP).normalized() * size
		var up = right.cross(to_cam).normalized() * size

		var pos = p.pos
		var v1 = pos - right - up
		var v2 = pos + right - up
		var v3 = pos + right + up
		var v4 = pos - right + up

		# Triangle 1
		st.set_color(color)
		st.add_vertex(v1)
		st.add_vertex(v2)
		st.add_vertex(v3)

		# Triangle 2
		st.add_vertex(v1)
		st.add_vertex(v3)
		st.add_vertex(v4)

	mesh_instance.mesh = st.commit()

# Static helper to spawn at position
static func spawn_at(parent: Node, pos: Vector3) -> ParrySpark:
	var spark = ParrySpark.new()
	parent.add_child(spark)
	spark.global_position = pos
	return spark
