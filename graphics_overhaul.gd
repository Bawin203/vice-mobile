extends Node

func _ready():
	call_deferred("apply_nextgen_graphics")

func apply_nextgen_graphics():
	var main = get_tree().current_scene
	if main == null:
		return

	# Sleek semi-wet asphalt using Mobile-compatible metallic/specular sky & light reflections
	var ground_mesh = main.get_node_or_null("Ground/MeshInstance3D")
	if ground_mesh and ground_mesh.mesh:
		var road_mat = StandardMaterial3D.new()
		road_mat.albedo_color = Color(0.11, 0.13, 0.16)
		road_mat.roughness = 0.22
		road_mat.metallic = 0.35
		road_mat.metallic_specular = 0.85
		ground_mesh.material_override = road_mat

	var we = main.get_node_or_null("WorldEnvironment")
	if we and we.environment:
		var env: Environment = we.environment
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.12
		env.tonemap_white = 6.0

		# Bloom / Glow for neon signs, headlights, sirens & tracers (fully supported on Mobile renderer)
		env.glow_enabled = true
		env.glow_intensity = 0.75
		env.glow_strength = 0.95
		env.glow_bloom = 0.18
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

		# Disable Forward+-only passes so Mobile renderer logs zero warnings
		env.ssr_enabled = false
		env.ssao_enabled = false

		# Soft Miami / Leonida coastal horizon haze
		env.fog_enabled = true
		env.fog_light_color = Color(0.55, 0.68, 0.85)
		env.fog_density = 0.0022
		env.fog_sky_affect = 0.45

	var sun = main.get_node_or_null("DirectionalLight3D")
	if sun:
		sun.shadow_enabled = true
		sun.shadow_blur = 1.0
		sun.light_energy = 1.35
