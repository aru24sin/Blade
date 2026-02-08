class_name HitSpark
extends Node3D
## HitSpark - PSX-style hit effect with low-poly sparks

@export var spark_count: int = 8
@export var spark_speed: float = 8.0
@export var spark_lifetime: float = 0.2
@export var spark_color: Color = Color(1.0, 0.9, 0.6)  # Yellow-white

var sparks: Array[Dictionary] = []
var mesh_instance: MeshInstance3D
var time_alive: float = 0.0

func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mesh_instance.material_override = mat

	_spawn_sparks()

func _spawn_sparks() -> void:
	for i in range(spark_count):
		# Random direction in hemisphere toward camera
		var angle = randf() * TAU
		var elevation = randf_range(0.2, 0.8) * PI * 0.5
		var dir = Vector3(
			cos(angle) * cos(elevation),
			sin(elevation),
			sin(angle) * cos(elevation)
		).normalized()

		var speed = spark_speed * randf_range(0.5, 1.0)

		sparks.append({
			"pos": Vector3.ZERO,
			"vel": dir * speed,
			"size": randf_range(0.05, 0.12),
			"age": 0.0
		})

func _process(delta: float) -> void:
	time_alive += delta

	# Update sparks
	var all_dead = true
	for spark in sparks:
		spark.age += delta
		if spark.age < spark_lifetime:
			all_dead = false
			spark.pos += spark.vel * delta
			spark.vel.y -= 20.0 * delta  # Gravity
			spark.vel *= 0.95  # Drag

	_rebuild_mesh()

	if all_dead:
		queue_free()

func _rebuild_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for spark in sparks:
		if spark.age >= spark_lifetime:
			continue

		var alpha = 1.0 - (spark.age / spark_lifetime)
		var size = spark.size * alpha
		var color = Color(spark_color.r, spark_color.g, spark_color.b, alpha)

		# PSX style: simple diamond/quad shape
		var pos = spark.pos
		var up = Vector3.UP * size
		var right = Vector3.RIGHT * size
		var forward = Vector3.FORWARD * size * 0.5

		st.set_color(color)

		# Diamond shape (4 triangles)
		# Top
		st.add_vertex(pos + up)
		st.add_vertex(pos + right)
		st.add_vertex(pos + forward)

		st.add_vertex(pos + up)
		st.add_vertex(pos + forward)
		st.add_vertex(pos - right)

		# Bottom
		st.add_vertex(pos - up)
		st.add_vertex(pos + forward)
		st.add_vertex(pos + right)

		st.add_vertex(pos - up)
		st.add_vertex(pos - right)
		st.add_vertex(pos + forward)

	mesh_instance.mesh = st.commit()

static func spawn_at(parent: Node, position: Vector3, color: Color = Color(1.0, 0.9, 0.6)) -> HitSpark:
	var spark = HitSpark.new()
	spark.spark_color = color
	spark.global_position = position
	parent.add_child(spark)
	return spark
