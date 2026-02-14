extends Node

# === ШРИФТЫ ===
var font_regular: FontVariation
var font_semibold: FontVariation
var font_bold: FontVariation

const FONT_PATH = "res://Fonts/Inter-VariableFont_opsz,wght.ttf"

# === АНИМАЦИИ ===
const FADE_DURATION = 0.2  # Секунд на появление/исчезновение

func _ready():
	var base_font = load(FONT_PATH) as FontFile
	if not base_font:
		push_warning("UITheme: Шрифт не найден по пути: " + FONT_PATH)
		return

	# Regular (weight 400)
	font_regular = FontVariation.new()
	font_regular.base_font = base_font
	font_regular.variation_opentype = {"wght": 400}

	# SemiBold (weight 600)
	font_semibold = FontVariation.new()
	font_semibold.base_font = base_font
	font_semibold.variation_opentype = {"wght": 600}

	# Bold (weight 700)
	font_bold = FontVariation.new()
	font_bold.base_font = base_font
	font_bold.variation_opentype = {"wght": 700}

	print("✅ UITheme: Шрифт Inter загружен (Regular, SemiBold, Bold)")

# === ПРИМЕНЕНИЕ ШРИФТА К НОДЕ ===
func apply_font(node: Control, weight: String = "regular"):
	if node == null:
		return
	var font = _get_font(weight)
	if font == null:
		return

	if node is Label:
		node.add_theme_font_override("font", font)
	elif node is Button:
		node.add_theme_font_override("font", font)
	elif node is LineEdit:
		node.add_theme_font_override("font", font)

func _get_font(weight: String) -> Font:
	match weight:
		"regular": return font_regular
		"semibold": return font_semibold
		"bold": return font_bold
	return font_regular

# === АНИМАЦИЯ FADE IN ===
func fade_in(node: Control, duration: float = FADE_DURATION):
	node.modulate.a = 0.0
	node.visible = true
	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT)

# === АНИМАЦИЯ FADE OUT ===
func fade_out(node: Control, duration: float = FADE_DURATION, hide_after: bool = true):
	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	if hide_after:
		tween.tween_callback(func(): node.visible = false)

# === ТЕНЬ ДЛЯ ПАНЕЛЕЙ ===
func apply_shadow(style: StyleBoxFlat, soft: bool = true):
	if soft:
		style.shadow_color = Color(0, 0, 0, 0.12)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 3)
	else:
		style.shadow_color = Color(0, 0, 0, 0.2)
		style.shadow_size = 12
		style.shadow_offset = Vector2(0, 4)

# === СОЗДАНИЕ СТИЛИЗОВАННОЙ ПАНЕЛИ С ТЕНЬЮ ===
func create_card_style(bg_color: Color = Color.WHITE, border_color: Color = Color(0.878, 0.878, 0.878), radius: int = 16) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	apply_shadow(style)
	return style
