## Главное меню: выбор самоката, карты и режима.
class_name MenuScreen
extends CanvasLayer

signal start_pressed(spec_id: String, map_id: int, mode_id: int)

var spec_id := "g4"
var map_id := GameConfig.MapId.STRAIGHT_TRACK
var mode_id := GameConfig.GameMode.FREE_RIDE

var _specs: Array[ScooterSpec] = []
var _scooter_buttons: Array[Button] = []
var _map_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _spec_info: Label
var _title: Label


func setup(specs: Array[ScooterSpec]) -> void:
	_specs = specs
	_refresh()


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var backdrop := UiFactory.panel(Color(0.02, 0.03, 0.05, 0.86))
	UiFactory.place(backdrop, 0.0, 0.0, 1280.0, 720.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	_title = UiFactory.label("KUGOO FREERIDE", 46, Color(1.0, 0.95, 0.9))
	UiFactory.place(_title, 48.0, 24.0, 700.0, 56.0)
	root.add_child(_title)

	var subtitle := UiFactory.label("Два самоката · две карты · трюки и комбо", 20, UiFactory.MUTED_COLOR)
	UiFactory.place(subtitle, 50.0, 78.0, 700.0, 28.0)
	root.add_child(subtitle)

	var y := 130.0
	root.add_child(_section_label("САМОКАТ", 50.0, y))
	y += 30.0
	# Кнопки создаём сразу (список самокатов приходит позже, из setup()),
	# иначе _ready отработал бы с пустым списком и кнопок не было бы вообще.
	for index in 2:
		var button := UiFactory.button("…", 20, Vector2(520.0, 52.0))
		UiFactory.place(button, 50.0, y, 520.0, 52.0)
		var captured_index := index
		button.pressed.connect(func() -> void: _select_spec_index(captured_index))
		root.add_child(button)
		_scooter_buttons.append(button)
		y += 60.0

	y += 10.0
	root.add_child(_section_label("КАРТА", 50.0, y))
	y += 30.0
	var map_names := ["Прямая трасса", "Город"]
	for index in map_names.size():
		var captured_map := index
		var button := UiFactory.button(map_names[index], 20, Vector2(250.0, 52.0))
		UiFactory.place(button, 50.0 + index * 260.0, y, 250.0, 52.0)
		button.pressed.connect(func() -> void: _select_map(captured_map))
		root.add_child(button)
		_map_buttons.append(button)
	y += 66.0

	root.add_child(_section_label("РЕЖИМ", 50.0, y))
	y += 30.0
	var mode_names := ["Свободная езда", "На время", "Фристайл"]
	for index in mode_names.size():
		var captured_mode := index
		var button := UiFactory.button(mode_names[index], 19, Vector2(172.0, 52.0))
		UiFactory.place(button, 50.0 + index * 178.0, y, 172.0, 52.0)
		button.pressed.connect(func() -> void: _select_mode(captured_mode))
		root.add_child(button)
		_mode_buttons.append(button)
	y += 78.0

	var start_button := UiFactory.primary_button("ПОЕХАЛИ", 30, Vector2(520.0, 74.0))
	UiFactory.place(start_button, 50.0, y, 520.0, 74.0)
	start_button.pressed.connect(_on_start)
	root.add_child(start_button)

	# Правая карточка с характеристиками.
	var card := UiFactory.panel(Color(0.05, 0.06, 0.09, 0.9))
	UiFactory.place(card, 640.0, 130.0, 592.0, 470.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)

	_spec_info = UiFactory.label("", 20, Color(0.95, 0.95, 1.0))
	_spec_info.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_spec_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFactory.place(_spec_info, 664.0, 152.0, 544.0, 430.0)
	root.add_child(_spec_info)

	var hint := UiFactory.label(
		"В игре: ГАЗ / ЗАД / ПЕРЕД — справа, РУЛЬ — слева, ВИЛЛИ — над газом.\n" +
		"С клавиатуры: W — газ, S — задний тормоз, Shift — передний, A/D — руль,\n" +
		"Space — вилли, Q/E — наклон, 1/2/3 — режимы, Tab — привод, R — респаун.",
		16, UiFactory.MUTED_COLOR)
	UiFactory.place(hint, 50.0, 630.0, 1180.0, 70.0)
	root.add_child(hint)

	_refresh()


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


func _on_start() -> void:
	start_pressed.emit(spec_id, map_id, mode_id)


func _refresh() -> void:
	for index in _scooter_buttons.size():
		if index >= _specs.size():
			continue
		var active := _specs[index].id == spec_id
		_scooter_buttons[index].text = ("● " if active else "   ") + _specs[index].display_name \
			+ "  ·  " + _specs[index].tagline
		UiFactory.style_button(_scooter_buttons[index], active)

	var maps := ["Прямая трасса", "Город"]
	for index in _map_buttons.size():
		_map_buttons[index].text = ("● " if index == map_id else "   ") + maps[index]
		UiFactory.style_button(_map_buttons[index], index == map_id)

	var modes := ["Свободная езда", "На время", "Фристайл"]
	for index in _mode_buttons.size():
		_mode_buttons[index].text = ("● " if index == mode_id else "   ") + modes[index]
		UiFactory.style_button(_mode_buttons[index], index == mode_id)

	if _spec_info != null and not _specs.is_empty():
		_spec_info.text = _describe_spec(ScooterSpec.get_by_id(spec_id))


func _describe_spec(spec: ScooterSpec) -> String:
	return "%s\n%s\n\nПривод: %s\nМотор: %d × %d Вт (пик %d Вт)\nМаксимальная скорость: %d км/ч\nЗапас хода: %d км\nБатарея: %s (%.0f Вт·ч)\nКолёса: %d″\nТормоза: %s\nПодвеска: %s\nМасса: %.1f кг · нагрузка до %d кг\nРежимы: %d / %d / %d км/ч\n\n%s" % [
		spec.display_name, spec.tagline, spec.drive_description,
		spec.motor_count, int(spec.power_watts), int(spec.peak_power_watts),
		int(spec.top_speed_kmh), int(spec.range_km), spec.battery_text, spec.battery_wh,
		int(spec.wheel_inches), spec.brakes_text, spec.suspension_text,
		spec.mass_kg, int(spec.max_load_kg),
		int(spec.gear_top_speed_kmh(0)), int(spec.gear_top_speed_kmh(1)), int(spec.gear_top_speed_kmh(2)),
		spec.features_text,
	]
