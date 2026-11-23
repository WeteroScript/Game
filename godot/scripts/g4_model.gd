## KuKirin G4: серый gunmetal корпус, длинная дека-короб с оранжевыми шевронами,
## односторонние рычаги подвески спереди и сзади, почти вертикальная стойка,
## приподнятая задняя площадка и высокий руль. Всё — по фото продукта.
class_name G4Model
extends ScooterModelBase

const STEM_BASE_Y := 0.41
const BAR_Y := 1.14
const ARM_X := 0.086


func _build_body(root: Node3D) -> void:
	_deck(root)
	_rear_arm(root)
	_rear_step(root)
	_rear_fender(root)
	_kickstand(root)
	_wheel(root, Vector3(0.0, 0.0, base * 0.5), "RearWheel", true, -1.0, _rim)
	_marker(root, "FootLeft", Vector3(-0.070, deck_top + 0.020, -0.10))
	_marker(root, "FootRight", Vector3(0.070, deck_top + 0.020, 0.10))


func _deck(root: Node3D) -> void:
	var z0 := 0.04
	# Короб-аккумулятор: низ на уровне осей, скруглённые рёбра.
	_rbox(root, Vector3(deck_w, deck_top, deck_len), Vector3(0.0, deck_top * 0.5, z0),
		_paint, Vector3.ZERO, 0.016)
	# Нос деки: скос вниз, к которому крепится рычаг.
	_rbox(root, Vector3(deck_w - 0.012, deck_top * 0.72, 0.10),
		Vector3(0.0, deck_top * 0.34, z0 - deck_len * 0.5 - 0.02), _paint,
		Vector3(deg_to_rad(-18.0), 0.0, 0.0), 0.012)
	# Гриптейп тремя полосами.
	for i in 3:
		var strip_z := z0 + (float(i) - 1.0) * 0.19
		_box(root, Vector3(deck_w - 0.028, 0.006, 0.175),
			Vector3(0.0, deck_top + 0.004, strip_z), _tape)
	# Оранжевая кромка по верху борта.
	for side in [-1.0, 1.0]:
		_rbox(root, Vector3(0.006, 0.012, deck_len - 0.02),
			Vector3(side * (deck_w * 0.5 - 0.004), deck_top - 0.004, z0), _accent,
			Vector3.ZERO, 0.002)
		# Чёрный молдинг по низу борта.
		_rbox(root, Vector3(0.008, 0.020, deck_len - 0.06),
			Vector3(side * (deck_w * 0.5 - 0.002), 0.020, z0), _plastic,
			Vector3.ZERO, 0.003)
	# Шевроны и надписи по бортам.
	for side in [-1.0, 1.0]:
		var x: float = side * (deck_w * 0.5 + 0.002)
		for chevron_z in [-deck_len * 0.5 + 0.075, deck_len * 0.5 - 0.075]:
			for offset in [-0.020, 0.0, 0.020]:
				_rbox(root, Vector3(0.006, 0.034, 0.013),
					Vector3(x, deck_top * 0.62, z0 + chevron_z + offset), _accent,
					Vector3(deg_to_rad(40.0), 0.0, 0.0), 0.002)
		_label(root, "B-05-1", Vector3(x, deck_top * 0.60, z0 - 0.045),
			Vector3(0.0, 90.0 * side, 0.0), 0.00030, Color(0.98, 0.45, 0.08))
		_label(root, spec.brand_text, Vector3(x, deck_top * 0.36, z0 + 0.145),
			Vector3(0.0, 90.0 * side, 0.0), 0.00026, Color(0.78, 0.80, 0.83))
		# Шильдик с характеристиками.
		_rbox(root, Vector3(0.004, 0.038, 0.085),
			Vector3(x, deck_top * 0.42, z0 + 0.215), _rim, Vector3.ZERO, 0.002)
	# Замок зажигания на борту у носа.
	_cyl(root, 0.012, 0.010, Vector3(deck_w * 0.5 + 0.004, deck_top * 0.55, z0 - 0.19),
		_steel, Vector3(0.0, 0.0, deg_to_rad(90.0)), 12)
	# Задняя «пятка» деки под площадку.
	_rbox(root, Vector3(deck_w - 0.02, 0.030, 0.05),
		Vector3(0.0, deck_top * 0.30, z0 + deck_len * 0.5 + 0.02), _paint,
		Vector3(deg_to_rad(-20.0), 0.0, 0.0), 0.008)


func _rear_arm(root: Node3D) -> void:
	var pivot := Vector3(ARM_X, deck_top * 0.78, deck_len * 0.5 - 0.06)
	var axle := Vector3(ARM_X, 0.0, base * 0.5)
	# Односторонний рычаг: толстая балка с фаской и косынкой.
	_plate_between(root, pivot, axle, 0.050, 0.019, _paint)
	_plate_between(root, pivot + Vector3(0.0, 0.0, 0.10), axle + Vector3(0.0, 0.03, 0.0),
		0.030, 0.014, _paint)
	_cyl(root, 0.017, 0.040, pivot, _rim, Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(root, 0.016, 0.060, axle, _alu, Vector3(0.0, 0.0, deg_to_rad(90.0)), 12)
	# Наклейки на рычаге: шеврон и «G4».
	_label(root, "G4", Vector3(pivot.x + 0.014, 0.055, pivot.z + 0.075),
		Vector3(0.0, 90.0, -70.0), 0.00028, Color(0.98, 0.45, 0.08))
	_rbox(root, Vector3(0.004, 0.016, 0.030), Vector3(pivot.x + 0.014, 0.045, pivot.z + 0.115),
		_accent, Vector3(0.0, 0.0, deg_to_rad(-20.0)), 0.002)
	# Амортизатор: от деки к середине рычага.
	_shock(root, Vector3(0.052, deck_top + 0.01, deck_len * 0.5 - 0.16),
		Vector3(0.052, 0.042, base * 0.5 - 0.075), 0.014, _accent)


func _rear_step(root: Node3D) -> void:
	var tilt := Vector3(deg_to_rad(-20.0), 0.0, 0.0)
	var pos := Vector3(0.0, deck_top + 0.120, deck_len * 0.5 + 0.11)
	_rbox(root, Vector3(0.185, 0.024, 0.215), pos, _paint, tilt, 0.008)
	_rbox(root, Vector3(0.168, 0.008, 0.190), pos + Vector3(0.0, 0.015, -0.004), _tape, tilt, 0.003)
	for side in [-1.0, 1.0]:
		_rbox(root, Vector3(0.006, 0.016, 0.19),
			pos + Vector3(side * 0.089, -0.004, 0.0), _accent, tilt, 0.002)
	# Кронштейн: две тяги + болт.
	var low := Vector3(0.0, deck_top - 0.02, deck_len * 0.5 - 0.02)
	_plate_between(root, low, Vector3(0.0, pos.y - 0.030, pos.z - 0.065), 0.058, 0.017, _paint)
	_plate_between(root, Vector3(0.0, 0.055, base * 0.5 - 0.075),
		Vector3(0.0, pos.y - 0.030, pos.z + 0.010), 0.048, 0.018, _paint)
	_cyl(root, 0.011, 0.148, low, _steel, Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	# Стоп-сигнал на корме площадки.
	_tail_light(root, pos + Vector3(0.0, 0.004, 0.104), Vector3(0.075, 0.020, 0.012),
		_tail, tilt)
	# Поворотники по краям.
	for side in [-1.0, 1.0]:
		_rbox(root, Vector3(0.020, 0.014, 0.010),
			pos + Vector3(side * 0.078, 0.002, 0.100), _amber, tilt, 0.003)


func _rear_fender(root: Node3D) -> void:
	var center := Vector3(0.0, 0.0, base * 0.5)
	_fender(root, center, radius + 0.008, radius + 0.015, -30.0, 136.0, _plastic, 26, 0.010)
	# Кронштейн крыла к рычагу.
	_plate_between(root, Vector3(ARM_X - 0.006, 0.055, base * 0.5 + 0.10),
		Vector3(0.0, radius + 0.03, base * 0.5 + 0.05), 0.030, 0.012, _rim)
	# Фонарь на крыле.
	_tail_light(root, Vector3(0.0, radius * 0.62, base * 0.5 + 0.155),
		Vector3(0.06, 0.018, 0.010), _tail, Vector3(deg_to_rad(-30.0), 0.0, 0.0))


func _kickstand(root: Node3D) -> void:
	var top := Vector3(-0.075, deck_top * 0.22, 0.06)
	var foot := Vector3(-0.155, -radius * 0.92, 0.15)
	_plate_between(root, top, foot, 0.026, 0.016, _rim)
	_cyl(root, 0.012, 0.040, top, _steel, Vector3(0.0, 0.0, deg_to_rad(90.0)), 12)
	_rbox(root, Vector3(0.024, 0.010, 0.040), foot + Vector3(0.0, -0.002, 0.0), _plastic,
		Vector3.ZERO, 0.003)


func _build_steer(root: Node3D) -> Node3D:
	var steer := Node3D.new()
	steer.name = "FrontSteer"
	steer.position = Vector3(0.0, 0.0, steer_z)
	root.add_child(steer)

	var axle := Vector3(0.0, 0.0, -(base * 0.5 + steer_z))
	_neck(steer)
	_front_arm(steer, axle)
	_stem(steer, axle)

	_wheel(steer, axle, "Wheel", false, -1.0, _rim)
	# Маркеры руля для IK рук райдера.
	var stem_top_z := 0.02 + tan(deg_to_rad(spec.stem_rake_deg)) * (BAR_Y - STEM_BASE_Y)
	_marker(steer, "BarLeft", Vector3(-0.200, BAR_Y, stem_top_z))
	_marker(steer, "BarRight", Vector3(0.200, BAR_Y, stem_top_z))
	return steer


func _neck(steer: Node3D) -> void:
	# Горловина: широкая косынка у деки, узкий стакан сверху — без «крыльев».
	_rbox(steer, Vector3(0.096, 0.205, 0.108), Vector3(0.0, 0.145, 0.058), _paint,
		Vector3(deg_to_rad(-11.0), 0.0, 0.0), 0.012)
	_rbox(steer, Vector3(0.064, 0.240, 0.066), Vector3(0.0, 0.330, 0.036), _paint,
		Vector3(deg_to_rad(-7.0), 0.0, 0.0), 0.010)
	# Рёбра по бокам косынки.
	for side in [-1.0, 1.0]:
		_rbox(steer, Vector3(0.008, 0.190, 0.096), Vector3(side * 0.050, 0.148, 0.058),
			_paint_dark, Vector3(deg_to_rad(-11.0), 0.0, 0.0), 0.004)
	# Компактный чёрный грязевик под стаканом.
	_rbox(steer, Vector3(0.058, 0.062, 0.058), Vector3(0.0, 0.108, 0.030), _plastic,
		Vector3(deg_to_rad(-18.0), 0.0, 0.0), 0.007)
	# Фара в носу + оранжевая кромка.
	_headlight(steer, Vector3(0.0, 0.180, 0.086), 0.026)
	_rbox(steer, Vector3(0.070, 0.011, 0.013), Vector3(0.0, 0.166, 0.098), _accent,
		Vector3(deg_to_rad(-14.0), 0.0, 0.0), 0.002)


func _front_arm(steer: Node3D, axle: Vector3) -> void:
	var pivot := Vector3(ARM_X, 0.085, 0.005)
	_plate_between(steer, pivot, Vector3(ARM_X, 0.0, axle.z + 0.02), 0.052, 0.021, _paint_dark)
	_cyl(steer, 0.016, 0.038, pivot, _rim, Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(steer, 0.015, 0.058, axle + Vector3(ARM_X, 0.0, 0.0), _alu,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 12)
	# Амортизатор от стакана к рычагу.
	_shock(steer, Vector3(0.046, 0.215, 0.045), Vector3(0.046, 0.035, axle.z + 0.175),
		0.013, _accent)
	# Наклейки рычага.
	_label(steer, "G4", Vector3(ARM_X + 0.013, 0.060, axle.z + 0.130),
		Vector3(0.0, 90.0, 62.0), 0.00026, Color(0.98, 0.45, 0.08))


func _stem(steer: Node3D, axle: Vector3) -> void:
	var rake := deg_to_rad(spec.stem_rake_deg)
	var bottom := Vector3(0.0, STEM_BASE_Y, 0.02)
	var top := Vector3(0.0, BAR_Y, 0.02 + tan(rake) * (BAR_Y - STEM_BASE_Y))
	# Основная труба и утолщение у основания.
	_plate_between(steer, bottom, top, 0.070, 0.050, _paint)
	_plate_between(steer, bottom, bottom.lerp(top, 0.22), 0.074, 0.052, _paint)
	# Замок складывания: воротник, шарнир, болты, оранжевый рычаг.
	var collar := bottom + Vector3(0.0, 0.035, 0.0)
	_rbox(steer, Vector3(0.078, 0.088, 0.078), collar, _rim, Vector3(rake, 0.0, 0.0), 0.008)
	for bolt_z in [-0.030, 0.030]:
		for bolt_y in [-0.030, 0.030]:
			_cyl(steer, 0.0060, 0.086, collar + Vector3(0.0, bolt_y, bolt_z), _steel,
				Vector3(0.0, 0.0, deg_to_rad(90.0)), 6)
	_cyl(steer, 0.009, 0.088, collar + Vector3(0.0, 0.0, 0.043), _steel,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	var lever_y := STEM_BASE_Y + 0.175
	var lever_z := 0.02 + tan(rake) * (lever_y - STEM_BASE_Y)
	_cyl(steer, 0.012, 0.104, Vector3(0.0, lever_y, lever_z), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	_rbox(steer, Vector3(0.014, 0.020, 0.080), Vector3(0.0, lever_y, lever_z + 0.040), _accent,
		Vector3(deg_to_rad(-24.0), 0.0, 0.0), 0.004)
	# Оранжевая полоса с брендом вдоль стойки.
	var mid := bottom.lerp(top, 0.58)
	for side in [-1.0, 1.0]:
		_rbox(steer, Vector3(0.005, 0.40, 0.016), mid + Vector3(side * 0.026, 0.0, 0.0),
			_accent, Vector3(rake, 0.0, 0.0), 0.002)
		_label(steer, spec.brand_text, mid + Vector3(side * 0.030, 0.010, 0.0),
			Vector3(0.0, 90.0 * side, 90.0), 0.00058, Color(0.95, 0.95, 0.96))
	# Верхняя площадка под руль и сам руль.
	var bar_z := top.z
	_rbox(steer, Vector3(0.070, 0.052, 0.062), Vector3(0.0, BAR_Y - 0.030, bar_z), _rim,
		Vector3.ZERO, 0.008)
	_bar_basic(steer, BAR_Y, bar_z)
	_grips(steer, BAR_Y, bar_z)
	_lever(steer, -1.0, BAR_Y, bar_z)
	_lever(steer, 1.0, BAR_Y, bar_z)
	_throttle(steer, 1.0, BAR_Y, bar_z)
	_bell(steer, BAR_Y, bar_z)
	_dash(steer, BAR_Y, bar_z, 0.85)
	# Тросы от руля вниз по стойке.
	for side in [-1.0, 1.0]:
		_tube(steer, [
			Vector3(side * 0.108, BAR_Y - 0.020, bar_z + 0.010),
			Vector3(side * 0.070, BAR_Y - 0.090, bar_z + 0.030),
			Vector3(side * 0.048, STEM_BASE_Y + 0.24, 0.062),
			Vector3(side * 0.040, 0.185, 0.098),
		], 0.0055, _plastic, 6)
	# Шланг переднего тормоза к суппорту.
	_tube(steer, [
		Vector3(-0.100, BAR_Y - 0.010, bar_z - 0.020),
		Vector3(-0.070, 0.700, 0.060),
		Vector3(-0.052, 0.330, 0.070),
		Vector3(-0.048, 0.150, -0.070),
		Vector3(-0.030, 0.055, axle.z + 0.14),
	], 0.0045, _plastic, 6)
