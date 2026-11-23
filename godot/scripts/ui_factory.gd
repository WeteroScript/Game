## Мелкие помощники для сборки интерфейса из кода (аналог UiFactory.cs).
class_name UiFactory
extends RefCounted

const TEXT_COLOR := Color(1.0, 1.0, 1.0)
const MUTED_COLOR := Color(0.72, 0.76, 0.82)
const ACCENT_COLOR := Color(1.0, 0.62, 0.15)
const PANEL_COLOR := Color(0.03, 0.04, 0.06, 0.72)


static func label(text: String, size: int, color := TEXT_COLOR, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	node.add_theme_constant_override("shadow_offset_x", 2)
	node.add_theme_constant_override("shadow_offset_y", 2)
	return node


static func panel(color := PANEL_COLOR) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	return rect


static func stylebox(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


## Перекрашивает кнопку: обычная или выбранная (акцентная рамка и фон).
static func style_button(node: Button, selected := false) -> void:
	var base_color := Color(1.0, 0.55, 0.12, 0.92) if selected else Color(0.09, 0.11, 0.15, 0.86)
	var border := ACCENT_COLOR if selected else Color(1.0, 1.0, 1.0, 0.16)
	var normal := stylebox(base_color, border)
	node.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base_color.lightened(0.08)
	node.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = base_color.darkened(0.25)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	node.add_theme_color_override("font_color", Color(0.06, 0.05, 0.04) if selected else TEXT_COLOR)
	node.add_theme_color_override("font_hover_color", Color(0.06, 0.05, 0.04) if selected else TEXT_COLOR)


static func button(text: String, size: int, min_size := Vector2(0.0, 46.0)) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = min_size
	node.add_theme_font_size_override("font_size", size)
	node.focus_mode = Control.FOCUS_NONE
	style_button(node, false)
	return node


## Главная кнопка экрана — яркая, чтобы её было видно с телефона.
static func primary_button(text: String, size: int, min_size := Vector2(0.0, 70.0)) -> Button:
	var node := button(text, size, min_size)
	var normal := stylebox(Color(1.0, 0.58, 0.12, 0.95), Color(1.0, 0.78, 0.42, 0.95), 16)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(1.0, 0.46, 0.05, 1.0)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02))
	node.add_theme_color_override("font_hover_color", Color(0.08, 0.05, 0.02))
	return node


## Плоская полупрозрачная кнопка для экранного геймпада.
static func touch_button(text: String, size: int) -> Button:
	var node := button(text, size, Vector2(110.0, 110.0))
	node.modulate = Color(1.0, 1.0, 1.0, 0.9)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.55)
	style.set_corner_radius_all(26)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 1.0, 1.0, 0.25)
	node.add_theme_stylebox_override("normal", style)

	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(1.0, 0.62, 0.15, 0.75)
	node.add_theme_stylebox_override("pressed", pressed_style)
	node.add_theme_stylebox_override("hover", style)

	var disabled_style := style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.12, 0.14, 0.18, 0.25)
	node.add_theme_stylebox_override("disabled", disabled_style)
	return node


static func place(node: Control, x: float, y: float, width: float, height: float) -> Control:
	node.offset_left = x
	node.offset_top = y
	node.offset_right = x + width
	node.offset_bottom = y + height
	node.size = Vector2(width, height)
	return node
