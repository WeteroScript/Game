## Райдер: процедурный человечек, который стоит на деке, держится за руль
## (руки тянутся к маркерам руля через двухзвенную IK) и реагирует на торможение,
## поворот и падение.
##
## Все суставы — плоский список дочерних узлов, каждый позиционируется в
## пространстве райдера: так поза считается без накопления поворотов.
class_name RiderModel
extends Node3D

const HIP_HEIGHT := 0.62
const SHOULDER_HEIGHT := 1.06
const HEAD_HEIGHT := 1.24
const UPPER_ARM := 0.27
const FOREARM := 0.26
const THIGH := 0.34
const SHIN := 0.32

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
	var helmet := _mat(HELMET, 0.35)
	var visor := _mat(VISOR, 0.15)
	var stripe := _mat(accent, 0.4)

	# Таз и корпус.
	_hips = _job_sized("Hips", Vector3(0.26, 0.16, 0.19), pants)
	_chest = _job()
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.34, SHOULDER_HEIGHT - HIP_HEIGHT, 0.21)
	_chest_mesh = _mesh(_chest, chest_mesh, jacket, Vector3(0.0, -(SHOULDER_HEIGHT - HIP_HEIGHT) * 0.5, 0.0))
	# Плечи в цвет акцента.
	for side in [-1.0, 1.0]:
		var shoulder := BoxMesh.new()
		shoulder.size = Vector3(0.10, 0.09, 0.20)
		_mesh(_chest, shoulder, stripe, Vector3(side * 0.155, -0.06, 0.0))

	# Рюкзак.
	_backpack = _job()
	var pack := BoxMesh.new()
	pack.size = Vector3(0.26, 0.32, 0.14)
	_mesh(_backpack, pack, jacket, Vector3(0.0, -0.16, 0.0))
	var pack_stripe := BoxMesh.new()
	pack_stripe.size = Vector3(0.06, 0.30, 0.02)
	_mesh(_backpack, pack_stripe, stripe, Vector3(0.0, -0.16, 0.08))

	# Голова в шлеме.
	_head = _job()
	var neck := CylinderMesh.new()
	neck.top_radius = 0.055
	neck.bottom_radius = 0.06
	neck.height = 0.08
	_mesh(_head, neck, skin, Vector3(0.0, -0.03, 0.0))
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.098
	head_mesh.height = 0.196
	_mesh(_head, head_mesh, skin, Vector3(0.0, 0.07, 0.0))
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.125
	helmet_mesh.height = 0.25
	_mesh(_head, helmet_mesh, helmet, Vector3(0.0, 0.085, 0.0))
	var visor_mesh := SphereMesh.new()
	visor_mesh.radius = 0.116
	visor_mesh.height = 0.12
	_mesh(_head, visor_mesh, visor, Vector3(0.0, 0.075, -0.055))
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.02, 0.26, 0.20)
	_mesh(_head, stripe_mesh, stripe, Vector3(0.0, 0.09, 0.0))

	# Руки и ноги.
	for side in [-1.0, 1.0]:
		var key := "l" if side < 0.0 else "r"
		_upper_arm[key] = _limb(side, UPPER_ARM, 0.045, jacket)
		_forearm[key] = _limb(side, FOREARM, 0.038, jacket)
		_hand[key] = _job_sized("Hand_" + key, Vector3(0.075, 0.09, 0.085), glove)
		_thigh[key] = _limb(side, THIGH, 0.062, pants)
		_shin[key] = _limb(side, SHIN, 0.05, pants)
		_foot[key] = _job_sized("Foot_" + key, Vector3(0.10, 0.07, 0.24), shoe)


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
func update_pose(delta: float, steer: float, brake: float, speed_kmh: float,
		grounded: bool, crashed: bool) -> void:
	_time += delta
	var target_blend := 1.0 if crashed else 0.0
	_crash_blend = move_toward(_crash_blend, target_blend, delta * 3.0)

	var brake_clamped := clampf(brake, 0.0, 1.0)
	var speed_factor := clampf(speed_kmh / 55.0, 0.0, 1.0)
	var crouch := clampf(brake_clamped * 0.9 + speed_factor * 0.25 + _crash_blend, 0.0, 1.0)

	var hip_y := deck_top + HIP_HEIGHT - crouch * 0.11
	var hip_z := 0.06 + crouch * 0.02
	var shoulder_y := hip_y + (SHOULDER_HEIGHT - HIP_HEIGHT) * (1.0 - crouch * 0.12)
	var shoulder_z := -0.02 - crouch * 0.06

	# Лёгкое покачивание корпуса — райдер живой, а не манекен.
	var sway := sin(_time * 6.0) * 0.006 * (0.4 + speed_factor)
	var hips_pos := Vector3(0.0, hip_y + sway, hip_z)
	_hips.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-crouch * 12.0)), hips_pos)

	var neck_pos := Vector3(0.0, shoulder_y, shoulder_z)
	_aim(_chest, hips_pos + Vector3(0.0, 0.05, 0.0), neck_pos, _chest_mesh,
		SHOULDER_HEIGHT - HIP_HEIGHT)

	# Голова смотрит вперёд и чуть в поворот.
	_head.transform = Transform3D(Basis(Vector3.UP, -steer * deg_to_rad(9.0)).rotated(Vector3.RIGHT, deg_to_rad(-6.0 - crouch * 8.0)),
		Vector3(steer * 0.02, shoulder_y + 0.16, shoulder_z - 0.03))

	# Рюкзак за спиной, наклоняется вместе с корпусом.
	_backpack.transform = Transform3D(
		Basis(Vector3.RIGHT, deg_to_rad(-12.0 - crouch * 10.0)),
		Vector3(0.0, shoulder_y - 0.16, shoulder_z + 0.20))

	# Кисти: на руле, пока не упали.
	var left_hand := _bar_point(_bar_left, Vector3(-0.02, -0.02, 0.0))
	var right_hand := _bar_point(_bar_right, Vector3(0.02, -0.02, 0.0))
	if _crash_blend > 0.01:
		var flail := Vector3(0.28, shoulder_y - 0.18, shoulder_z - 0.25)
		left_hand = left_hand.lerp(flail * Vector3(1.0, 1.0, 1.0) + Vector3(-0.15, 0.0, 0.0), _crash_blend)
		right_hand = right_hand.lerp(flail + Vector3(0.15, 0.0, 0.0), _crash_blend)

	var shoulder_l := Vector3(-0.175, shoulder_y - 0.02, shoulder_z)
	var shoulder_r := Vector3(0.175, shoulder_y - 0.02, shoulder_z)
	_solve_arm("l", shoulder_l, left_hand, Vector3(-1.0, 0.2, 0.6))
	_solve_arm("r", shoulder_r, right_hand, Vector3(1.0, 0.2, 0.6))

	# Ноги: стопы на деке, колени чуть вперёд (сгибаются при торможении).
	var foot_l := Vector3(-0.075, deck_top + 0.035, -0.02)
	var foot_r := Vector3(0.075, deck_top + 0.035, 0.16)
	_solve_leg("l", Vector3(-0.09, hip_y - 0.03, hip_z), foot_l)
	_solve_leg("r", Vector3(0.09, hip_y - 0.03, hip_z), foot_r)

	_foot["l"].transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-4.0)), foot_l + Vector3(0.0, 0.0, -0.06))
	_foot["r"].transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-4.0)), foot_r + Vector3(0.0, 0.0, -0.06))

	# Корпус наклоняется в поворот вместе с самокатом.
	var lean := deg_to_rad(-steer * 4.0)
	rotation = Vector3(0.0, -steer * deg_to_rad(3.0), lean * (1.0 - _crash_blend) + deg_to_rad(38.0) * _crash_blend)
	if not grounded:
		position.y = sin(_time * 8.0) * 0.01
	else:
		position.y = 0.0


func _bar_point(marker: Node3D, offset: Vector3) -> Vector3:
	if marker == null:
		return Vector3(0.225, deck_top + 0.9, -0.4)
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
