@tool
extends EditorScript
## PSXTextureGenerator - Run this in the editor to generate static PNG textures

const TEX_SIZE := 64

func _run() -> void:
	print("Generating PSX textures...")

	_save_texture(_create_floor_image(), "res://assets/textures/psx_floor.png")
	_save_texture(_create_wall_image(), "res://assets/textures/psx_wall.png")
	_save_texture(_create_pillar_image(), "res://assets/textures/psx_pillar.png")
	_save_texture(_create_platform_image(), "res://assets/textures/psx_platform.png")
	_save_texture(_create_wall_run_image(), "res://assets/textures/psx_wallrun.png")
	_save_texture(_create_item_box_image(), "res://assets/textures/psx_itembox.png")
	_save_texture(_create_ramp_image(), "res://assets/textures/psx_ramp.png")

	print("PSX textures generated successfully!")

func _save_texture(img: Image, path: String) -> void:
	var err := img.save_png(path)
	if err != OK:
		print("Failed to save: ", path)
	else:
		print("Saved: ", path)

func _create_floor_image() -> Image:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base_color := Color(0.25, 0.22, 0.28)
	var highlight := Color(0.35, 0.32, 0.38)
	var shadow := Color(0.15, 0.12, 0.18)

	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var tile_x: int = x % 16
			var tile_y: int = y % 16
			var color := base_color

			if tile_x == 0 or tile_y == 0:
				color = shadow
			elif tile_x == 15 or tile_y == 15:
				color = highlight
			else:
				var noise: float = float((x * 7 + y * 13) % 20 - 10) / 255.0
				color = Color(base_color.r + noise, base_color.g + noise, base_color.b + noise)

			img.set_pixel(x, y, color)

	return img

func _create_wall_image() -> Image:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base_color := Color(0.35, 0.28, 0.25)
	var mortar := Color(0.2, 0.18, 0.16)
	var highlight := Color(0.45, 0.38, 0.35)

	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var brick_h: int = 8
			var brick_w: int = 16
			var row: int = y / brick_h
			var offset: int = (row % 2) * (brick_w / 2)
			var bx: int = (x + offset) % brick_w
			var by: int = y % brick_h

			var color := base_color

			if by == 0 or bx == 0:
				color = mortar
			elif by == brick_h - 1:
				color = highlight.lerp(base_color, 0.5)
			elif bx == brick_w - 1:
				color = highlight.lerp(base_color, 0.7)
			else:
				var brick_id: int = (row * 4 + (x + offset) / brick_w) % 7
				var variation: float = (brick_id * 0.03) - 0.09
				color = Color(base_color.r + variation, base_color.g + variation * 0.8, base_color.b + variation * 0.6)

			img.set_pixel(x, y, color)

	return img

func _create_pillar_image() -> Image:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base_color := Color(0.4, 0.38, 0.42)
	var dark := Color(0.25, 0.23, 0.27)
	var light := Color(0.55, 0.53, 0.57)

	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var block_h: int = 12
			var by: int = y % block_h

			var color := base_color

			if by == 0:
				color = dark
			elif by == block_h - 1:
				color = light.lerp(base_color, 0.6)
			else:
				var center_dist: float = float(abs(x - TEX_SIZE / 2)) / float(TEX_SIZE / 2)
				color = base_color.lerp(dark, center_dist * 0.5)
				var noise: float = float((x * 3 + y * 7) % 10 - 5) / 255.0
				color = Color(color.r + noise, color.g + noise, color.b + noise)

			img.set_pixel(x, y, color)

	return img

func _create_platform_image() -> Image:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base_color := Color(0.3, 0.32, 0.4)
	var rust := Color(0.4, 0.25, 0.2)
	var highlight := Color(0.5, 0.52, 0.6)
	var dark := Color(0.15, 0.16, 0.2)

	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var color := base_color

			if x < 2 or y < 2:
				color = highlight
			elif x > TEX_SIZE - 3 or y > TEX_SIZE - 3:
				color = dark
			else:
				var px: int = (x + y) % 8
				var py: int = abs(x - y) % 8
				if px < 2 and py < 2:
					color = highlight.lerp(base_color, 0.5)
				else:
					var rust_noise: int = ((x * 7 + y * 13) % 23)
					if rust_noise < 3:
						color = base_color.lerp(rust, 0.3)
					else:
						var noise: float = float((x * 5 + y * 11) % 15 - 7) / 255.0
						color = Color(base_color.r + noise, base_color.g + noise, base_color.b + noise)

			img.set_pixel(x, y, color)

	return img

func _create_wall_run_image() -> Image:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base_color := Color(0.28, 0.35, 0.32)
	var stripe := Color(0.8, 0.6, 0.1)
	var dark := Color(0.18, 0.22, 0.2)

	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var color := base_color

			if y < 8:
				var stripe_pos: int = (x + y) % 16
				if stripe_pos < 8:
					color = stripe
				else:
					color = dark
			else:
				var noise: float = float((x * 7 + y * 11) % 20 - 10) / 255.0
				color = Color(base_color.r + noise, base_color.g + noise, base_color.b + noise)
				if (x * 3 + y * 7) % 47 == 0:
					color = dark

			img.set_pixel(x, y, color)

	return img

func _create_item_box_image() -> Image:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var gold := Color(1.0, 0.85, 0.2)
	var dark_gold := Color(0.7, 0.55, 0.1)
	var bright := Color(1.0, 0.95, 0.6)
	var outline := Color(0.4, 0.3, 0.05)

	var center_x: int = TEX_SIZE / 2
	var center_y: int = TEX_SIZE / 2

	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var color := gold

			if x < 3 or y < 3 or x > TEX_SIZE - 4 or y > TEX_SIZE - 4:
				if x < 2 or y < 2:
					color = bright
				else:
					color = outline
			else:
				var dist: float = sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
				var t: float = dist / (TEX_SIZE * 0.5)
				color = bright.lerp(dark_gold, t)

				var qx: int = x - center_x
				var qy: int = y - center_y
				var in_question := false

				if qy >= -18 and qy <= -8:
					var curve_x: float = sin((qy + 18) * PI / 10.0) * 8
					if abs(qx - curve_x) < 4:
						in_question = true
				if qy >= 10 and qy <= 16 and abs(qx) < 4:
					in_question = true
				if qy >= -8 and qy <= 4 and abs(qx) < 3:
					in_question = true

				if in_question:
					color = outline

			img.set_pixel(x, y, color)

	return img

func _create_ramp_image() -> Image:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var base := Color(0.35, 0.3, 0.28)
	var grip := Color(0.25, 0.22, 0.2)
	var edge := Color(0.5, 0.45, 0.4)

	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			var color := base

			if y % 6 < 2:
				color = grip
			elif y % 6 == 2:
				color = edge
			else:
				var noise: float = float((x * 5 + y * 9) % 12 - 6) / 255.0
				color = Color(base.r + noise, base.g + noise, base.b + noise)

			if x < 4 or x > TEX_SIZE - 5:
				color = Color(0.6, 0.55, 0.2)

			img.set_pixel(x, y, color)

	return img
