## Общая база для процедурных моделей самокатов: материалы, гнутые корпуса,
## колёса с шашками и диском, руль, бортовой компьютер, амортизаторы, тросы.
##
## Модель собирается из деталей в реальных миллиметрах: колёсная база, высота
## деки и вылет руля берутся из ScooterSpec, остальное задают наследники
## (G4Model, F3Model) по фотографиям своих самокатов.
class_name ScooterModelBase
extends RefCounted

const RUBBER := Color(0.095, 0.094, 0.099)

const TAPE := Color(0.055, 0.055, 0.060)
const STEEL := Color(0.80, 0.82, 0.85)
const ALU := Color(0.66, 0.68, 0.71)
const DARK_PLASTIC := Color(0.070, 0.073, 0.082)
const MATTE_BLACK := Color(0.042, 0.042, 0.048)
const SCREEN_LIGHT := Color(0.35, 0.92, 1.0)
const LAMP := Color(1.0, 0.95, 0.84)
const TAIL := Color(1.0, 0.14, 0.10)
const AMBER := Color(1.0, 0.55, 0.06)

var spec: ScooterSpec
var radius := 0.162
var base := 1.06
var deck_top := 0.10
var deck_len := 0.64
var deck_w := 0.215
var steer_z := -0.33

var _paint: StandardMaterial3D
var _paint_dark: StandardMaterial3D
var _accent: StandardMaterial3D
var _plastic: StandardMaterial3D
var _rubber: StandardMaterial3D
var _tape: StandardMaterial3D
var _steel: StandardMaterial3D
var _alu: StandardMaterial3D
var _rim: StandardMaterial3D
var _screen: StandardMaterial3D
var _lamp: StandardMaterial3D
var _tail: StandardMaterial3D
var _amber: StandardMaterial3D
var _caliper: StandardMaterial3D
var _rubber_dark: StandardMaterial3D


# ---- сборка ------------------------------------------------------------------
func build_model(new_spec: ScooterSpec) -> Dictionary:
	_prepare(new_spec)
	var root := Node3D.new()
	root.name = "Model"
	_build_body(root)
	var steer := _build_steer(root)
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


func _prepare(new_spec: ScooterSpec) -> void:
	spec = new_spec
	radius = spec.wheel_radius
	base = spec.wheel_base
	deck_top = spec.deck_height if spec.deck_height > 0.02 else radius * 0.62
	deck_len = clampf(spec.deck_length + 0.13, 0.55, 0.70)
	deck_w = spec.deck_width
	# Рулевой стакан стоит на 0.20 м позади передней оси — как на фото.
	steer_z = -base * 0.5 + 0.20
	_make_materials()


func _make_materials() -> void:
	# Краска: слабый металлик и низкая шероховатость — читается как автолак.
	_paint = _mat(spec.frame_color, 0.16, 0.52)
	_paint.clearcoat_enabled = true
	_paint.clearcoat = 0.22
	_paint.clearcoat_roughness = 0.34
	_paint_dark = _mat(spec.frame_color.darkened(0.45), 0.12, 0.55)
	_accent = _mat(spec.accent_color, 0.12, 0.30)
	_accent.clearcoat_enabled = true
	_accent.clearcoat = 0.4
	_accent.clearcoat_roughness = 0.18
	_plastic = _mat(DARK_PLASTIC, 0.15, 0.55)
	_rubber = _mat(RUBBER, 0.0, 0.92, Color.BLACK, 0.0, true)
	_rubber.albedo_texture = _speckle(Color(0.098, 0.096, 0.101), 0.30, 48, 777)
	_rubber.uv1_scale = Vector3(4.0, 4.0, 4.0)
	_tape = _mat(TAPE, 0.0, 0.95)
	_tape.albedo_texture = _speckle(Color(0.062, 0.062, 0.067), 0.22)
	_tape.uv1_scale = Vector3(3.0, 3.0, 3.0)
	_tape.uv1_triplanar = true
	_steel = _mat(STEEL, 0.95, 0.22)
	_alu = _mat(ALU, 0.85, 0.30)
	_rim = _mat(Color(0.095, 0.100, 0.110), 0.65, 0.30)
	_screen = _mat(Color(0.01, 0.03, 0.05), 0.05, 0.10, SCREEN_LIGHT, 0.45)
	_lamp = _mat(Color(0.95, 0.93, 0.86), 0.15, 0.20, LAMP, 1.6)
	_tail = _mat(Color(0.30, 0.03, 0.03), 0.10, 0.30, TAIL, 2.2)
	_amber = _mat(Color(0.35, 0.18, 0.02), 0.10, 0.30, AMBER, 1.4)
	_rubber_dark = _mat(Color(0.055, 0.054, 0.058), 0.0, 0.80)
	_caliper = _mat(Color(0.62, 0.085, 0.065), 0.35, 0.32)


# ---- наследники --------------------------------------------------------------
func _build_body(_root: Node3D) -> void:
	pass


func _build_steer(_root: Node3D) -> Node3D:
	return null


## Процедурное зерно без внешних файлов: шершавый гриптейп, резина, металл.
func _speckle(base: Color, spread: float, size := 48, seed_value := 20260101) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in size:
		for x in size:
			var n := rng.randf()
			var c: Color = base.lightened(spread * n) if n > 0.5 else base.darkened(spread * (1.0 - n))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# ---- материалы и примитивы ---------------------------------------------------
func _mat(color: Color, metallic := 0.2, roughness := 0.6,
		emission_color := Color.BLACK, emission_energy := 0.0,
		double_sided := false) -> StandardMaterial3D:
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
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


## Корпус с фаской: даёт «мягкие» рёбра вместо картонных углов.
func _rbox(parent: Node3D, size: Vector3, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, bevel := 0.006) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.45)
	var x0 := -h.x
	var x1 := h.x
	var y0 := -h.y
	var y1 := h.y
	var z0 := -h.z
	var z1 := h.z
	var ix := h.x - b
	var iy := h.y - b
	var iz := h.z - b
	# Шесть основных граней.
	var faces := [
		[Vector3(x1, -iy, -iz), Vector3(x1, -iy, iz), Vector3(x1, iy, iz), Vector3(x1, iy, -iz)],
		[Vector3(x0, iy, -iz), Vector3(x0, iy, iz), Vector3(x0, -iy, iz), Vector3(x0, -iy, -iz)],
		[Vector3(-ix, y1, -iz), Vector3(ix, y1, -iz), Vector3(ix, y1, iz), Vector3(-ix, y1, iz)],
		[Vector3(-ix, y0, iz), Vector3(ix, y0, iz), Vector3(ix, y0, -iz), Vector3(-ix, y0, -iz)],
		[Vector3(-ix, -iy, z1), Vector3(ix, -iy, z1), Vector3(ix, iy, z1), Vector3(-ix, iy, z1)],
		[Vector3(ix, -iy, z0), Vector3(-ix, -iy, z0), Vector3(-ix, iy, z0), Vector3(ix, iy, z0)],
	]
	var normals := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN,
		Vector3.BACK, Vector3.FORWARD]
	for i in 6:
		_quad_out(st, faces[i][0], faces[i][1], faces[i][2], faces[i][3], normals[i])
	# Двенадцать рёбер-фасок.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var out := Vector3(sx, sy, 0.0).normalized()
			_quad_out(st,
				Vector3(sx * h.x, sy * iy, -iz), Vector3(sx * h.x, sy * iy, iz),
				Vector3(sx * ix, sy * h.y, iz), Vector3(sx * ix, sy * h.y, -iz), out)
		for sz in [-1.0, 1.0]:
			var out2 := Vector3(sx, 0.0, sz).normalized()
			_quad_out(st,
				Vector3(sx * h.x, -iy, sz * h.z), Vector3(sx * h.x, iy, sz * h.z),
				Vector3(sx * ix, iy, sz * iz), Vector3(sx * ix, -iy, sz * iz), out2)
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var out3 := Vector3(0.0, sy, sz).normalized()
			_quad_out(st,
				Vector3(-ix, sy * h.y, sz * h.z), Vector3(ix, sy * h.y, sz * h.z),
				Vector3(ix, sy * iy, sz * iz), Vector3(-ix, sy * iy, sz * iz), out3)
	# Восемь угловых треугольников.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var out4 := Vector3(sx, sy, sz).normalized()
				var a := Vector3(sx * h.x, sy * iy, sz * iz)
				var c := Vector3(sx * ix, sy * iy, sz * h.z)
				var d := Vector3(sx * ix, sy * h.y, sz * iz)
				var n := (c - a).cross(d - a)
				if n.dot(out4) >= 0.0:
					_quad_out(st, a, c, d, d, out4)
				else:
					_quad_out(st, a, d, c, c, out4)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = mat
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


func _quad_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		out_dir: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(out_dir) < 0.0:
		_quad(st, a, d, c, b)
	else:
		_quad(st, a, b, c, d)


func _cyl(parent: Node3D, cyl_radius: float, height: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO, segments := 20) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = cyl_radius
	cylinder.bottom_radius = cyl_radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	instance.mesh = cylinder
	instance.material_override = mat
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


func _cone(parent: Node3D, bottom: float, top: float, height: float, pos: Vector3,
		mat: Material, rot := Vector3.ZERO, segments := 20) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	instance.mesh = cylinder
	instance.material_override = mat
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, sphere_radius: float, pos: Vector3, mat: Material,
		scale := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = sphere_radius
	mesh.height = sphere_radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	instance.scale = scale
	parent.add_child(instance)
	return instance


func _torus(parent: Node3D, inner: float, outer: float, mat: Material,
		rot := Vector3.ZERO, center := Vector3.ZERO, rings := 20) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = rings
	torus.ring_segments = 8
	instance.mesh = torus
	instance.material_override = mat
	instance.rotation = rot + Vector3(0.0, 0.0, deg_to_rad(90.0))
	instance.position = center
	parent.add_child(instance)
	return instance


## Кольцо (шина, диск) с прямоугольным профилем — не «бублик».
func _ring(parent: Node3D, outer: float, inner: float, half_width: float,
		mat: Material, segments := 30, center := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
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
		_quad(st, l + o0, r + o0, r + o1, l + o1)
		_quad(st, r + n1, l + n1, l + n0, r + n0)
		_quad(st, r + n0, r + o0, r + o1, r + n1)
		_quad(st, l + o0, l + n0, l + n1, l + o1)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = mat
	instance.position = center
	parent.add_child(instance)
	return instance




# ---- гнутые оболочки ---------------------------------------------------------
## Точки скруглённого прямоугольника (x — полширины, y — полувысоты) по кругу.
## Из таких сечений собираются дека, стойка, короба — не коробки, а оболочки.
func _round_ring(half_w: float, half_h: float, corner: float, steps := 5) -> Array:
	var r: float = minf(corner, minf(half_w, half_h) * 0.99)
	var pts := []
	var centers := [
		Vector2(half_w - r, half_h - r), Vector2(-(half_w - r), half_h - r),
		Vector2(-(half_w - r), -(half_h - r)), Vector2(half_w - r, -(half_h - r)),
	]
	var first := [0.0, 90.0, 180.0, 270.0]
	for ci in 4:
		var c: Vector2 = centers[ci]
		var a0: float = first[ci]
		for st in steps + 1:
			var a := deg_to_rad(a0 + 90.0 * float(st) / float(steps))
			pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Оболочка по кольцам: гладкие нормали, мягкие рёбра, любой изгиб.
func _loft(parent: Node3D, rings: Array, mat: Material, caps := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = (rings[0] as PackedVector3Array).size()
	var centers := []
	for ring in rings:
		centers.append(_centroid(ring as PackedVector3Array))
	for ri in rings.size() - 1:
		var a: PackedVector3Array = rings[ri]
		var b: PackedVector3Array = rings[ri + 1]
		var c0: Vector3 = centers[ri]
		var c1: Vector3 = centers[ri + 1]
		for i in count:
			var j := (i + 1) % count
			var mid: Vector3 = (a[i] + a[j] + b[i] + b[j]) * 0.25
			var inner: Vector3 = ((a[i] + a[j]) * 0.5 + (b[i] + b[j]) * 0.5) * 0.5
			_quad_out(st, a[i], a[j], b[j], b[i], mid - (inner.lerp((c0 + c1) * 0.5, 0.5)))
	if caps:
		var axis: Vector3 = (centers[centers.size() - 1] - centers[0]).normalized()
		_cap_ring(st, rings[0] as PackedVector3Array, -axis)
		_cap_ring(st, rings[rings.size() - 1] as PackedVector3Array, axis)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = mat
	parent.add_child(instance)
	return instance


func _centroid(ring: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in ring:
		c += p
	return c / float(maxi(ring.size(), 1))


## Заглушка оболочки: веер из центра кольца, нормаль вдоль оси оболочки.
func _cap_ring(st: SurfaceTool, ring: PackedVector3Array, axis: Vector3) -> void:
	var center := _centroid(ring)
	for i in ring.size():
		var j := (i + 1) % ring.size()
		var n := (ring[i] - center).cross(ring[j] - center)
		if n.dot(axis) < 0.0:
			st.add_vertex(center)
			st.add_vertex(ring[j])
			st.add_vertex(ring[i])
		else:
			st.add_vertex(center)
			st.add_vertex(ring[i])
			st.add_vertex(ring[j])


## Оболочка из сечений вида {pos, w, h, r, basis?}: строится вдоль локальной Z.
func _loft_rect(parent: Node3D, sections: Array, mat: Material, caps := true) -> MeshInstance3D:
	var rings := []
	for section in sections:
		var basis: Basis = section.get("basis", Basis.IDENTITY)
		var origin: Vector3 = section["pos"]
		var pts := _round_ring(float(section["w"]) * 0.5, float(section["h"]) * 0.5,
			float(section.get("r", 0.012)), int(section.get("steps", 5)))
		var dx: float = float(section.get("dx", 0.0))
		var dy: float = float(section.get("dy", 0.0))
		var ring := PackedVector3Array()
		for pt in pts:
			ring.append(origin + basis * Vector3(pt.x * (1.0 + dx), pt.y * (1.0 + dy), 0.0))
		rings.append(ring)
	return _loft(parent, rings, mat, caps)


## Тело вращения вокруг оси X: шина, обод, ступица. Профиль — (радиус, осевое).
func _revolve(parent: Node3D, profile: Array, segments: int, mat: Material,
		center := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var area := 0.0
	for i in profile.size():
		var p: Vector2 = profile[i]
		var q: Vector2 = profile[(i + 1) % profile.size()]
		area += p.x * q.y - q.x * p.y
	var orientation := 1.0 if area >= 0.0 else -1.0
	for s in segments:
		var a0 := TAU * float(s) / float(segments)
		var a1 := TAU * float(s + 1) / float(segments)
		var am := (a0 + a1) * 0.5
		for i in profile.size():
			var p0: Vector2 = profile[i]
			var p1: Vector2 = profile[(i + 1) % profile.size()]
			var edge := p1 - p0
			var n_radial: float = edge.y * orientation
			var n_axial: float = -edge.x * orientation
			var out3 := Vector3(n_axial, n_radial * cos(am), n_radial * sin(am)).normalized()
			var v00 := center + Vector3(p0.y, p0.x * cos(a0), p0.x * sin(a0))
			var v01 := center + Vector3(p0.y, p0.x * cos(a1), p0.x * sin(a1))
			var v11 := center + Vector3(p1.y, p1.x * cos(a1), p1.x * sin(a1))
			var v10 := center + Vector3(p1.y, p1.x * cos(a0), p1.x * sin(a0))
			_quad_out(st, v00, v01, v11, v10, out3)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = mat
	parent.add_child(instance)
	return instance


## Балка с переменным сечением между двумя точками: стойка, маятник, вилка.
func _beam(parent: Node3D, from: Vector3, to: Vector3, size0: Vector2, size1: Vector2,
		mat: Material, corner := 0.010, steps := 3,
		up_hint := Vector3.UP) -> MeshInstance3D:
	var dir := (to - from).normalized()
	var side := dir.cross(up_hint)
	if side.length() < 0.001:
		side = dir.cross(Vector3.RIGHT)
		if side.length() < 0.001:
			side = dir.cross(Vector3.UP)
	side = side.normalized()
	var up_vec := side.cross(dir).normalized()
	var basis := Basis(side, up_vec, dir)
	var sections := []
	for i in steps + 1:
		var t := float(i) / float(steps)
		var size := size0.lerp(size1, t)
		sections.append({
			"pos": from.lerp(to, t), "w": size.x, "h": size.y,
			"r": corner, "basis": basis,
		})
	return _loft_rect(parent, sections, mat)


## Трос/шланг по ломаной линии.
func _tube(parent: Node3D, points: Array, tube_radius: float, mat: Material,
		segments := 7) -> MeshInstance3D:
	if points.size() < 2:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3.UP
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var dir := (b - a).normalized()
		var side := dir.cross(up)
		if side.length() < 0.001:
			side = dir.cross(Vector3.RIGHT)
		side = side.normalized()
		var up2 := side.cross(dir).normalized()
		for s in segments:
			var t0 := TAU * float(s) / float(segments)
			var t1 := TAU * float(s + 1) / float(segments)
			var p0: Vector3 = a + (side * cos(t0) + up2 * sin(t0)) * tube_radius
			var p1: Vector3 = a + (side * cos(t1) + up2 * sin(t1)) * tube_radius
			var p2: Vector3 = b + (side * cos(t1) + up2 * sin(t1)) * tube_radius
			var p3: Vector3 = b + (side * cos(t0) + up2 * sin(t0)) * tube_radius
			var mid: Vector3 = (p0 + p2) * 0.5 - (a + b) * 0.5
			_quad_out(st, p0, p1, p2, p3, mid)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = mat
	parent.add_child(instance)
	return instance


func _cyl_between(parent: Node3D, from: Vector3, to: Vector3, cyl_radius: float,
		mat: Material) -> MeshInstance3D:
	var direction := to - from
	var length := direction.length()
	if length < 0.001:
		return null
	var instance := _cyl(parent, cyl_radius, length, (from + to) * 0.5, mat)
	instance.rotation = _basis_from_up(direction).get_euler()
	return instance


func _plate_between(parent: Node3D, from: Vector3, to: Vector3, width: float,
		thickness: float, mat: Material) -> MeshInstance3D:
	var direction := to - from
	var length := direction.length()
	if length < 0.001:
		return null
	var instance := _rbox(parent, Vector3(thickness, length, width), (from + to) * 0.5,
		mat, Vector3.ZERO, 0.004)
	instance.rotation = _basis_from_up(direction).get_euler()
	return instance


func _basis_from_up(direction: Vector3) -> Basis:
	var dir := direction.normalized()
	if dir.dot(Vector3.UP) > 0.999:
		return Basis.IDENTITY
	if dir.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	var axis := Vector3.UP.cross(dir).normalized()
	return Basis(axis, acos(clampf(Vector3.UP.dot(dir), -1.0, 1.0)))


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func _label(parent: Node3D, text: String, pos: Vector3, rot_deg: Vector3,
		pixel_size: float, color: Color, font := 48) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.double_sided = false
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


# ---- колесо ------------------------------------------------------------------
func _wheel(parent: Node3D, pos: Vector3, node_name: String, motor: bool,
		disc_side: float, rim_paint: Material, knobby := false,
		rim_accent := false) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = pos
	parent.add_child(pivot)

	var r := radius
	var half_w := 0.056
	# Покрышка — тело вращения: округлые плечи и беговая дорожка, как у
	# мотоциклетной шины. Никаких «шестерёнок» из коробок по кругу.
	var tyre := [
		Vector2(r * 0.630, half_w * 0.80), Vector2(r * 0.700, half_w * 1.00),
		Vector2(r * 0.860, half_w * 1.00), Vector2(r * 0.940, half_w * 0.90),
		Vector2(r * 0.992, half_w * 0.66), Vector2(r * 1.004, half_w * 0.30),
		Vector2(r * 1.002, -half_w * 0.30), Vector2(r * 0.992, -half_w * 0.66),
		Vector2(r * 0.940, -half_w * 0.90), Vector2(r * 0.860, -half_w * 1.00),
		Vector2(r * 0.700, -half_w * 1.00), Vector2(r * 0.630, -half_w * 0.80),
	]
	_revolve(pivot, tyre, 52, _rubber)
	_tread(pivot, knobby)

	# Обод: профиль от борта к полке с плавным переходом.
	var bead := [
		Vector2(r * 0.628, half_w * 0.76), Vector2(r * 0.600, half_w * 0.52),
		Vector2(r * 0.556, half_w * 0.44), Vector2(r * 0.548, half_w * 0.10),
		Vector2(r * 0.548, -half_w * 0.10), Vector2(r * 0.556, -half_w * 0.44),
		Vector2(r * 0.600, -half_w * 0.52), Vector2(r * 0.628, -half_w * 0.76),
		Vector2(r * 0.610, -half_w * 0.80), Vector2(r * 0.586, -half_w * 0.60),
		Vector2(r * 0.540, -half_w * 0.50), Vector2(r * 0.532, 0.0),
		Vector2(r * 0.540, half_w * 0.50), Vector2(r * 0.586, half_w * 0.60),
		Vector2(r * 0.610, half_w * 0.80),
	]
	_revolve(pivot, bead, 48, rim_paint)
	if rim_accent:
		for side_w in [-1.0, 1.0]:
			_ring(pivot, r * 0.600, r * 0.545, 0.0035, _accent, 44,
				Vector3(0.0, 0.0, side_w * half_w * 0.50))
	_spokes(pivot, r, half_w, rim_paint)
	# Ступица / мотор-колесо.
	var hub_radius := r * 0.215 if motor else r * 0.165
	_revolve(pivot, [
		Vector2(hub_radius, half_w * 0.40), Vector2(hub_radius * 0.96, half_w * 0.46),
		Vector2(hub_radius * 0.70, half_w * 0.46), Vector2(hub_radius * 0.62, half_w * 0.40),
		Vector2(hub_radius * 0.62, -half_w * 0.40), Vector2(hub_radius * 0.70, -half_w * 0.46),
		Vector2(hub_radius * 0.96, -half_w * 0.46), Vector2(hub_radius, -half_w * 0.40),
	], 30, rim_paint)
	# Оребрение мотора.
	if motor:
		for k in 10:
			var a := TAU * float(k) / 10.0
			_rbox(pivot, Vector3(half_w * 0.86, 0.008, 0.014),
				Vector3(0.0, cos(a), sin(a)) * hub_radius * 1.02, _rim,
				Vector3(a, 0.0, 0.0), 0.002)
	# Гайки оси.
	for side in [-1.0, 1.0]:
		_cyl(pivot, r * 0.070, 0.014, Vector3(side * half_w * 0.48, 0.0, 0.0), _steel,
			Vector3(0.0, 0.0, deg_to_rad(90.0)), 6)
	# Тормозной диск с перфорацией и суппорт.
	if absf(disc_side) > 0.01:
		var disc_x: float = disc_side * half_w * 0.44
		_ring(pivot, r * 0.560, r * 0.330, 0.0025, _steel, 40, Vector3(disc_x, 0.0, 0.0))
		_ring(pivot, r * 0.360, r * 0.318, 0.0035, _rim, 34, Vector3(disc_x, 0.0, 0.0))
		for k in 14:
			var a2 := TAU * float(k) / 14.0
			_cyl(pivot, 0.0045, 0.008,
				Vector3(disc_x, cos(a2) * r * 0.455, sin(a2) * r * 0.455), _rubber_dark,
				Vector3(0.0, 0.0, deg_to_rad(90.0)), 8)
		var caliper := _rbox(pivot, Vector3(0.032, 0.070, 0.044),
			Vector3(disc_side * (half_w * 0.44 + 0.014), r * 0.44, r * 0.30),
			_caliper, Vector3(deg_to_rad(-18.0), 0.0, 0.0), 0.006)
		caliper.name = "Caliper"
	# Ниппель.
	_cyl(pivot, 0.0045, 0.024, Vector3(0.0, r * 0.50, 0.0), _steel, Vector3.ZERO, 8)
	return pivot


## Протектор: у F3 — злые шашки, у G4 — мелкие насечки по беговой дорожке.
func _tread(pivot: Node3D, knobby := false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := radius
	var rows := 30 if knobby else 40
	var lift := 0.989 if knobby else 0.997
	var thick := 0.010 if knobby else 0.006
	var wide := 0.030 if knobby else 0.022
	var length := 0.014 if knobby else 0.009
	for i in rows:
		var angle := TAU * float(i) / float(rows)
		for side in [-1.0, 1.0]:
			var pos := Vector3(side * 0.030, cos(angle) * r * lift, sin(angle) * r * lift)
			_add_box(st, Transform3D(Basis(Vector3.RIGHT, angle), pos),
				Vector3(wide, thick, length))
		var mid := angle + PI / float(rows) * 0.5
		var center_pos := Vector3(0.0, cos(mid) * r * (lift + 0.0008),
			sin(mid) * r * (lift + 0.0008))
		_add_box(st, Transform3D(Basis(Vector3.RIGHT, mid), center_pos),
			Vector3(wide * 1.35, thick * 0.9, length * 1.35))
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = _rubber_dark
	pivot.add_child(instance)


## Спицы: пять сужающихся лопастей от ступицы к ободу, с двух сторон.
func _spokes(parent: Node3D, r: float, half_w: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for i in 5:
			var angle := TAU * float(i) / 5.0 + 0.32
			var dir := Vector3(0.0, cos(angle), sin(angle))
			var inner: Vector3 = Vector3(side * half_w * 0.34, 0.0, 0.0) + dir * r * 0.17
			var outer: Vector3 = Vector3(side * half_w * 0.46, 0.0, 0.0) + dir * r * 0.56
			var blade := Transform3D(Basis(Vector3.RIGHT, angle),
				(inner + outer) * 0.5)
			_add_box(st, blade, Vector3(0.020, r * 0.40, 0.030))
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = mat
	parent.add_child(instance)


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
	var center := xform.origin
	_quad_out(st, p[0], p[1], p[2], p[3], Vector3(0.0, 0.0, -1.0))
	_quad_out(st, p[5], p[4], p[7], p[6], Vector3(0.0, 0.0, 1.0))
	_quad_out(st, p[4], p[0], p[3], p[7], Vector3(-1.0, 0.0, 0.0))
	_quad_out(st, p[1], p[5], p[6], p[2], Vector3(1.0, 0.0, 0.0))
	_quad_out(st, p[3], p[2], p[6], p[7], Vector3(0.0, 1.0, 0.0))
	_quad_out(st, p[4], p[5], p[1], p[0], Vector3(0.0, -1.0, 0.0))
	if center.length() > 1000.0:
		print("unused")


# ---- руль и бортовой компьютер -----------------------------------------------
func _bar_basic(steer: Node3D, bar_y: float, bar_z: float, bar_half := 0.255) -> void:
	_rbox(steer, Vector3(0.082, 0.054, 0.050), Vector3(0.0, bar_y - 0.030, bar_z), _rim,
		Vector3.ZERO, 0.005)
	_cyl(steer, 0.0145, bar_half * 2.0, Vector3(0.0, bar_y, bar_z), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(steer, 0.019, 0.10, Vector3(-0.055, bar_y, bar_z), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(steer, 0.019, 0.10, Vector3(0.055, bar_y, bar_z), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)


func _grips(steer: Node3D, bar_y: float, bar_z: float, grip_x := 0.200) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * grip_x
		_cyl(steer, 0.0230, 0.140, Vector3(x, bar_y, bar_z), _rubber,
			Vector3(0.0, 0.0, deg_to_rad(90.0)), 18)
		# Кольца на грипсе — «противоскользящий» профиль.
		for k in 3:
			_torus(steer, 0.0195, 0.0215, _plastic, Vector3.ZERO,
				Vector3(x + side * (0.02 + 0.04 * float(k)), bar_y, bar_z), 16)
		_cyl(steer, 0.0260, 0.022, Vector3(side * (grip_x + 0.074), bar_y, bar_z),
			_accent, Vector3(0.0, 0.0, deg_to_rad(90.0)), 18)


func _lever(parent: Node3D, side: float, bar_y: float, bar_z: float) -> void:
	var x: float = side * 0.128
	_rbox(parent, Vector3(0.034, 0.040, 0.044), Vector3(x, bar_y - 0.004, bar_z),
		_plastic, Vector3.ZERO, 0.006)
	var blade := _rbox(parent, Vector3(0.016, 0.012, 0.115),
		Vector3(x + side * 0.012, bar_y - 0.012, bar_z - 0.062), _rim, Vector3.ZERO, 0.004)
	blade.rotation = Vector3(deg_to_rad(-9.0), side * deg_to_rad(6.0), 0.0)
	_cyl(parent, 0.008, 0.026, Vector3(x, bar_y - 0.006, bar_z - 0.008), _steel,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 12)


func _throttle(parent: Node3D, side: float, bar_y: float, bar_z: float) -> void:
	var x: float = side * 0.118
	_cyl(parent, 0.022, 0.046, Vector3(x, bar_y, bar_z), _plastic,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 18)
	_rbox(parent, Vector3(0.030, 0.016, 0.028), Vector3(x - side * 0.012, bar_y + 0.014, bar_z),
		_plastic, Vector3.ZERO, 0.004)


func _bell(parent: Node3D, bar_y: float, bar_z: float) -> void:
	_cyl(parent, 0.017, 0.014, Vector3(-0.150, bar_y + 0.014, bar_z - 0.004), _steel,
		Vector3.ZERO, 18)
	_cyl(parent, 0.006, 0.018, Vector3(-0.150, bar_y + 0.002, bar_z - 0.004), _plastic,
		Vector3.ZERO, 8)


## Держатель телефона: хомут на руле, шарнир, площадка и сам телефон.
func _phone_mount(steer: Node3D, bar_y: float, bar_z: float, side := 0.075) -> void:
	var clamp_pos := Vector3(side, bar_y, bar_z)
	_cyl(steer, 0.026, 0.028, clamp_pos, _plastic, Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_cyl(steer, 0.030, 0.010, clamp_pos + Vector3(0.0, 0.0, 0.019), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 16)
	_sphere(steer, 0.011, clamp_pos + Vector3(0.0, 0.008, 0.030), _rim)
	# Поворотная площадка под углом к райдеру.
	var plate_center := clamp_pos + Vector3(0.0, 0.052, 0.062)
	var plate_basis := Basis(Vector3.RIGHT, deg_to_rad(-58.0))
	_beam(steer, clamp_pos + Vector3(0.0, 0.010, 0.030), plate_center, Vector2(0.020, 0.012),
		Vector2(0.024, 0.010), _rim, 0.004, 1)
	var plate := _rbox(steer, Vector3(0.086, 0.010, 0.150), plate_center,
		_plastic, Vector3(deg_to_rad(-58.0), 0.0, 0.0), 0.006)
	plate.name = "PhonePlate"
	# Телефон: рамка, тёмное стекло, отблеск.
	var body := plate_center + plate_basis * Vector3(0.0, 0.008, 0.0)
	_rbox(steer, Vector3(0.074, 0.010, 0.138), body, _rim,
		Vector3(deg_to_rad(-58.0), 0.0, 0.0), 0.005)
	_rbox(steer, Vector3(0.064, 0.004, 0.122), body + plate_basis * Vector3(0.0, 0.007, 0.0),
		_screen, Vector3(deg_to_rad(-58.0), 0.0, 0.0), 0.003)
	# Прижимные лапки.
	for sx in [-1.0, 1.0]:
		_rbox(steer, Vector3(0.008, 0.018, 0.020),
			body + plate_basis * Vector3(sx * 0.040, 0.006, 0.0), _plastic,
			Vector3(deg_to_rad(-58.0), 0.0, 0.0), 0.003)


## Бортовой компьютер: кронштейн, корпус с козырьком, экран с цифрами, кнопки, ключ.
func _dash(steer: Node3D, bar_y: float, bar_z: float, wide := 1.0) -> void:
	var w := 0.135 * wide
	var h := 0.072 * wide
	var d := 0.052
	var tilt := deg_to_rad(-16.0)
	var center := Vector3(0.0, bar_y + 0.052 * wide, bar_z - 0.014)
	var basis := Basis(Vector3.RIGHT, tilt)
	# Кронштейн из двух пластин.
	for side in [-1.0, 1.0]:
		_plate_between(steer, Vector3(side * 0.030, bar_y + 0.004, bar_z),
			Vector3(side * 0.030, center.y - h * 0.5, center.z), 0.012, 0.006, _rim)
	# Корпус и козырёк.
	_rbox(steer, Vector3(w, h, d), center, _plastic, Vector3(tilt, 0.0, 0.0), 0.008)
	_rbox(steer, Vector3(w * 1.06, 0.010, d * 1.15),
		center + basis * Vector3(0.0, h * 0.5 + 0.004, 0.004), _plastic,
		Vector3(tilt, 0.0, 0.0), 0.004)
	# Экран смотрит на райдера (+Z), корпус с козырьком прикрывает его сверху.
	var screen_pos := center + basis * Vector3(0.0, 0.006, d * 0.5 + 0.002)
	_rbox(steer, Vector3(w * 0.90, h * 0.66, 0.006), screen_pos, _screen,
		Vector3(tilt, 0.0, 0.0), 0.002)
	var face := screen_pos + basis * Vector3(0.0, 0.0, 0.004)
	_label(steer, "48", face + basis * Vector3(-w * 0.17, 0.004, 0.0),
		Vector3(-16.0, 0.0, 0.0), 0.0010, Color(0.80, 0.98, 1.0), 64)
	_label(steer, "KM/H", face + basis * Vector3(w * 0.26, -h * 0.10, 0.0),
		Vector3(-16.0, 0.0, 0.0), 0.00028, Color(0.60, 0.92, 1.0))
	_label(steer, "ECO", face + basis * Vector3(-w * 0.32, h * 0.16, 0.0),
		Vector3(-16.0, 0.0, 0.0), 0.00026, Color(1.0, 0.62, 0.18))
	# Индикатор батареи: четыре деления.
	for i in 4:
		_rbox(steer, Vector3(0.007, 0.011, 0.002),
			face + basis * Vector3(w * (0.16 + 0.05 * float(i)), h * 0.18, 0.0),
			_amber if i < 3 else _plastic, Vector3(tilt, 0.0, 0.0), 0.001)
	# Кнопки под экраном.
	for i in 3:
		_cyl(steer, 0.005, 0.005,
			screen_pos + basis * Vector3(w * (-0.22 + 0.13 * float(i)), -h * 0.42, 0.004),
			_alu, Vector3(deg_to_rad(-90.0 + 16.0), 0.0, 0.0), 12)
	# Замок зажигания с ключом.
	_cyl(steer, 0.014, 0.014, center + basis * Vector3(w * 0.5 + 0.012, 0.0, 0.0), _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	_rbox(steer, Vector3(0.008, 0.030, 0.012),
		center + basis * Vector3(w * 0.5 + 0.030, 0.006, 0.0), _steel, Vector3.ZERO, 0.002)


# ---- подвеска и крылья -------------------------------------------------------
func _shock(parent: Node3D, from: Vector3, to: Vector3, shock_radius: float,
		spring: Material) -> void:
	var direction := (to - from).normalized()
	var length := from.distance_to(to)
	var lower := from + direction * (length * 0.06)
	var upper := to - direction * (length * 0.05)
	# Корпус демпфера и шток.
	_cyl_between(parent, from, from + direction * (length * 0.46), shock_radius, _rim)
	_cyl_between(parent, from + direction * (length * 0.40), upper, shock_radius * 0.52, _steel)
	# Проушины.
	_cyl(parent, shock_radius * 1.30, shock_radius * 1.70, from, _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	_cyl(parent, shock_radius * 1.15, shock_radius * 1.60, to, _rim,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 14)
	_cyl(parent, shock_radius * 0.62, shock_radius * 1.90, from, _steel,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 10)
	_cyl(parent, shock_radius * 0.55, shock_radius * 1.80, to, _steel,
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 10)
	# Винтовая пружина: настоящая спираль, а не стопка колец.
	var side := direction.cross(Vector3.UP)
	if side.length() < 0.001:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	var up_vec := side.cross(direction).normalized()
	var coil_radius := shock_radius * 1.45
	var turns := 6.0
	var samples := 84
	var start_t := 0.30
	var end_t := 0.94
	var points := []
	for k in samples + 1:
		var t := start_t + (end_t - start_t) * float(k) / float(samples)
		var ang := TAU * turns * float(k) / float(samples)
		var radial := side * cos(ang) + up_vec * sin(ang)
		points.append(from + direction * (length * t) + radial * coil_radius)
	_tube(parent, points, shock_radius * 0.34, spring, 6)
	# Тарелки пружины и регулировочная гайка.
	_cyl_between(parent, from + direction * (length * 0.28),
		from + direction * (length * 0.31), coil_radius * 1.15, _alu)
	_cyl_between(parent, to - direction * (length * 0.085),
		to - direction * (length * 0.055), coil_radius * 1.15, _alu)
	_cyl_between(parent, to - direction * (length * 0.135),
		to - direction * (length * 0.105), coil_radius * 1.30, _rim)


func _fender(parent: Node3D, center: Vector3, rad: float, width: float,
		from_deg: float, to_deg: float, mat: Material, segments := 18,
		thickness := 0.012, taper := 0.62) -> MeshInstance3D:
	var rings := []
	var arch_steps := 6
	for i in segments + 1:
		var t := float(i) / float(segments)
		var a := deg_to_rad(lerpf(from_deg, to_deg, t))
		# Ширина сужается к концам, как у литого крыла.
		var w := width * lerpf(taper, 1.0, sin(PI * t))
		var half := w * 0.5
		var arch := half * 0.16
		var n := Vector3(0.0, cos(a), -sin(a))
		var ring := PackedVector3Array()
		for k in arch_steps:
			var x := -half + w * float(k) / float(arch_steps - 1)
			var bulge := arch * (1.0 - pow(x / maxf(half, 0.001), 2.0))
			ring.append(center + n * (rad + thickness + bulge) + Vector3(x, 0.0, 0.0))
		for k in arch_steps:
			var x := half - w * float(k) / float(arch_steps - 1)
			var bulge := arch * 0.22 * (1.0 - pow(x / maxf(half, 0.001), 2.0))
			ring.append(center + n * (rad + bulge) + Vector3(x, 0.0, 0.0))
		rings.append(ring)
	return _loft(parent, rings, mat)


## Фара: корпус, хромированное кольцо, линза.
func _headlight(parent: Node3D, pos: Vector3, body_radius: float) -> void:
	# Тёмный корпус, узкое хром-кольцо и матовая линза — без «дверной ручки».
	_cyl(parent, body_radius, 0.026, pos, _plastic, Vector3(deg_to_rad(90.0), 0.0, 0.0), 20)
	_cyl(parent, body_radius * 0.92, 0.006, pos + Vector3(0.0, 0.0, -0.013), _rim,
		Vector3(deg_to_rad(90.0), 0.0, 0.0), 20)
	_torus(parent, body_radius * 0.80, body_radius * 0.90, _alu, Vector3.ZERO,
		pos + Vector3(0.0, 0.0, -0.014), 20)
	_cyl(parent, body_radius * 0.78, 0.004, pos + Vector3(0.0, 0.0, -0.015), _lamp,
		Vector3(deg_to_rad(90.0), 0.0, 0.0), 20)


## Стоп-сигнал/поворотник: блок со светящейся вставкой.
func _tail_light(parent: Node3D, pos: Vector3, size: Vector3, mat: Material,
		rot := Vector3.ZERO) -> void:
	_rbox(parent, size, pos, _plastic, rot, 0.003)
	var lens := _rbox(parent, Vector3(size.x * 0.86, size.y * 0.62, 0.006),
		pos + Vector3(0.0, 0.0, size.z * 0.5), mat, rot, 0.002)
	lens.name = "Lens"
