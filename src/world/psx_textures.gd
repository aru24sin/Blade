class_name PSXTextures
extends RefCounted
## PSXTextures - Generates PS1/PS2 style low-res textures procedurally

const TEX_SIZE := 64  # Classic PS1 texture resolution

static func create_floor_texture() -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base_color := Color(0.25, 0.22, 0.28)  # Dark purple-gray stone
	var highlight := Color(0.35, 0.32, 0.38)
	var shadow := Color(0.15, 0.12, 0.18)

	# Create tiled stone pattern
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var tile_x := x % 16
			var tile_y := y % 16
			var color := base_color

			# Tile borders (grout lines)
			if tile_x == 0 or tile_y == 0:
				color = shadow
			elif tile_x == 15 or tile_y == 15:
				color = highlight
			else:
				# Add noise/variation
				var noise := (randi() % 20 - 10) / 255.0
				color = Color(base_color.r + noise, base_color.g + noise, base_color.b + noise)

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

static func create_wall_texture() -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base_color := Color(0.35, 0.28, 0.25)  # Brownish brick
	var mortar := Color(0.2, 0.18, 0.16)
	var highlight := Color(0.45, 0.38, 0.35)

	# Brick pattern
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var brick_h := 8
			var brick_w := 16
			var row := y / brick_h
			var offset := (row % 2) * (brick_w / 2)
			var bx := (x + offset) % brick_w
			var by := y % brick_h

			var color := base_color

			# Mortar lines
			if by == 0 or bx == 0:
				color = mortar
			elif by == brick_h - 1:
				color = highlight.lerp(base_color, 0.5)
			elif bx == brick_w - 1:
				color = highlight.lerp(base_color, 0.7)
			else:
				# Brick variation
				var brick_id := (row * 4 + (x + offset) / brick_w) % 7
				var variation := (brick_id * 0.03) - 0.09
				color = Color(base_color.r + variation, base_color.g + variation * 0.8, base_color.b + variation * 0.6)

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

static func create_pillar_texture() -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base_color := Color(0.4, 0.38, 0.42)  # Gray stone
	var dark := Color(0.25, 0.23, 0.27)
	var light := Color(0.55, 0.53, 0.57)

	# Vertical stone blocks
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var block_h := 12
			var by := y % block_h
			var block_idx := y / block_h

			var color := base_color

			# Horizontal lines between blocks
			if by == 0:
				color = dark
			elif by == block_h - 1:
				color = light.lerp(base_color, 0.6)
			else:
				# Vertical shading for cylindrical look
				var center_dist: float = float(abs(x - TEX_SIZE / 2)) / float(TEX_SIZE / 2)
				color = base_color.lerp(dark, center_dist * 0.5)

				# Add noise
				var noise := (randi() % 10 - 5) / 255.0
				color = Color(color.r + noise, color.g + noise, color.b + noise)

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

static func create_platform_texture() -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base_color := Color(0.3, 0.32, 0.4)  # Blue-gray metal
	var rust := Color(0.4, 0.25, 0.2)
	var highlight := Color(0.5, 0.52, 0.6)
	var dark := Color(0.15, 0.16, 0.2)

	# Industrial metal plate with rivets
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var color := base_color

			# Edge bevels
			if x < 2 or y < 2:
				color = highlight
			elif x > TEX_SIZE - 3 or y > TEX_SIZE - 3:
				color = dark
			else:
				# Diamond plate pattern
				var px: int = (x + y) % 8
				var py: int = abs(x - y) % 8
				if px < 2 and py < 2:
					color = highlight.lerp(base_color, 0.5)
				else:
					# Add rust spots
					var rust_noise := ((x * 7 + y * 13) % 23)
					if rust_noise < 3:
						color = base_color.lerp(rust, 0.3)
					else:
						var noise := (randi() % 15 - 7) / 255.0
						color = Color(base_color.r + noise, base_color.g + noise, base_color.b + noise)

			# Corner rivets
			for ry in [6, TEX_SIZE - 8]:
				for rx in [6, TEX_SIZE - 8]:
					var dist := sqrt(pow(x - rx, 2) + pow(y - ry, 2))
					if dist < 3:
						color = dark if dist < 2 else highlight

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

static func create_wall_run_texture() -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base_color := Color(0.28, 0.35, 0.32)  # Greenish concrete
	var stripe := Color(0.8, 0.6, 0.1)  # Warning yellow
	var dark := Color(0.18, 0.22, 0.2)

	# Concrete with warning stripes
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var color := base_color

			# Warning stripe at top
			if y < 8:
				var stripe_pos := (x + y) % 16
				if stripe_pos < 8:
					color = stripe
				else:
					color = dark
			else:
				# Concrete texture
				var noise := (randi() % 20 - 10) / 255.0
				color = Color(base_color.r + noise, base_color.g + noise, base_color.b + noise)

				# Occasional cracks
				if (x * 3 + y * 7) % 47 == 0:
					color = dark

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

static func create_item_box_texture() -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var gold := Color(1.0, 0.85, 0.2)
	var dark_gold := Color(0.7, 0.55, 0.1)
	var bright := Color(1.0, 0.95, 0.6)
	var outline := Color(0.4, 0.3, 0.05)

	# Mysterious glowing box with question mark
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var color := gold

			# Border
			if x < 3 or y < 3 or x > TEX_SIZE - 4 or y > TEX_SIZE - 4:
				if x < 2 or y < 2:
					color = bright
				else:
					color = outline
			else:
				# Inner gradient
				var center_x := TEX_SIZE / 2
				var center_y := TEX_SIZE / 2
				var dist := sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
				var t := dist / (TEX_SIZE * 0.5)
				color = bright.lerp(dark_gold, t)

				# Question mark pattern
				var qx := x - center_x
				var qy := y - center_y
				var in_question := false

				# Top curve of ?
				if qy >= -18 and qy <= -8:
					var curve_x := sin((qy + 18) * PI / 10.0) * 8
					if abs(qx - curve_x) < 4:
						in_question = true
				# Dot of ?
				if qy >= 10 and qy <= 16 and abs(qx) < 4:
					in_question = true
				# Stem
				if qy >= -8 and qy <= 4 and abs(qx) < 3:
					in_question = true

				if in_question:
					color = outline

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

static func create_skybox_gradient() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var top := Color(0.05, 0.02, 0.1)  # Dark purple
	var mid := Color(0.15, 0.08, 0.2)  # Purple
	var horizon := Color(0.3, 0.15, 0.25)  # Pinkish

	for y in range(64):
		var t := y / 63.0
		var color: Color
		if t < 0.5:
			color = top.lerp(mid, t * 2)
		else:
			color = mid.lerp(horizon, (t - 0.5) * 2)

		# Add stars in upper portion
		for x in range(64):
			var final_color := color
			if t < 0.4 and (x * 7 + y * 13) % 37 == 0:
				final_color = color.lerp(Color.WHITE, 0.8)
			img.set_pixel(x, y, final_color)

	return ImageTexture.create_from_image(img)

static func create_ramp_texture() -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base := Color(0.35, 0.3, 0.28)
	var grip := Color(0.25, 0.22, 0.2)
	var edge := Color(0.5, 0.45, 0.4)

	# Non-slip ramp surface
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var color := base

			# Grip lines running across ramp
			if y % 6 < 2:
				color = grip
			elif y % 6 == 2:
				color = edge
			else:
				var noise := (randi() % 12 - 6) / 255.0
				color = Color(base.r + noise, base.g + noise, base.b + noise)

			# Side rails
			if x < 4 or x > TEX_SIZE - 5:
				color = Color(0.6, 0.55, 0.2)  # Yellow safety rail

			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)
