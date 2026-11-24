## KuKirin G4: 11" колёса с литыми пятилучевыми дисками, gunmetal-корпус,
## длинная объёмная дека с резиновым настилом и оранжевыми шевронами,
## фрезерованная стойка с логотипом, фара в горловине, двусторонние рычаги
## с пружинными амортизаторами спереди и сзади. Всё — по фото продукта.
class_name G4Model
extends ScooterModelBase

const STEM_BASE_Y := 0.40
const BAR_Y := 1.15
const ARM_X := 0.082
const DECK_Z := 0.04


func _build_body(root: Node3D) -> void:
	_deck(root)
	_rear_step(root)
	_rear_arm(root)
	_rear_hugger(root)
	_wheel(root, Vector3(0.0, 0.0, base * 0.5), "RearWheel", true, -1.0, _rim, true)
	_marker(root, "FootLeft", Vector3(-0.072, deck_top + 0.014, -0.10))
	_marker(root, "FootRight", Vector3(0.072, deck_top + 0.014, 0.10))


# ---- дека --------------------------------------------------------------------
func _deck(root: Node3D) -> void:
	# Оболочка с сужением к носу и подъёмом на корме — не коробка.
	var sections := [
		{"pos": Vector3(0.0, 0.058, DECK_Z - 0.345), "w": 0.142, "h": 0.072, "r": 0.024},
		{"pos": Vector3(0.0, 0.048, DECK_Z - 0.298), "w": 0.192, "h": 0.114, "r": 0.028},
		{"pos": Vector3(0.0, 0.042, DECK_Z - 0.190), "w": 0.216, "h": 0.132, "r": 0.030},
		{"pos": Vector3(0.0, 0.040, DECK_Z), "w": 0.220, "h": 0.136, "r": 0.030},
		{"pos": Vector3(0.0, 0.044, DECK_Z + 0.180), "w": 0.214, "h": 0.126, "r": 0.030},
		{"pos": Vector3(0.0, 0.052, DECK_Z + 0.248), "w": 0.192, "h": 0.098, "r": 0.024},
		{"pos": Vector3(0.0, 0.066, DECK_Z + 0.292), "w": 0.158, "h": 0.066, "r": 0.018},
	]
	var shell := _loft_rect(root, sections, _paint)
	shell.name = "Deck"
	# Настил: четыре панели шершавого гриптейпа с зазорами между ними.
	var panels := [
		[DECK_Z - 0.215, 0.104], [DECK_Z - 0.070, 0.107],
		[DECK_Z + 0.080, 0.107], [DECK_Z + 0.212, 0.101],
	]
	for panel in panels:
		_rbox(root, Vector3(0.150, 0.007, 0.122),
			Vector3(0.0, float(panel[1]), float(panel[0])), _tape,
			Vector3.ZERO, 0.006)
	# Оранжевый кант по верхней кромке и чёрный молдинг по низу.
	for side in [-1.0, 1.0]:
		var sx: float = side * 0.104
		_rbox(root, Vector3(0.007, 0.011, 0.300), Vector3(sx, 0.092, DECK_Z + 0.010),
			_accent, Vector3.ZERO, 0.004)
		_rbox(root, Vector3(0.009, 0.022, 0.330), Vector3(sx, 0.020, DECK_Z + 0.010),
			_plastic, Vector3.ZERO, 0.005)
	_deck_graphics(root)
	# Аккумуляторный короб под декой и рёбра жёсткости.
	_rbox(root, Vector3(0.158, 0.032, 0.360), Vector3(0.0, -0.032, DECK_Z + 0.010),
		_paint_dark, Vector3.ZERO, 0.010)
	for k in 3:
		_rbox(root, Vector3(0.168, 0.010, 0.014),
			Vector3(0.0, -0.040, DECK_Z - 0.120 + 0.120 * float(k)), _rim,
			Vector3.ZERO, 0.004)
	# Замок зажигания на борту у носа.
	_cyl(root, 0.011, 0.010, Vector3(0.106, 0.062, DECK_Z - 0.135), _steel,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	# Задний торец деки: технологическая накладка и кабель.
	_rbox(root, Vector3(0.120, 0.052, 0.014), Vector3(0.0, 0.044, DECK_Z + 0.292), _paint_dark,
		Vector3.ZERO, 0.008)


func _deck_graphics(root: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var gx: float = side * 0.108
		var yaw: float = 90.0 * side
		# Шевроны у носа: пара косых штрихов на каждой стороне.
		for k in 3:
			var cz: float = DECK_Z - 0.150 + 0.048 * float(k)
			_rbox(root, Vector3(0.006, 0.032, 0.013), Vector3(gx, 0.070, cz), _accent,
				Vector3(deg_to_rad(38.0), 0.0, 0.0), 0.002)
			_rbox(root, Vector3(0.006, 0.032, 0.013), Vector3(gx, 0.038, cz), _accent,
				Vector3(deg_to_rad(-38.0), 0.0, 0.0), 0.002)
		# Бренд по борту и модель у кормы.
		_label(root, spec.brand_text, Vector3(gx + side * 0.004, 0.072, DECK_Z + 0.070),
			Vector3(0.0, yaw, 0.0), 0.00040, Color(0.93, 0.94, 0.955))
		_label(root, "G4", Vector3(gx + side * 0.004, 0.042, DECK_Z + 0.196),
			Vector3(0.0, yaw, 0.0), 0.00048, Color(0.98, 0.45, 0.08))
		# Светоотражатель у кормы.
		_rbox(root, Vector3(0.004, 0.014, 0.044), Vector3(gx + side * 0.002, 0.030, DECK_Z + 0.268),
			_amber, Vector3.ZERO, 0.002)


## Задняя площадка на кронштейне: настил, кронштейн к деке, тяги, стоп-сигнал.
func _rear_step(root: Node3D) -> void:
	var tilt := Vector3(deg_to_rad(-9.0), 0.0, 0.0)
	var pos := Vector3(0.0, 0.192, DECK_Z + 0.372)
	var plate := _rbox(root, Vector3(0.182, 0.026, 0.196), pos, _paint, tilt, 0.010)
	plate.name = "RearStep"
	_rbox(root, Vector3(0.164, 0.008, 0.174), pos + Vector3(0.0, 0.016, -0.004), _tape,
		tilt, 0.004)
	for side in [-1.0, 1.0]:
		_rbox(root, Vector3(0.006, 0.014, 0.172), pos + Vector3(side * 0.086, -0.004, 0.0),
			_accent, tilt, 0.002)
	# Кронштейн от деки и тяги к маятнику.
	_beam(root, Vector3(0.0, 0.104, DECK_Z + 0.242), Vector3(0.0, 0.168, DECK_Z + 0.300),
		Vector2(0.142, 0.032), Vector2(0.152, 0.024), _paint, 0.010, 2)
	for side in [-1.0, 1.0]:
		_plate_between(root, Vector3(side * 0.068, 0.050, base * 0.5 - 0.046),
			Vector3(side * 0.078, pos.y - 0.022, pos.z + 0.024), 0.026, 0.012, _paint_dark)
	# Стоп-сигнал, поворотники, брызговик.
	_tail_light(root, Vector3(0.0, pos.y + 0.004, pos.z + 0.102), Vector3(0.086, 0.024, 0.012),
		_tail, tilt)
	for side in [-1.0, 1.0]:
		_rbox(root, Vector3(0.022, 0.014, 0.010),
			Vector3(side * 0.062, pos.y + 0.002, pos.z + 0.098), _amber, tilt, 0.003)
	_rbox(root, Vector3(0.148, 0.012, 0.062), Vector3(0.0, pos.y - 0.030, pos.z + 0.062),
		_plastic, tilt, 0.006)


# ---- маятник и корма ---------------------------------------------------------
func _rear_arm(root: Node3D) -> void:
	var pivot_z: float = DECK_Z + 0.262
	var axle_z: float = base * 0.5
	for side in [-1.0, 1.0]:
		var x: float = side * ARM_X
		# Рычаг маятника: сужается к оси, скруглённые рёбра.
		_beam(root, Vector3(x, 0.070, pivot_z), Vector3(x, 0.004, axle_z - 0.032),
			Vector2(0.046, 0.064), Vector2(0.032, 0.046), _paint, 0.010, 3)
		# Косынка у шарнира.
		_rbox(root, Vector3(0.010, 0.052, 0.072), Vector3(x, 0.088, pivot_z - 0.032),
			_paint, Vector3(deg_to_rad(18.0), 0.0, 0.0), 0.006)
		# Пружинный амортизатор от деки к рычагу.
		_shock(root, Vector3(x * 0.66, 0.166, pivot_z + 0.028),
			Vector3(x * 0.66, 0.052, axle_z - 0.088), 0.013, _accent)
		_label(root, "G4", Vector3(x + side * 0.026, 0.052, pivot_z + 0.070),
			Vector3(0.0, 90.0 * side, -74.0), 0.00030, Color(0.98, 0.45, 0.08))
	# Шарнир и ось с гайками.
	_cyl(root, 0.017, ARM_X * 2.0 + 0.030, Vector3(0.0, 0.070, pivot_z), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(root, 0.015, ARM_X * 2.0 + 0.024, Vector3(0.0, 0.004, axle_z - 0.032), _alu,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	# Поперечина маятника.
	_beam(root, Vector3(-ARM_X, 0.040, axle_z - 0.118), Vector3(ARM_X, 0.040, axle_z - 0.118),
		Vector2(0.048, 0.030), Vector2(0.048, 0.030), _paint_dark, 0.008, 2)
	# Кабель мотора от деки к оси.
	_tube(root, [
		Vector3(-0.068, 0.004, pivot_z - 0.070),
		Vector3(-0.080, -0.022, pivot_z + 0.060),
		Vector3(-0.072, -0.010, axle_z - 0.122),
		Vector3(-0.030, 0.002, axle_z - 0.014),
	], 0.0055, _plastic, 7)


func _rear_hugger(root: Node3D) -> void:
	var center := Vector3(0.0, 0.0, base * 0.5)
	_fender(root, center, radius + 0.020, 0.152, -104.0, 76.0, _plastic, 20, 0.012)
	# Кронштейны крыла к маятнику.
	for side in [-1.0, 1.0]:
		_plate_between(root, Vector3(side * (ARM_X - 0.004), 0.052, base * 0.5 + 0.058),
			Vector3(side * 0.050, radius + 0.028, base * 0.5 + 0.024), 0.020, 0.010, _rim)
	# Брызговик на конце крыла.
	_rbox(root, Vector3(0.112, 0.052, 0.010),
		Vector3(0.0, radius * 0.30, base * 0.5 + radius * 0.90), _plastic,
		Vector3(deg_to_rad(-58.0), 0.0, 0.0), 0.004)


# ---- рулевая часть -----------------------------------------------------------
func _build_steer(root: Node3D) -> Node3D:
	var steer := Node3D.new()
	steer.name = "FrontSteer"
	steer.position = Vector3(0.0, 0.0, steer_z)
	root.add_child(steer)

	var axle := Vector3(0.0, 0.0, -(base * 0.5 + steer_z))
	_neck(steer)
	_front_fork(steer, axle)
	var top_z := _stem(steer)
	_wheel(steer, axle, "Wheel", false, -1.0, _rim, true)
	_marker(steer, "BarLeft", Vector3(-0.200, BAR_Y, top_z))
	_marker(steer, "BarRight", Vector3(0.200, BAR_Y, top_z))
	return steer


func _neck(steer: Node3D) -> void:
	# Горловина: широкий литой клин от деки к стакану.
	_beam(steer, Vector3(0.0, 0.018, 0.050), Vector3(0.0, 0.332, 0.058),
		Vector2(0.186, 0.168), Vector2(0.098, 0.112), _paint, 0.032, 4, Vector3.BACK)
	# Тень под клином и резиновый грязевик.
	_rbox(steer, Vector3(0.152, 0.038, 0.124), Vector3(0.0, 0.008, 0.048), _paint_dark,
		Vector3(deg_to_rad(-8.0), 0.0, 0.0), 0.010)
	# Передняя грань горловины: оранжевая бровь и вентиляционные прорези.
	var lamp_z := -0.026
	_rbox(steer, Vector3(0.078, 0.014, 0.016), Vector3(0.0, 0.206, lamp_z - 0.004), _accent,
		Vector3(deg_to_rad(-16.0), 0.0, 0.0), 0.004)
	for k in 3:
		_rbox(steer, Vector3(0.048, 0.006, 0.008),
			Vector3(0.0, 0.150 - 0.022 * float(k), lamp_z + 0.004), _rim,
			Vector3(deg_to_rad(-16.0), 0.0, 0.0), 0.002)
	# Отражатель в носу горловины.
	_rbox(steer, Vector3(0.040, 0.012, 0.010), Vector3(0.0, 0.104, lamp_z + 0.006), _amber,
		Vector3(deg_to_rad(-16.0), 0.0, 0.0), 0.003)


func _front_fork(steer: Node3D, axle: Vector3) -> void:
	# Траверса под горловиной.
	_beam(steer, Vector3(-ARM_X - 0.012, 0.104, 0.020), Vector3(ARM_X + 0.012, 0.104, 0.020),
		Vector2(0.082, 0.054), Vector2(0.082, 0.054), _paint_dark, 0.012, 2)
	for side in [-1.0, 1.0]:
		var x: float = side * ARM_X
		# Рычаг вниз-вперёд к оси.
		_beam(steer, Vector3(x, 0.100, 0.020), Vector3(x, 0.004, axle.z + 0.030),
			Vector2(0.044, 0.062), Vector2(0.030, 0.044), _paint, 0.010, 3)
		# Косынка и шильдик на рычаге.
		_rbox(steer, Vector3(0.010, 0.048, 0.062), Vector3(x, 0.068, 0.000), _paint_dark,
			Vector3(deg_to_rad(-52.0), 0.0, 0.0), 0.005)
		_label(steer, "G4", Vector3(x + side * 0.024, 0.054, axle.z + 0.112),
			Vector3(0.0, 90.0 * side, -62.0), 0.00030, Color(0.98, 0.45, 0.08))
		# Пружинный амортизатор от горловины к рычагу.
		_shock(steer, Vector3(x, 0.292, 0.030), Vector3(x, 0.062, axle.z + 0.122),
			0.013, _accent)
	# Шарнир, ось и гайки.
	_cyl(steer, 0.016, ARM_X * 2.0 + 0.034, Vector3(0.0, 0.100, 0.020), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(steer, 0.015, ARM_X * 2.0 + 0.038, Vector3(0.0, 0.004, axle.z + 0.030), _alu,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)


func _stem(steer: Node3D) -> float:
	var rake := deg_to_rad(spec.stem_rake_deg)
	var bottom := Vector3(0.0, STEM_BASE_Y, 0.058)
	var top := Vector3(0.0, BAR_Y, bottom.z + tan(rake) * (BAR_Y - STEM_BASE_Y))
	# Стойка: сужающийся фрезерованный профиль вместо плоской пластины.
	_beam(steer, bottom, top, Vector2(0.066, 0.030), Vector2(0.050, 0.024), _paint,
		0.008, 5, Vector3.BACK)
	_beam(steer, bottom - Vector3(0.0, 0.030, 0.0), bottom.lerp(top, 0.14),
		Vector2(0.072, 0.040), Vector2(0.068, 0.034), _paint, 0.010, 2, Vector3.BACK)
	var mid := bottom.lerp(top, 0.55)
	for side in [-1.0, 1.0]:
		# Фрезерованный канал и оранжевая вставка по бокам стойки.
		_rbox(steer, Vector3(0.005, 0.320, 0.010), mid + Vector3(side * 0.026, 0.010, 0.0),
			_paint_dark, Vector3(rake, 0.0, 0.0), 0.002)
		_rbox(steer, Vector3(0.004, 0.120, 0.006), mid + Vector3(side * 0.027, -0.120, 0.0),
			_accent, Vector3(rake, 0.0, 0.0), 0.002)
		_label(steer, spec.brand_text, mid + Vector3(side * 0.030, 0.046, 0.0),
			Vector3(0.0, 90.0 * side, 90.0), 0.00040, Color(0.94, 0.95, 0.96))
		# Шахматный логотип у основания стойки.
		for k in 3:
			_rbox(steer, Vector3(0.004, 0.014, 0.014),
				bottom.lerp(top, 0.16) + Vector3(side * 0.027, 0.010 * float(k) - 0.016, 0.014 * float(k % 2)),
				_accent, Vector3(rake, 0.0, 0.0), 0.002)
	# Замок складывания: воротник, болты, эксцентрик.
	var collar := bottom + Vector3(0.0, 0.028, 0.0)
	_rbox(steer, Vector3(0.086, 0.074, 0.082), collar, _rim, Vector3(rake, 0.0, 0.0), 0.010)
	for bolt_y in [-0.024, 0.024]:
		_cyl(steer, 0.0055, 0.092, collar + Vector3(0.0, bolt_y, 0.0), _steel,
			Vector3(0.0, 0.0, deg_to_rad(90.0)), 8)
	_cyl(steer, 0.010, 0.098, collar + Vector3(0.0, 0.0, 0.046), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	_rbox(steer, Vector3(0.014, 0.026, 0.086), collar + Vector3(0.0, -0.006, 0.054), _accent,
		Vector3(deg_to_rad(-24.0), 0.0, 0.0), 0.005)
	var bar_z := top.z
	# Хомут руля с болтами и сам руль.
	_rbox(steer, Vector3(0.078, 0.048, 0.066), Vector3(0.0, BAR_Y - 0.026, bar_z), _rim,
		Vector3.ZERO, 0.010)
	for side in [-1.0, 1.0]:
		_cyl(steer, 0.006, 0.012, Vector3(side * 0.024, BAR_Y + 0.002, bar_z - 0.016), _steel,
			Vector3.ZERO, 8)
	_bar_basic(steer, BAR_Y, bar_z)
	_grips(steer, BAR_Y, bar_z)
	_lever(steer, -1.0, BAR_Y, bar_z)
	_lever(steer, 1.0, BAR_Y, bar_z)
	_throttle(steer, 1.0, BAR_Y, bar_z)
	_bell(steer, BAR_Y, bar_z)
	_dash(steer, BAR_Y, bar_z, 0.88)
	_phone_mount(steer, BAR_Y, bar_z, 0.104)
	# Фара в обойме под бортовым компьютером.
	var lamp := Vector3(0.0, BAR_Y - 0.082, bar_z - 0.052)
	_rbox(steer, Vector3(0.096, 0.062, 0.048), lamp + Vector3(0.0, 0.010, 0.020), _plastic,
		Vector3(deg_to_rad(-12.0), 0.0, 0.0), 0.012)
	_headlight(steer, lamp, 0.030)
	_torus(steer, 0.031, 0.039, _accent, Vector3(0.0, deg_to_rad(90.0), 0.0),
		lamp + Vector3(0.0, 0.0, -0.002), 22)
	# Проводка: два жгута вдоль стойки и шланг переднего тормоза.
	for side in [-1.0, 1.0]:
		_tube(steer, [
			Vector3(side * 0.110, BAR_Y - 0.020, bar_z + 0.012),
			Vector3(side * 0.078, BAR_Y - 0.105, bar_z + 0.040),
			Vector3(side * 0.048, STEM_BASE_Y + 0.240, 0.086),
			Vector3(side * 0.042, 0.190, 0.106),
		], 0.0055, _plastic, 7)
	_tube(steer, [
		Vector3(-0.112, BAR_Y - 0.012, bar_z - 0.024),
		Vector3(-0.084, 0.700, 0.082),
		Vector3(-0.062, 0.330, 0.094),
		Vector3(-0.066, 0.150, -0.030),
		Vector3(-0.038, 0.054, -(base * 0.5 + steer_z) + 0.040),
	], 0.0048, _plastic, 7)
	return bar_z
