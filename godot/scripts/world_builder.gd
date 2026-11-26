## Сборка двух карт из примитивов: «Прямая трасса» и «Город».
## Аналог TrackMap.cs / CityMap.cs, но без префабов: всё строится кодом.
class_name WorldBuilder
extends RefCounted

const ROAD_WIDTH := 12.0
## Длина ровного шоссе: длинный прямой участок без единого бугра.
const FLAT_LENGTH := 1500.0
const FLAT_START_Z := 60.0
const ROAD_TOP := 0.0
## Трамплины на прямой трассе: длина плиты, угол подъёма и ширина.
const RAMP_LENGTH := 5.6
const RAMP_ANGLE := 12.0
const RAMP_WIDTH := 5.2

var _asphalt: StandardMaterial3D
var _concrete: StandardMaterial3D
var _grass: StandardMaterial3D
var _white: StandardMaterial3D
var _orange: StandardMaterial3D
var _metal: StandardMaterial3D
var _brick_a: StandardMaterial3D
var _brick_b: StandardMaterial3D
var _roof: StandardMaterial3D
var _bark: StandardMaterial3D
var _pine: StandardMaterial3D
var _window: StandardMaterial3D
var _ramp: StandardMaterial3D
var _ramp_dark: StandardMaterial3D

## Очередь «добора» сцены: тяжёлые куски (лес, дома) строятся по одному за кадр,
## а не всей картой сразу — прогрузка идёт плавно, без длинного фриза.
var _queue: Array = []


func _init() -> void:
	_asphalt = _mat(Color(0.16, 0.17, 0.19), 0.0, 0.92)
	_concrete = _mat(Color(0.55, 0.55, 0.57), 0.0, 0.85)
	_grass = _mat(Color(0.20, 0.34, 0.16), 0.0, 0.95)
	_white = _mat(Color(0.92, 0.92, 0.9), 0.0, 0.7)
	_orange = _mat(Color(0.95, 0.42, 0.08), 0.1, 0.6, true)
	_metal = _mat(Color(0.62, 0.64, 0.68), 0.75, 0.35)
	_brick_a = _mat(Color(0.72, 0.55, 0.44), 0.0, 0.85)
	_brick_b = _mat(Color(0.82, 0.78, 0.70), 0.0, 0.85)
	_roof = _mat(Color(0.35, 0.18, 0.16), 0.0, 0.8)
	_bark = _mat(Color(0.28, 0.21, 0.15), 0.0, 0.95)
	_pine = _mat(Color(0.13, 0.27, 0.15), 0.0, 0.9)
	# Одно окно на все дома: раньше материал создавался на каждое окно,
	# и в городе набегали сотни лишних материалов.
	_window = _mat(Color(0.15, 0.2, 0.26), 0.3, 0.2)
	_ramp = _mat(Color(0.93, 0.72, 0.12), 0.05, 0.55)
	_ramp_dark = _mat(Color(0.24, 0.25, 0.27), 0.35, 0.6)


func _mat(color: Color, metallic: float, roughness: float, emission := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	return m


## Возвращает словарь с точкой старта: {"spawn": Vector3, "basis": Basis}.
func build(map_id: int, parent: Node3D) -> Dictionary:
	# Одна огромная «земля» под обеими картами: раньше доехавший дальше конца
	# трассы игрок просто падал в пустоту.
	_solid(parent, Vector3(2400.0, 0.3, 2400.0), Vector3(0.0, -0.55, -400.0),
		_grass, Vector3.ZERO, true)

	match map_id:
		GameConfig.MapId.CITY:
			return _build_city(parent)
		GameConfig.MapId.JUMP_PARK:
			return _build_jump_park(parent)
		_:
			return _build_straight_track(parent)


# ---------------------------------------------------------------------------
# Общий строитель статичного блока: меш + коллизия в одном StaticBody3D.
# ---------------------------------------------------------------------------
func _solid(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, offroad := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	if offroad:
		body.add_to_group("offroad")
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body


func _decor(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	parent.add_child(mesh_instance)
	return mesh_instance


func _post(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 10
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = mat
	mesh_instance.position = pos + Vector3(0.0, height * 0.5, 0.0)
	parent.add_child(mesh_instance)


# ---------------------------------------------------------------------------
# Карта 1: прямая трасса с трамплинами, обочинами и отбойниками.
# ---------------------------------------------------------------------------
func _build_straight_track(parent: Node3D, with_landings := false) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "FlatRoad"
	parent.add_child(holder)

	var length := FLAT_LENGTH
	var mid_z := FLAT_START_Z - length * 0.5

	# Асфальт: идеально ровный, во всю длину; трамплины ставятся отдельно
	# поверх него, чтобы не ломать основание.
	_solid(holder, Vector3(ROAD_WIDTH, 0.5, length),
		Vector3(0.0, ROAD_TOP - 0.25, mid_z), _asphalt)

	var post_xforms := []
	var dash_xforms := []
	for side in [-1.0, 1.0]:
		# Грунтовая обочина за отбойником.
		_solid(holder, Vector3(10.0, 0.30, length),
			Vector3(side * (ROAD_WIDTH * 0.5 + 5.5), -0.20, mid_z), _grass,
			Vector3.ZERO, true)
		# Отбойник: две балки на столбах.
		_solid(holder, Vector3(0.14, 0.30, length),
			Vector3(side * (ROAD_WIDTH * 0.5 + 0.55), 0.70, mid_z), _metal)
		_solid(holder, Vector3(0.10, 0.13, length),
			Vector3(side * (ROAD_WIDTH * 0.5 + 0.55), 0.36, mid_z), _metal)
		# Сплошная разметка по краю полосы.
		_decor(holder, Vector3(0.16, 0.02, length),
			Vector3(side * (ROAD_WIDTH * 0.5 - 0.45), ROAD_TOP + 0.012, mid_z), _white)
		var post_z := FLAT_START_Z
		while post_z > FLAT_START_Z - length:
			post_xforms.append(_inst(Vector3(side * (ROAD_WIDTH * 0.5 + 0.55), 0.36, post_z),
				Vector3(0.11, 0.72, 0.11)))
			post_z -= 4.5

	# Прерывистая осевая.
	var dash_z := FLAT_START_Z - 6.0
	while dash_z > FLAT_START_Z - length + 6.0:
		dash_xforms.append(_inst(Vector3(0.0, ROAD_TOP + 0.012, dash_z),
			Vector3(0.22, 0.02, 3.2)))
		dash_z -= 9.0

	# Ровная дорога остаётся ровной: трамплины живут на отдельной карте.
	if with_landings:
		_add_jump_line(holder)

	_add_forest(holder, length)

	# Столбы отбойника и разметку рисуем одним MultiMesh: на телефоне это
	# пара вызовов отрисовки вместо тысячи отдельных узлов.
	_multimesh(holder, _unit_box(), _metal, post_xforms)
	_multimesh(holder, _unit_box(), _white, dash_xforms, false)

	# Спаун почти на асфальте: раньше самокат падал с 0.6 м, бился о дорогу
	# и начинал заезд с «приземления» в счётчике прыжков.
	return {"spawn": Vector3(0.0, 0.14, FLAT_START_Z - 20.0), "basis": Basis.IDENTITY}


## Трамплин: наклонная плита, подпорка под верхней кромкой и разметка
## приземления. Низ верхней грани лежит ровно на асфальте — иначе на въезде
## получается ступенька, и самокат на ней глохнет (в автотесте скорость
## падала с 37 до 3 км/ч, а на второй версии он вообще проваливался под дорогу).
func _add_ramp(parent: Node3D, z: float, angle_deg := RAMP_ANGLE,
		length := RAMP_LENGTH, width := RAMP_WIDTH) -> void:
	var thickness := 0.22
	var angle := deg_to_rad(angle_deg)
	var half := length * 0.5
	var half_thickness := thickness * 0.5
	# Геометрия с проверкой: верхняя грань наклонённой плиты поднимается над
	# её центром на half_thickness * cos(угла) — это вертикальная проекция
	# нормали. Низ верхней грани должен касаться асфальта, иначе на въезде
	# ступенька (сначала 11 см, потом 22 см — самокат на ней глох и проваливался).
	var center_y: float = ROAD_TOP + sin(angle) * half - half_thickness * cos(angle)
	_solid(parent, Vector3(width, thickness, length),
		Vector3(0.0, center_y, z), _ramp, Vector3(angle, 0.0, 0.0))

	# Губа: высота верхней грани на дальнем крае = sin(угла) * длина.
	var lip_y: float = ROAD_TOP + sin(angle) * length
	# Подпорка под высоким краем: без неё плита висит в воздухе.
	_decor(parent, Vector3(width, lip_y - 0.12, 0.6),
		Vector3(0.0, (lip_y - 0.12) * 0.5, z - half + 0.35), _ramp_dark)
	# Полосы по краям плиты — трамплин читается с ходу даже в сумерках.
	for side in [-1.0, 1.0]:
		_decor(parent, Vector3(0.22, 0.06, length),
			Vector3(side * (width * 0.5 - 0.2), center_y + half_thickness * cos(angle) + 0.03, z),
			_white, Vector3(angle, 0.0, 0.0))
	# Разметка приземления: белая полоса за трамплином.
	_decor(parent, Vector3(width, 0.02, 0.25),
		Vector3(0.0, ROAD_TOP + 0.014, z - half - 9.0), _white)


## Джамп-парк: та же ровная дорога, но с пятью трамплинами разной высоты.
## Отдельная карта, чтобы «Ровная дорога» оставалась действительно ровной.
func _build_jump_park(parent: Node3D) -> Dictionary:
	var info := _build_straight_track(parent, true)
	info["spawn"] = Vector3(0.0, 0.14, FLAT_START_Z - 18.0)
	return info


## Пять трамплинов: от маленького разминочного до большого.
func _add_jump_line(parent: Node3D) -> void:
	# Углы подобраны по реальному отрыву: на 10° самокат почти не улетал
	# (0.2 с в воздухе), на 16–20° уже хватает на JUMP и вращение.
	_add_ramp(parent, FLAT_START_Z - 120.0, 12.0, 5.2, 5.6)
	_add_ramp(parent, FLAT_START_Z - 280.0, 16.0, 6.2, 5.2)
	_add_ramp(parent, FLAT_START_Z - 460.0, 20.0, 7.0, 4.8)
	_add_ramp(parent, FLAT_START_Z - 660.0, 14.0, 5.6, 6.0)
	_add_ramp(parent, FLAT_START_Z - 850.0, 18.0, 6.6, 5.0)


## Лес по обе стороны: три линии деревьев в MultiMesh.
## Сколько кусков сцены ещё не построено.
func pending_jobs() -> int:
	return _queue.size()


func _defer(job: Callable) -> void:
	if job.is_valid():
		_queue.append(job)


## Строит очередь порциями: не дольше budget_ms за кадр.
func pump(budget_ms := 4.0) -> void:
	var start := Time.get_ticks_usec()
	while not _queue.is_empty():
		var job: Callable = _queue.pop_front()
		if job.is_valid():
			job.call()
		if float(Time.get_ticks_usec() - start) / 1000.0 > budget_ms:
			break


func _add_forest(parent: Node3D, length: float) -> void:
	var index := 0
	for side in [-1.0, 1.0]:
		for row in 3:
			var lane: float = side * (ROAD_WIDTH * 0.5 + 7.4 + row * 4.6)
			_defer(Callable(self, "_forest_row").bind(parent, lane, length, 20261124 + index))
			index += 1


## Один ряд леса: стволы и кроны одним MultiMesh.
func _forest_row(parent: Node3D, lane: float, length: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var trunks := []
	var crowns := []
	var z := FLAT_START_Z - 4.0
	while z > FLAT_START_Z - length:
		var height := rng.randf_range(4.2, 8.6)
		var radius := rng.randf_range(1.05, 1.85)
		var px := lane + rng.randf_range(-1.5, 1.5)
		var pz := z + rng.randf_range(-2.4, 2.4)
		trunks.append(_inst(Vector3(px, ROAD_TOP + height * 0.22, pz),
			Vector3(0.30, height * 0.44, 0.30)))
		crowns.append(_inst(Vector3(px, ROAD_TOP + height * 0.40 + height * 0.37, pz),
			Vector3(radius, height * 0.74, radius), rng.randf_range(0.0, TAU)))
		z -= rng.randf_range(7.0, 12.0)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.5
	trunk_mesh.bottom_radius = 0.58
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	_multimesh(parent, trunk_mesh, _bark, trunks)

	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 1.0
	crown_mesh.height = 1.0
	crown_mesh.radial_segments = 7
	_multimesh(parent, crown_mesh, _pine, crowns)


static func _unit_box() -> BoxMesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	return box


## Трансформация инстанса: масштаб + поворот вокруг вертикали.
static func _inst(pos: Vector3, scale_value: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(scale_value), pos)


func _multimesh(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array,
		shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])

	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


# ---------------------------------------------------------------------------
# Карта 2: город — дома, ступени, перила, парковка, стройка.
# ---------------------------------------------------------------------------
func _build_city(parent: Node3D) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "City"
	parent.add_child(holder)

	# Асфальт и удалённые кварталы.
	_solid(holder, Vector3(240.0, 0.4, 240.0), Vector3(0.0, -0.2, 0.0), _asphalt)

	# Главная улица вдоль -Z: тротуары по бокам.
	_solid(holder, Vector3(6.0, 0.25, 220.0), Vector3(-13.0, 0.12, 0.0), _concrete)
	_solid(holder, Vector3(6.0, 0.25, 220.0), Vector3(13.0, 0.12, 0.0), _concrete)

	# Дома в два ряда.
	var house_z := 40.0
	var row := 0
	while row < 2:
		var x_side := -1.0 if row == 0 else 1.0
		var hz := house_z
		var count := 0
		while count < 6 and hz > -160.0:
			_defer(Callable(self, "_add_house").bind(holder, Vector3(x_side * 30.0, 0.0, hz),
				10.0 + count % 2 * 2.0, 7.0 + (count % 3) * 1.5, count % 2 == 0))
			hz -= 34.0
			count += 1
		row += 1

	# Лестница в парк и перила.
	var step := 0
	while step < 7:
		_solid(holder, Vector3(9.0, 0.24, 1.1), Vector3(-24.0, 0.12 + step * 0.24, -60.0 - step * 1.1), _concrete)
		step += 1
	_solid(holder, Vector3(9.0, 0.2, 8.0), Vector3(-24.0, 0.12 + 7 * 0.24, -60.0 - 7 * 1.1 - 4.0), _concrete)

	var rail_index := 0
	while rail_index < 6:
		_post(holder, 0.06, 1.0, Vector3(-28.5, 0.12, -60.0 - rail_index * 1.8), _metal)
		_post(holder, 0.06, 1.0, Vector3(-19.5, 0.12, -60.0 - rail_index * 1.8), _metal)
		rail_index += 1
	_decor(holder, Vector3(0.08, 0.08, 9.0), Vector3(-28.5, 1.1, -64.5), _metal)
	_decor(holder, Vector3(0.08, 0.08, 9.0), Vector3(-19.5, 1.1, -64.5), _metal)

	# Парковка с разметкой и стройка с барьерами.
	_decor(holder, Vector3(24.0, 0.01, 30.0), Vector3(24.0, 0.01, -70.0), _concrete)
	var stall := 0
	while stall < 8:
		_decor(holder, Vector3(0.18, 0.02, 5.0), Vector3(14.0 + stall * 3.0, 0.02, -70.0), _white)
		stall += 1

	# Барьеры стройки: по центру оставляем проезд, иначе улица перекрыта
	# полностью и заезд по прямой упирается в забор.
	var barrier := 0
	while barrier < 10:
		var bx := -6.0 + (barrier % 5) * 3.0
		var bz := -100.0 - (barrier / 5) * 5.0
		if absf(bx) > 0.1:
			_solid(holder, Vector3(2.6, 0.9, 0.3), Vector3(bx, 0.45, bz), _orange)
		barrier += 1
	_solid(holder, Vector3(6.0, 1.6, 6.0), Vector3(-9.0, 0.8, -112.0), _brick_b)

	# Фонари с настоящим светом (мало, ради производительности на телефоне).
	var lamp := 0
	while lamp < 6:
		var lz := 20.0 - lamp * 34.0
		_post(holder, 0.09, 5.0, Vector3(-17.0, 0.2, lz), _metal)
		_decor(holder, Vector3(1.2, 0.12, 0.3), Vector3(-16.5, 5.0, lz), _metal)
		var light := OmniLight3D.new()
		light.position = Vector3(-16.2, 4.8, lz)
		light.light_energy = 2.2
		light.omni_range = 14.0
		light.light_color = Color(1.0, 0.9, 0.72)
		holder.add_child(light)
		lamp += 1

	# Пешеходная разметка «зебра».
	var stripe := 0
	while stripe < 6:
		_decor(holder, Vector3(1.1, 0.02, 6.0), Vector3(-3.5 + stripe * 1.4, 0.02, 8.0), _white)
		stripe += 1

	return {"spawn": Vector3(0.0, 0.14, 34.0), "basis": Basis.IDENTITY}


func _add_house(parent: Node3D, base: Vector3, width: float, height: float, use_brick_a: bool) -> void:
	var mat := _brick_a if use_brick_a else _brick_b
	_solid(parent, Vector3(width, height, width), base + Vector3(0.0, height * 0.5, 0.0), mat)
	# Двускатная крыша из двух наклонных плит.
	var roof_y := base.y + height + 0.55
	_decor(parent, Vector3(width * 1.16, 0.3, width * 0.72), Vector3(base.x, roof_y, base.z - width * 0.28),
		_roof, Vector3(deg_to_rad(24.0), 0.0, 0.0))
	_decor(parent, Vector3(width * 1.16, 0.3, width * 0.72), Vector3(base.x, roof_y, base.z + width * 0.28),
		_roof, Vector3(deg_to_rad(-24.0), 0.0, 0.0))
	# Окна: два ряда тёмных панелей.
	var row := 0
	while row < int(height / 2.6):
		_decor(parent, Vector3(width * 0.22, 1.0, 0.12),
			Vector3(base.x - width * 0.25, base.y + 1.8 + row * 2.4, base.z + width * 0.5 + 0.02),
			_window)
		_decor(parent, Vector3(width * 0.22, 1.0, 0.12),
			Vector3(base.x + width * 0.25, base.y + 1.8 + row * 2.4, base.z + width * 0.5 + 0.02),
			_window)
		row += 1
