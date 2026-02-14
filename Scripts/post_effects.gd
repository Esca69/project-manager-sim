extends Node

# === ПОСТ-ЭФФЕКТЫ (Мягкая виньетка) ===
# Рисуется НИЖЕ HUD (layer 0), поэтому UI не затрагивается.
# Затемняет только самые углы экрана.

var _canvas_layer: CanvasLayer = null
var _color_rect: ColorRect = null

# --- Настройки виньетки ---
const VIGNETTE_RADIUS = 0.65      # Где начинается затемнение (от центра)
const VIGNETTE_SOFTNESS = 0.25    # Мягкость перехода
const VIGNETTE_STRENGTH = 0.25     # Сила затемнения (слабая)

func setup(scene_root: Node):
	# layer = 0 — между игрой и HUD (HUD = CanvasLayer layer 1)
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "PostEffectsLayer"
	_canvas_layer.layer = 0
	scene_root.add_child(_canvas_layer)

	# ColorRect на весь экран
	_color_rect = ColorRect.new()
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Шейдер-материал
	var shader = Shader.new()
	shader.code = _get_vignette_shader()

	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("vignette_radius", VIGNETTE_RADIUS)
	mat.set_shader_parameter("vignette_softness", VIGNETTE_SOFTNESS)
	mat.set_shader_parameter("vignette_strength", VIGNETTE_STRENGTH)

	_color_rect.material = mat
	_canvas_layer.add_child(_color_rect)

func _get_vignette_shader() -> String:
	return """
shader_type canvas_item;

uniform float vignette_radius : hint_range(0.0, 1.0) = 0.45;
uniform float vignette_softness : hint_range(0.01, 1.0) = 0.35;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	// UV — координаты от (0,0) до (1,1) по самому ColorRect
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);

	// Затемнение от центра к краям
	float vignette = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);

	COLOR = vec4(0.0, 0.0, 0.0, vignette * vignette_strength);
}
"""
