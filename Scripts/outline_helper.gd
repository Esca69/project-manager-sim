extends Node

# Outline helper — autoload utility for showing/hiding a white outline
# on interactive objects when the player is nearby.
#
# Usage: OutlineHelper.set_outline(node, true/false)
#
# Approach: creates a duplicate Sprite2D child behind the original sprite
# with a slightly larger scale and a solid-color shader. This avoids the
# UV-space clipping problem of the previous shader-only approach.

const OUTLINE_SHADER_PATH: String = "res://Resources/outline.gdshader"
# Scale multiplier for the outline copy — increase to make outline thicker
const OUTLINE_SCALE_MULTIPLIER: float = 1.06

var _outline_shader: Shader = null

func _get_shader() -> Shader:
	if _outline_shader == null:
		_outline_shader = load(OUTLINE_SHADER_PATH)
	return _outline_shader

# Main public API — call this from player.gd
func set_outline(node: Node, enabled: bool) -> void:
	var sprite := _find_sprite(node)
	if sprite == null:
		return

	if enabled:
		_show_outline_copy(sprite)
	else:
		_hide_outline_copy(sprite)

func _show_outline_copy(sprite: Sprite2D) -> void:
	var outline_copy: Sprite2D
	if sprite.has_meta("_outline_sprite"):
		outline_copy = sprite.get_meta("_outline_sprite")
		if not is_instance_valid(outline_copy):
			outline_copy = null

	if outline_copy == null:
		outline_copy = Sprite2D.new()
		outline_copy.scale = Vector2.ONE * OUTLINE_SCALE_MULTIPLIER
		outline_copy.z_index = -1
		outline_copy.visible = false

		var mat := ShaderMaterial.new()
		mat.shader = _get_shader()
		mat.set_shader_parameter("outline_color", Color.WHITE)
		outline_copy.material = mat

		sprite.add_child(outline_copy)
		sprite.set_meta("_outline_sprite", outline_copy)

	_sync_outline_properties(outline_copy, sprite)
	outline_copy.visible = true

func _sync_outline_properties(outline_copy: Sprite2D, sprite: Sprite2D) -> void:
	outline_copy.texture = sprite.texture
	outline_copy.hframes = sprite.hframes
	outline_copy.vframes = sprite.vframes
	outline_copy.frame = sprite.frame
	outline_copy.centered = sprite.centered
	outline_copy.offset = sprite.offset
	# Compensate position so that scaling happens from the visual center of the
	# sprite rather than from the node origin. Without this, a sprite with a
	# large offset gets a thick outline on the far side and almost none on the
	# near side (because scale expands proportionally from the origin).
	var scale_diff: float = OUTLINE_SCALE_MULTIPLIER - 1.0
	outline_copy.position = -sprite.offset * scale_diff

func _hide_outline_copy(sprite: Sprite2D) -> void:
	if sprite.has_meta("_outline_sprite"):
		var outline_copy = sprite.get_meta("_outline_sprite")
		if is_instance_valid(outline_copy):
			outline_copy.visible = false

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
