class_name SlashTrail
extends Node3D
## SlashTrail - Bright, impactful sword trail effect

@export var trail_length: int = 16
@export var trail_width: float = 0.12
@export var trail_lifetime: float = 0.18
@export var trail_color: Color = Color(0.95, 0.98, 1.0, 0.9)  # Bright white-blue

var points: Array[Vector3] = []
var ages: Array[float] = []
var mesh_instance: MeshInstance3D
var is_active: bool = false

# Glow effect
var glow_intensity: float = 2.0

func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	# Add bloom/glow
	mat.emission_enabled = true
	mat.emission = trail_color
	mat.emission_energy_multiplier = glow_intensity
	mesh_instance.material_override = mat

func _process(delta: float) -> void:
	# Age all points
	for i in range(ages.size()):
		ages[i] += delta

	# Remove old points
	while ages.size() > 0 and ages[0] > trail_lifetime:
		ages.pop_front()
		points.pop_front()

	# Rebuild mesh
	_rebuild_mesh()

	# Auto-cleanup when inactive and empty
	if not is_active and points.size() == 0:
		queue_free()

func start_trail() -> void:
	is_active = true
	points.clear()
	ages.clear()

func stop_trail() -> void:
	is_active = false

func add_point(tip_pos: Vector3, base_pos: Vector3) -> void:
	if not is_active:
		return

	# Store both tip and base for better trail shape
	# We'll use this to compute proper width
	var center = (tip_pos + base_pos) * 0.5
	points.append(center)
	ages.append(0.0)

	# Limit trail length
	while points.size() > trail_length:
		points.pop_front()
		ages.pop_front()

func _rebuild_mesh() -> void:
	if points.size() < 2:
		mesh_instance.mesh = null
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i + 1]

		# Calculate perpendicular for width
		var dir = (p2 - p1).normalized()
		var up = Vector3.UP
		if abs(dir.dot(up)) > 0.9:
			up = Vector3.RIGHT
		var perp = dir.cross(up).normalized()

		# Taper trail - newer is thicker, older is thinner
		var t1 = ages[i] / trail_lifetime
		var t2 = ages[i + 1] / trail_lifetime
		var alpha1 = 1.0 - t1
		var alpha2 = 1.0 - t2

		# Width tapers more dramatically at the end
		var width_curve1 = pow(alpha1, 0.5)  # Slower taper
		var width_curve2 = pow(alpha2, 0.5)
		var width1 = trail_width * width_curve1
		var width2 = trail_width * width_curve2

		# Four corners of quad
		var v1 = p1 + perp * width1 * 0.5
		var v2 = p1 - perp * width1 * 0.5
		var v3 = p2 + perp * width2 * 0.5
		var v4 = p2 - perp * width2 * 0.5

		# Bright core color with alpha fade
		# Inner core is pure white, edges are colored
		var core_brightness = 1.0 + (alpha1 * 0.5)  # Brighter when fresh
		var color1 = Color(
			min(trail_color.r * core_brightness, 1.0),
			min(trail_color.g * core_brightness, 1.0),
			min(trail_color.b * core_brightness, 1.0),
			trail_color.a * alpha1
		)
		var color2 = Color(
			min(trail_color.r * core_brightness, 1.0),
			min(trail_color.g * core_brightness, 1.0),
			min(trail_color.b * core_brightness, 1.0),
			trail_color.a * alpha2
		)

		# Triangle 1
		st.set_color(color1)
		st.add_vertex(v1)
		st.set_color(color2)
		st.add_vertex(v3)
		st.set_color(color1)
		st.add_vertex(v2)

		# Triangle 2
		st.set_color(color1)
		st.add_vertex(v2)
		st.set_color(color2)
		st.add_vertex(v3)
		st.set_color(color2)
		st.add_vertex(v4)

	mesh_instance.mesh = st.commit()

# Set custom color for different effects
func set_trail_color(color: Color, intensity: float = 2.0) -> void:
	trail_color = color
	glow_intensity = intensity
	if mesh_instance and mesh_instance.material_override:
		var mat = mesh_instance.material_override as StandardMaterial3D
		mat.emission = color
		mat.emission_energy_multiplier = intensity
