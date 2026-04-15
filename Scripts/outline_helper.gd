extends Node

# Outline helper — autoload utility for showing/hiding a white outline
# on interactive objects when the player is nearby.
#
# Usage: OutlineHelper.set_outline(node, true/false)
#
# Supports:
#   - Nodes with $Sprite2D child (desks)
#   - Nodes with a body_sprite property (NPCs)
#   - Objects that already have a ShaderMaterial (volume shader on NPCs):
#     outline is chained via next_pass so both effects coexist
#
# Materials are cached on the sprite node so they are created only once and
# toggled via the outline_enabled shader parameter on subsequent calls.

const OUTLINE_SHADER_PATH: String = "res://Resources/outline.gdshader"
const OUTLINE_WIDTH: float = 2.0

var _outline_shader: Shader = null

func _get_shader() -> Shader:
	if _outline_shader == null:
		_outline_shader = load(OUTLINE_SHADER_PATH)
	return _outline_shader

func _create_outline_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_shader()
	mat.set_shader_parameter("outline_enabled", true)
	mat.set_shader_parameter("outline_color", Color.WHITE)
	mat.set_shader_parameter("outline_width", OUTLINE_WIDTH)
	return mat

# Main public API — call this from player.gd
func set_outline(node: Node, enabled: bool) -> void:
	var sprite := _find_sprite(node)
	if sprite == null:
		return

	# Reuse an already-attached outline material if present (just toggle the uniform)
	var existing := _find_existing_outline(sprite)

	if enabled:
		if existing != null:
			existing.set_shader_parameter("outline_enabled", true)
		elif sprite.material == null:
			# No existing material — apply outline shader directly
			sprite.material = _create_outline_material()
		else:
			# Existing material (e.g. volume shader) — chain via next_pass
			sprite.material.next_pass = _create_outline_material()
	else:
		if existing != null:
			existing.set_shader_parameter("outline_enabled", false)

# Return the ShaderMaterial that holds our outline shader, if one is already
# attached either directly or via next_pass. Returns null if not found.
func _find_existing_outline(sprite: Sprite2D) -> ShaderMaterial:
	if sprite.material is ShaderMaterial and sprite.material.shader == _get_shader():
		return sprite.material
	if sprite.material != null and sprite.material.next_pass is ShaderMaterial \
			and sprite.material.next_pass.shader == _get_shader():
		return sprite.material.next_pass as ShaderMaterial
	return null

# Find the best Sprite2D target on a node:
#   1. body_sprite property (NPCs: employee, boss_npc)
#   2. Direct $Sprite2D child (desks)
#   3. Recursive search for the first Sprite2D descendant
func _find_sprite(node: Node) -> Sprite2D:
	if node == null:
		return null

	# NPCs expose body_sprite directly
	if "body_sprite" in node and node.body_sprite is Sprite2D:
		return node.body_sprite

	# Desks and most objects have a direct Sprite2D child
	var direct := node.get_node_or_null("Sprite2D")
	if direct is Sprite2D:
		return direct

	# Fallback: depth-first search
	return _find_sprite_recursive(node)

func _find_sprite_recursive(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
		var found := _find_sprite_recursive(child)
		if found != null:
			return found
	return null
