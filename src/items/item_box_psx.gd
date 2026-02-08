extends Node
## ItemBoxPSX - Applies PSX-style texture to item box and adds visual effects

@onready var item_box: Area3D = get_parent()
@onready var mesh_instance: MeshInstance3D = get_parent().get_node("MeshInstance3D")
@onready var light: OmniLight3D = get_parent().get_node("OmniLight3D")

var bob_time: float = 0.0
var rotation_speed: float = 1.5
var bob_speed: float = 2.0
var bob_height: float = 0.15
var base_y: float = 0.7
var pulse_time: float = 0.0

func _ready() -> void:
	# Apply PSX texture
	_apply_item_box_texture()

func _process(delta: float) -> void:
	if not is_instance_valid(mesh_instance):
		return

	# Rotate the box
	mesh_instance.rotation.y += rotation_speed * delta

	# Bob up and down
	bob_time += delta * bob_speed
	var bob_offset := sin(bob_time) * bob_height
	mesh_instance.position.y = base_y + bob_offset

	# Pulse the light
	pulse_time += delta * 3.0
	if light:
		light.light_energy = 1.0 + sin(pulse_time) * 0.4
		light.position.y = base_y + bob_offset

func _apply_item_box_texture() -> void:
	if not mesh_instance:
		return

	var texture := PSXTextures.create_item_box_texture()
	var mat := mesh_instance.get_surface_override_material(0)

	if mat is ShaderMaterial:
		mat.set_shader_parameter("albedo", texture)
	else:
		var psx_shader := load("res://assets/shaders/PSXMaterial.gdshader")
		if psx_shader:
			var new_mat := ShaderMaterial.new()
			new_mat.shader = psx_shader
			new_mat.set_shader_parameter("albedo", texture)
			new_mat.set_shader_parameter("affine_mapping", true)
			new_mat.set_shader_parameter("jitter", 0.35)
			new_mat.set_shader_parameter("resolution", Vector2i(320, 240))
			mesh_instance.set_surface_override_material(0, new_mat)
