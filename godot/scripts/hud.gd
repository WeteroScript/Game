## Игровой интерфейс: спидометр, батарея, режимы, трюки и экранные кнопки.
## Кнопки газа/тормозов/руля сделаны мультитач-зонами: обычные Button в Godot
## получают только одно касание, а игроку нужно держать газ и руль одновременно.
class_name Hud
extends CanvasLayer

signal menu_pressed
signal drive_toggled
signal speed_mode_changed(mode: int)
signal respawn_pressed

const DESIGN_WIDTH := 1280.0

var input: InputState

var _speed_label: Label
var _speed_unit: Label
var _mode_label: Label
var _drive_label: Label
var _battery_bar: ProgressBar
var _battery_label: Label
var _distance_label: Label
var _time_label: Label
var _score_label: Label
var _combo_label: Label
var _trick_label: Label
var _trick_timer := 0.0
var _countdown_label: Label
var _crash_label: Label
var _hint_label: Label

var _zones := {}
var _zone_rects := {}
var _zone_rect_nodes := {}
var _active_touch := {}

var _base_color := Color(0.12, 0.14, 0.18, 0.45)
var _active_color := Color(1.0, 0.62, 0.15, 0.75)


func setup(new_input: InputState) -> void:
	input = new_input


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top_left(root)
	_build_top_right(root)
	_build_center(root)
	_build_touch_controls(root)


func _build_top_left(root: Control) -> void:
	var panel := UiFactory.panel()
	UiFactory.place(panel, 18.0, 16.0, 300.0, 150.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	_speed_label = UiFactory.label("0", 62, Color(1.0, 1.0, 1.0))
	UiFactory.place(_speed_label, 30.0, 20.0, 160.0, 70.0)
	root.add_child(_speed_label)

	_speed_unit = UiFactory.label("км/ч", 20, UiFactory.MUTED_COLOR)
	UiFactory.place(_speed_unit, 150.0, 58.0, 90.0, 26.0)
	root.add_child(_speed_unit)

	_mode_label = UiFactory.label("РЕЖИМ 2 · до 40 км/ч", 18, UiFactory.ACCENT_COLOR)
	UiFactory.place(_mode_label, 30.0, 92.0, 280.0, 26.0)
	root.add_child(_mode_label)

	_drive_label = UiFactory.label("RWD", 20, Color(0.75, 0.85, 1.0))
	UiFactory.place(_drive_label, 30.0, 120.0, 260.0, 28.0)
	root.add_child(_drive_label)


func _build_top_right(root: Control) -> void:
	var panel := UiFactory.panel()
	UiFactory.place(panel, 962.0, 16.0, 300.0, 150.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	_battery_bar = ProgressBar.new()
	_battery_bar.min_value = 0.0
	_battery_bar.max_value = 100.0
	_battery_bar.value = 100.0
	_battery_bar.show_percentage = false
	UiFactory.place(_battery_bar, 980.0, 26.0, 200.0, 22.0)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.09, 0.11, 0.15, 0.95)
	bar_bg.set_corner_radius_all(8)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.36, 0.86, 0.48)
	bar_fill.set_corner_radius_all(8)
	_battery_bar.add_theme_stylebox_override("background", bar_bg)
	_battery_bar.add_theme_stylebox_override("fill", bar_fill)
	root.add_child(_battery_bar)

	var battery_caption := UiFactory.label("БАТАРЕЯ", 14, UiFactory.MUTED_COLOR)
	UiFactory.place(battery_caption, 980.0, 52.0, 200.0, 20.0)
	root.add_child(battery_caption)

	_battery_label = UiFactory.label("100%", 26, Color(0.6, 1.0, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	UiFactory.place(_battery_label, 1186.0, 22.0, 70.0, 30.0)
	root.add_child(_battery_label)

	_distance_label = UiFactory.label("0.00 км", 22, Color(1.0, 1.0, 1.0))
	UiFactory.place(_distance_label, 980.0, 78.0, 260.0, 28.0)
	root.add_child(_distance_label)

	_time_label = UiFactory.label("0:00", 22, Color(1.0, 1.0, 1.0))
	UiFactory.place(_time_label, 980.0, 110.0, 260.0, 28.0)
	root.add_child(_time_label)


func _build_center(root: Control) -> void:
	_score_label = UiFactory.label("0", 36, Color(1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	UiFactory.place(_score_label, 490.0, 18.0, 300.0, 44.0)
	root.add_child(_score_label)

	_combo_label = UiFactory.label("", 20, UiFactory.ACCENT_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	UiFactory.place(_combo_label, 490.0, 60.0, 300.0, 26.0)
	root.add_child(_combo_label)

	_trick_label = UiFactory.label("", 26, Color(1.0, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	UiFactory.place(_trick_label, 390.0, 96.0, 500.0, 36.0)
	root.add_child(_trick_label)

	_countdown_label = UiFactory.label("", 110, Color(1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	UiFactory.place(_countdown_label, 340.0, 250.0, 600.0, 150.0)
	root.add_child(_countdown_label)

	_crash_label = UiFactory.label("", 30, Color(1.0, 0.4, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
	UiFactory.place(_crash_label, 240.0, 300.0, 800.0, 80.0)
	root.add_child(_crash_label)

	_hint_label = UiFactory.label("ГАЗ — справа · ТОРМОЗ — рядом · ВИЛЛИ — над газом · РУЛЬ — слева",
		16, UiFactory.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	UiFactory.place(_hint_label, 240.0, 668.0, 800.0, 24.0)
	root.add_child(_hint_label)

	# Кнопки-события: режим, привод, респаун, меню.
	var mode_button := UiFactory.button("РЕЖИМ", 18, Vector2(140.0, 40.0))
	UiFactory.place(mode_button, 18.0, 182.0, 142.0, 40.0)
	mode_button.pressed.connect(_on_mode_button)
	root.add_child(mode_button)

	var drive_button := UiFactory.button("AWD/RWD", 18, Vector2(140.0, 40.0))
	UiFactory.place(drive_button, 176.0, 182.0, 142.0, 40.0)
	drive_button.pressed.connect(_on_drive_button)
	root.add_child(drive_button)

	var respawn_button := UiFactory.button("РЕСПАУН", 18, Vector2(140.0, 40.0))
	UiFactory.place(respawn_button, 18.0, 230.0, 142.0, 40.0)
	respawn_button.pressed.connect(_on_respawn_button)
	root.add_child(respawn_button)

	var menu_button := UiFactory.button("МЕНЮ", 18, Vector2(140.0, 40.0))
	UiFactory.place(menu_button, 176.0, 230.0, 142.0, 40.0)
	menu_button.pressed.connect(_on_menu_button)
	root.add_child(menu_button)


func _build_touch_controls(root: Control) -> void:
	_add_zone(root, "steer_left", Rect2(24.0, 540.0, 130.0, 130.0), "◀")
	_add_zone(root, "steer_right", Rect2(172.0, 540.0, 130.0, 130.0), "▶")
	_add_zone(root, "wheelie", Rect2(1132.0, 392.0, 126.0, 84.0), "ВИЛЛИ")
	_add_zone(root, "brake_front", Rect2(986.0, 486.0, 126.0, 84.0), "ПЕРЕД")
	_add_zone(root, "brake_rear", Rect2(986.0, 584.0, 126.0, 84.0), "ЗАД")
	_add_zone(root, "throttle", Rect2(1128.0, 500.0, 134.0, 134.0), "ГАЗ")


func _add_zone(root: Control, zone_id: String, rect: Rect2, caption: String) -> void:
	var background := ColorRect.new()
	background.color = _base_color
	background.position = rect.position
	background.size = rect.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var text := UiFactory.label(caption, 20, Color(1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	text.position = rect.position
	text.size = rect.size
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(text)

	_zone_rects[zone_id] = rect
	_zone_rect_nodes[zone_id] = background


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var zone_id := _zone_at(event.position)
			if zone_id != "":
				_active_touch[event.index] = zone_id
		else:
			_active_touch.erase(event.index)
	elif event is InputEventScreenDrag:
		var zone_id := _zone_at(event.position)
		if _active_touch.has(event.index):
			if zone_id == "":
				_active_touch.erase(event.index)
			else:
				_active_touch[event.index] = zone_id


func _zone_at(point: Vector2) -> String:
	for zone_id in _zone_rects.keys():
		var rect: Rect2 = _zone_rects[zone_id]
		if rect.has_point(point):
			return zone_id
	return ""


func _zone_held(zone_id: String) -> bool:
	for key in _active_touch.keys():
		if _active_touch[key] == zone_id:
			return true
	return false


func _process(delta: float) -> void:
	if _trick_timer > 0.0:
		_trick_timer -= delta
		if _trick_timer <= 0.0:
			_trick_label.text = ""

	if input == null:
		return
	input.touch_throttle = 1.0 if _zone_held("throttle") else 0.0
	input.touch_brake_rear = 1.0 if _zone_held("brake_rear") else 0.0
	input.touch_brake_front = 1.0 if _zone_held("brake_front") else 0.0
	input.touch_wheelie = _zone_held("wheelie")

	var steer := 0.0
	if _zone_held("steer_left"):
		steer -= 1.0
	if _zone_held("steer_right"):
		steer += 1.0
	input.touch_steer = steer

	for zone_id in _zone_rect_nodes.keys():
		var node: ColorRect = _zone_rect_nodes[zone_id]
		node.color = _active_color if _zone_held(zone_id) else _base_color


func _on_mode_button() -> void:
	speed_mode_changed.emit(-1)


func _on_drive_button() -> void:
	drive_toggled.emit()


func _on_respawn_button() -> void:
	respawn_pressed.emit()


func _on_menu_button() -> void:
	menu_pressed.emit()


# ---- данные на экране -------------------------------------------------------
func update_stats(scooter: Scooter, tricks: TrickSystem, time_left: float, show_timer: bool) -> void:
	if scooter == null:
		return
	_speed_label.text = "%d" % int(round(scooter.speed_kmh()))
	var gear_limit := int(round(scooter.spec.gear_top_speed_kmh(scooter.speed_mode)))
	_mode_label.text = "РЕЖИМ %d · до %d км/ч" % [scooter.speed_mode + 1, gear_limit]
	_drive_label.text = "AWD — полный привод" if scooter.drive_mode == GameConfig.DriveMode.AWD else "RWD — задний привод"

	var percent := scooter.battery_percent()
	_battery_bar.value = percent
	_battery_label.text = "%d%%" % int(round(percent))
	_distance_label.text = "%.2f км" % (scooter.distance_meters / 1000.0)
	_time_label.text = _format_time(scooter.run_time if not show_timer else time_left)

	_score_label.text = "%d" % tricks.score
	if tricks.combo > 1:
		_combo_label.text = "КОМБО x%.2f · %.1f с" % [tricks.combo_multiplier(), tricks.combo_time_left]
	else:
		_combo_label.text = ""


func _format_time(seconds: float) -> String:
	var total := int(maxf(0.0, seconds))
	return "%d:%02d" % [total / 60, total % 60]


func set_countdown(text: String) -> void:
	_countdown_label.text = text


func show_crash(reason: String) -> void:
	_crash_label.text = reason


func clear_crash() -> void:
	_crash_label.text = ""


func show_trick(trick_name: String, points: int) -> void:
	_trick_label.text = "%s  +%d" % [trick_name, points]
	_trick_timer = 1.6


func set_hint(text: String) -> void:
	_hint_label.text = text
