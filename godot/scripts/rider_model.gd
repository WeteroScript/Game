## Райдер: процедурный человечек, который стоит на деке, держится за руль
## (руки тянутся к маркерам руля через двухзвенную IK) и реагирует на торможение,
## поворот и падение.
##
## Все суставы — плоский список дочерних узлов, каждый позиционируется в
## пространстве райдера: так поза считается без накопления поворотов.
class_name RiderModel
extends Node3D

# Пропорции взрослого райдера: таз ~0.78 м над декой, плечи ~1.36 м,
# руки 0.55 м — ровно чтобы дотянуться до руля с наклоном корпуса.
const HIP_HEIGHT := 0.70
const TORSO_LENGTH := 0.52
const HEAD_OFFSET := 0.185
const UPPER_ARM := 0.255
const FOREARM := 0.245
const THIGH := 0.375
const SHIN := 0.36
const LEAN_BASE_DEG := 22.0

const SKIN := Color(0.78, 0.60, 0.47)
const JACKET := Color(0.13, 0.16, 0.22)
const PANTS := Color(0.16, 0.17, 0.20)
const GLOVE := Color(0.08, 0.08, 0.09)
const SHOE := Color(0.10, 0.10, 0.12)
const HELMET := Color(0.92, 0.93, 0.95)
const VISOR := Color(0.10, 0.14, 0.20)

var deck_top := 0.14
var accent := Color(0.95, 0.45, 0.08)

var _hips: Node3D
var _chest: Node3D
var _chest_mesh: MeshInstance3D
var _head: Node3D
var _upper_arm := {}
var _forearm := {}
var _hand := {}
var _thigh := {}
var _shin := {}
var _foot := {}
var _backpack: Node3D

var _bar_left: Node3D
var _bar_right: Node3D
var _time := 0.0
var _crash_blend := 0.0
var _wheelie := 0.0


static func create(new_deck_top: float, new_accent: Color, bar_left: Node3D, bar_right: Node3D) -> RiderModel:
	var rider := RiderModel.new()
	rider.name = "Rider"
	rider.deck_top = new_deck_top
	rider.accent = new_accent
	rider._bar_left = bar_left
	rider._bar_right = bar_right
	rider._build()
	return rider


func _mat(color: Color, roughness := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _mesh(joint: Node3D, mesh: Mesh, mat: Material, offset: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = offset
	joint.add_child(instance)
	return instance


func _job() -> Node3D:
	var node := Node3D.new()
	add_child(node)
	return node


func _build() -> void:
	var skin := _mat(SKIN, 0.75)
	var jacket := _mat(JACKET, 0.8)
	var pants := _mat(PANTS, 0.85)
	var glove := _mat(GLOVE, 0.6)
	var shoe := _mat(SHOE, 0.5)
	var hair := _mat(Color(0.105, 0.078, 0.058), 0.55)
	var eye_mat := _mat(Color(0.055, 0.055, 0.065), 0.30)
	var visor := _mat(VISOR, 0.15)
	var stripe := _mat(accent, 0.4)

	# Таз и корпус.
	_hips = _job_sized("Hips", Vector3(0.27, 0.17, 0.19), pants)
	_chest = _job()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.32, TORSO_LENGTH, 0.185)
	_chest_mesh = _mesh(_chest, chest_mesh, jacket, Vector3(0.0, -TORSO_LENGTH * 0.5, 0.0))
	# Пояс — сужение к тазу, чтобы корпус не выглядел доской.
	var waist := BoxMesh.new()
	waist.size = Vector3(0.27, 0.12, 0.17)
	_mesh(_chest, waist, pants, Vector3(0.0, -TORSO_LENGTH + 0.03, 0.0))

	# Плечи в цвет акцента.
	for side in [-1.0, 1.0]:
		var shoulder := BoxMesh.new()
		shoulder.size = Vector3(0.10, 0.09, 0.20)
		_mesh(_chest, shoulder, stripe, Vector3(side * 0.155, -0.06, 0.0))

	# Рюкзак.
	_backpack = _job()
	var pack := BoxMesh.new()
	pack.size = Vector3(0.215, 0.265, 0.110)
	_mesh(_backpack, pack, jacket, Vector3.ZERO)
	var pack_stripe := BoxMesh.new()
	pack_stripe.size = Vector3(0.050, 0.230, 0.015)
	_mesh(_backpack, pack_stripe, stripe, Vector3(0.0, 0.0, 0.065))

	# Голова без шлема: лицо, волосы, шея.
	_head = _job()
	var neck := CylinderMesh.new()
	neck.top_radius = 0.048
	neck.bottom_radius = 0.058
	neck.height = 0.13
	# Низ шеи уходит в корпус, верх держит голову — иначе видна дырка.
	_mesh(_head, neck, skin, Vector3(0.0, -0.035, 0.0))
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.092
	head_mesh.height = 0.184
	_mesh(_head, head_mesh, skin, Vector3(0.0, 0.075, 0.0))
	# Волосы: шапка сверху и масса на затылке.
	var hair_top := SphereMesh.new()
	hair_top.radius = 0.097
	hair_top.height = 0.120
	_mesh(_head, hair_top, hair, Vector3(0.0, 0.099, 0.012))
	var hair_back := SphereMesh.new()
	hair_back.radius = 0.083
	hair_back.height = 0.140
	_mesh(_head, hair_back, hair, Vector3(0.0, 0.066, 0.046))
	var hair_fringe := BoxMesh.new()
	hair_fringe.size = Vector3(0.150, 0.030, 0.036)
	_mesh(_head, hair_fringe, hair, Vector3(0.0, 0.135, -0.055))
	# Лицо: нос, глаза, рот, уши.
	var nose := BoxMesh.new()
	nose.size = Vector3(0.024, 0.034, 0.030)
	_mesh(_head, nose, skin, Vector3(0.0, 0.068, -0.086))
	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.0125
		eye.height = 0.021
		_mesh(_head, eye, eye_mat, Vector3(0.032 * side, 0.092, -0.078))
		var ear := SphereMesh.new()
		ear.radius = 0.020
		ear.height = 0.036
		_mesh(_head, ear, skin, Vector3(0.089 * side, 0.068, 0.006))
	var mouth := BoxMesh.new()
	mouth.size = Vector3(0.036, 0.008, 0.012)
	_mesh(_head, mouth, eye_mat, Vector3(0.0, 0.038, -0.084))

	# Руки и ноги.
	for side in [-1.0, 1.0]:
		var key := "l" if side < 0.0 else "r"
		_upper_arm[key] = _limb(side, UPPER_ARM, 0.041, jacket)
		_forearm[key] = _limb(side, FOREARM, 0.034, jacket)
		_hand[key] = _job_sized("Hand_" + key, Vector3(0.068, 0.082, 0.078), glove)
		_thigh[key] = _limb(side, THIGH, 0.056, pants)
		_shin[key] = _limb(side, SHIN, 0.045, pants)
		_foot[key] = _job_sized("Foot_" + key, Vector3(0.095, 0.066, 0.225), shoe)


func _job_sized(node_name: String, size: Vector3, mat: Material) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	add_child(node)
	var box := BoxMesh.new()
	box.size = size
	_mesh(node, box, mat, Vector3.ZERO)
	return node


## Звено конечности: капсула, висящая вниз от сустава.
func _limb(side: float, length: float, limb_radius: float, mat: Material) -> Node3D:
	var joint := Node3D.new()
	joint.name = "Limb"
	add_child(joint)
	var capsule := CapsuleMesh.new()
	capsule.radius = limb_radius
	capsule.height = length
	_mesh(joint, capsule, mat, Vector3(0.0, -length * 0.5, 0.0))
	return joint


# ---- поза --------------------------------------------------------------------
## Жёсткая рамка: ни одно звено тела не выходит за габарит руля.
## Раньше на большом угле корпус и голова уезжали за грипсы.
func _clamp_inside_scooter() -> void:
	var z_min := -0.28
	var z_max := 0.30
	var y_min: float = deck_top - 0.04
	var y_max: float = deck_top + 1.10
	var parts: Array = [_hips, _chest, _head, _backpack]
	for part in parts:
		if part == null:
			continue
		var p: Vector3 = part.transform.origin
		p.x = clampf(p.x, -0.32, 0.32)
		p.y = clampf(p.y, y_min, y_max)
		p.z = clampf(p.z, z_min, z_max)
		part.position = p


func update_pose(delta: float, steer: float, brake: float, speed_kmh: float,
		grounded: bool, crashed: bool, pitch_deg := 0.0, wheelie := 0.0,
		throttle := 0.0, pitch_rate := 0.0) -> void:
	_time += delta
	_crash_blend = move_toward(_crash_blend, 1.0 if crashed else 0.0, delta * 3.0)
	# Поза станта включается быстро и чуть пружинит: райдер реагирует на угол
	# сразу, как тряпичная кукла, но продолжает стоять на деке.
	_wheelie = move_toward(_wheelie, clampf(wheelie, 0.0, 1.0), delta * 6.0)
	var w := clampf(_wheelie, 0.0, 1.0)

	var brake_clamped := clampf(brake, 0.0, 1.0)
	var speed_factor := clampf(speed_kmh / 55.0, 0.0, 1.0)
	var crouch := clampf(brake_clamped * 0.9 + speed_factor * 0.2 + _crash_blend, 0.0, 1.0)
	crouch *= 1.0 - 0.5 * w

	# На станте райдер распрямляется относительно земли: компенсируем большую
	# часть тангажа самоката, иначе кажется, что его выбрасывает за руль.
	var upright := lerpf(0.65, 0.74, w)
	var pitch_comp := deg_to_rad(clampf(-pitch_deg * upright, -52.0, 52.0) * (1.0 - _crash_blend))
	var body_basis := Basis(Vector3.RIGHT, pitch_comp)
	# Точки деки живут в системе самоката — переводим их в систему райдера,
	# иначе при поднятом носе ступни уезжают с деки.
	var to_body := body_basis.inverse()

	# Наклон корпуса: на станте райдер откидывается назад, к заднему колесу.
	var lean_deg := lerpf(LEAN_BASE_DEG + speed_factor * 6.0 + crouch * 8.0, -16.0, w)
	var lean := deg_to_rad(lean_deg)

	var hip_y := deck_top + HIP_HEIGHT - crouch * 0.10 - 0.05 * w + sin(_time * 6.0) * 0.004
	var hip_z := lerpf(0.07, 0.30, w)
	# Чувствительность: резкий набор угла качнёт корпус назад.
	hip_z += clampf(-pitch_rate * 0.018, -0.05, 0.09) * w
	var hip_pos := Vector3(0.0, hip_y, hip_z)
	_hips.transform = Transform3D(Basis(Vector3.RIGHT, -lean * 0.35), hip_pos)

	var neck_pos := hip_pos + Vector3(0.0, cos(lean) * TORSO_LENGTH, -sin(lean) * TORSO_LENGTH)
	_aim(_chest, hip_pos + Vector3(0.0, 0.03, 0.0), neck_pos + Vector3(0.0, -0.055, 0.0),
		_chest_mesh, TORSO_LENGTH - 0.055)

	var shoulder_y := neck_pos.y - 0.05
	var shoulder_z := neck_pos.z - 0.02

	# Голова сидит на шее и смотрит вперёд, чуть в поворот.
	var head_basis := Basis(Vector3.UP, -steer * deg_to_rad(10.0)) \
		.rotated(Vector3.RIGHT, deg_to_rad(-(lean_deg - 14.0) * 0.5 - crouch * 6.0))
	_head.transform = Transform3D(head_basis,
		Vector3(steer * 0.015, neck_pos.y + HEAD_OFFSET, neck_pos.z - 0.02))

	# Рюкзак за спиной, наклоняется вместе с корпусом.
	var torso_mid := hip_pos + Vector3(0.0, cos(lean) * TORSO_LENGTH * 0.55, -sin(lean) * TORSO_LENGTH * 0.55)
	var back_dir := Vector3(0.0, sin(lean), cos(lean))
	var pack_back := 0.185 * 0.5 + 0.12 * 0.5 + 0.015
	_backpack.transform = Transform3D(Basis(Vector3.RIGHT, -lean), torso_mid + back_dir * pack_back)

	_clamp_inside_scooter()

	# Кисти держатся за руль, пока райдер не упал.
	var left_hand := _bar_point(_bar_left, Vector3(-0.01, -0.02, 0.0))
	var right_hand := _bar_point(_bar_right, Vector3(0.01, -0.02, 0.0))
	if _crash_blend > 0.01:
		var flail := Vector3(0.0, shoulder_y - 0.15, shoulder_z - 0.32)
		left_hand = left_hand.lerp(flail + Vector3(-0.30, 0.0, 0.0), _crash_blend)
		right_hand = right_hand.lerp(flail + Vector3(0.30, 0.0, 0.0), _crash_blend)

	var shoulder_l := Vector3(-0.158, shoulder_y, shoulder_z)
	var shoulder_r := Vector3(0.158, shoulder_y, shoulder_z)
	_solve_arm("l", shoulder_l, left_hand, Vector3(-1.0, 0.25, 0.7))
	_solve_arm("r", shoulder_r, right_hand, Vector3(1.0, 0.25, 0.7))

	# Ноги. На станте опорная (левая) стоит на деке ближе к корме, а правая
	# уходит в воздух и машет, ловя баланс.
	var support_deck := Vector3(-0.075, deck_top + 0.035, lerpf(-0.02, 0.11, w))
	var free_deck := Vector3(0.075, deck_top + 0.035, 0.17)
	var foot_l := to_body * support_deck
	var foot_r := to_body * free_deck
	if w > 0.01:
		var wave := sin(_time * 4.6) * (0.45 + 0.55 * clampf(throttle, 0.0, 1.0))
		wave += clampf(pitch_rate * 0.10, -0.5, 0.5)
		# Нога уходит вбок от деки и машет там, а не вытягивается к рулю.
		var free_air := Vector3(0.315 + 0.055 * wave, deck_top + 0.175 + 0.135 * wave,
			hip_pos.z - 0.10 + 0.06 * wave)
		foot_r = foot_r.lerp(free_air, w)
	_solve_leg("l", Vector3(-0.087, hip_y - 0.02, hip_pos.z), foot_l)
	_solve_leg("r", Vector3(0.087, hip_y - 0.02, hip_pos.z), foot_r)
	var foot_tilt := -4.0 - 26.0 * w
	_foot["l"].transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-4.0)),
		foot_l + Vector3(0.0, -0.01, -0.05))
	_foot["r"].transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(foot_tilt)),
		foot_r + Vector3(0.0, -0.01, -0.05))

	# Корпус поворачивается и наклоняется в поворот, падение — отдельная поза.
	rotation = Vector3(pitch_comp, -steer * deg_to_rad(4.0),
		deg_to_rad(-steer * 4.0) * (1.0 - _crash_blend) + deg_to_rad(40.0) * _crash_blend)
	position.y = sin(_time * 8.0) * 0.008 if not grounded and _crash_blend < 0.5 else 0.0


func _bar_point(marker: Node3D, offset: Vector3) -> Vector3:
	if marker == null:
		return Vector3(0.225, deck_top + 1.12, -0.30)
	return global_transform.affine_inverse() * (marker.global_transform * offset)


## Двухзвенная IK: ставит плечо и локоть так, чтобы кисть попала в цель.
func _solve_arm(key: String, shoulder: Vector3, hand: Vector3, pole: Vector3) -> void:
	var to_hand := hand - shoulder
	var distance := clampf(to_hand.length(), 0.05, UPPER_ARM + FOREARM - 0.01)
	var dir := to_hand.normalized()
	var cos_shoulder := clampf((UPPER_ARM * UPPER_ARM + distance * distance - FOREARM * FOREARM)
		/ (2.0 * UPPER_ARM * distance), -1.0, 1.0)
	var along := UPPER_ARM * cos_shoulder
	var height := sqrt(maxf(0.0, UPPER_ARM * UPPER_ARM - along * along))

	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 0.001:
		perp = Vector3.DOWN
	perp = perp.normalized()
	var elbow := shoulder + dir * along + perp * height

	_aim(_upper_arm[key], shoulder, elbow, null, UPPER_ARM)
	_aim(_forearm[key], elbow, hand - dir * 0.02, null, FOREARM)
	_hand[key].transform = Transform3D(Basis.looking_at(dir, Vector3.UP), hand - dir * 0.04)


func _solve_leg(key: String, hip: Vector3, foot: Vector3) -> void:
	var ankle := foot + Vector3(0.0, 0.075, 0.0)
	var to_foot := ankle - hip
	var distance := clampf(to_foot.length(), 0.1, THIGH + SHIN - 0.01)
	var dir := to_foot.normalized()
	var cos_hip := clampf((THIGH * THIGH + distance * distance - SHIN * SHIN)
		/ (2.0 * THIGH * distance), -1.0, 1.0)
	var along := THIGH * cos_hip
	var height := sqrt(maxf(0.0, THIGH * THIGH - along * along))

	var pole := Vector3(0.0, 0.2, -1.0)
	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 0.001:
		perp = Vector3(0.0, 0.0, -1.0)
	perp = perp.normalized()
	var knee := hip + dir * along + perp * height

	_aim(_thigh[key], hip, knee, null, THIGH)
	_aim(_shin[key], knee, ankle, null, SHIN)


## Ставит звено так, чтобы его локальный -Y смотрел из from в to.
func _aim(joint: Node3D, from: Vector3, to: Vector3, mesh: MeshInstance3D, base_length: float) -> void:
	var delta := to - from
	var distance := maxf(delta.length(), 0.001)
	var dir := delta / distance
	var down := Vector3.DOWN
	var basis := Basis.IDENTITY
	var dot := down.dot(dir)
	if dot < -0.999:
		basis = Basis(Vector3.RIGHT, PI)
	elif dot < 0.999:
		var axis := down.cross(dir)
		basis = Basis(axis.normalized(), acos(clampf(dot, -1.0, 1.0)))
	joint.transform = Transform3D(basis, from)
	if mesh != null:
		mesh.position = Vector3(0.0, -distance * 0.5, 0.0)
		mesh.scale = Vector3(1.0, distance / maxf(base_length, 0.001), 1.0)
