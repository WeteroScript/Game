## KuKirin G4 — модель, загруженная пользователем (base.glb → g4_user.glb).
##
## Файл специально разбит на три меша, чтобы колеса могли крутиться:
##   Body (рама/стойка/руль), WheelFront, WheelRear — пивоты стоят на осях.
## Масштаб приведён к игровому (1.211 м длина, радиус колеса 0.153 м).
class_name G4UserModel
extends RefCounted

const PATH := "res://assets/models/g4_user.glb"
const R := 0.153
const AXLE_F := -0.4525
const AXLE_R := 0.4525
const BAR_Y := 0.962
const BAR_HALF := 0.290
const DECK_TOP := 0.168

var spec: ScooterSpec


func build_model(new_spec: ScooterSpec) -> Dictionary:
	spec = new_spec
	var root := Node3D.new()
	root.name = "Model"

	var packed: PackedScene = load(PATH)
	var inst: Node3D = null
	if packed != null:
		inst = packed.instantiate()
		inst.name = "UserMesh"
		root.add_child(inst)

	var body: Node3D = null
	var front: Node3D = null
	var rear: Node3D = null
	if inst != null:
		body = inst.get_node_or_null("Body")
		front = inst.get_node_or_null("WheelFront")
		rear = inst.get_node_or_null("WheelRear")

	# Передняя сборка: колесо висит на узле Steer, чтобы поворачиваться с рулём.
	var steer := Node3D.new()
	steer.name = "Steer"
	root.add_child(steer)
	if front != null and front.get_parent() != null:
		front.reparent(steer, true)
	else:
		front = Node3D.new()
		front.name = "WheelFront"
		front.position = Vector3(0.0, R, AXLE_F)
		steer.add_child(front)
	if rear == null:
		rear = Node3D.new()
		rear.name = "WheelRear"
		rear.position = Vector3(0.0, R, AXLE_R)
		root.add_child(rear)

	var bar_left := Node3D.new()
	bar_left.name = "BarLeft"
	bar_left.position = Vector3(-(BAR_HALF - 0.09), BAR_Y, AXLE_F + 0.09)
	steer.add_child(bar_left)
	var bar_right := Node3D.new()
	bar_right.name = "BarRight"
	bar_right.position = Vector3(BAR_HALF - 0.09, BAR_Y, AXLE_F + 0.09)
	steer.add_child(bar_right)

	var foot_left := Node3D.new()
	foot_left.name = "FootLeft"
	foot_left.position = Vector3(-0.070, DECK_TOP + 0.010, -0.08)
	root.add_child(foot_left)
	var foot_right := Node3D.new()
	foot_right.name = "FootRight"
	foot_right.position = Vector3(0.070, DECK_TOP + 0.010, -0.08)
	root.add_child(foot_right)

	if body == null:
		push_warning("G4UserModel: в GLB нет узла Body")

	return {
		"root": root,
		"front_steer": steer,
		"front_wheel": front,
		"rear_wheel": rear,
		"bar_left": bar_left,
		"bar_right": bar_right,
		"foot_left": foot_left,
		"foot_right": foot_right,
	}
