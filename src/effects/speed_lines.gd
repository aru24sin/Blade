class_name SpeedLines
extends Node3D
## SpeedLines - PSX-style speed line effect for high velocity movement

@export var line_count: int = 20
@export var min_speed_threshold: float = 25.0
@export var max_speed_for_full: float = 50.0
@export var line_length: float = 2.0
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.4)

var mesh_instance: MeshInstance3D
var lines: Array[Dictionary] = []
var current_intensity: float = 0.0
var target_intensity: float = 0.0

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

	# Pre-generate line positions
	for i in range(line_count):
		lines.append({
			"angle": randf() * TAU,
			"radius": randf_range(0.3, 1.0),
			"z_offset": randf_range(-1.0, 0.5),
			"length_mult": randf_range(0.5, 1.5),
			"phase": randf() * TAU
		})

func _process(delta: float) -> void:
	# Smooth intensity transition
	current_intensity = lerp(current_intensity, target_intensity, 10.0 * delta)

	if current_intensity < 0.01:
		mesh_instance.mesh = null
		return

	_rebuild_mesh()

func set_speed(speed: float) -> void:
	if speed < min_speed_threshold:
		target_intensity = 0.0
	else:
		target_intensity = clamp(
			(speed - min_speed_threshold) / (max_speed_for_full - min_speed_threshold),
			0.0,
			1.0
		)

func _rebuild_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	var time = Time.get_ticks_msec() / 1000.0

	for line in lines:
		var angle = line.angle
		var radius = line.radius

		# Animate lines inward
		var z = fmod(line.z_offset + time * 3.0, 2.5) - 1.5

		# Screen-space-ish positioning
		var x = cos(angle) * radius
		var y = sin(angle) * radius

		var start = Vector3(x, y, z)
		var length = line_length * line.length_mult * current_intensity
		var end_point = Vector3(x, y, z - length)

		# PSX dithered alpha
		var alpha = line_color.a * current_intensity
		alpha *= 1.0 - abs(z) * 0.5  # Fade at edges
		var color = Color(line_color.r, line_color.g, line_color.b, alpha)

		st.set_color(color)
		st.add_vertex(start)
		st.set_color(Color(color.r, color.g, color.b, alpha * 0.3))
		st.add_vertex(end_point)

	mesh_instance.mesh = st.commit()
