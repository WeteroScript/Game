## Процедурная 3D-модель самоката: рама, дека, вилка, подвеска, колёса, крылья,
## фара, стоп-сигнал, дисплей. Всё собирается кодом — внешних ассетов нет.
##
## Местные оси:origin на высоте осей колёс, «вперёд» = -Z (как у Node3D в Godot).
## Возвращает словарь с узлами, которые анимирует Scooter:
##   root, front_steer (поворот руля), front_wheel / rear_wheel (вращение),
##   bar_left / bar_right (за них держится райдер), foot_left / foot_right.
class_name ScooterModel
extends RefCounted

const RUBBER := Color(0.045, 0.045, 0.05)
const GRIP_TAPE := Color(0.07, 0.07, 0.08)
const STEEL := Color(0.72, 0.74, 0.78)
const DARK_STEEL := Color(0.30, 0.32, 0.35)
const SCREEN := Color(0.35, 0.85, 1.0)
const LAMP := Color(1.0, 0.95, 0.82)
const TAIL := Color(1.0, 0.16, 0.12)

var spec: ScooterSpec
var radius := 0.14
var base := 1.06
var deck_top := 0.16
var board_length := 0.82

var _frame: StandardMaterial3D
var _accent: StandardMaterial3D
var _rubber: StandardMaterial3D
var _tape: StandardMaterial3D
var _steel: StandardMaterial3D
var _dark: StandardMaterial3D
var _screen: StandardMaterial3D
var _lamp: StandardMaterial3D
var _tail: StandardMaterial3D


static func build(new_spec: ScooterSpec) -> Dictionary:
	return ScooterModel.new()._build(new_spec)


func _build(new_spec: ScooterSpec) -> Dictionary:
	spec = new_spec
	radius = spec.wheel_radius
	base = spec.wheel_base
	deck_top = spec.deck_height if spec.deck_height > 0.01 else radius + 0.02
	board_length = spec.deck_length + 0.30

	_make_materials()

	var root := Node3D.new()
	root.name = "Model"

	var body := _body(root)
	var front_steer := _front_assembly(root)

	return {
		"root": root,
		"front_steer": front_steer,
		"front_wheel": front_steer.get_node("Wheel"),
		"rear_wheel": body.get_node("RearWheel"),
		"bar_left": front_steer.get_node("BarLeft"),
		"bar_right": front_steer.get_node("BarRight"),
		"foot_left": body.get_node("FootLeft"),
		"foot_right": body.get_node("FootRight"),
	}


func _make_materials() -> void:
	_frame = _mat(spec.frame_color, 0.55, 0.34)
	_accent = _mat(spec.accent_color, 0.35, 0.30)
	_rubber = _mat(RUBBER, 0.0, 0.95, Color.BLACK, 0.0, true)
	_tape = _mat(GRIP_TAPE, 0.0, 0.98)
	_steel = _mat(STEEL, 0.92, 0.22)
	_dark = _mat(DARK_STEEL, 0.6, 0.45)
	_screen = _mat(Color(0.02, 0.05, 0.08), 0.1, 0.2, SCREEN, 2.2)
	_lamp = _mat(Color(0.95, 0.93, 0.85), 0.2, 0.25, LAMP, 3.2)
	_tail = _mat(Color(0.35, 0.04, 0.04), 0.1, 0.35, TAIL, 2.6)


# ---- корпус ------------------------------------------------------------------
func _body(root: Node3D) -> Node3D:
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	# Дека и накладка-гриптейп.
	_box(body, Vector3(spec.deck_width, 0.05, board_length),
		Vector3(0.0, deck_top - 0.025, 0.05), _frame)
	_box(body, Vector3(spec.deck_width - 0.03, 0.006, board_length - 0.12),
		Vector3(0.0, deck_top + 0.002, 0.05), _tape)
	_box(body, Vector3(spec.deck_width - 0.10, 0.012, board_length - 0.20),
		Vector3(0.0, deck_top + 0.008, 0.05), _tape)

	# Боковые молдинги в цвет акцента.
	for side in [-1.0, 1.0]:
		_box(body, Vector3(0.012, 0.028, board_length - 0.06),
			Vector3(side * spec.deck_width * 0.5, deck_top - 0.022, 0.05), _accent)

	# Задний «хвост» с габаритом.
	_box(body, Vector3(spec.deck_width - 0.04, 0.035, 0.14),
		Vector3(0.0, deck_top - 0.005, board_length * 0.5 + 0.02), _frame)
	_box(body, Vector3(0.075, 0.022, 0.014),
		Vector3(0.0, deck_top - 0.002, board_length * 0.5 + 0.095), _tail)

	# Аккумуляторный отсек и защита картера.
	_box(body, Vector3(spec.deck_width - 0.05, 0.105, board_length - 0.26),
		Vector3(0.0, deck_top - 0.105, 0.06), _dark)
	_box(body, Vector3(spec.deck_width - 0.09, 0.02, board_length - 0.34),
		Vector3(0.0, deck_top - 0.16, 0.06), _frame)

	# Декоративные вставки (у F3 оранжевые).
	if spec.orange_accents:
		for side in [-1.0, 1.0]:
			_box(body, Vector3(0.008, 0.016, 0.26),
				Vector3(side * (spec.deck_width * 0.5 + 0.004), deck_top - 0.075, 0.10), _accent)

	# Задняя подвеска: два амортизатора от деки к оси.
	for side in [-1.0, 1.0]:
		_cyl_between(body, Vector3(side * 0.075, deck_top - 0.10, base * 0.5 - 0.20),
			Vector3(side * 0.075, 0.01, base * 0.5 - 0.02), 0.016, _steel)
		_cyl_between(body, Vector3(side * 0.075, deck_top - 0.10, base * 0.5 - 0.20),
			Vector3(side * 0.075, deck_top - 0.135, base * 0.5 - 0.21), 0.024, _accent)

	# Подножка (сложена вдоль деки).
	_cyl_between(body, Vector3(0.085, deck_top - 0.08, 0.28),
		Vector3(0.115, -radius * 0.35, 0.34), 0.008, _steel)

	# Заднее крыло над колесом.
	_fender(body, Vector3(0.0, 0.0, base * 0.5), radius + 0.018, spec.deck_width + 0.02, -25.0, 105.0, _frame)

	# Заднее колесо (с хаб-мотором).
	_wheel_pivot(body, Vector3(0.0, 0.0, base * 0.5), "RearWheel", true)

	# Точки постановки ног для райдера.
	_marker(body, "FootLeft", Vector3(-0.075, deck_top + 0.01, -0.02))
	_marker(body, "FootRight", Vector3(0.075, deck_top + 0.01, 0.14))

	# Светоотражатели на боках.
	for side in [-1.0, 1.0]:
		_box(body, Vector3(0.006, 0.03, 0.05),
			Vector3(side * (spec.deck_width * 0.5 + 0.002), deck_top - 0.10, -0.22), _tail)

	return body


func _front_assembly(root: Node3D) -> Node3D:
	var steer := Node3D.new()
	steer.name = "FrontSteer"
	steer.position = Vector3(0.0, 0.0, -base * 0.5)
	root.add_child(steer)

	# Вилка: две стойки + корона.
	for side in [-1.0, 1.0]:
		_cyl_between(steer, Vector3(side * 0.055, 0.30, 0.0),
			Vector3(side * 0.055, 0.015, 0.0), 0.017, _steel)
		_cyl_between(steer, Vector3(side * 0.055, 0.20, 0.0),
			Vector3(side * 0.055, 0.30, 0.0), 0.022, _accent)
	_box(steer, Vector3(0.15, 0.035, 0.06), Vector3(0.0, 0.315, 0.0), _dark)

	# Рулевая колонка и складывающийся узел.
	_cyl_between(steer, Vector3(0.0, 0.30, 0.0), Vector3(0.0, 0.40, 0.02), 0.045, _frame)
	_cyl_between(steer, Vector3(0.0, 0.40, 0.02), Vector3(0.0, 0.88, 0.10), 0.028, _frame)
	_cyl(steer, 0.038, 0.06, Vector3(0.0, 0.36, 0.008), _accent, Vector3(deg_to_rad(11.0), 0.0, 0.0))

	# Стопор замка складывания.
	_box(steer, Vector3(0.05, 0.055, 0.055), Vector3(0.0, 0.345, 0.012), _dark)

	# Руль: поперечина, грипсы, тормозные ручки, курок газа, дисплей, фара.
	var bar_height := 0.92
	var bar_z := 0.105
	_cyl(steer, 0.017, 0.46, Vector3(0.0, bar_height, bar_z), _dark, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	for side in [-1.0, 1.0]:
		_cyl(steer, 0.023, 0.115, Vector3(side * 0.225, bar_height, bar_z), _rubber,
			Vector3(0.0, 0.0, deg_to_rad(90.0)))
		_cyl(steer, 0.026, 0.014, Vector3(side * 0.288, bar_height, bar_z), _accent,
			Vector3(0.0, 0.0, deg_to_rad(90.0)))
		# Тормозная ручка.
		_box(steer, Vector3(0.012, 0.012, 0.10),
			Vector3(side * 0.20, bar_height - 0.022, bar_z - 0.045), _steel,
			Vector3(deg_to_rad(6.0), 0.0, 0.0))
		_box(steer, Vector3(0.03, 0.028, 0.03),
			Vector3(side * 0.145, bar_height - 0.01, bar_z - 0.02), _dark)

	# Курок газа на правой грипсе.
	_box(steer, Vector3(0.02, 0.014, 0.055),
		Vector3(0.19, bar_height + 0.028, bar_z - 0.02), _accent)

	# Дисплей-панель по центру.
	_box(steer, Vector3(0.105, 0.05, 0.035), Vector3(0.0, bar_height + 0.032, bar_z - 0.005), _dark)
	_box(steer, Vector3(0.08, 0.034, 0.006), Vector3(0.0, bar_height + 0.034, bar_z - 0.024), _screen)

	# Фара.
	_cyl(steer, 0.030, 0.032, Vector3(0.0, bar_height - 0.055, bar_z - 0.055), _lamp,
		Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_cyl(steer, 0.034, 0.014, Vector3(0.0, bar_height - 0.055, bar_z - 0.040), _dark,
		Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# Переднее крыло.
	_fender(steer, Vector3.ZERO, radius + 0.016, spec.deck_width + 0.01, -30.0, 115.0, _frame)

	# Переднее колесо и маркеры руля для райдера.
	_wheel_pivot(steer, Vector3.ZERO, "Wheel", false)
	_marker(steer, "BarLeft", Vector3(-0.225, bar_height, bar_z))
	_marker(steer, "BarRight", Vector3(0.225, bar_height, bar_z))

	return steer


# ---- колесо ------------------------------------------------------------------
func _wheel_pivot(parent: Node3D, pos: Vector3, node_name: String, motor: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = pos
	parent.add_child(pivot)

	# Покрышка (тор) + обод + ступица.
	_torus(pivot, radius * 0.62, radius, _rubber)
	_cyl(pivot, radius * 0.60, 0.055, Vector3.ZERO, _steel, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_cyl(pivot, radius * 0.58, 0.020, Vector3.ZERO, _dark, Vector3(0.0, 0.0, deg_to_rad(90.0)))

	if motor:
		# Хаб-мотор: толстая ступица с акцентным кольцом.
		_cyl(pivot, radius * 0.30, 0.075, Vector3.ZERO, _dark, Vector3(0.0, 0.0, deg_to_rad(90.0)))
		_torus(pivot, radius * 0.32, radius * 0.40, _accent, Vector3.ZERO)
		_cyl(pivot, radius * 0.10, 0.08, Vector3.ZERO, _steel, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	else:
		_cyl(pivot, radius * 0.10, 0.085, Vector3.ZERO, _steel, Vector3(0.0, 0.0, deg_to_rad(90.0)))
		# Тормозной диск.
		_cyl(pivot, radius * 0.42, 0.006, Vector3(0.045, 0.0, 0.0), _steel,
			Vector3(0.0, 0.0, deg_to_rad(90.0)))

	# Спицы-спицы: 6 тонких планок, чтобы колесо читалось в движении.
	for i in 6:
		var angle := TAU * float(i) / 6.0
		_box(pivot, Vector3(0.012, radius * 1.10, 0.014), Vector3.ZERO, _dark,
			Vector3(angle, 0.0, 0.0))
	return pivot


# ---- примитивы ---------------------------------------------------------------
func _mat(color: Color, metallic := 0.2, roughness := 0.6,
		emission_color := Color.BLACK, emission_energy := 0.0, double_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission_color
		m.emission_energy_multiplier = emission_energy
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
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


func _cyl(parent: Node3D, cyl_radius: float, height: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, segments := 18, top_radius := -1.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = cyl_radius if top_radius < 0.0 else top_radius
	cylinder.bottom_radius = cyl_radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	parent.add_child(mesh_instance)
	return mesh_instance


func _torus(parent: Node3D, inner: float, outer: float, mat: Material,
		rot := Vector3.ZERO, center := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 20
	torus.ring_segments = 8
	mesh_instance.mesh = torus
	mesh_instance.material_override = mat
	# Тор лежит в плоскости XZ, колесу нужна ось X.
	mesh_instance.rotation = rot + Vector3(0.0, 0.0, deg_to_rad(90.0))
	mesh_instance.position = center
	parent.add_child(mesh_instance)
	return mesh_instance


## Цилиндр между двумя точками — вилка, стойки, амортизаторы.
func _cyl_between(parent: Node3D, from: Vector3, to: Vector3, cyl_radius: float,
		mat: Material) -> MeshInstance3D:
	var direction := to - from
	var length := direction.length()
	if length < 0.001:
		return null
	var mid := (from + to) * 0.5
	var mesh_instance := _cyl(parent, cyl_radius, length, mid, mat)
	var up := Vector3.UP
	var dir := direction.normalized()
	if absf(dir.dot(up)) < 0.999:
		var axis := up.cross(dir).normalized()
		var angle := acos(clampf(up.dot(dir), -1.0, 1.0))
		mesh_instance.rotation = (Basis(axis, angle)).get_euler()
	return mesh_instance


## Крыло: дуга над колесом из полигональной ленты.
func _fender(parent: Node3D, center: Vector3, rad: float, width: float,
		from_deg: float, to_deg: float, mat: Material, segments := 12, thickness := 0.012) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width * 0.5
	for i in segments:
		var a0 := deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(segments)))
		var a1 := deg_to_rad(lerpf(from_deg, to_deg, float(i + 1) / float(segments)))
		# Дуга в плоскости YZ: угол 0 — впереди сверху.
		var o0 := Vector3(0.0, cos(a0), -sin(a0)) * (rad + thickness)
		var o1 := Vector3(0.0, cos(a1), -sin(a1)) * (rad + thickness)
		var i0 := Vector3(0.0, cos(a0), -sin(a0)) * rad
		var i1 := Vector3(0.0, cos(a1), -sin(a1)) * rad

		# Внешняя поверхность.
		_quad(st, center + o0 + Vector3(-half, 0, 0), center + o0 + Vector3(half, 0, 0),
			center + o1 + Vector3(half, 0, 0), center + o1 + Vector3(-half, 0, 0))
		# Внутренняя поверхность.
		_quad(st, center + i0 + Vector3(half, 0, 0), center + i0 + Vector3(-half, 0, 0),
			center + i1 + Vector3(-half, 0, 0), center + i1 + Vector3(half, 0, 0))
		# Боковые кромки.
		_quad(st, center + o0 + Vector3(half, 0, 0), center + i0 + Vector3(half, 0, 0),
			center + i1 + Vector3(half, 0, 0), center + o1 + Vector3(half, 0, 0))
		_quad(st, center + i0 + Vector3(-half, 0, 0), center + o0 + Vector3(-half, 0, 0),
			center + o1 + Vector3(-half, 0, 0), center + i1 + Vector3(-half, 0, 0))

	st.generate_normals()
	var mesh := st.commit()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func _marker(parent: Node3D, node_name: String, pos: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = pos
	parent.add_child(marker)
	return marker
