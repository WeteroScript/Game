## KuKirin G4 — модель, загруженная пользователем (base.glb → g4_user.glb).
##
## Файл специально разбит на три меша, чтобы колеса могли крутиться:
##   Body (рама/стойка/руль), WheelFront, WheelRear — пивоты стоят на осях.
## Масштаб приведён к игровому (1.211 м длина, радиус колеса 0.153 м).
class_name G4UserModel
extends RefCounted

## Файл лежит как .dat: Godot его не импортирует, а мы разбираем сами —
## импорт GLB вешал шаг «Import project resources» в CI.
const PATH := "res://assets/models/g4_user.glb.dat"
const R := 0.153
const AXLE_F := -0.4525
const AXLE_R := 0.4525
const BAR_Y := 1.150
const BAR_HALF := 0.235
const DECK_TOP := 0.243

var spec: ScooterSpec
var _bytes_cache: PackedByteArray


## Свой материал поверх GLB: модель не должна зависеть от того, что записано
## в файле (там может не быть материала или нормалей).
func _apply_material(node: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.105, 0.115, 0.110)
	mat.metallic = 0.55
	mat.roughness = 0.42
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = mat
			(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_apply_material(child)


## Разбор GLB в рантайме: свой буфер, свой GLTFDocument.
func _load_scene() -> Node3D:
	if not FileAccess.file_exists(PATH):
		push_warning("G4UserModel: нет файла " + PATH)
		return null
	var bytes := _bytes_cache if not _bytes_cache.is_empty() else FileAccess.get_file_as_bytes(PATH)
	_bytes_cache = bytes
	if bytes.is_empty():
		push_warning("G4UserModel: пустой файл " + PATH)
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_buffer(bytes, "res://assets/models/", state)
	if err != OK:
		push_warning("G4UserModel: GLB не разобран, код %d" % err)
		return null
	var scene := doc.generate_scene(state)
	if scene == null:
		push_warning("G4UserModel: сцена из GLB не собралась")
		return null
	_apply_material(scene)
	return scene


func build_model(new_spec: ScooterSpec) -> Dictionary:
	spec = new_spec
	# Высота деки берётся с фактической геометрии модели, иначе райдер висит.
	spec.deck_height = DECK_TOP
	var root := Node3D.new()
	root.name = "Model"

	var inst: Node3D = _load_scene()
	if inst != null:
		inst.name = "UserMesh"
		# Модель собрана «рулём назад»: разворачиваем, чтобы перед смотрел в -Z.
		inst.rotation = Vector3(0.0, PI, 0.0)
		root.add_child(inst)

	var body: Node3D = null
	var front: Node3D = null
	var rear: Node3D = null
	var fork: Node3D = null
	if inst != null:
		body = inst.get_node_or_null("Body")
		front = inst.get_node_or_null("WheelFront")
		rear = inst.get_node_or_null("WheelRear")
		fork = inst.get_node_or_null("Steer")

	# Передняя сборка: колесо висит на узле Steer, чтобы поворачиваться с рулём.
	var steer := Node3D.new()
	steer.name = "Steer"
	root.add_child(steer)
	# Иерархия уже собрана в GLB (Steer -> SteerMesh + WheelFront), поэтому
	# ничего не перевешиваем — только подключаем узлы.
	if fork != null:
		steer = fork
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
	bar_left.position = Vector3(-BAR_HALF, BAR_Y, -0.285)
	steer.add_child(bar_left)
	var bar_right := Node3D.new()
	bar_right.name = "BarRight"
	bar_right.position = Vector3(BAR_HALF, BAR_Y, -0.285)
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
