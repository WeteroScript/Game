## Процедурные модели самокатов по реальным фото G4 и F3 Pro Max.
##
## Что повторяем с фотографий:
##   * глубокая дека-короб (аккумулятор) с гриптейпом и боковыми наклейками;
##   * высокий рулевой стакан и длинная стойка с деколью бренда;
##   * рычажная подвеска (trailing arm) спереди и сзади с амортизаторами;
##   * зубастые покрышки, крылья-дуги, задний «хвост» с площадкой и стоп-сигналом;
##   * G4 — серый gunmetal с оранжевыми шевронами, F3 Pro Max — чёрный с
##     оранжевыми рычагами подвески и кольцами на дисках.
##
## Местные оси: origin на высоте осей колёс, «вперёд» = -Z.
## Возвращает словарь: root, front_steer, front_wheel, rear_wheel,
## bar_left, bar_right, foot_left, foot_right.
class_name ScooterModel
extends RefCounted

const RUBBER := Color(0.045, 0.045, 0.05)
const GRIP_TAPE := Color(0.06, 0.06, 0.07)
const STEEL := Color(0.74, 0.76, 0.80)
const DARK_STEEL := Color(0.26, 0.27, 0.30)
const BLACK_PLASTIC := Color(0.05, 0.05, 0.06)
const SCREEN := Color(0.35, 0.85, 1.0)
const LAMP := Color(1.0, 0.95, 0.82)
const TAIL := Color(1.0, 0.16, 0.12)

var spec: ScooterSpec
var radius := 0.14
var base := 1.06
var deck_top := 0.075
var deck_len := 0.64
var steer_z := -0.33

var _frame: StandardMaterial3D
var _accent: StandardMaterial3D
var _susp: StandardMaterial3D
var _dark: StandardMaterial3D
var _rubber: StandardMaterial3D
var _tape: StandardMaterial3D
var _steel: StandardMaterial3D
var _plastic: StandardMaterial3D
var _rim: StandardMaterial3D
var _screen: StandardMaterial3D
var _lamp: StandardMaterial3D
var _tail: StandardMaterial3D


static func build(new_spec: ScooterSpec) -> Dictionary:
	return ScooterModel.new()._build(new_spec)


func _build(new_spec: ScooterSpec) -> Dictionary:
	spec = new_spec
	radius = spec.wheel_radius
	base = spec.wheel_base
	deck_top = spec.deck_height if spec.deck_height > 0.02 else radius * 0.55
	# Длина деки-короба: площадка под ноги + запас под аккумулятор спереди и сзади.
	deck_len = clampf(spec.deck_length + 0.13, 0.55, 0.70)
	# Рулевой стакан стоит на 0.20 м позади передней оси — как на фото.
	steer_z = -base * 0.5 + 0.20

	_make_materials()

	var root := Node3D.new()
	root.name = "Model"

	_body(root)
	var steer := _front_assembly(root)

	return {
		"root": root,
		"front_steer": steer,
		"front_wheel": steer.get_node("Wheel"),
		"rear_wheel": root.get_node("RearWheel"),
		"bar_left": steer.get_node("BarLeft"),
		"bar_right": steer.get_node("BarRight"),
		"foot_left": root.get_node("FootLeft"),
		"foot_right": root.get_node("FootRight"),
	}


func _make_materials() -> void:
	_frame = _mat(spec.frame_color, 0.55, 0.35)
	_accent = _mat(spec.accent_color, 0.12, 0.46)
	_susp = _mat(spec.suspension_color, 0.45, 0.35)
	_dark = _mat(DARK_STEEL, 0.30, 0.62)
	_plastic = _mat(Color(0.055, 0.058, 0.068), 0.10, 0.72)
	_rim = _mat(Color(0.30, 0.31, 0.34), 0.55, 0.40)
	_rubber = _mat(RUBBER, 0.0, 0.95, Color.BLACK, 0.0, true)
	_tape = _mat(GRIP_TAPE, 0.0, 0.98)
	_steel = _mat(STEEL, 0.55, 0.32)
	_screen = _mat(Color(0.02, 0.05, 0.08), 0.1, 0.2, SCREEN, 2.2)
	_lamp = _mat(Color(0.95, 0.93, 0.85), 0.2, 0.25, LAMP, 1.4)
	_tail = _mat(Color(0.35, 0.04, 0.04), 0.1, 0.35, TAIL, 2.6)


# ---- корпус ------------------------------------------------------------------
func _body(root: Node3D) -> void:
	var base_z := -0.02

	# Дека-короб: аккумулятор внутри, сверху гриптейп.
	# На фото низ деки проходит по уровню осей, а верх — на 0.10 м выше.
	_box(root, Vector3(0.215, deck_top, deck_len),
		Vector3(0.0, deck_top * 0.5, base_z), _frame)
	_box(root, Vector3(0.195, 0.008, deck_len - 0.06),
		Vector3(0.0, deck_top + 0.004, base_z), _tape)
	_box(root, Vector3(0.165, 0.006, deck_len - 0.14),
		Vector3(0.0, deck_top + 0.010, base_z), _tape)
	# Оранжевая кромка вдоль верха деки (видна на фото G4).
	_box(root, Vector3(0.219, 0.008, deck_len),
		Vector3(0.0, deck_top - 0.004, base_z), _accent)

	# Боковые панели и наклейки-шевроны (они и делают узнаваемый вид).
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.006, deck_top * 0.62, deck_len - 0.02),
			Vector3(side * 0.108, deck_top * 0.52, base_z), _dark)
		for chevron_z in [-deck_len * 0.5 + 0.07, deck_len * 0.5 - 0.07]:
			for offset in [-0.022, 0.0, 0.022]:
				_box(root, Vector3(0.008, 0.038, 0.015),
					Vector3(side * 0.112, deck_top * 0.52,
						base_z + chevron_z + offset), _accent,
					Vector3(deg_to_rad(38.0), 0.0, 0.0))

	# Небольшая наклейка бренда ближе к корме — как на фото («B-05-1»).
	_label(root, spec.brand_text, Vector3(0.113, deck_top * 0.55, base_z + 0.02),
		Vector3(0.0, 90.0, 0.0), 0.00042, Color(0.93, 0.93, 0.95))
	_label(root, spec.brand_text, Vector3(-0.113, deck_top * 0.55, base_z + 0.02),
		Vector3(0.0, -90.0, 0.0), 0.00042, Color(0.93, 0.93, 0.95))

	# Защита снизу и подножка.
	_box(root, Vector3(0.17, 0.024, deck_len - 0.12),
		Vector3(0.0, deck_top * 0.12, base_z), _dark)
	_plate_between(root, Vector3(0.085, deck_top - 0.035, 0.10),
		Vector3(0.135, -radius * 0.45, 0.17), 0.02, 0.03, _dark)

	# Задний амортизатор и рычаг подвески.
	var rear_pivot := Vector3(0.0, deck_top * 0.75, deck_len * 0.5 - 0.04)
	var rear_axle := Vector3(0.0, 0.0, base * 0.5)
	for side in [-1.0, 1.0]:
		var arm_from2 := rear_pivot + Vector3(side * 0.072, 0.0, 0.0)
		_plate_between(root, arm_from2, arm_from2.lerp(rear_axle + Vector3(side * 0.072, 0.0, 0.0), 0.94),
			0.038, 0.015, _susp)
		_box(root, Vector3(0.014, 0.03, 0.03),
			rear_pivot + Vector3(side * 0.072, 0.0, 0.0), _accent)
	_shock(root, Vector3(0.0, deck_top + 0.02, deck_len * 0.5 - 0.16),
		Vector3(0.0, 0.05, base * 0.5 - 0.06), 0.016)

	# Заднее крыло и стойка крыла.
	_fender(root, Vector3(0.0, 0.0, base * 0.5), radius + 0.016, radius + 0.012,
		-24.0, 130.0, _plastic)
	_plate_between(root, Vector3(0.0, deck_top - 0.01, deck_len * 0.5),
		Vector3(0.0, radius + 0.04, base * 0.5 + 0.02), 0.05, 0.02, _frame)

	# Задняя приподнятая площадка на треугольном кронштейне (как на фото G4).
	if spec.has_rear_step:
		_rear_step(root)

	# Заднее колесо (хаб-мотор).
	_wheel(root, Vector3(0.0, 0.0, base * 0.5), "RearWheel", true, spec.motor_count == 1)

	# Точки постановки ног.
	_marker(root, "FootLeft", Vector3(-0.072, deck_top + 0.015, -0.06))
	_marker(root, "FootRight", Vector3(0.072, deck_top + 0.015, 0.10))


func _front_assembly(root: Node3D) -> Node3D:
	var steer := Node3D.new()
	steer.name = "FrontSteer"
	steer.position = Vector3(0.0, 0.0, steer_z)
	root.add_child(steer)

	var axle := Vector3(0.0, 0.0, -(base * 0.5 + steer_z))
	var pivot := Vector3(0.0, deck_top + 0.06, 0.09)

	# Рулевой стакан: короткая шея от деки, косынка и замок складывания.
	_box(steer, Vector3(0.115, 0.14, 0.095), Vector3(0.0, deck_top + 0.055, 0.03), _frame,
		Vector3(deg_to_rad(-12.0), 0.0, 0.0))
	_plate_between(steer, Vector3(0.0, deck_top - 0.02, 0.185),
		Vector3(0.0, deck_top + 0.155, 0.045), 0.098, 0.030, _frame)
	_plate_between(steer, Vector3(-0.052, deck_top + 0.02, 0.14),
		Vector3(0.052, deck_top + 0.02, 0.14), 0.04, 0.02, _frame)
	_box(steer, Vector3(0.15, 0.018, 0.026), Vector3(0.0, deck_top + 0.005, 0.075), _accent)

	# Передний рычаг подвески (две пластины вокруг колеса).
	for side in [-1.0, 1.0]:
		var arm_from := pivot + Vector3(side * 0.076, 0.0, 0.0)
		_plate_between(steer, arm_from, arm_from.lerp(axle + Vector3(side * 0.076, 0.0, 0.0), 0.94),
			0.038, 0.015, _susp)
		_box(steer, Vector3(0.014, 0.032, 0.032), pivot + Vector3(side * 0.076, 0.0, 0.0), _accent)
		_box(steer, Vector3(0.016, 0.05, 0.02), axle + Vector3(side * 0.076, 0.0, 0.02), _susp)
	# Распорка между пластинами.
	_plate_between(steer, pivot + Vector3(-0.076, 0.0, 0.0), pivot + Vector3(0.076, 0.0, 0.0),
		0.05, 0.02, _susp)

	# Передний амортизатор: от стакана к середине рычага.
	var shock_top := Vector3(0.0, deck_top + 0.10, 0.06)
	var shock_bottom := axle + Vector3(0.0, 0.055, 0.16)
	_shock(steer, shock_top, shock_bottom, 0.017)

	# Крыло переднего колеса (у G4 его нет, у F3 — есть).
	if spec.front_fender:
		_fender(steer, axle, radius + 0.016, radius + 0.012, -18.0, 122.0, _plastic)

	# Стойка: широкая плоская труба с замком складывания и деколью бренда.
	# На фото она почти вертикальная, чуть отклонена назад, руль на 1.22 м.
	var stem_bottom := Vector3(0.0, deck_top + 0.20, 0.02)
	var rake := deg_to_rad(spec.stem_rake_deg)
	var stem_top := Vector3(0.0, 1.22, 0.02 + tan(rake) * (1.22 - stem_bottom.y))
	_plate_between(steer, stem_bottom, stem_top, 0.058, 0.046, _frame)
	_plate_between(steer, stem_bottom, stem_bottom.lerp(stem_top, 0.42), 0.074, 0.056, _frame)
	_box(steer, Vector3(0.092, 0.115, 0.102), stem_bottom + Vector3(0.0, 0.045, 0.005), _dark)
	for bolt_z in [-0.036, 0.036]:
		for bolt_y in [0.012, 0.078]:
			_cyl(steer, 0.007, 0.105, stem_bottom + Vector3(0.0, bolt_y, bolt_z), _steel,
				Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_cyl(steer, 0.011, 0.115, stem_bottom + Vector3(0.0, 0.045, 0.052), _steel,
		Vector3(0.0, 0.0, deg_to_rad(90.0)))
	# Быстросъёмный рычаг.
	_cyl(steer, 0.013, 0.115, Vector3(0.0, 0.46, 0.075), _dark,
		Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_box(steer, Vector3(0.016, 0.02, 0.085), Vector3(0.0, 0.46, 0.11), _accent,
		Vector3(deg_to_rad(-26.0), 0.0, 0.0))

	# Цветная полоса на стойке (как на фото) и деколь бренда вдоль неё.
	var stem_mid := stem_bottom.lerp(stem_top, 0.60)
	for side in [-1.0, 1.0]:
		_box(steer, Vector3(0.006, 0.44, 0.030),
			stem_mid + Vector3(side * 0.026, 0.0, 0.0), _accent,
			Vector3(rake, 0.0, 0.0))
		_label(steer, spec.brand_text, stem_mid + Vector3(side * 0.031, 0.02, 0.0),
			Vector3(0.0, 90.0 * side, 90.0), 0.00045, Color(0.96, 0.96, 0.97))

	# Руль: поперечина, грипсы, ручки тормоза, дисплей, фара, звонок.
	var bar_y := stem_top.y
	var bar_z := stem_top.z
	_box(steer, Vector3(0.10, 0.06, 0.06), Vector3(0.0, bar_y - 0.02, bar_z), _dark)
	_cyl(steer, 0.016, 0.50, Vector3(0.0, bar_y, bar_z), _dark,
		Vector3(0.0, 0.0, deg_to_rad(90.0)))
	for side in [-1.0, 1.0]:
		_cyl(steer, 0.024, 0.125, Vector3(side * 0.215, bar_y, bar_z), _rubber,
			Vector3(0.0, 0.0, deg_to_rad(90.0)))
		_cyl(steer, 0.026, 0.018, Vector3(side * 0.272, bar_y, bar_z), _dark,
			Vector3(0.0, 0.0, deg_to_rad(90.0)))
		_torus(steer, 0.020, 0.026, _accent, Vector3.ZERO,
			Vector3(side * 0.282, bar_y, bar_z))
		# Ручка тормоза.
		_box(steer, Vector3(0.012, 0.013, 0.105),
			Vector3(side * 0.185, bar_y - 0.026, bar_z - 0.05), _steel,
			Vector3(deg_to_rad(8.0), 0.0, 0.0))
		_box(steer, Vector3(0.028, 0.03, 0.032),
			Vector3(side * 0.135, bar_y - 0.012, bar_z - 0.02), _dark)
	# Дисплей по центру.
	_box(steer, Vector3(0.10, 0.05, 0.035), Vector3(0.0, bar_y + 0.036, bar_z - 0.01), _dark)
	_box(steer, Vector3(0.078, 0.036, 0.006), Vector3(0.0, bar_y + 0.038, bar_z - 0.028), _screen)
	# Звонок и курок газа.
	_cyl(steer, 0.018, 0.02, Vector3(-0.145, bar_y + 0.02, bar_z - 0.01), _steel)
	_box(steer, Vector3(0.018, 0.014, 0.05), Vector3(0.175, bar_y + 0.026, bar_z - 0.015), _accent)
	# Фара под стаканом.
	_cyl(steer, 0.028, 0.026, Vector3(0.0, deck_top + 0.055, 0.095), _lamp,
		Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_cyl(steer, 0.032, 0.018, Vector3(0.0, deck_top + 0.055, 0.080), _dark,
		Vector3(deg_to_rad(90.0), 0.0, 0.0))

	# Переднее колесо и маркеры руля для рук райдера.
	_wheel(steer, axle, "Wheel", spec.motor_count > 1, true)
	_marker(steer, "BarLeft", Vector3(-0.215, bar_y, bar_z))
	_marker(steer, "BarRight", Vector3(0.215, bar_y, bar_z))

	return steer


# ---- колесо ------------------------------------------------------------------
func _wheel(parent: Node3D, pos: Vector3, node_name: String, motor: bool, disc: bool) -> void:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = pos
	parent.add_child(pivot)

	# Покрышка — широкое кольцо (на фото шины жирные, 10-11 дюймов).
	_tyre(pivot, radius * 0.90, radius * 0.63, 0.052, _rubber)
	_tread(pivot, radius)

	# Обод: два диска по бокам + спицы + ступица.
	for side in [-1.0, 1.0]:
		_cyl(pivot, radius * 0.66, 0.014, Vector3(side * 0.046, 0.0, 0.0),
			_accent if spec.orange_accents else _dark,
			Vector3(0.0, 0.0, deg_to_rad(90.0)), 24)
		# Акцентное кольцо по краю обода (у F3 оранжевое).
		_torus(pivot, radius * 0.60, radius * 0.665,
			_accent if spec.orange_accents else _rim, Vector3.ZERO,
			Vector3(side * 0.050, 0.0, 0.0))
	_spokes(pivot, radius * 0.66, 0.045, _rim)
	if motor:
		_cyl(pivot, radius * 0.38, 0.105, Vector3.ZERO, _dark,
			Vector3(0.0, 0.0, deg_to_rad(90.0)), 20)
		_torus(pivot, radius * 0.38, radius * 0.44, _accent)
	else:
		_cyl(pivot, radius * 0.17, 0.10, Vector3.ZERO, _steel,
			Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)

	if disc:
		# Тормозной диск снаружи, суппорт над ним.
		_cyl(pivot, radius * 0.46, 0.006, Vector3(-0.062, 0.0, 0.0), _steel,
			Vector3(0.0, 0.0, deg_to_rad(90.0)), 24)
		_box(pivot, Vector3(0.022, 0.055, 0.034), Vector3(-0.066, radius * 0.34, 0.0), _dark)


## Кольцо-шина: широкий профиль, а не «бублик» — так покрышка читается сбоку.
func _tyre(parent: Node3D, outer: float, inner: float, half_width: float,
		mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 26
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var o0 := Vector3(0.0, d0.x * outer, d0.y * outer)
		var o1 := Vector3(0.0, d1.x * outer, d1.y * outer)
		var n0 := Vector3(0.0, d0.x * inner, d0.y * inner)
		var n1 := Vector3(0.0, d1.x * inner, d1.y * inner)
		var l := Vector3(-half_width, 0.0, 0.0)
		var r := Vector3(half_width, 0.0, 0.0)
		# Наружная беговая дорожка.
		_quad(st, l + o0, r + o0, r + o1, l + o1)
		# Внутренняя поверхность (её видно у обода).
		_quad(st, r + n1, l + n1, l + n0, r + n0)
		# Боковины.
		_quad(st, r + n0, r + o0, r + o1, r + n1)
		_quad(st, l + o0, l + n0, l + n1, l + o1)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = mat
	parent.add_child(instance)


## Спицы обода — одной лентой на обе стороны.
func _spokes(parent: Node3D, rim_radius: float, half_width: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for i in 5:
			var angle := TAU * float(i) / 5.0 + 0.45
			var local := Transform3D(Basis(Vector3.RIGHT, angle),
				Vector3(side * half_width, cos(angle), sin(angle)) * rim_radius * 0.80)
			_add_box(st, local, Vector3(0.012, rim_radius * 0.42, 0.026))
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = mat
	parent.add_child(instance)


## Задняя приподнятая площадка на треугольном кронштейне — как на фото G4.
func _rear_step(root: Node3D) -> void:
	var tilt := Vector3(deg_to_rad(-21.0), 0.0, 0.0)
	var pos := Vector3(0.0, deck_top + 0.11, deck_len * 0.5 + 0.10)
	_box(root, Vector3(0.185, 0.028, 0.205), pos, _frame, tilt)
	_box(root, Vector3(0.17, 0.008, 0.18), pos + Vector3(0.0, 0.016, -0.005), _tape, tilt)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.008, 0.02, 0.195), pos + Vector3(side * 0.094, -0.006, 0.0),
			_accent, tilt)
	# Стоп-сигнал на корме площадки.
	_box(root, Vector3(0.07, 0.024, 0.014), pos + Vector3(0.0, 0.005, 0.108), _tail, tilt)
	# Треугольный кронштейн: передняя и задняя тяги + болты.
	var low := Vector3(0.0, deck_top - 0.05, deck_len * 0.5 - 0.01)
	_plate_between(root, low, Vector3(0.0, pos.y - 0.035, pos.z - 0.07), 0.064, 0.022, _frame)
	_plate_between(root, Vector3(0.0, 0.06, base * 0.5 - 0.04),
		Vector3(0.0, pos.y - 0.035, pos.z + 0.015), 0.05, 0.020, _frame)
	_cyl(root, 0.010, 0.135, low, _steel, Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	_cyl(root, 0.009, 0.115, Vector3(0.0, 0.06, base * 0.5 - 0.04), _steel,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)


## Зубастый протектор: шашки одним мешем, чтобы не плодить draw call'ы.
func _tread(pivot: Node3D, wheel_radius: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blocks := 24
	for i in blocks:
		var angle := TAU * float(i) / float(blocks)
		var local := Transform3D(Basis(Vector3.RIGHT, angle),
			Vector3(0.0, cos(angle), sin(angle)) * wheel_radius * 0.907)
		_add_box(st, local, Vector3(0.078, 0.026, 0.038))
		# Боковые шашки чуть меньше — получается «ёлочка».
		for side in [-0.030, 0.030]:
			_add_box(st, Transform3D(Basis(Vector3.RIGHT, angle + 0.13),
				Vector3(side, cos(angle + 0.13), sin(angle + 0.13)) * wheel_radius * 0.895),
				Vector3(0.026, 0.030, 0.030))
	st.generate_normals()
	var mesh := st.commit()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _rubber
	pivot.add_child(instance)


func _add_box(st: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var half := size * 0.5
	var corners := [
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, half.y, -half.z), Vector3(-half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z),
		Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z),
	]
	var p := []
	for corner in corners:
		p.append(xform * corner)
	_quad(st, p[0], p[1], p[2], p[3])
	_quad(st, p[5], p[4], p[7], p[6])
	_quad(st, p[4], p[0], p[3], p[7])
	_quad(st, p[1], p[5], p[6], p[2])
	_quad(st, p[3], p[2], p[6], p[7])
	_quad(st, p[4], p[5], p[1], p[0])


# ---- амортизатор -------------------------------------------------------------
func _shock(parent: Node3D, from: Vector3, to: Vector3, shock_radius: float) -> void:
	var direction := (to - from).normalized()
	var length := from.distance_to(to)
	_cyl_between(parent, from, from + direction * (length * 0.55), shock_radius, _dark)
	_cyl_between(parent, from + direction * (length * 0.45), to, shock_radius * 0.62, _steel)
	# Витки пружины — несколько колец вдоль штока.
	for i in 6:
		var t := 0.50 + float(i) * 0.075
		var ring_pos := from + direction * (length * t)
		var ring := _torus(parent, shock_radius * 1.1, shock_radius * 1.45, _steel,
			Vector3.ZERO, ring_pos)
		if ring != null:
			var axis := Vector3.UP.cross(direction)
			if axis.length() > 0.001:
				ring.rotation = Basis(axis.normalized(), acos(clampf(Vector3.UP.dot(direction), -1.0, 1.0))) \
					.get_euler()


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
		rot := Vector3.ZERO, segments := 18) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = cyl_radius
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
	torus.rings = 18
	torus.ring_segments = 8
	mesh_instance.mesh = torus
	mesh_instance.material_override = mat
	mesh_instance.rotation = rot + Vector3(0.0, 0.0, deg_to_rad(90.0))
	mesh_instance.position = center
	parent.add_child(mesh_instance)
	return mesh_instance


## Цилиндр между двумя точками.
func _cyl_between(parent: Node3D, from: Vector3, to: Vector3, cyl_radius: float,
		mat: Material) -> MeshInstance3D:
	var direction := to - from
	var length := direction.length()
	if length < 0.001:
		return null
	var mesh_instance := _cyl(parent, cyl_radius, length, (from + to) * 0.5, mat)
	mesh_instance.rotation = _basis_from_up(direction).get_euler()
	return mesh_instance


## Пластина (рычаг подвески) между двумя точками.
func _plate_between(parent: Node3D, from: Vector3, to: Vector3, width: float,
		thickness: float, mat: Material) -> MeshInstance3D:
	var direction := to - from
	var length := direction.length()
	if length < 0.001:
		return null
	var mesh_instance := _box(parent, Vector3(thickness, length, width), (from + to) * 0.5, mat)
	mesh_instance.rotation = _basis_from_up(direction).get_euler()
	return mesh_instance


func _basis_from_up(direction: Vector3) -> Basis:
	var dir := direction.normalized()
	if dir.dot(Vector3.UP) > 0.999:
		return Basis.IDENTITY
	if dir.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	var axis := Vector3.UP.cross(dir).normalized()
	return Basis(axis, acos(clampf(Vector3.UP.dot(dir), -1.0, 1.0)))


## Крыло: дуга над колесом из полигональной ленты.
func _fender(parent: Node3D, center: Vector3, rad: float, width: float,
		from_deg: float, to_deg: float, mat: Material, segments := 12,
		thickness := 0.014) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width * 0.5
	for i in segments:
		var a0 := deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(segments)))
		var a1 := deg_to_rad(lerpf(from_deg, to_deg, float(i + 1) / float(segments)))
		var o0 := Vector3(0.0, cos(a0), -sin(a0)) * (rad + thickness)
		var o1 := Vector3(0.0, cos(a1), -sin(a1)) * (rad + thickness)
		var i0 := Vector3(0.0, cos(a0), -sin(a0)) * rad
		var i1 := Vector3(0.0, cos(a1), -sin(a1)) * rad

		_quad(st, center + o0 + Vector3(-half, 0, 0), center + o0 + Vector3(half, 0, 0),
			center + o1 + Vector3(half, 0, 0), center + o1 + Vector3(-half, 0, 0))
		_quad(st, center + i0 + Vector3(half, 0, 0), center + i0 + Vector3(-half, 0, 0),
			center + i1 + Vector3(-half, 0, 0), center + i1 + Vector3(half, 0, 0))
		_quad(st, center + o0 + Vector3(half, 0, 0), center + i0 + Vector3(half, 0, 0),
			center + i1 + Vector3(half, 0, 0), center + o1 + Vector3(half, 0, 0))
		_quad(st, center + i0 + Vector3(-half, 0, 0), center + o0 + Vector3(-half, 0, 0),
			center + o1 + Vector3(-half, 0, 0), center + i1 + Vector3(-half, 0, 0))

	st.generate_normals()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
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


## Надпись на корпусе (бренд, модель) — без текстур.
func _label(parent: Node3D, text: String, pos: Vector3, rot_deg: Vector3,
		pixel_size: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 6
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label.double_sided = true
	label.no_depth_test = false
	label.position = pos
	label.rotation = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	parent.add_child(label)
	return label


func _marker(parent: Node3D, node_name: String, pos: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = pos
	parent.add_child(marker)
	return marker
