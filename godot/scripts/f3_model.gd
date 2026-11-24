## Kugoo F3 Pro Max: 10" колёса с оранжевыми кольцами на дисках, чёрный корпус
## с оранжевыми рычагами, заваленная назад стойка с графикой, переднее крыло,
## приподнятая задняя площадка, пружины под декой и на подвеске. Всё — по фото.
class_name F3Model
extends ScooterModelBase

const STEM_BASE_Y := 0.36
const BAR_Y := 1.19
const ARM_X := 0.078
const DECK_Z := 0.03
const STEP_Y := 0.238

## Полуширина деки по длине: по ней ставятся кант, полосы и надписи.
const DECK_HALF := [
	[-0.348, 0.070], [-0.298, 0.092], [-0.200, 0.103], [0.0, 0.105],
	[0.170, 0.103], [0.238, 0.092], [0.282, 0.075],
]


func _build_body(root: Node3D) -> void:
	_deck(root)
	_rear_step(root)
	_rear_arm(root)
	_rear_hugger(root)
	_under_spring(root)
	_wheel(root, Vector3(0.0, 0.0, base * 0.5), "RearWheel", true, 1.0, _rim, true, true)
	_marker(root, "FootLeft", Vector3(-0.070, deck_top + 0.014, -0.09))
	_marker(root, "FootRight", Vector3(0.070, deck_top + 0.014, 0.10))


## Полуширина деки на заданном z — чтобы графика лежала на её боку.
func _half_at(z_local: float) -> float:
	for i in DECK_HALF.size() - 1:
		var a: Array = DECK_HALF[i]
		var b: Array = DECK_HALF[i + 1]
		if z_local >= float(a[0]) and z_local <= float(b[0]):
			var t: float = (z_local - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), t)
	if z_local < float(DECK_HALF[0][0]):
		return float(DECK_HALF[0][1])
	return float(DECK_HALF[DECK_HALF.size() - 1][1])


# ---- дека --------------------------------------------------------------------
func _deck(root: Node3D) -> void:
	var white := _mat(Color(0.90, 0.91, 0.93), 0.10, 0.30)
	var sections := [
		{"pos": Vector3(0.0, 0.118, DECK_Z - 0.348), "w": 0.140, "h": 0.066, "r": 0.022},
		{"pos": Vector3(0.0, 0.100, DECK_Z - 0.298), "w": 0.184, "h": 0.100, "r": 0.026},
		{"pos": Vector3(0.0, 0.090, DECK_Z - 0.200), "w": 0.206, "h": 0.114, "r": 0.028},
		{"pos": Vector3(0.0, 0.088, DECK_Z), "w": 0.210, "h": 0.118, "r": 0.028},
		{"pos": Vector3(0.0, 0.092, DECK_Z + 0.170), "w": 0.206, "h": 0.112, "r": 0.028},
		{"pos": Vector3(0.0, 0.104, DECK_Z + 0.238), "w": 0.184, "h": 0.088, "r": 0.024},
		{"pos": Vector3(0.0, 0.122, DECK_Z + 0.282), "w": 0.150, "h": 0.058, "r": 0.018},
	]
	var shell := _loft_rect(root, sections, _paint)
	shell.name = "Deck"
	# Настил: тёмный гриптейп с оранжевыми продольными полосами.
	_box(root, Vector3(0.146, 0.007, 0.404), Vector3(0.0, 0.151, DECK_Z - 0.004), _tape)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.018, 0.004, 0.396),
			Vector3(side * 0.050, 0.155, DECK_Z - 0.004), _accent)
	# Оранжевая кромка по борту, белая полоса и надписи.
	for side in [-1.0, 1.0]:
		var yaw: float = 90.0 * side
		# Оранжевый кант по обводу и чёрный молдинг снизу.
		for k in 5:
			var bz: float = -0.290 + 0.118 * float(k)
			_rbox(root, Vector3(0.006, 0.012, 0.122),
				Vector3(side * (_half_at(bz) + 0.002), 0.130, DECK_Z + bz), _accent,
				Vector3.ZERO, 0.003)
		for k in 4:
			var mz: float = -0.280 + 0.146 * float(k)
			_rbox(root, Vector3(0.008, 0.020, 0.152),
				Vector3(side * (_half_at(mz) + 0.001), 0.048, DECK_Z + mz), _plastic,
				Vector3.ZERO, 0.005)
		# Белая полоса-панель и надписи на боку деки.
		var wz: float = 0.040
		_rbox(root, Vector3(0.004, 0.020, 0.170),
			Vector3(side * (_half_at(wz) + 0.002), 0.096, DECK_Z + wz), white,
			Vector3.ZERO, 0.002)
		var lz: float = 0.140
		_label(root, spec.brand_text, Vector3(side * (_half_at(lz) + 0.004), 0.110, DECK_Z + lz),
			Vector3(0.0, yaw, 0.0), 0.00046, Color(0.92, 0.93, 0.95))
		var pz: float = 0.052
		_label(root, "PRO MAX", Vector3(side * (_half_at(pz) + 0.004), 0.082, DECK_Z + pz),
			Vector3(0.0, yaw, 0.0), 0.00026, Color(0.14, 0.14, 0.16))
		# Косые оранжевые штрихи у носа.
		for k in 3:
			var cz: float = -0.196 + 0.036 * float(k)
			_rbox(root, Vector3(0.005, 0.026, 0.011),
				Vector3(side * (_half_at(cz) + 0.002), 0.104, DECK_Z + cz), _accent,
				Vector3(deg_to_rad(40.0), 0.0, 0.0), 0.002)
	# Аккумуляторный блок под кормой и рёбра.
	_rbox(root, Vector3(0.152, 0.034, 0.240), Vector3(0.0, 0.014, DECK_Z + 0.060),
		_paint_dark, Vector3.ZERO, 0.010)
	_rbox(root, Vector3(0.120, 0.008, 0.200), Vector3(0.0, -0.004, DECK_Z + 0.060),
		_accent, Vector3.ZERO, 0.003)
	# Вентиляционная решётка в носу деки — характерная деталь F3.
	_rbox(root, Vector3(0.030, 0.052, 0.016), Vector3(0.062, 0.096, DECK_Z - 0.200), _rim,
		Vector3(deg_to_rad(-10.0), 0.0, 0.0), 0.004)
	for k in 4:
		_rbox(root, Vector3(0.004, 0.040, 0.010),
			Vector3(0.072 - 0.006 * float(k), 0.096, DECK_Z - 0.206), _plastic,
			Vector3(deg_to_rad(-10.0), 0.0, 0.0), 0.002)


# ---- приподнятая задняя площадка --------------------------------------------
func _rear_step(root: Node3D) -> void:
	var tilt := Vector3(deg_to_rad(-10.0), 0.0, 0.0)
	var pos := Vector3(0.0, STEP_Y, DECK_Z + 0.352)
	var plate := _rbox(root, Vector3(0.174, 0.024, 0.188), pos, _paint, tilt, 0.010)
	plate.name = "RearStep"
	_rbox(root, Vector3(0.156, 0.008, 0.166), pos + Vector3(0.0, 0.015, -0.004), _tape,
		tilt, 0.004)
	for side in [-1.0, 1.0]:
		_rbox(root, Vector3(0.007, 0.016, 0.176), pos + Vector3(side * 0.082, -0.004, 0.0),
			_accent, tilt, 0.002)
	_beam(root, Vector3(0.0, 0.140, DECK_Z + 0.228), Vector3(0.0, STEP_Y - 0.016, DECK_Z + 0.286),
		Vector2(0.132, 0.028), Vector2(0.144, 0.020), _paint, 0.010, 2)
	for side in [-1.0, 1.0]:
		_rbox(root, Vector3(0.013, 0.052, 0.028),
			Vector3(side * 0.050, STEP_Y - 0.040, DECK_Z + 0.306), _paint,
			Vector3(deg_to_rad(-10.0), 0.0, 0.0), 0.005)
	for side in [-1.0, 1.0]:
		_plate_between(root, Vector3(side * 0.070, 0.040, base * 0.5 - 0.030),
			Vector3(side * 0.074, STEP_Y - 0.018, DECK_Z + 0.400), 0.022, 0.011, _accent)
	_tail_light(root, Vector3(0.0, pos.y + 0.004, pos.z + 0.098), Vector3(0.080, 0.022, 0.012),
		_tail, tilt)
	for side in [-1.0, 1.0]:
		_rbox(root, Vector3(0.020, 0.012, 0.010),
			Vector3(side * 0.058, pos.y + 0.002, pos.z + 0.094), _amber, tilt, 0.003)
	_rbox(root, Vector3(0.140, 0.011, 0.058), Vector3(0.0, pos.y - 0.030, pos.z + 0.056),
		_plastic, tilt, 0.006)


# ---- маятник и корма ---------------------------------------------------------
func _rear_arm(root: Node3D) -> void:
	var pivot_z: float = DECK_Z + 0.240
	var axle_z: float = base * 0.5
	for side in [-1.0, 1.0]:
		var x: float = side * ARM_X
		# Оранжевый маятник: сужается к оси.
		_beam(root, Vector3(x, 0.092, pivot_z), Vector3(x, 0.004, axle_z - 0.030),
			Vector2(0.048, 0.062), Vector2(0.032, 0.044), _accent, 0.010, 3)
		_rbox(root, Vector3(0.010, 0.050, 0.068), Vector3(x, 0.110, pivot_z - 0.032),
			_accent, Vector3(deg_to_rad(18.0), 0.0, 0.0), 0.006)
		# Амортизатор от площадки к рычагу.
		_shock(root, Vector3(x * 0.64, 0.182, DECK_Z + 0.286),
			Vector3(x * 0.64, 0.046, axle_z - 0.070), 0.012, _accent)
	# Шарнир, ось, поперечина.
	_cyl(root, 0.016, ARM_X * 2.0 + 0.028, Vector3(0.0, 0.092, pivot_z), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(root, 0.014, ARM_X * 2.0 + 0.022, Vector3(0.0, 0.004, axle_z - 0.030), _alu,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	_beam(root, Vector3(-ARM_X, 0.036, axle_z - 0.112), Vector3(ARM_X, 0.036, axle_z - 0.112),
		Vector2(0.046, 0.028), Vector2(0.046, 0.028), _paint_dark, 0.008, 2)
	_tube(root, [
		Vector3(-0.064, 0.036, pivot_z - 0.070),
		Vector3(-0.076, -0.018, pivot_z + 0.050),
		Vector3(-0.068, -0.008, axle_z - 0.116),
		Vector3(-0.028, 0.002, axle_z - 0.012),
	], 0.0052, _plastic, 7)


## Пружина-коромысло под декой — характерная деталь F3.
func _under_spring(root: Node3D) -> void:
	_shock(root, Vector3(0.0, 0.020, DECK_Z + 0.080),
		Vector3(0.0, -0.010, DECK_Z + 0.222), 0.011, _accent)
	_rbox(root, Vector3(0.086, 0.014, 0.020), Vector3(0.0, 0.026, DECK_Z + 0.072),
		_rim, Vector3.ZERO, 0.004)
	_rbox(root, Vector3(0.066, 0.012, 0.018), Vector3(0.0, -0.004, DECK_Z + 0.218),
		_rim, Vector3.ZERO, 0.004)


func _rear_hugger(root: Node3D) -> void:
	var center := Vector3(0.0, 0.0, base * 0.5)
	_fender(root, center, radius + 0.012, 0.156, -84.0, 68.0, _plastic, 20, 0.012)
	for side in [-1.0, 1.0]:
		_plate_between(root, Vector3(side * (ARM_X - 0.004), 0.056, base * 0.5 + 0.052),
			Vector3(side * 0.046, radius + 0.026, base * 0.5 + 0.020), 0.018, 0.010, _rim)
	_rbox(root, Vector3(0.100, 0.046, 0.010),
		Vector3(0.0, radius * 0.28, base * 0.5 + radius * 0.88), _plastic,
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
	_wheel(steer, axle, "Wheel", true, -1.0, _rim, true, true)
	# Переднее крыло (у F3 оно есть) с брызговиком.
	_fender(steer, axle, radius + 0.012, 0.150, 92.0, -30.0, _plastic, 18, 0.012)
	for side in [-1.0, 1.0]:
		_plate_between(steer, Vector3(side * (ARM_X - 0.006), 0.070, axle.z + 0.068),
			Vector3(side * 0.044, radius + 0.024, axle.z + 0.028), 0.018, 0.009, _rim)
	_rbox(steer, Vector3(0.094, 0.040, 0.010), Vector3(0.0, radius * 0.22, axle.z - radius * 0.86),
		_plastic, Vector3(deg_to_rad(54.0), 0.0, 0.0), 0.004)
	_marker(steer, "BarLeft", Vector3(-0.198, BAR_Y, top_z))
	_marker(steer, "BarRight", Vector3(0.198, BAR_Y, top_z))
	return steer


func _neck(steer: Node3D) -> void:
	# Компактный угловатый стакан.
	_beam(steer, Vector3(0.0, 0.106, 0.038), Vector3(0.0, 0.302, 0.060),
		Vector2(0.152, 0.140), Vector2(0.084, 0.098), _paint, 0.024, 3, Vector3.BACK)
	_rbox(steer, Vector3(0.128, 0.034, 0.108), Vector3(0.0, 0.100, 0.038), _paint_dark,
		Vector3(deg_to_rad(-10.0), 0.0, 0.0), 0.010)
	# Чёрный кожух перед колесом и оранжевая накладка на стакане.
	_rbox(steer, Vector3(0.066, 0.058, 0.062), Vector3(0.0, 0.126, -0.014), _plastic,
		Vector3(deg_to_rad(-24.0), 0.0, 0.0), 0.010)
	_rbox(steer, Vector3(0.038, 0.086, 0.012), Vector3(0.0, 0.216, -0.008), _accent,
		Vector3(deg_to_rad(-20.0), 0.0, 0.0), 0.004)
	# Габаритный отражатель в носу стакана.
	_rbox(steer, Vector3(0.042, 0.012, 0.008), Vector3(0.0, 0.166, -0.026), _amber,
		Vector3(deg_to_rad(-20.0), 0.0, 0.0), 0.003)


func _front_fork(steer: Node3D, axle: Vector3) -> void:
	_beam(steer, Vector3(-ARM_X - 0.010, 0.205, -0.020), Vector3(ARM_X + 0.010, 0.205, -0.020),
		Vector2(0.072, 0.054), Vector2(0.072, 0.054), _paint_dark, 0.010, 2)
	for side in [-1.0, 1.0]:
		var x: float = side * ARM_X
		# Оранжевый рычаг подвески.
		_beam(steer, Vector3(x, 0.203, -0.020), Vector3(x, 0.004, axle.z + 0.010),
			Vector2(0.052, 0.070), Vector2(0.036, 0.050), _accent, 0.010, 3)
		# Ступичная бобышка на конце рычага.
		_cyl(steer, 0.034, 0.030, Vector3(x - side * 0.004, 0.004, axle.z + 0.010), _rim,
			Vector3(0.0, 0.0, deg_to_rad(90.0)), 18)
		_rbox(steer, Vector3(0.010, 0.044, 0.058), Vector3(x, 0.168, -0.048), _accent,
			Vector3(deg_to_rad(-62.0), 0.0, 0.0), 0.005)
		# Ухо крепления амортизатора.
		_rbox(steer, Vector3(0.028, 0.028, 0.018), Vector3(side * 0.058, 0.238, -0.010),
			_paint_dark, Vector3.ZERO, 0.004)
		# Пружинный амортизатор от стакана к рычагу.
		_shock(steer, Vector3(x, 0.238, -0.010), Vector3(x, 0.096, -0.104),
			0.012, _accent)
	# Шарнир и ось.
	_cyl(steer, 0.016, ARM_X * 2.0 + 0.030, Vector3(0.0, 0.205, -0.020), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(steer, 0.014, ARM_X * 2.0 + 0.028, Vector3(0.0, 0.004, axle.z + 0.010), _alu,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	# Фара на кронштейне — как на фото F3.
	var lamp_y := STEM_BASE_Y + 0.30
	var rake := deg_to_rad(spec.stem_rake_deg)
	var lamp_z: float = 0.060 + tan(rake) * (lamp_y - STEM_BASE_Y) - 0.070
	_beam(steer, Vector3(0.0, lamp_y, lamp_z + 0.062), Vector3(0.0, lamp_y, lamp_z + 0.012),
		Vector2(0.034, 0.020), Vector2(0.040, 0.024), _rim, 0.006, 1)
	_headlight(steer, Vector3(0.0, lamp_y, lamp_z), 0.030)
	_torus(steer, 0.032, 0.040, _accent, Vector3(0.0, deg_to_rad(90.0), 0.0),
		Vector3(0.0, lamp_y, lamp_z - 0.002), 22)


func _stem(steer: Node3D) -> float:
	var rake := deg_to_rad(spec.stem_rake_deg)
	var bottom := Vector3(0.0, STEM_BASE_Y, 0.060)
	var top := Vector3(0.0, BAR_Y, bottom.z + tan(rake) * (BAR_Y - STEM_BASE_Y))
	_beam(steer, bottom, top, Vector2(0.064, 0.032), Vector2(0.050, 0.026), _paint,
		0.009, 5, Vector3.BACK)
	_beam(steer, bottom - Vector3(0.0, 0.026, 0.0), bottom.lerp(top, 0.16),
		Vector2(0.070, 0.042), Vector2(0.066, 0.036), _paint, 0.010, 2, Vector3.BACK)
	# Графика F3: оранжевые полосы со стрелкой и надпись.
	var mid := bottom.lerp(top, 0.50)
	for side in [-1.0, 1.0]:
		_rbox(steer, Vector3(0.005, 0.300, 0.012), mid + Vector3(side * 0.024, 0.020, 0.0),
			_accent, Vector3(rake, 0.0, 0.0), 0.002)
		_rbox(steer, Vector3(0.004, 0.110, 0.008), mid + Vector3(side * 0.025, -0.104, 0.0),
			_accent, Vector3(rake, 0.0, 0.0), 0.002)
		_rbox(steer, Vector3(0.004, 0.024, 0.010), mid + Vector3(side * 0.025, 0.118, 0.0),
			_accent, Vector3(rake + deg_to_rad(34.0), 0.0, 0.0), 0.002)
		_label(steer, spec.brand_text, mid + Vector3(side * 0.028, 0.004, 0.0),
			Vector3(0.0, 90.0 * side, 90.0), 0.00046, Color(0.95, 0.96, 0.97))
	# Замок складывания с эксцентриком.
	var collar := bottom + Vector3(0.0, 0.030, 0.0)
	_rbox(steer, Vector3(0.080, 0.078, 0.072), collar, _rim, Vector3(rake, 0.0, 0.0), 0.010)
	for bolt_y in [-0.022, 0.022]:
		_cyl(steer, 0.0055, 0.086, collar + Vector3(0.0, bolt_y, 0.0), _steel,
			Vector3(0.0, 0.0, deg_to_rad(90.0)), 8)
	_cyl(steer, 0.010, 0.092, collar + Vector3(0.0, 0.0, 0.042), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	_rbox(steer, Vector3(0.014, 0.024, 0.078), collar + Vector3(0.0, -0.006, 0.050), _accent,
		Vector3(deg_to_rad(-26.0), 0.0, 0.0), 0.005)
	var bar_z := top.z
	_rbox(steer, Vector3(0.076, 0.046, 0.060), Vector3(0.0, BAR_Y - 0.026, bar_z), _rim,
		Vector3.ZERO, 0.010)
	for side in [-1.0, 1.0]:
		_cyl(steer, 0.006, 0.012, Vector3(side * 0.023, BAR_Y + 0.002, bar_z - 0.016), _steel,
			Vector3.ZERO, 8)
	_bar_basic(steer, BAR_Y, bar_z)
	_grips(steer, BAR_Y, bar_z)
	_lever(steer, -1.0, BAR_Y, bar_z)
	_lever(steer, 1.0, BAR_Y, bar_z)
	_throttle(steer, 1.0, BAR_Y, bar_z)
	_bell(steer, BAR_Y, bar_z)
	_dash(steer, BAR_Y, bar_z, 1.05)
	_phone_mount(steer, BAR_Y, bar_z, 0.096)
	# Жгут проводки вдоль стойки и шланг переднего тормоза.
	for side in [-1.0, 1.0]:
		_tube(steer, [
			Vector3(side * 0.108, BAR_Y - 0.020, bar_z + 0.010),
			Vector3(side * 0.076, BAR_Y - 0.110, bar_z + 0.042),
			Vector3(side * 0.050, STEM_BASE_Y + 0.220, 0.092),
			Vector3(side * 0.044, 0.190, 0.108),
		], 0.0060, _plastic, 7)
	_tube(steer, [
		Vector3(-0.104, BAR_Y - 0.012, bar_z - 0.022),
		Vector3(-0.080, 0.640, 0.086),
		Vector3(-0.060, 0.340, 0.062),
		Vector3(-0.064, 0.170, -0.046),
		Vector3(-0.036, 0.050, -(base * 0.5 + steer_z) + 0.036),
	], 0.0048, _plastic, 7)
	return bar_z
