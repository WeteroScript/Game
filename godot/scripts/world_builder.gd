## Сборка двух карт из примитивов: «Прямая трасса» и «Город».
## Аналог TrackMap.cs / CityMap.cs, но без префабов: всё строится кодом.
class_name WorldBuilder
extends RefCounted

const ROAD_WIDTH := 14.0
const TRACK_LENGTH := 700.0
const ROAD_TOP := 0.0

var _asphalt: StandardMaterial3D
var _concrete: StandardMaterial3D
var _grass: StandardMaterial3D
var _white: StandardMaterial3D
var _orange: StandardMaterial3D
var _metal: StandardMaterial3D
var _brick_a: StandardMaterial3D
var _brick_b: StandardMaterial3D
var _roof: StandardMaterial3D


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
	if map_id == GameConfig.MapId.CITY:
		return _build_city(parent)
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
func _build_straight_track(parent: Node3D) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "StraightTrack"
	parent.add_child(holder)

	# Трава под всем и обочины — низкое сцепление.
	_solid(holder, Vector3(240.0, 0.3, TRACK_LENGTH + 240.0), Vector3(0.0, -0.55, -TRACK_LENGTH * 0.5),
		_grass, Vector3.ZERO, true)
	_solid(holder, Vector3(9.0, 0.35, TRACK_LENGTH), Vector3(-11.5, -0.28, -TRACK_LENGTH * 0.5 + 20.0),
		_grass, Vector3.ZERO, true)
	_solid(holder, Vector3(9.0, 0.35, TRACK_LENGTH), Vector3(11.5, -0.28, -TRACK_LENGTH * 0.5 + 20.0),
		_grass, Vector3.ZERO, true)

	# Асфальт.
	_solid(holder, Vector3(ROAD_WIDTH, 0.4, TRACK_LENGTH), Vector3(0.0, ROAD_TOP - 0.2, -TRACK_LENGTH * 0.5 + 20.0),
		_asphalt)

	# Разметка: прерывистая центральная линия.
	var z := 10.0
	while z > -TRACK_LENGTH + 40.0:
		_decor(holder, Vector3(0.22, 0.02, 3.0), Vector3(0.0, ROAD_TOP + 0.01, z), _white)
		z -= 9.0

	# Отбойники по краям.
	_solid(holder, Vector3(0.25, 0.85, TRACK_LENGTH), Vector3(-ROAD_WIDTH * 0.5 - 0.4, 0.42, -TRACK_LENGTH * 0.5 + 20.0),
		_metal)
	_solid(holder, Vector3(0.25, 0.85, TRACK_LENGTH), Vector3(ROAD_WIDTH * 0.5 + 0.4, 0.42, -TRACK_LENGTH * 0.5 + 20.0),
		_metal)

	# Трамплины: чем дальше, тем круче.
	var ramp_z := -80.0
	var ramp_angle := 11.0
	var index := 0
	while index < 5 and ramp_z > -TRACK_LENGTH + 80.0:
		_add_ramp(holder, ramp_z, ramp_angle, 8.0, 12.0)
		ramp_z -= 110.0
		ramp_angle += 2.0
		index += 1

	# Столбы-ворота каждые 100 метров.
	z = 0.0
	while z > -TRACK_LENGTH + 60.0:
		_post(holder, 0.12, 3.2, Vector3(-ROAD_WIDTH * 0.5 + 0.6, ROAD_TOP, z), _metal)
		_post(holder, 0.12, 3.2, Vector3(ROAD_WIDTH * 0.5 - 0.6, ROAD_TOP, z), _metal)
		_decor(holder, Vector3(ROAD_WIDTH - 1.2, 0.18, 0.18), Vector3(0.0, 3.0, z), _orange)
		z -= 100.0

	# Конический слалом ближе к финишу.
	index = 0
	while index < 12:
		_post(holder, 0.22, 0.7, Vector3(sin(index * 1.1) * 4.5, ROAD_TOP, -420.0 - index * 8.0), _orange)
		index += 1

	# Финишная арка.
	_solid(holder, Vector3(0.4, 5.0, 0.4), Vector3(-ROAD_WIDTH * 0.5, 2.5, -TRACK_LENGTH + 100.0), _metal)
	_solid(holder, Vector3(0.4, 5.0, 0.4), Vector3(ROAD_WIDTH * 0.5, 2.5, -TRACK_LENGTH + 100.0), _metal)
	_decor(holder, Vector3(ROAD_WIDTH, 1.2, 0.3), Vector3(0.0, 5.0, -TRACK_LENGTH + 100.0), _orange)

	return {"spawn": Vector3(0.0, 0.6, 6.0), "basis": Basis.IDENTITY}


func _add_ramp(parent: Node3D, z: float, angle_deg: float, width: float, length: float) -> void:
	var angle := deg_to_rad(angle_deg)
	var half_len := length * 0.5
	var center_y := half_len * sin(angle) + ROAD_TOP
	# rotation.x отрицательный — дальний край (-Z) поднимается.
	_solid(parent, Vector3(width, 0.45, length), Vector3(0.0, center_y, z),
		_concrete, Vector3(-angle, 0.0, 0.0))
	# жёлтая кромка на подъёме
	_decor(parent, Vector3(width, 0.06, 0.5), Vector3(0.0, center_y + half_len * sin(angle) - 0.2, z - half_len * 0.9),
		_orange, Vector3(-angle, 0.0, 0.0))


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
			_add_house(holder, Vector3(x_side * 30.0, 0.0, hz), 10.0 + count % 2 * 2.0,
				7.0 + (count % 3) * 1.5, count % 2 == 0)
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

	var barrier := 0
	while barrier < 10:
		var bx := -6.0 + (barrier % 5) * 3.0
		var bz := -100.0 - (barrier / 5) * 5.0
		_solid(holder, Vector3(2.6, 0.9, 0.3), Vector3(bx, 0.45, bz), _orange)
		barrier += 1
	_solid(holder, Vector3(6.0, 1.6, 6.0), Vector3(-2.0, 0.8, -112.0), _brick_b)

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

	return {"spawn": Vector3(0.0, 0.6, 34.0), "basis": Basis.IDENTITY}


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
			_mat(Color(0.15, 0.2, 0.26), 0.3, 0.2))
		_decor(parent, Vector3(width * 0.22, 1.0, 0.12),
			Vector3(base.x + width * 0.25, base.y + 1.8 + row * 2.4, base.z + width * 0.5 + 0.02),
			_mat(Color(0.15, 0.2, 0.26), 0.3, 0.2))
		row += 1
