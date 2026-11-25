## Игровой интерфейс: спидометр, батарея, режимы, трюки и экранные кнопки.
## Кнопки газа/тормозов/руля сделаны мультитач-зонами: обычные Button в Godot
## получают только одно касание, а игроку нужно держать газ и руль одновременно.
class_name Hud
extends CanvasLayer

signal menu_pressed
signal drive_toggled
signal speed_mode_changed(mode: int)
signal respawn_pressed
signal view_toggled

const DESIGN_WIDTH := 1280.0

var input: InputState

var _speed_label: Label
var _speed_unit: Label
var _mode_label: Label
var _drive_label: Label
var _fps_label: Label
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
var _wheelie_active := false

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


	_distance_label = UiFactory.label("0.00 км", 22, Color(1.0, 1.0, 1.0))
	UiFactory.place(_distance_label, 980.0, 78.0, 260.0, 28.0)
	root.add_child(_distance_label)

	_fps_label = UiFactory.label("— FPS", 20, Color(0.72, 0.80, 0.72), HORIZONTAL_ALIGNMENT_RIGHT)
	UiFactory.place(_fps_label, 1140.0, 142.0, 116.0, 26.0)
	root.add_child(_fps_label)
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

	_hint_label = UiFactory.label("ВИЛЛИ — одно нажатие и газ · камера — свайп · ВИД — первое лицо",
		16, UiFactory.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	UiFactory.place(_hint_label, 240.0, 668.0, 800.0, 24.0)
	root.add_child(_hint_label)

	# Кнопки-события: режим, привод, респаун, меню и вид камеры.
	_add_zone(root, "mode", Rect2(18.0, 182.0, 142.0, 40.0), "РЕЖИМ")
	_add_zone(root, "drive", Rect2(176.0, 182.0, 142.0, 40.0), "AWD/RWD")
	_add_zone(root, "respawn", Rect2(18.0, 230.0, 142.0, 40.0), "РЕСПАУН")
	_add_zone(root, "menu", Rect2(176.0, 230.0, 142.0, 40.0), "МЕНЮ")
	_add_zone(root, "view", Rect2(18.0, 278.0, 142.0, 40.0), "ВИД")


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


## Сбросить зажатые кнопки (ставим на паузу — иначе газ остаётся вжатым).
func release_touches() -> void:
	_active_touch.clear()
	if input != null:
		input.clear_touch()


## Нажатие попало в экранную кнопку? Нужно камере, чтобы свайп по пустому
## месту крутил обзор, а не сбивал управление.
func is_over_controls(point: Vector2) -> bool:
	return _zone_at(point) != ""


func _input(event: InputEvent) -> void:
	# В меню и на паузе интерфейс не должен ловить касания.
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var zone_id := _zone_at(event.position)
			if zone_id != "":
				_active_touch[event.index] = zone_id
				_handle_press(zone_id)
		else:
			_active_touch.erase(event.index)
	elif event is InputEventMouseButton:
		# На десктопе мышью тоже можно нажимать экранные кнопки.
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var zone_id := _zone_at(event.position)
			if zone_id != "":
				_handle_press(zone_id)
	elif event is InputEventScreenDrag:
		var zone_id := _zone_at(event.position)
		if _active_touch.has(event.index):
			if zone_id == "":
				_active_touch.erase(event.index)
			else:
				_active_touch[event.index] = zone_id


## Разовые действия по нажатию экранной кнопки.
func _handle_press(zone_id: String) -> void:
	match zone_id:
		"wheelie":
			if input != null:
				input.request_wheelie_toggle()
		"respawn":
			respawn_pressed.emit()
		"menu":
			menu_pressed.emit()
		"drive":
			drive_toggled.emit()
		"mode":
			speed_mode_changed.emit(-1)
		"view":
			view_toggled.emit()


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
	if not visible:
		return
	if _trick_timer > 0.0:
		_trick_timer -= delta
		if _trick_timer <= 0.0:
			_trick_label.text = ""

	if input == null:
		return
	input.touch_throttle = 1.0 if _zone_held("throttle") else 0.0
	input.touch_brake_rear = 1.0 if _zone_held("brake_rear") else 0.0
	input.touch_brake_front = 1.0 if _zone_held("brake_front") else 0.0

	var steer := 0.0
	if _zone_held("steer_left"):
		steer -= 1.0
	if _zone_held("steer_right"):
		steer += 1.0
	input.touch_steer = steer

	for zone_id in _zone_rect_nodes.keys():
		var node: ColorRect = _zone_rect_nodes[zone_id]
		var lit := _zone_held(zone_id)
		# ВИЛЛИ светится, только пока ждёт газ. На поднятом носу — гаснет.
		if zone_id == "wheelie":
			lit = input.wheelie_armed and not _wheelie_active
		node.color = _active_color if lit else _base_color


# ---- данные на экране -------------------------------------------------------
func update_stats(scooter: Scooter, tricks: TrickSystem, time_left: float, show_timer: bool) -> void:
	if scooter == null:
		return
	_speed_label.text = "%d" % int(round(scooter.speed_kmh()))
	var gear_limit := int(round(scooter.spec.gear_top_speed_kmh(scooter.speed_mode)))
	_mode_label.text = "РЕЖИМ %d · до %d км/ч" % [scooter.speed_mode + 1, gear_limit]
	_drive_label.text = "AWD — полный привод" if scooter.drive_mode == GameConfig.DriveMode.AWD else "RWD — задний привод"


	if _fps_label != null:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	_wheelie_active = scooter.wheelie != null and scooter.wheelie.active
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
