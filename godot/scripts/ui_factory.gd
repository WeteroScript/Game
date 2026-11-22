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


static func button(text: String, size: int, min_size := Vector2(0.0, 46.0)) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = min_size
	node.add_theme_font_size_override("font_size", size)
	node.focus_mode = Control.FOCUS_NONE
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
