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
## Середины грипс. Маркеры руля — дети узла Steer из GLB, то есть живут в
## координатах файла (y = 1.150 от асфальта), а не в системе игры: смещение
## модели на -AXLE_Y на них действует сверху. |x| = BAR_HALF, z — в системе Steer.
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


## Ось колеса — X, угол вокруг неё считаем в плоскости YZ.
const SPIN_BINS := 36
## Деталь, описанная почти полным кругом, — это само колесо. Дуга (крыло,
## кожух, суппорт) крутиться не должна.
const SPIN_MIN_BINS := 30


## Вынести из пивота колеса всё, что не описано полным кругом вокруг оси:
## крыло, брызговик, суппорт. Такие детали не могут вращаться вместе с шиной.
## Возвращает число треугольников, перенесённых в статичный узел.
func _split_static_parts(wheel: Node3D, parent: Node3D) -> int:
	if wheel == null:
		return 0
	var targets: Array[MeshInstance3D] = []
	if wheel is MeshInstance3D and (wheel as MeshInstance3D).mesh != null:
		targets.append(wheel as MeshInstance3D)
	_gather_meshes(wheel, targets)
	var static_node: Node3D = null
	var moved := 0
	for target in targets:
		var mesh: Mesh = target.mesh
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var spin := ArrayMesh.new()
		var still := ArrayMesh.new()
		for surface in mesh.get_surface_count():
			var split := _split_surface(mesh, surface)
			var spin_arrays: Array = split[0]
			var still_arrays: Array = split[1]
			var mat: Material = target.get_surface_override_material(surface)
			if mat == null:
				mat = mesh.surface_get_material(surface)
			if not spin_arrays.is_empty():
				var spin_index := spin.get_surface_count()
				spin.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, spin_arrays)
				if mat != null:
					spin.surface_set_material(spin_index, mat)
			if not still_arrays.is_empty():
				var still_index := still.get_surface_count()
				still.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, still_arrays)
				if mat != null:
					still.surface_set_material(still_index, mat)
				moved += int((still_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
		if spin.get_surface_count() == 0:
			continue
		target.mesh = spin
		if still.get_surface_count() == 0:
			continue
		# Статичная часть живёт на той же оси, но вне пивота колеса.
		if static_node == null:
			static_node = Node3D.new()
			static_node.name = "%sStatic" % str(wheel.name)
			static_node.position = wheel.position
			parent.add_child(static_node)
		var instance := MeshInstance3D.new()
		instance.name = "%sStatic" % str(target.name)
		instance.mesh = still
		instance.transform = _relative_transform(target, wheel)
		instance.material_override = target.material_override
		instance.cast_shadow = target.cast_shadow
		static_node.add_child(instance)
	return moved


func _gather_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null and not out.has(child):
			out.append(child as MeshInstance3D)
		_gather_meshes(child, out)


## Преобразование узла относительно предка — чтобы статичная копия встала
## ровно на место исходной детали.
func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != ancestor:
		xf = cur.transform * xf
		cur = cur.get_parent() as Node3D
	return xf


func _find(parent: Array[int], x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


func _bit_count(value: int) -> int:
	var bits := 0
	var left := value
	while left != 0:
		left &= left - 1
		bits += 1
	return bits


## Разделить поверхность на «крутится» (полный круг вокруг оси) и «стоит»
## (дуга). Возвращает [массивы колеса, массивы неподвижных деталей] либо пусто.
func _split_surface(mesh: Mesh, surface: int) -> Array:
	var empty: Array = [[], []]
	var arrays: Array = mesh.surface_get_arrays(surface)
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return empty
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals := PackedVector3Array()
	if arrays[Mesh.ARRAY_NORMAL] != null:
		normals = arrays[Mesh.ARRAY_NORMAL]
	var uvs := PackedVector2Array()
	if arrays[Mesh.ARRAY_TEX_UV] != null:
		uvs = arrays[Mesh.ARRAY_TEX_UV]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	var tri_count := int((indices.size() / 3) if indices.size() > 0 else verts.size() / 3)
	if tri_count <= 0:
		return empty

	# Вершины граней по порядку: у GLB индексов нет, у других мешей бывают.
	var corners := PackedInt32Array()
	corners.resize(tri_count * 3)
	for i in corners.size():
		corners[i] = indices[i] if indices.size() > 0 else i

	# Сшиваем совпадающие вершины: иначе каждая грань — отдельная деталь.
	var weld := {}
	var parent: Array[int] = []
	var welded_pos: Array[Vector3] = []
	var ids := PackedInt32Array()
	ids.resize(corners.size())
	for i in corners.size():
		var v: Vector3 = verts[corners[i]]
		var key := Vector3i(roundi(v.x * 10000.0), roundi(v.y * 10000.0),
			roundi(v.z * 10000.0))
		var id: int = weld.get(key, -1)
		if id < 0:
			id = parent.size()
			weld[key] = id
			parent.append(id)
			welded_pos.append(v)
		ids[i] = id

	# Треугольники одной детали — в одну группу.
	for t in tri_count:
		var a := _find(parent, ids[t * 3])
		var b := _find(parent, ids[t * 3 + 1])
		var c := _find(parent, ids[t * 3 + 2])
		if b != a:
			parent[b] = a
		if c != a:
			parent[c] = a

	# Сколько секторов вокруг оси занимает деталь: полный круг — это колесо.
	var masks := {}
	for id in parent.size():
		var root := _find(parent, id)
		var p: Vector3 = welded_pos[id]
		var sector := int(floor((atan2(p.z, p.y) + PI) / (TAU / float(SPIN_BINS))))
		sector = clampi(sector, 0, SPIN_BINS - 1)
		masks[root] = int(masks.get(root, 0)) | (1 << sector)

	var spin_pos := PackedVector3Array()
	var spin_nor := PackedVector3Array()
	var spin_uv := PackedVector2Array()
	var still_pos := PackedVector3Array()
	var still_nor := PackedVector3Array()
	var still_uv := PackedVector2Array()
	var has_normals := not normals.is_empty()
	var has_uvs := not uvs.is_empty()
	for t in tri_count:
		var turns := _bit_count(int(masks[_find(parent, ids[t * 3])])) >= SPIN_MIN_BINS
		for k in 3:
			var index := corners[t * 3 + k]
			if turns:
				spin_pos.append(verts[index])
				if has_normals:
					spin_nor.append(normals[index])
				if has_uvs:
					spin_uv.append(uvs[index])
			else:
				still_pos.append(verts[index])
				if has_normals:
					still_nor.append(normals[index])
				if has_uvs:
					still_uv.append(uvs[index])

	if spin_pos.is_empty() or still_pos.is_empty():
		# Делить нечего: либо колесо целиком, либо деталь целиком.
		return empty
	return [
		_arrays_of(spin_pos, spin_nor, spin_uv, has_normals, has_uvs),
		_arrays_of(still_pos, still_nor, still_uv, has_normals, has_uvs),
	]


func _arrays_of(pos: PackedVector3Array, nor: PackedVector3Array,
		uv: PackedVector2Array, has_normals: bool, has_uvs: bool) -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	if has_normals:
		arrays[Mesh.ARRAY_NORMAL] = nor
	if has_uvs:
		arrays[Mesh.ARRAY_TEX_UV] = uv
	return arrays


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

	# В файле крыло заднего колеса лежит в том же меше, что и шина: при
	# вращении колеса крыло крутилось вместе с ним (со стороны — «колесо
	# крутится вместе с маятником»). Разделяем детали по углу вокруг оси.
	var rear_moved := _split_static_parts(rear, inst)
	var front_moved := _split_static_parts(front, inst)
	print("G4UserModel: неподвижных деталей вынесено из колёс: rear=%d front=%d" % [
		rear_moved, front_moved,
	])

	var bar_left := Node3D.new()
	bar_left.name = "BarLeft"
	bar_left.position = Vector3(-BAR_HALF, BAR_Y, BAR_Z)
	steer.add_child(bar_left)
	var bar_right := Node3D.new()
	bar_right.name = "BarRight"
	bar_right.position = Vector3(BAR_HALF, BAR_Y, BAR_Z)
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
