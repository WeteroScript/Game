## Главное меню: самокат, карта, режим и кнопка старта. Без лишнего текста —
## только выбор и короткая карточка характеристик.
## Список самокатов приходит из ScooterSpec.all(), поэтому кнопки создаются
## по фактическому числу моделей (сейчас их три: G4, F3 Pro Max, G4 TEST).
class_name MenuScreen
extends CanvasLayer

signal start_pressed(spec_id: String, map_id: int, mode_id: int)
## Переключатель персонажа: игра прячет/показывает райдера и запоминает выбор.
signal rider_toggled(shown: bool)

const MAP_NAMES := ["Ровная дорога", "Город", "Джамп-парк"]
const MODE_NAMES := ["Свободная езда", "На время", "Фристайл"]

var spec_id := "g4"
var map_id := GameConfig.MapId.STRAIGHT_TRACK
var mode_id := GameConfig.GameMode.FREE_RIDE
## Показывать персонажа (райдера) в игре и в фоне меню.
var rider_shown := true

var _specs: Array[ScooterSpec] = []
var _left: Control
var _scooter_buttons: Array[Button] = []
var _map_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _spec_info: Label
var _rider_button: Button


func setup(specs: Array[ScooterSpec]) -> void:
	_specs = specs
	_refresh()


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var backdrop := UiFactory.panel(Color(0.02, 0.03, 0.05, 0.88))
	UiFactory.place(backdrop, 0.0, 0.0, 1280.0, 720.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	var title := UiFactory.label("KUGOO FREERIDE", 46, Color(1.0, 0.95, 0.9))
	UiFactory.place(title, 48.0, 26.0, 700.0, 56.0)
	root.add_child(title)

	# Левая колонка пересобирается, когда меняется число самокатов.
	_left = Control.new()
	_left.set_anchors_preset(Control.PRESET_FULL_RECT)
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_left)

	# Карточка характеристик.
	var card := UiFactory.panel(Color(0.05, 0.06, 0.09, 0.9))
	UiFactory.place(card, 640.0, 104.0, 592.0, 400.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)

	_spec_info = UiFactory.label("", 21, Color(0.95, 0.95, 1.0))
	_spec_info.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_spec_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFactory.place(_spec_info, 668.0, 128.0, 540.0, 360.0)
	root.add_child(_spec_info)

	# Переключатель персонажа — справа под карточкой характеристик.
	_rider_button = UiFactory.button("", 22, Vector2(592.0, 60.0))
	UiFactory.place(_rider_button, 640.0, 520.0, 592.0, 60.0)
	_rider_button.pressed.connect(_toggle_rider)
	root.add_child(_rider_button)

	var hint := UiFactory.label("Выключи — в меню и в заезде будет виден только самокат.",
		16, UiFactory.MUTED_COLOR)
	UiFactory.place(hint, 648.0, 588.0, 576.0, 44.0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	_build_left()
	_refresh()


func _build_left() -> void:
	for child in _left.get_children():
		_left.remove_child(child)
		child.queue_free()
	_scooter_buttons.clear()
	_map_buttons.clear()
	_mode_buttons.clear()

	var y := 104.0
	_left.add_child(_section_label("САМОКАТ", 50.0, y))
	y += 28.0
	for index in _specs.size():
		var captured_spec := index
		var button := UiFactory.button("…", 20, Vector2(520.0, 54.0))
		UiFactory.place(button, 50.0, y, 520.0, 54.0)
		button.pressed.connect(func() -> void: _select_spec_index(captured_spec))
		_left.add_child(button)
		_scooter_buttons.append(button)
		y += 62.0

	y += 14.0
	_left.add_child(_section_label("КАРТА", 50.0, y))
	y += 28.0
	for index in MAP_NAMES.size():
		var captured_map := index
		# Три карты должны помещаться в левую колонку, не заезжая под карточку
		# характеристик (она начинается на x=660).
		var button := UiFactory.button(MAP_NAMES[index], 16, Vector2(150.0, 54.0))
		UiFactory.place(button, 50.0 + index * 158.0, y, 150.0, 54.0)
		button.pressed.connect(func() -> void: _select_map(captured_map))
		_left.add_child(button)
		_map_buttons.append(button)
	y += 66.0

	_left.add_child(_section_label("РЕЖИМ", 50.0, y))
	y += 28.0
	for index in MODE_NAMES.size():
		var captured_mode := index
		var button := UiFactory.button(MODE_NAMES[index], 16, Vector2(180.0, 54.0))
		UiFactory.place(button, 50.0 + index * 186.0, y, 180.0, 54.0)
		button.pressed.connect(func() -> void: _select_mode(captured_mode))
		_left.add_child(button)
		_mode_buttons.append(button)
	y += 78.0

	var start_button := UiFactory.primary_button("ПОЕХАЛИ", 32, Vector2(520.0, 78.0))
	UiFactory.place(start_button, 50.0, y, 520.0, 78.0)
	start_button.pressed.connect(_on_start)
	_left.add_child(start_button)


func _section_label(text: String, x: float, y: float) -> Label:
	var label := UiFactory.label(text, 16, UiFactory.ACCENT_COLOR)
	UiFactory.place(label, x, y, 400.0, 24.0)
	return label


## Публичная обёртка: игра обновляет подсветку выбора при входе в меню.
func refresh() -> void:
	_refresh()


func _select_spec_index(index: int) -> void:
	if index < 0 or index >= _specs.size():
		return
	spec_id = _specs[index].id
	_refresh()


func _select_map(new_map: int) -> void:
	map_id = new_map
	_refresh()


func _select_mode(new_mode: int) -> void:
	mode_id = new_mode
	_refresh()


func _toggle_rider() -> void:
	rider_shown = not rider_shown
	_refresh()
	rider_toggled.emit(rider_shown)


func _on_start() -> void:
	start_pressed.emit(spec_id, map_id, mode_id)


func _refresh() -> void:
	if _scooter_buttons.size() != _specs.size():
		_build_left()
	for index in _scooter_buttons.size():
		if index >= _specs.size():
			continue
		var active := _specs[index].id == spec_id
		_scooter_buttons[index].text = ("● " if active else "   ") + _specs[index].display_name \
			+ "  ·  " + _specs[index].tagline
		UiFactory.style_button(_scooter_buttons[index], active)

	for index in _map_buttons.size():
		_map_buttons[index].text = ("● " if index == map_id else "   ") + MAP_NAMES[index]
		UiFactory.style_button(_map_buttons[index], index == map_id)

	for index in _mode_buttons.size():
		_mode_buttons[index].text = ("● " if index == mode_id else "   ") + MODE_NAMES[index]
		UiFactory.style_button(_mode_buttons[index], index == mode_id)

	if _rider_button != null:
		_rider_button.text = ("● ПЕРСОНАЖ: ВКЛ" if rider_shown else "   ПЕРСОНАЖ: ВЫКЛ")
		UiFactory.style_button(_rider_button, rider_shown)

	if _spec_info != null and not _specs.is_empty():
		# Рекорд относится к выбранной паре «карта + режим», поэтому и обновляется
		# вместе с выбором.
		_spec_info.text = _describe_spec(ScooterSpec.get_by_id(spec_id)) \
			+ "\n\n" + Records.describe(map_id, mode_id)


func _describe_spec(spec: ScooterSpec) -> String:
	return "%s\n%s\n\nПривод: %s\nМотор: %d × %d Вт (пик %d)\nСкорость: %d км/ч\nЗапас: %d км · %s\nКолёса: %d″ · масса %.0f кг\nРежимы: %d / %d / %d км/ч" % [
		spec.display_name, spec.tagline, spec.drive_description,
		spec.motor_count, int(spec.power_watts), int(spec.peak_power_watts),
		int(spec.top_speed_kmh), int(spec.range_km), spec.battery_text,
		int(spec.wheel_inches), spec.mass_kg,
		int(spec.gear_top_speed_kmh(0)), int(spec.gear_top_speed_kmh(1)), int(spec.gear_top_speed_kmh(2)),
	]
