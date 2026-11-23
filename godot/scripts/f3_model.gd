## Kugoo F3 Pro Max: чёрный корпус с оранжевыми рычагами, сильно заваленная
## назад стойка с оранжевой графикой и фарой на ней, односторонние оранжевые
## рычаги подвески спереди и сзади, широкая задняя площадка. Всё — по фото.
class_name F3Model
extends ScooterModelBase

const STEM_BASE_Y := 0.36
const BAR_Y := 1.10
const ARM_X := 0.082


func _build_body(root: Node3D) -> void:
	_deck(root)
	_rear_arm(root)
	_rear_step(root)
	_rear_fender(root)
	_battery_box(root)
	_kickstand(root)
	_wheel(root, Vector3(0.0, 0.0, base * 0.5), "RearWheel", true, 1.0, _rim)
	_marker(root, "FootLeft", Vector3(-0.068, deck_top + 0.020, -0.09))
	_marker(root, "FootRight", Vector3(0.068, deck_top + 0.020, 0.10))


func _deck(root: Node3D) -> void:
	var z0 := 0.04
	# Чёрная дека-короб, чуть сужается к носу.
	_rbox(root, Vector3(deck_w, deck_top, deck_len), Vector3(0.0, deck_top * 0.5, z0),
		_paint, Vector3.ZERO, 0.015)
	_rbox(root, Vector3(deck_w - 0.014, deck_top * 0.80, 0.09),
		Vector3(0.0, deck_top * 0.38, z0 - deck_len * 0.5 - 0.015), _paint,
		Vector3(deg_to_rad(-16.0), 0.0, 0.0), 0.010)
	# Верх: карбоновая накладка с оранжевыми полосами.
	_rbox(root, Vector3(deck_w - 0.020, 0.007, deck_len - 0.03),
		Vector3(0.0, deck_top + 0.004, z0), _tape, Vector3.ZERO, 0.003)
	for side in [-1.0, 1.0]:
		_rbox(root, Vector3(0.020, 0.004, deck_len - 0.10),
			Vector3(side * 0.052, deck_top + 0.008, z0), _accent, Vector3.ZERO, 0.002)
		# Оранжевая кромка по борту и белая полоса-логотип.
		_rbox(root, Vector3(0.006, 0.010, deck_len - 0.02),
			Vector3(side * (deck_w * 0.5 - 0.003), deck_top - 0.016, z0), _accent,
			Vector3.ZERO, 0.002)
		_rbox(root, Vector3(0.005, 0.028, 0.150),
			Vector3(side * (deck_w * 0.5 + 0.001), deck_top * 0.40, z0 - 0.02), _tape,
			Vector3.ZERO, 0.002)
		_label(root, "KUGOO", Vector3(side * (deck_w * 0.5 + 0.004), deck_top * 0.40, z0 + 0.13),
			Vector3(0.0, 90.0 * side, 0.0), 0.00034, Color(0.92, 0.93, 0.95))
		# Косые оранжевые штрихи графики.
		for k in 3:
			_rbox(root, Vector3(0.005, 0.030, 0.010),
				Vector3(side * (deck_w * 0.5 + 0.001), deck_top * 0.62, z0 - 0.20 + 0.035 * float(k)),
				_accent, Vector3(deg_to_rad(38.0), 0.0, 0.0), 0.002)
	# Задняя пятка.
	_rbox(root, Vector3(deck_w - 0.018, 0.026, 0.05),
		Vector3(0.0, deck_top * 0.28, z0 + deck_len * 0.5 + 0.02), _paint,
		Vector3(deg_to_rad(-22.0), 0.0, 0.0), 0.008)


## Батарейный блок под кормой деки — на фото F3 он висит снизу.
func _battery_box(root: Node3D) -> void:
	_rbox(root, Vector3(deck_w - 0.045, 0.055, 0.22),
		Vector3(0.0, -0.030, deck_len * 0.5 - 0.07), _plastic, Vector3.ZERO, 0.008)
	_rbox(root, Vector3(deck_w - 0.060, 0.006, 0.180),
		Vector3(0.0, -0.060, deck_len * 0.5 - 0.07), _accent, Vector3.ZERO, 0.002)


func _rear_arm(root: Node3D) -> void:
	var pivot := Vector3(ARM_X, deck_top * 0.74, deck_len * 0.5 - 0.05)
	var axle := Vector3(ARM_X, 0.0, base * 0.5)
	# Оранжевый рычаг: балка + косынка + усиление.
	_plate_between(root, pivot, axle, 0.070, 0.026, _accent)
	_plate_between(root, pivot + Vector3(0.0, 0.0, 0.10), axle + Vector3(0.0, 0.035, 0.0),
		0.032, 0.016, _accent)
	_cyl(root, 0.022, 0.056, pivot, _rim, Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(root, 0.017, 0.062, axle, _alu, Vector3(0.0, 0.0, deg_to_rad(90.0)), 12)
	# Красный суппорт сбоку колеса.
	_rbox(root, Vector3(0.026, 0.048, 0.034),
		Vector3(ARM_X + 0.020, radius * 0.30, base * 0.5 + 0.10), _caliper,
		Vector3(deg_to_rad(-12.0), 0.0, 0.0), 0.004)
	# Амортизатор.
	_shock(root, Vector3(0.048, deck_top + 0.005, deck_len * 0.5 - 0.15),
		Vector3(0.048, 0.040, base * 0.5 - 0.070), 0.013, _accent)


func _rear_step(root: Node3D) -> void:
	var tilt := Vector3(deg_to_rad(-22.0), 0.0, 0.0)
	var pos := Vector3(0.0, deck_top + 0.125, deck_len * 0.5 + 0.11)
	_rbox(root, Vector3(0.180, 0.024, 0.215), pos, _paint, tilt, 0.008)
	_rbox(root, Vector3(0.162, 0.008, 0.185), pos + Vector3(0.0, 0.015, -0.004), _tape, tilt, 0.003)
	for side in [-1.0, 1.0]:
		_rbox(root, Vector3(0.006, 0.018, 0.205),
			pos + Vector3(side * 0.091, -0.004, 0.0), _accent, tilt, 0.002)
		_rbox(root, Vector3(0.016, 0.012, 0.012),
			pos + Vector3(side * 0.078, 0.002, 0.104), _amber, tilt, 0.003)
	var low := Vector3(0.0, deck_top - 0.015, deck_len * 0.5 - 0.015)
	_plate_between(root, low, Vector3(0.0, pos.y - 0.032, pos.z - 0.070), 0.072, 0.020, _paint)
	_plate_between(root, Vector3(0.0, 0.050, base * 0.5 - 0.080),
		Vector3(0.0, pos.y - 0.032, pos.z + 0.012), 0.050, 0.018, _accent)
	_cyl(root, 0.011, 0.150, low, _steel, Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	_tail_light(root, pos + Vector3(0.0, 0.004, 0.112), Vector3(0.080, 0.018, 0.012),
		_tail, tilt)


func _rear_fender(root: Node3D) -> void:
	var center := Vector3(0.0, 0.0, base * 0.5)
	_fender(root, center, radius + 0.012, radius + 0.020, -18.0, 130.0, _plastic, 18, 0.014)
	_plate_between(root, Vector3(ARM_X - 0.006, 0.050, base * 0.5 + 0.10),
		Vector3(0.0, radius + 0.028, base * 0.5 + 0.06), 0.028, 0.012, _rim)


func _kickstand(root: Node3D) -> void:
	var top := Vector3(-0.070, deck_top * 0.20, 0.04)
	var foot := Vector3(-0.150, -radius * 0.92, 0.13)
	_plate_between(root, top, foot, 0.024, 0.015, _rim)
	_cyl(root, 0.011, 0.038, top, _steel, Vector3(0.0, 0.0, deg_to_rad(90.0)), 12)


func _build_steer(root: Node3D) -> Node3D:
	var steer := Node3D.new()
	steer.name = "FrontSteer"
	steer.position = Vector3(0.0, 0.0, steer_z)
	root.add_child(steer)

	var axle := Vector3(0.0, 0.0, -(base * 0.5 + steer_z))
	var rake := deg_to_rad(spec.stem_rake_deg)
	var stem_top_z := 0.03 + tan(rake) * (BAR_Y - STEM_BASE_Y)

	_triangle_neck(steer)
	_front_arm(steer, axle)
	_stem(steer, rake, stem_top_z)
	_wheel(steer, axle, "Wheel", true, -1.0, _rim)
	# Переднее крыло (у F3 оно есть).
	_fender(steer, axle, radius + 0.012, radius + 0.020, -20.0, 122.0, _plastic, 18, 0.014)
	_plate_between(steer, Vector3(ARM_X, 0.06, axle.z + 0.06),
		Vector3(0.0, radius + 0.03, axle.z + 0.10), 0.026, 0.012, _rim)

	_marker(steer, "BarLeft", Vector3(-0.198, BAR_Y, stem_top_z))
	_marker(steer, "BarRight", Vector3(0.198, BAR_Y, stem_top_z))
	return steer


## Характерный для F3 угловатый «стакан»: толстый блок от деки к стойке
## плюс площадка над передним колесом.
func _triangle_neck(steer: Node3D) -> void:
	_rbox(steer, Vector3(0.112, 0.235, 0.125), Vector3(0.0, 0.235, 0.070), _paint,
		Vector3(deg_to_rad(-26.0), 0.0, 0.0), 0.012)
	_rbox(steer, Vector3(0.100, 0.10, 0.085), Vector3(0.0, STEM_BASE_Y - 0.045, 0.045),
		_paint, Vector3.ZERO, 0.010)
	# Наклонная балка вдоль низа к рычагу.

	# Чёрный кожух над колесом и брызговик.
	_rbox(steer, Vector3(0.084, 0.085, 0.075), Vector3(0.0, 0.115, 0.005), _plastic,
		Vector3(deg_to_rad(-20.0), 0.0, 0.0), 0.008)
	# Оранжевая накладка на стакане.
	_rbox(steer, Vector3(0.030, 0.075, 0.010), Vector3(0.0, 0.245, 0.020), _accent,
		Vector3(deg_to_rad(-26.0), 0.0, 0.0), 0.003)


func _front_arm(steer: Node3D, axle: Vector3) -> void:
	var pivot := Vector3(ARM_X, 0.125, -0.185)
	_plate_between(steer, pivot, Vector3(ARM_X, 0.0, axle.z + 0.02), 0.060, 0.024, _accent)
	_plate_between(steer, pivot + Vector3(0.0, 0.0, 0.05),
		Vector3(ARM_X, 0.005, axle.z + 0.10), 0.030, 0.014, _accent)
	_cyl(steer, 0.021, 0.052, pivot, _rim, Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(steer, 0.016, 0.060, axle + Vector3(ARM_X, 0.0, 0.0), _alu,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 12)
	# Пружинный амортизатор от стакана к рычагу.
	_shock(steer, Vector3(0.050, 0.205, -0.175), Vector3(0.050, 0.035, axle.z + 0.165),
		0.014, _accent)
	# Красный суппорт.
	_rbox(steer, Vector3(0.024, 0.044, 0.030),
		Vector3(ARM_X + 0.018, radius * 0.30, axle.z + 0.095), _caliper,
		Vector3(deg_to_rad(-14.0), 0.0, 0.0), 0.004)


func _stem(steer: Node3D, rake: float, top_z: float) -> void:
	var bottom := Vector3(0.0, STEM_BASE_Y, 0.035)
	var top := Vector3(0.0, BAR_Y, top_z)
	_plate_between(steer, bottom, top, 0.058, 0.044, _paint)
	_plate_between(steer, bottom, bottom.lerp(top, 0.30), 0.072, 0.054, _paint)
	# Большая оранжевая графика с белой стрелкой — визитная карточка F3.
	var mid := bottom.lerp(top, 0.52)
	for side in [-1.0, 1.0]:
		_rbox(steer, Vector3(0.005, 0.46, 0.022), mid + Vector3(side * 0.024, 0.0, 0.0),
			_accent, Vector3(rake, 0.0, 0.0), 0.002)
		_label(steer, spec.brand_text, mid + Vector3(side * 0.028, 0.010, 0.0),
			Vector3(0.0, 90.0 * side, 90.0), 0.00040, Color(0.14, 0.14, 0.16))

	# Фара на стойке с кронштейном (так на фото F3).
	var lamp_y := STEM_BASE_Y + 0.36
	var lamp_z := 0.035 + tan(rake) * (lamp_y - STEM_BASE_Y) - 0.045
	_plate_between(steer, Vector3(0.0, lamp_y, lamp_z + 0.04), Vector3(0.0, lamp_y, lamp_z),
		0.030, 0.016, _rim)
	_headlight(steer, Vector3(0.0, lamp_y, lamp_z), 0.030)
	# Замок складывания с оранжевым рычагом.
	var collar := bottom + Vector3(0.0, 0.045, 0.0)
	_rbox(steer, Vector3(0.086, 0.100, 0.082), collar, _rim, Vector3(rake, 0.0, 0.0), 0.008)
	for bolt_z in [-0.026, 0.026]:
		for bolt_y in [-0.028, 0.028]:
			_cyl(steer, 0.006, 0.094, collar + Vector3(0.0, bolt_y, bolt_z), _steel,
				Vector3(0.0, 0.0, deg_to_rad(90.0)), 6)
	var lever_y := STEM_BASE_Y + 0.20
	var lever_z := 0.035 + tan(rake) * (lever_y - STEM_BASE_Y)
	_cyl(steer, 0.013, 0.096, Vector3(0.0, lever_y, lever_z), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	_rbox(steer, Vector3(0.016, 0.024, 0.078), Vector3(0.0, lever_y, lever_z + 0.042), _accent,
		Vector3(deg_to_rad(-26.0), 0.0, 0.0), 0.004)
	# Руль и бортовой компьютер.
	var bar_z := top.z
	_rbox(steer, Vector3(0.076, 0.055, 0.068), Vector3(0.0, BAR_Y - 0.032, bar_z), _rim,
		Vector3.ZERO, 0.008)
	_bar_basic(steer, BAR_Y, bar_z)
	_grips(steer, BAR_Y, bar_z)
	_lever(steer, -1.0, BAR_Y, bar_z)
	_lever(steer, 1.0, BAR_Y, bar_z)
	_throttle(steer, 1.0, BAR_Y, bar_z)
	_dash(steer, BAR_Y, bar_z, 1.15)
	# Жгут тросов: на F3 он хорошо виден вдоль стойки.
	for side in [-1.0, 1.0]:
		_tube(steer, [
			Vector3(side * 0.112, BAR_Y - 0.020, bar_z + 0.008),
			Vector3(side * 0.074, BAR_Y - 0.110, bar_z + 0.040),
			Vector3(side * 0.050, STEM_BASE_Y + 0.22, 0.095),
			Vector3(side * 0.040, 0.160, 0.115),
		], 0.006, _plastic, 6)
	_tube(steer, [
		Vector3(-0.104, BAR_Y - 0.010, bar_z - 0.020),
		Vector3(-0.080, 0.640, 0.120),
		Vector3(-0.060, 0.300, 0.090),
		Vector3(-0.050, 0.130, -0.060),
		Vector3(-0.032, 0.050, -(base * 0.5 + steer_z) + 0.12),
	], 0.0048, _plastic, 6)
