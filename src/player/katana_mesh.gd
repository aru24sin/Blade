class_name KatanaMesh
extends MeshInstance3D
## KatanaMesh - Sleek, impactful katana with dramatic proportions
## Designed for fast-paced combat with clear silhouette

func _ready() -> void:
	mesh = _create_katana_mesh()
	_apply_material()

func _create_katana_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Color palette - high contrast for visibility
	var blade_bright = Color(0.92, 0.94, 0.98)      # Bright steel highlight
	var blade_main = Color(0.78, 0.82, 0.88)        # Main blade color
	var blade_dark = Color(0.45, 0.50, 0.58)        # Shadow side
	var blade_edge = Color(1.0, 1.0, 1.0)           # Sharp edge (pure white)
	var hamon_color = Color(0.65, 0.68, 0.75)       # Hamon line hint
	var guard_color = Color(0.12, 0.10, 0.08)       # Dark iron tsuba
	var guard_accent = Color(0.25, 0.20, 0.15)      # Guard edge
	var wrap_primary = Color(0.7, 0.08, 0.05)       # Deep red wrap
	var wrap_secondary = Color(0.3, 0.03, 0.02)     # Dark red diamonds
	var handle_core = Color(0.05, 0.04, 0.03)       # Near black
	var brass_color = Color(0.75, 0.6, 0.25)        # Habaki brass

	# === BLADE - Longer, sleeker, more dramatic ===
	var blade_length = 1.6  # Longer blade for dramatic sweeps
	var blade_width = 0.028  # Thinner for elegance
	var blade_thick = 0.007  # Thin profile
	var curve_amount = 0.08  # Elegant curve

	var blade_segments = 8  # More segments for smoother curve
	var blade_verts: Array[Vector3] = []

	for i in range(blade_segments + 1):
		var t = float(i) / blade_segments
		var z = -blade_length * t

		# Elegant curve - more pronounced near tip
		var curve_t = pow(t, 0.8)
		var y_curve = sin(curve_t * PI * 0.55) * curve_amount

		# Taper - gradual then sharp at tip
		var taper = 1.0
		if t < 0.7:
			taper = 1.0 - t * 0.15
		else:
			var tip_t = (t - 0.7) / 0.3
			taper = 0.895 - tip_t * 0.85

		var w = blade_width * taper
		var h = blade_thick * max(taper, 0.3)

		# Diamond cross-section (shinogi-zukuri style)
		var spine_height = h * 1.2
		var edge_depth = h * 0.4
		blade_verts.append(Vector3(0, y_curve + spine_height, z))      # 0: Spine (top)
		blade_verts.append(Vector3(w, y_curve + h * 0.3, z))           # 1: Right shinogi
		blade_verts.append(Vector3(w * 0.7, y_curve - edge_depth, z))  # 2: Right edge
		blade_verts.append(Vector3(0, y_curve - edge_depth * 1.1, z))  # 3: Edge (bottom)
		blade_verts.append(Vector3(-w * 0.7, y_curve - edge_depth, z)) # 4: Left edge
		blade_verts.append(Vector3(-w, y_curve + h * 0.3, z))          # 5: Left shinogi

	# Create blade faces with proper shading
	for i in range(blade_segments):
		var base = i * 6
		var next = (i + 1) * 6
		var t = float(i) / blade_segments

		# Top right face (bright - catches light)
		st.set_color(blade_bright)
		_add_quad(st, blade_verts[base], blade_verts[base + 1], blade_verts[next + 1], blade_verts[next])

		# Right shinogi to edge (main blade color with hamon hint)
		var face_color = blade_main.lerp(hamon_color, 0.3) if t > 0.2 and t < 0.8 else blade_main
		st.set_color(face_color)
		_add_quad(st, blade_verts[base + 1], blade_verts[base + 2], blade_verts[next + 2], blade_verts[next + 1])

		# Right edge (sharp - white)
		st.set_color(blade_edge)
		_add_quad(st, blade_verts[base + 2], blade_verts[base + 3], blade_verts[next + 3], blade_verts[next + 2])

		# Left edge (sharp - slightly less bright)
		st.set_color(blade_edge.lerp(blade_bright, 0.2))
		_add_quad(st, blade_verts[base + 3], blade_verts[base + 4], blade_verts[next + 4], blade_verts[next + 3])

		# Left shinogi to edge (shadow side)
		st.set_color(blade_dark)
		_add_quad(st, blade_verts[base + 4], blade_verts[base + 5], blade_verts[next + 5], blade_verts[next + 4])

		# Top left face (shadow)
		st.set_color(blade_dark.lerp(blade_main, 0.3))
		_add_quad(st, blade_verts[base + 5], blade_verts[base], blade_verts[next], blade_verts[next + 5])

	# Blade tip - sharp point
	var tip = blade_segments * 6
	st.set_color(blade_edge)
	var tip_point = Vector3(0, blade_verts[tip].y, blade_verts[tip].z - 0.02)
	for j in range(6):
		var j_next = (j + 1) % 6
		st.add_vertex(blade_verts[tip + j])
		st.add_vertex(tip_point)
		st.add_vertex(blade_verts[tip + j_next])

	# === HABAKI (blade collar) - elegant brass ===
	st.set_color(brass_color)
	_add_tapered_box(st, Vector3(0, 0, 0.012), Vector3(0.034, 0.014, 0.025), Vector3(0.038, 0.016, 0.025))

	# === TSUBA (guard) - elegant oval with subtle detail ===
	st.set_color(guard_color)
	_add_oval_guard(st, Vector3(0, 0, 0.038), 0.058, 0.048, 0.006)

	# Guard accent ring
	st.set_color(guard_accent)
	_add_guard_ring(st, Vector3(0, 0, 0.038), 0.05, 0.042, 0.007)

	# === HANDLE (Tsuka) - traditional wrap pattern ===
	var handle_start = 0.048
	var handle_len = 0.32
	var handle_segments = 12

	for i in range(handle_segments):
		var t = float(i) / handle_segments
		var z1 = handle_start + t * handle_len
		var z2 = handle_start + (t + 1.0 / handle_segments) * handle_len
		var mid_z = (z1 + z2) / 2

		# Traditional wrap pattern - diagonal
		var is_wrap = (i % 3) != 2
		var wrap_color = wrap_primary if is_wrap else wrap_secondary

		# Handle tapers toward pommel
		var taper = 1.0 - pow(abs(t - 0.45), 2) * 0.2
		var width = 0.020 * taper
		var height = 0.016 * taper

		st.set_color(wrap_color)
		_add_handle_segment(st, Vector3(0, 0, mid_z), width, height, (z2 - z1))

		# Add subtle menuki (ornament) at grip points
		if i == 4 or i == 8:
			st.set_color(brass_color.darkened(0.2))
			_add_box(st, Vector3(0.018, 0, mid_z), Vector3(0.008, 0.006, 0.015))

	# === KASHIRA (pommel) - clean cap ===
	st.set_color(handle_core)
	_add_pommel(st, Vector3(0, 0, handle_start + handle_len + 0.015), 0.022, 0.018, 0.028)

	# Pommel cap accent
	st.set_color(guard_color)
	_add_box(st, Vector3(0, 0, handle_start + handle_len + 0.028), Vector3(0.018, 0.014, 0.004))

	st.generate_normals()
	return st.commit()

func _add_tapered_box(st: SurfaceTool, center: Vector3, size_front: Vector3, size_back: Vector3) -> void:
	var hxf = size_front.x / 2
	var hyf = size_front.y / 2
	var hxb = size_back.x / 2
	var hyb = size_back.y / 2
	var hz = size_front.z / 2

	var verts = [
		center + Vector3(-hxf, hyf, -hz),  center + Vector3(hxf, hyf, -hz),
		center + Vector3(hxf, -hyf, -hz),  center + Vector3(-hxf, -hyf, -hz),
		center + Vector3(-hxb, hyb, hz),   center + Vector3(hxb, hyb, hz),
		center + Vector3(hxb, -hyb, hz),   center + Vector3(-hxb, -hyb, hz),
	]

	_add_quad(st, verts[0], verts[1], verts[2], verts[3])
	_add_quad(st, verts[5], verts[4], verts[7], verts[6])
	_add_quad(st, verts[4], verts[5], verts[1], verts[0])
	_add_quad(st, verts[3], verts[2], verts[6], verts[7])
	_add_quad(st, verts[1], verts[5], verts[6], verts[2])
	_add_quad(st, verts[4], verts[0], verts[3], verts[7])

func _add_oval_guard(st: SurfaceTool, center: Vector3, rx: float, ry: float, thickness: float) -> void:
	var segs = 12
	var half_t = thickness / 2

	# Front face
	for i in range(segs):
		var a1 = float(i) / segs * TAU
		var a2 = float(i + 1) / segs * TAU
		st.add_vertex(center + Vector3(0, 0, -half_t))
		st.add_vertex(center + Vector3(cos(a1) * rx, sin(a1) * ry, -half_t))
		st.add_vertex(center + Vector3(cos(a2) * rx, sin(a2) * ry, -half_t))

	# Back face
	for i in range(segs):
		var a1 = float(i) / segs * TAU
		var a2 = float(i + 1) / segs * TAU
		st.add_vertex(center + Vector3(0, 0, half_t))
		st.add_vertex(center + Vector3(cos(a2) * rx, sin(a2) * ry, half_t))
		st.add_vertex(center + Vector3(cos(a1) * rx, sin(a1) * ry, half_t))

	# Edge
	for i in range(segs):
		var a1 = float(i) / segs * TAU
		var a2 = float(i + 1) / segs * TAU
		_add_quad(st,
			center + Vector3(cos(a1) * rx, sin(a1) * ry, -half_t),
			center + Vector3(cos(a1) * rx, sin(a1) * ry, half_t),
			center + Vector3(cos(a2) * rx, sin(a2) * ry, half_t),
			center + Vector3(cos(a2) * rx, sin(a2) * ry, -half_t))

func _add_guard_ring(st: SurfaceTool, center: Vector3, rx_outer: float, rx_inner: float, thickness: float) -> void:
	var segs = 12
	var ry_outer = rx_outer * 0.82
	var ry_inner = rx_inner * 0.82

	for i in range(segs):
		var a1 = float(i) / segs * TAU
		var a2 = float(i + 1) / segs * TAU

		var outer1 = center + Vector3(cos(a1) * rx_outer, sin(a1) * ry_outer, 0)
		var outer2 = center + Vector3(cos(a2) * rx_outer, sin(a2) * ry_outer, 0)
		var inner1 = center + Vector3(cos(a1) * rx_inner, sin(a1) * ry_inner, 0)
		var inner2 = center + Vector3(cos(a2) * rx_inner, sin(a2) * ry_inner, 0)

		# Top face of ring
		_add_quad(st, inner1, outer1, outer2, inner2)

func _add_handle_segment(st: SurfaceTool, center: Vector3, width: float, height: float, length: float) -> void:
	# Octagonal cross-section for handle
	var segs = 8
	var half_l = length / 2

	var front_verts: Array[Vector3] = []
	var back_verts: Array[Vector3] = []

	for i in range(segs):
		var angle = float(i) / segs * TAU + PI / 8
		var x = cos(angle) * width
		var y = sin(angle) * height
		front_verts.append(center + Vector3(x, y, -half_l))
		back_verts.append(center + Vector3(x, y, half_l))

	# Side faces
	for i in range(segs):
		var i_next = (i + 1) % segs
		_add_quad(st, front_verts[i], back_verts[i], back_verts[i_next], front_verts[i_next])

func _add_pommel(st: SurfaceTool, center: Vector3, width: float, height: float, length: float) -> void:
	# Rounded pommel cap
	var segs = 8
	var half_l = length / 2

	var front_verts: Array[Vector3] = []
	var back_verts: Array[Vector3] = []

	for i in range(segs):
		var angle = float(i) / segs * TAU
		var x = cos(angle) * width
		var y = sin(angle) * height
		front_verts.append(center + Vector3(x, y, -half_l))
		back_verts.append(center + Vector3(x * 0.7, y * 0.7, half_l))

	# Side faces
	for i in range(segs):
		var i_next = (i + 1) % segs
		_add_quad(st, front_verts[i], back_verts[i], back_verts[i_next], front_verts[i_next])

	# Back cap
	for i in range(segs):
		var i_next = (i + 1) % segs
		st.add_vertex(center + Vector3(0, 0, half_l))
		st.add_vertex(back_verts[i_next])
		st.add_vertex(back_verts[i])

func _add_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var hx = size.x / 2
	var hy = size.y / 2
	var hz = size.z / 2

	var verts = [
		center + Vector3(-hx, hy, -hz),  center + Vector3(hx, hy, -hz),
		center + Vector3(hx, -hy, -hz),  center + Vector3(-hx, -hy, -hz),
		center + Vector3(-hx, hy, hz),   center + Vector3(hx, hy, hz),
		center + Vector3(hx, -hy, hz),   center + Vector3(-hx, -hy, hz),
	]

	_add_quad(st, verts[0], verts[1], verts[2], verts[3])
	_add_quad(st, verts[5], verts[4], verts[7], verts[6])
	_add_quad(st, verts[4], verts[5], verts[1], verts[0])
	_add_quad(st, verts[3], verts[2], verts[6], verts[7])
	_add_quad(st, verts[1], verts[5], verts[6], verts[2])
	_add_quad(st, verts[4], verts[0], verts[3], verts[7])

func _add_quad(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3) -> void:
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)
	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v4)

func _apply_material() -> void:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# Semi-unshaded for retro feel but with some depth
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.metallic = 0.3
	mat.roughness = 0.7
	# Subtle emission for blade edge visibility
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.15, 0.18)
	mat.emission_energy_multiplier = 0.3
	material_override = mat
