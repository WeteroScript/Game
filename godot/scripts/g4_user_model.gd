## KuKirin G4 — модель, загруженная пользователем (base.glb → g4_user.glb).
##
## Файл разбит так, чтобы колесо крутилось, а вилка поворачивалась:
##   model → Body (рама/дека), RearWheel, Steer (рулевая колонка)
##   Steer → SteerMesh (вилка и руль), WheelFront.
## Пивоты стоят на осях: у колёс — центр колеса, у вилки — ось рулевой колонки.
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
## Середины грипс: |x| = BAR_HALF, z в системе рулевой колонки (Steer).
const BAR_HALF := 0.235
const BAR_Z := -0.201
const DECK_TOP := 0.243
## Высота оси колёс в координатах файла: модель построена от асфальта, а игра
## ставит начало координат на ось колёс, поэтому модель опускается на AXLE_Y.
const AXLE_Y := 0.156

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


func _node_name(node: Node3D) -> String:
	if node == null:
		return "нет"
	if not node.is_inside_tree():
		return str(node.name)
	return str(node.get_path())


## Узел GLB по имени: файл может быть обёрнут root-узлом (`Scene → model → …`),
## поэтому ищем и в корне, и вглубь — от этого зависит, будут ли крутиться колёса.
func _pick(node: Node, wanted: String) -> Node3D:
	if node == null:
		return null
	if node.name == wanted and node is Node3D:
		return node as Node3D
	var direct := node.get_node_or_null(wanted)
	if direct is Node3D:
		return direct as Node3D
	var found := node.find_child(wanted, true, false)
	if found is Node3D:
		return found as Node3D
	return null


func build_model(new_spec: ScooterSpec) -> Dictionary:
	spec = new_spec
	# Дека в координатах игры: модель построена «от земли», а в игре y = 0 — ось колёс.
	spec.deck_height = DECK_TOP - AXLE_Y
	var root := Node3D.new()
	root.name = "Model"

	# В файле низ колёс лежит на y = 0 (модель строилась от асфальта), а игра
	# ставит начало координат самоката на ось колёс: поднимаем модель ВНИЗ на
	# высоту оси. Без этого самокат «левитирует» над дорогой на ~24 см.
	var inst: Node3D = _load_scene()
	if inst != null:
		inst.name = "UserMesh"
		# Модель собрана «рулём назад»: разворачиваем, чтобы перед смотрел в -Z.
		inst.rotation = Vector3(0.0, PI, 0.0)
		inst.position = Vector3(0.0, -AXLE_Y, 0.0)
		root.add_child(inst)

	var body := _pick(inst, "Body")
	var front := _pick(inst, "WheelFront")
	# В файле заднее колесо называется RearWheel; старое имя тоже принимаем,
	# иначе узел не находился и колесо стояло на месте.
	var rear := _pick(inst, "RearWheel")
	if rear == null:
		rear = _pick(inst, "WheelRear")
	var fork := _pick(inst, "Steer")
	print("G4UserModel: body=%s steer=%s front=%s rear=%s" % [
		_node_name(body), _node_name(fork), _node_name(front), _node_name(rear),
	])

	# Передняя сборка: колесо — ребёнок Steer, поэтому поворачивается с рулём.
	# Иерархия уже собрана в GLB, ничего не перевешиваем.
	var steer := fork
	if steer == null:
		steer = Node3D.new()
		steer.name = "Steer"
		steer.position = Vector3(0.0, 0.0, 0.360)
		root.add_child(steer)
	if front == null:
		front = Node3D.new()
		front.name = "WheelFront"
		front.position = Vector3(0.0, 0.0, AXLE_F)
		steer.add_child(front)
	if rear == null:
		rear = Node3D.new()
		rear.name = "WheelRear"
		rear.position = Vector3(0.0, 0.0, AXLE_R)
		root.add_child(rear)

	var bar_left := Node3D.new()
	bar_left.name = "BarLeft"
	bar_left.position = Vector3(-BAR_HALF, BAR_Y - AXLE_Y, BAR_Z)
	steer.add_child(bar_left)
	var bar_right := Node3D.new()
	bar_right.name = "BarRight"
	bar_right.position = Vector3(BAR_HALF, BAR_Y - AXLE_Y, BAR_Z)
	steer.add_child(bar_right)

	var foot_left := Node3D.new()
	foot_left.name = "FootLeft"
	foot_left.position = Vector3(-0.070, DECK_TOP - AXLE_Y + 0.010, -0.08)
	root.add_child(foot_left)
	var foot_right := Node3D.new()
	foot_right.name = "FootRight"
	foot_right.position = Vector3(0.070, DECK_TOP - AXLE_Y + 0.010, -0.08)
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
