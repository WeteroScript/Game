## Процедурная модель самоката из примитивов (аналог Assets/Scripts/Vehicle/ScooterFactory.cs).
## Возвращает узлы, которые крутит и поворачивает сам Scooter.
## Замена на настоящую FBX/GLB-модель описана в docs/MODELS.md.
class_name ScooterModel
extends RefCounted


static func material(color: Color, metallic := 0.3, roughness := 0.55, emission := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
	return mat


static func box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	parent.add_child(mesh_instance)
	return mesh_instance


static func cylinder(radius: float, height: float, pos: Vector3, mat: Material, parent: Node3D,
		rot := Vector3(0.0, 0.0, PI * 0.5)) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.rotation = rot
	parent.add_child(mesh_instance)
	return mesh_instance


static func sphere(radius: float, pos: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


## Собирает внешний вид. Ключи: root, front_wheel, rear_wheel, handlebar.
static func build(spec: ScooterSpec) -> Dictionary:
	var root := Node3D.new()
	root.name = "Visual"

	var frame := material(spec.frame_color, 0.55, 0.35)
	var accent := material(spec.accent_color, 0.6, 0.3)
	var dark := material(Color(0.05, 0.05, 0.06), 0.2, 0.8)
	var rubber := material(Color(0.06, 0.06, 0.07), 0.0, 0.95)
	var glass := material(Color(0.75, 0.8, 0.9), 0.1, 0.2)
	var light_mat := material(Color(1.0, 0.96, 0.85), 0.0, 0.2, true)
	var tail_mat := material(Color(1.0, 0.15, 0.1), 0.0, 0.3, true)

	var deck_y := 0.0
	var wheel_radius := spec.wheel_radius

	# ---- дека и аккумуляторный отсек ----------------------------------------
	box(Vector3(spec.deck_width, 0.06, spec.deck_length), Vector3(0.0, deck_y, 0.0), frame, root)
	box(Vector3(spec.deck_width * 0.86, 0.10, spec.deck_length * 0.9),
		Vector3(0.0, deck_y - 0.07, 0.0), dark, root)
	# противоскользящее покрытие
	box(Vector3(spec.deck_width * 0.9, 0.012, spec.deck_length * 0.92),
		Vector3(0.0, deck_y + 0.036, 0.0), dark, root)

	# ---- колёса (пивот + цилиндр внутри) ------------------------------------
	var front_pivot := Node3D.new()
	front_pivot.name = "FrontWheelVisual"
	front_pivot.position = Vector3(0.0, 0.0, -spec.wheel_base * 0.5)
	root.add_child(front_pivot)
	cylinder(wheel_radius, 0.075, Vector3.ZERO, rubber, front_pivot)
	cylinder(wheel_radius * 0.45, 0.08, Vector3.ZERO, accent, front_pivot)

	var rear_pivot := Node3D.new()
	rear_pivot.name = "RearWheelVisual"
	rear_pivot.position = Vector3(0.0, 0.0, spec.wheel_base * 0.5)
	root.add_child(rear_pivot)
	cylinder(wheel_radius, 0.08, Vector3.ZERO, rubber, rear_pivot)
	cylinder(wheel_radius * 0.5, 0.085, Vector3.ZERO, frame, rear_pivot)

	# ---- вилка, стойка, руль ------------------------------------------------
	var fork_z := -spec.wheel_base * 0.5
	box(Vector3(0.05, wheel_radius * 1.9, 0.07), Vector3(0.09, deck_y + wheel_radius * 0.35, fork_z), frame, root)
	box(Vector3(0.05, wheel_radius * 1.9, 0.07), Vector3(-0.09, deck_y + wheel_radius * 0.35, fork_z), frame, root)

	var handlebar := Node3D.new()
	handlebar.name = "Handlebar"
	handlebar.position = Vector3(0.0, deck_y + 0.02, fork_z + 0.03)
	root.add_child(handlebar)
	# стойка руля
	box(Vector3(0.07, 1.0, 0.07), Vector3(0.0, 0.5, 0.0), frame, handlebar, Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	# руль
	box(Vector3(0.62, 0.035, 0.035), Vector3(0.0, 1.0, 0.02), frame, handlebar)
	box(Vector3(0.9, 0.045, 0.045), Vector3(0.0, 1.0, -0.01), accent, handlebar)
	box(Vector3(0.1, 0.05, 0.05), Vector3(0.36, 1.0, -0.01), dark, handlebar)
	box(Vector3(0.1, 0.05, 0.05), Vector3(-0.36, 1.0, -0.01), dark, handlebar)
	# дисплей
	box(Vector3(0.14, 0.09, 0.03), Vector3(0.0, 1.06, -0.02), glass, handlebar, Vector3(deg_to_rad(-18.0), 0.0, 0.0))
	# фара
	box(Vector3(0.10, 0.08, 0.05), Vector3(0.0, 0.86, -0.05), light_mat, handlebar)

	# ---- заднее крыло и стоп-сигнал -----------------------------------------
	var rear_z := spec.wheel_base * 0.5
	box(Vector3(spec.deck_width * 0.9, 0.04, 0.24), Vector3(0.0, deck_y + 0.07, rear_z - 0.02), frame, root, Vector3(deg_to_rad(9.0), 0.0, 0.0))
	box(Vector3(0.11, 0.035, 0.03), Vector3(0.0, deck_y + 0.06, rear_z + 0.09), tail_mat, root)

	# ---- амортизаторы -------------------------------------------------------
	box(Vector3(0.04, 0.16, 0.04), Vector3(0.07, deck_y + 0.11, rear_z - 0.14), accent, root)
	box(Vector3(0.04, 0.16, 0.04), Vector3(-0.07, deck_y + 0.11, rear_z - 0.14), accent, root)
	box(Vector3(0.04, 0.14, 0.04), Vector3(0.07, deck_y + 0.10, fork_z + 0.10), accent, root)
	box(Vector3(0.04, 0.14, 0.04), Vector3(-0.07, deck_y + 0.10, fork_z + 0.10), accent, root)

	# ---- подсветка бренда ---------------------------------------------------
	var brand := accent if not spec.orange_accents else material(Color(1.0, 0.55, 0.1), 0.2, 0.4, true)
	box(Vector3(0.02, 0.05, spec.deck_length * 0.7), Vector3(spec.deck_width * 0.5, deck_y - 0.02, 0.0), brand, root)
	box(Vector3(0.02, 0.05, spec.deck_length * 0.7), Vector3(-spec.deck_width * 0.5, deck_y - 0.02, 0.0), brand, root)

	return {
		"root": root,
		"front_wheel": front_pivot,
		"rear_wheel": rear_pivot,
		"handlebar": handlebar,
	}
