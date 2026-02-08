extends Node
## PSXArenaSetup - Applies static PSX-style textures to arena at runtime
## Uses StandardMaterial3D for stable, non-warping textures with proper tiling

func _ready() -> void:
	# Wait for arena to be fully loaded
	await get_tree().process_frame
	_apply_psx_textures()

func _apply_psx_textures() -> void:
	var arena := get_parent()

	# Apply floor texture
	var floor_node := arena.get_node_or_null("Floor/MeshInstance3D")
	if floor_node:
		_apply_static_texture(floor_node, PSXTextures.create_floor_texture(), Vector2(8, 8))

	# Apply wall textures
	var walls := arena.get_node_or_null("Walls")
	if walls:
		for wall in walls.get_children():
			var mesh := wall.get_node_or_null("MeshInstance3D")
			if mesh:
				_apply_static_texture(mesh, PSXTextures.create_wall_texture(), Vector2(8, 2))

	# Apply pillar textures
	var pillars := arena.get_node_or_null("Pillars")
	if pillars:
		for pillar in pillars.get_children():
			var mesh := pillar.get_node_or_null("MeshInstance3D")
			if mesh:
				_apply_static_texture(mesh, PSXTextures.create_pillar_texture(), Vector2(1, 2))

	# Apply platform textures
	var platforms := arena.get_node_or_null("Platforms")
	if platforms:
		for platform in platforms.get_children():
			var mesh := platform.get_node_or_null("MeshInstance3D")
			if mesh:
				# Scale UV based on platform size
				var uv_scale := Vector2(2, 2)
				if "Large" in platform.name:
					uv_scale = Vector2(3, 3)
				elif "Small" in platform.name or "Floating" in platform.name:
					uv_scale = Vector2(1, 1)
				_apply_static_texture(mesh, PSXTextures.create_platform_texture(), uv_scale)

	# Apply ramp textures
	var ramps := arena.get_node_or_null("Ramps")
	if ramps:
		for ramp in ramps.get_children():
			var mesh := ramp.get_node_or_null("MeshInstance3D")
			if mesh:
				_apply_static_texture(mesh, PSXTextures.create_ramp_texture(), Vector2(1, 2))

	# Apply wall run surface textures
	var wall_run := arena.get_node_or_null("WallRunSurfaces")
	if wall_run:
		for surface in wall_run.get_children():
			var mesh := surface.get_node_or_null("MeshInstance3D")
			if mesh:
				_apply_static_texture(mesh, PSXTextures.create_wall_run_texture(), Vector2(2, 2))

func _apply_static_texture(mesh_instance: MeshInstance3D, texture: ImageTexture, uv_scale: Vector2 = Vector2(1, 1)) -> void:
	# Create StandardMaterial3D for stable, non-warping textures
	var mat := StandardMaterial3D.new()

	# Set texture with nearest filtering for PSX look
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# UV tiling to prevent stretching on large surfaces
	mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)

	# PSX-style flat shading
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX

	# No specular for matte PSX look
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	# Disable metallic/roughness for flat look
	mat.metallic = 0.0
	mat.roughness = 1.0

	mesh_instance.set_surface_override_material(0, mat)
