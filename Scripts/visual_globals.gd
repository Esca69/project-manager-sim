class_name VisualGlobals

const CLOTHING_PALETTE: Array[Color] = [
	Color("#FFADAD"), Color("#FFD6A5"), Color("#FDFFB6"), Color("#CAFFBF"),
	Color("#9BF6FF"), Color("#A0C4FF"), Color("#BDB2FF"), Color("#FFC6FF"),
	Color("#F15BB5"), Color("#FEE440"), Color("#00BBF9"), Color("#00F5D4"),
	Color("#8A2BE2"), Color("#FF9F1C"), Color("#2EC4B6"), Color("#E71D36"),
	Color("#9C89B8"), Color("#F0A6CA"), Color("#B8BEDD"), Color("#99E2B4")
]

const SKIN_LIGHT: Array[Color] = [
	Color("#FFE0BD"), Color("#FFCD94"), Color("#fff0e1")
]

const SKIN_MEDIUM: Array[Color] = [
	Color("#FFAD60"), Color("#CB8E63"), Color("#C68642"), Color("#8D5524")
]

const SKIN_DARK: Array[Color] = [
	Color("#61412A"), Color("#4A2E1B"), Color("#311A0E")
]

# Объединённый плоский массив для карусели кастомизации (10 цветов)
const ALL_SKIN_COLORS: Array[Color] = [
	# SKIN_LIGHT
	Color("#FFE0BD"), Color("#FFCD94"), Color("#fff0e1"),
	# SKIN_MEDIUM
	Color("#FFAD60"), Color("#CB8E63"), Color("#C68642"), Color("#8D5524"),
	# SKIN_DARK
	Color("#61412A"), Color("#4A2E1B"), Color("#311A0E")
]

const HAIR_PALETTE: Array[Color] = [
	Color("#F5DEB3"),  # Блонд
	Color("#C8A882"),  # Русый
	Color("#C45232"),  # Рыжий
	Color("#6B3A2A"),  # Коричневый
	Color("#1A1A1A"),  # Чёрный
]

const HAIR_OFFSET_X: float = 0.0
const HAIR_OFFSET_Y: float = -19.0

const MALE_HAIR_PATHS: Array[String] = [
	"res://Sprites/hairs/man_hair1.png",
	"res://Sprites/hairs/man_hair2.png",
	"res://Sprites/hairs/man_hair3.png",
]

const FEMALE_HAIR_PATHS: Array[String] = [
	"res://Sprites/hairs/woman_hair1.png",
	"res://Sprites/hairs/woman_hair2.png",
	"res://Sprites/hairs/woman_hair3.png",
]

const DEFAULT_BODY_PATH: String = "res://Sprites/body2.png"
const DEFAULT_BODY_WIDTH: int = 79

const MALE_BODY_PATHS: Dictionary = {
	"man_fat": "res://Sprites/bodies/man_fat.png",
	"man_fit": "res://Sprites/bodies/man_fit.png",
	"man_skinny": "res://Sprites/bodies/man_skinny.png",
}

const FEMALE_BODY_PATHS: Dictionary = {
	"woman_fat": "res://Sprites/bodies/woman_fat.png",
	"woman_fit": "res://Sprites/bodies/woman_fit.png",
	"woman_skinny": "res://Sprites/bodies/woman_skinny.png",
}
