## Самокат на VehicleBody3D: привод RWD/AWD, раздельные тормоза, рекуперация,
## режимы скорости, вилли, аварии и респаун.
##
## Тяга и торможение считаются вручную (apply_force в точках контакта), а
## VehicleWheel3D отвечает за подвеску и поворот — так поведение одинаково
## предсказуемо и не зависит от внутренней математики двигателя Godot.
class_name Scooter
extends VehicleBody3D

signal crashed(reason: String)
signal respawned

var spec: ScooterSpec
var input: InputState

var drive_mode: int = GameConfig.DriveMode.RWD
var speed_mode := 1

var front_wheel: VehicleWheel3D
var rear_wheel: VehicleWheel3D
var front_visual: Node3D
var rear_visual: Node3D
var front_steer: Node3D
var bar_left: Node3D
var bar_right: Node3D
var foot_left: Node3D
var foot_right: Node3D
var rider: RiderModel
var audio: ScooterAudio
## Настройка игрока из меню: показывать персонажа вообще.
var rider_shown := true
## Вид от первого лица: райдер скрыт всегда, чтобы не смотреть из его головы.
var first_person_view := false

# Визуальная посадка на асфальт: низ модели (отрицательный, в системе самоката)
# и текущее смещение, которое её прижимает к фактической точке контакта колеса.
var model_root: Node3D
var _model_bottom := -0.16
var _ground_offset := 0.0

var wheelie: Wheelie

# ---- входные значения (сглаженные) -----------------------------------------
var throttle_input := 0.0
var brake_front_input := 0.0
var brake_rear_input := 0.0
var steer_input := 0.0

# ---- состояние --------------------------------------------------------------
var speed_mps := 0.0
var pitch_deg := 0.0
var pitch_rate := 0.0
var roll_deg := 0.0
var yaw_rate := 0.0

var front_grounded := false
var rear_grounded := false
var ground_normal := Vector3.UP
var off_road_amount := 0.0

var battery_wh := 0.0
## Сглаженный угол руля: поворот не дёргается от резкого ввода.
var _steer_smooth := 0.0
var distance_meters := 0.0
var run_time := 0.0
var air_time := 0.0
var max_air_time := 0.0
var last_air_time := 0.0
var landing_counter := 0
var wheelie_balance_time := 0.0
var stoppie_time := 0.0

var is_crashed := false
var crash_reason := ""
var crash_count := 0
## Причина последнего падения — остаётся после респауна, удобно для логов.
var last_crash_reason := ""
var max_pitch_deg := 0.0
var stuck_time := 0.0
var _fall_speed := 0.0
var crash_timer := 0.0
var input_enabled := true

var current_force := 0.0
var respawn_position := Vector3.ZERO
var respawn_basis := Basis.IDENTITY

var _front_spin := 0.0
var _rear_spin := 0.0


static func create(new_spec: ScooterSpec, new_input: InputState) -> Scooter:
	var scooter := Scooter.new()
	scooter.name = "Scooter"
	scooter.spec = new_spec
	scooter.input = new_input

	scooter.mass = new_spec.mass_kg
	scooter.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	scooter.center_of_mass = Vector3(0.0, -0.16, 0.02)
	# Держим раму ровно: подвеска гасит удары, искусственный баланс — качку.
	scooter.continuous_cd = true
	scooter.can_sleep = false

	# Тело тоже должно иметь коллизию: без неё физический движок не считает его твёрдым.
	# Коробка поднята над землёй: снизу самокат держат колёса, а тело нужно
	# только чтобы не проезжать сквозь стены и отбойники. Раньше коробка
	# цепляла асфальт и съедала разгон.
	var body_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.26, 0.18, new_spec.wheel_base * 0.8)
	body_shape.shape = box_shape
	body_shape.position = Vector3(0.0, 0.25, 0.0)
	scooter.add_child(body_shape)

	scooter.front_wheel = scooter._make_wheel("FrontWheel", -new_spec.wheel_base * 0.5, true, false)
	scooter.rear_wheel = scooter._make_wheel("RearWheel", new_spec.wheel_base * 0.5, false, true)

	scooter.drive_mode = GameConfig.DriveMode.RWD
	if new_spec.supports_awd_toggle:
		scooter.drive_mode = GameConfig.DriveMode.AWD
	scooter.speed_mode = 1
	scooter.battery_wh = new_spec.battery_wh
	scooter.wheelie = Wheelie.new(scooter)
	return scooter


func _make_wheel(wheel_name: String, z: float, steering: bool, traction: bool) -> VehicleWheel3D:
	var wheel := VehicleWheel3D.new()
	wheel.name = wheel_name
	wheel.position = Vector3(0.0, 0.0, z)
	wheel.wheel_radius = spec.wheel_radius
	wheel.wheel_rest_length = GameConfig.SUSPENSION_TRAVEL
	wheel.suspension_travel = GameConfig.SUSPENSION_TRAVEL
	wheel.suspension_stiffness = GameConfig.SUSPENSION_STIFFNESS
	wheel.suspension_max_force = GameConfig.SUSPENSION_MAX_FORCE
	wheel.damping_compression = GameConfig.DAMPING_COMPRESSION
	wheel.damping_relaxation = GameConfig.DAMPING_RELAXATION
	wheel.wheel_friction_slip = spec.grip_road
	wheel.use_as_steering = steering
	wheel.use_as_traction = traction
	add_child(wheel)
	return wheel


func _ready() -> void:
	var model := ScooterModel.build(spec)
	add_child(model["root"])
	front_visual = model["front_wheel"]
	rear_visual = model["rear_wheel"]
	front_steer = model["front_steer"]
	bar_left = model["bar_left"]
	bar_right = model["bar_right"]
	foot_left = model["foot_left"]
	foot_right = model["foot_right"]

	rider = RiderModel.create(spec.deck_height, spec.accent_color, bar_left, bar_right)
	model["root"].add_child(rider)
	model_root = model["root"]
	_refresh_rider_visibility()
	_report_model()

	audio = ScooterAudio.create(spec.top_speed_kmh)
	add_child(audio)
	respawn_position = global_position
	respawn_basis = global_transform.basis


# ---- персонаж ---------------------------------------------------------------
## Показывать или убирать персонажа (переключатель в главном меню).
func set_rider_shown(shown: bool) -> void:
	rider_shown = shown
	_refresh_rider_visibility()


func set_first_person(first: bool) -> void:
	first_person_view = first
	_refresh_rider_visibility()


func _refresh_rider_visibility() -> void:
	if rider == null:
		return
	rider.visible = rider_shown and not first_person_view


## Корень визуальной геометрии самоката: у загружаемого GLB это отдельный узел
## `UserMesh`, райдера в расчёт высоты брать нельзя (до первой позы его суставы
## стоят в нуле и утаскивают «низ модели» вниз).
func _visual_root() -> Node3D:
	if model_root == null:
		return null
	var user := model_root.get_node_or_null("UserMesh")
	if user is Node3D:
		return user as Node3D
	return model_root


## Диагностика для CI: какие узлы модели подключены и где её низ относительно
## самоката. Печатается один раз при сборке модели — по этой строке видно,
## какой узел колеса реальный, а какой создан заглушкой.
func _report_model() -> void:
	var bottom := INF
	var top := -INF
	var meshes := 0
	# Низ считаем в системе самоката: мировой AABB растёт при крене и наклоне,
	# и по нему модель «садилась» бы ниже, чем нужно.
	var to_mine := global_transform.affine_inverse()
	for mesh in _visual_meshes():
		meshes += 1
		var box: AABB = to_mine * mesh.global_transform * mesh.mesh.get_aabb()
		bottom = minf(bottom, box.position.y)
		top = maxf(top, box.end.y)
	var spin_nodes := ""
	for pair in [["front", front_visual], ["rear", rear_visual], ["steer", front_steer]]:
		var node: Node3D = pair[1]
		spin_nodes += "%s=%s " % [pair[0], "нет" if node == null else str(node.get_path())]
	if meshes > 0:
		_model_bottom = bottom
	print("MODEL: %smeshes=%d bottom=%.3f top=%.3f wheel_r=%.3f" % [
		spin_nodes, meshes, bottom, top, spec.wheel_radius,
	])


## Диагностика посадки на дорогу: низ модели, земля под самокатом и зазор.
func visual_report() -> String:
	if _visual_root() == null:
		return "нет модели"
	var bottom := INF
	for mesh in _visual_meshes():
		var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		bottom = minf(bottom, box.position.y)
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.45, global_position - Vector3.UP * 0.85)
	var exclude_rids: Array[RID] = [get_rid()]
	query.exclude = exclude_rids
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var ground := NAN
	if not hit.is_empty():
		var point: Vector3 = hit["position"]
		ground = point.y
	return "bottom=%.3f ground=%.3f gap=%.3f offset=%.3f y=%.3f" % [
		bottom, ground, bottom - ground, _ground_offset, global_position.y,
	]


## Меши самой модели без райдера: до первой позы его суставы стоят в нуле,
## и его геометрия утаскивает «низ модели» на полметра вниз.
func _visual_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var visual := _visual_root()
	if visual == null:
		return out
	for mesh in _all_meshes(visual):
		if rider != null and rider.is_ancestor_of(mesh):
			continue
		out.append(mesh)
	return out


func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			out.append(child as MeshInstance3D)
		out.append_array(_all_meshes(child))
	return out


# ---- публичные свойства -----------------------------------------------------
func speed_kmh() -> float:
	return absf(speed_mps) * 3.6


func signed_speed_kmh() -> float:
	return speed_mps * 3.6


func battery_percent() -> float:
	# Батарея отключена в игре; оставлено для совместимости старых вызовов.
	return 100.0


func is_grounded() -> bool:
	return front_grounded or rear_grounded


func max_speed_kmh() -> float:
	return minf(spec.gear_top_speed_kmh(speed_mode), spec.top_speed_kmh)


func can_toggle_drive() -> bool:
	return spec != null and spec.supports_awd_toggle


func stoppie_active() -> bool:
	return brake_front_input > 0.5 and front_grounded and not rear_grounded and speed_kmh() > 6.0


func normal_load() -> float:
	return spec.mass_kg * GameConfig.GRAVITY


# ---- управление -------------------------------------------------------------
func set_speed_mode(mode: int) -> void:
	speed_mode = clampi(mode, 0, maxi(0, spec.gear_count() - 1))


func cycle_speed_mode() -> void:
	if spec.gear_count() == 0:
		return
	speed_mode = (speed_mode + 1) % spec.gear_count()


func toggle_drive() -> void:
	if not can_toggle_drive():
		return
	if drive_mode == GameConfig.DriveMode.AWD:
		drive_mode = GameConfig.DriveMode.RWD
	else:
		drive_mode = GameConfig.DriveMode.AWD


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		throttle_input = 0.0
		brake_front_input = 0.0
		brake_rear_input = 0.0
		steer_input = 0.0


func set_respawn_point(pos: Vector3, basis_value: Basis) -> void:
	respawn_position = pos
	respawn_basis = basis_value


## Положительный момент = нос вверх (поворот вокруг локальной оси +X).
func apply_nose_up_torque(torque: float) -> void:
	apply_torque(global_transform.basis * Vector3(torque, 0.0, 0.0))


# ---- физика -----------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if spec == null or input == null:
		return

	_update_kinematics(delta)

	if is_crashed:
		_process_crash(delta)
		_update_rider(delta)
		_update_audio()
		_update_wheel_visuals(delta)
		return

	run_time += delta
	_read_inputs(delta)
	_apply_steering()
	_apply_aerodynamics()
	_apply_drive(delta)
	_apply_brakes()
	_apply_balance()
	_anti_sink()
	_tick_wheelie(delta)
	_check_failures()
	_update_rider(delta)
	_update_audio()
	_update_wheel_visuals(delta)


func _update_kinematics(delta: float) -> void:
	var basis := global_transform.basis
	speed_mps = linear_velocity.dot(-basis.z)

	var fwd := -basis.z
	pitch_deg = rad_to_deg(atan2(fwd.y, Vector2(fwd.x, fwd.z).length()))
	max_pitch_deg = maxf(max_pitch_deg, pitch_deg)
	roll_deg = rad_to_deg(asin(clampf(basis.x.y, -1.0, 1.0)))
	# Положительный pitch_rate — нос идёт вверх (вращение вокруг локальной +X).
	pitch_rate = angular_velocity.dot(basis.x)
	# yaw_rate в градусах/с — так его ждёт система трюков (SPIN).
	yaw_rate = rad_to_deg(angular_velocity.y)

	var front_hit := _ground_ray(Vector3(0.0, 0.0, -spec.wheel_base * 0.5))
	var rear_hit := _ground_ray(Vector3(0.0, 0.0, spec.wheel_base * 0.5))
	front_grounded = not front_hit.is_empty()
	rear_grounded = not rear_hit.is_empty()

	off_road_amount = 0.0
	if front_grounded:
		off_road_amount = maxf(off_road_amount, _hit_off_road(front_hit))
	if rear_grounded:
		off_road_amount = maxf(off_road_amount, _hit_off_road(rear_hit))

	if front_grounded and rear_grounded:
		ground_normal = (front_hit["normal"] + rear_hit["normal"]).normalized()
	elif front_grounded:
		ground_normal = front_hit["normal"]
	elif rear_grounded:
		ground_normal = rear_hit["normal"]
	else:
		ground_normal = Vector3.UP

	if is_grounded():
		distance_meters += maxf(0.0, speed_mps) * delta
		if air_time > 0.15:
			last_air_time = air_time
			landing_counter += 1
			# Жёсткое приземление ломает самокат — падаем, но не от каждого трамплина.
			if _fall_speed > GameConfig.HARD_IMPACT_SPEED:
				crash("Жёсткое приземление")
			_fall_speed = 0.0
		air_time = 0.0
	else:
		air_time += delta
		max_air_time = maxf(max_air_time, air_time)
		_fall_speed = maxf(_fall_speed, -linear_velocity.y)

	if wheelie != null and wheelie.in_balance_zone:
		wheelie_balance_time += delta
	if stoppie_active():
		stoppie_time += delta


func _ground_ray(local_offset: Vector3) -> Dictionary:
	var from := global_transform * local_offset
	var length := spec.wheel_radius + GameConfig.SUSPENSION_TRAVEL + 0.14
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * length, 0xFFFFFFFF, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


func _hit_off_road(hit: Dictionary) -> float:
	var collider = hit.get("collider")
	if collider is Node and (collider as Node).is_in_group("offroad"):
		return 1.0
	return 0.0


func _read_inputs(delta: float) -> void:
	if not input_enabled:
		throttle_input = move_toward(throttle_input, 0.0, delta * 8.0)
		brake_front_input = move_toward(brake_front_input, 0.0, delta * 8.0)
		brake_rear_input = move_toward(brake_rear_input, 0.0, delta * 8.0)
		steer_input = move_toward(steer_input, 0.0, delta * 8.0)
		return

	throttle_input = move_toward(throttle_input, clampf(input.throttle, 0.0, 1.0), delta * 7.0)
	brake_front_input = move_toward(brake_front_input, clampf(input.brake_front, 0.0, 1.0), delta * 12.0)
	brake_rear_input = move_toward(brake_rear_input, clampf(input.brake_rear, 0.0, 1.0), delta * 12.0)
	steer_input = move_toward(steer_input, clampf(input.steer, -1.0, 1.0), delta * 8.0)


func _apply_steering() -> void:
	var speed := absf(speed_mps)
	var falloff := lerpf(1.0, GameConfig.STEER_MIN_FACTOR,
		inverse_lerp(GameConfig.STEER_FALLOFF_START, GameConfig.STEER_FALLOFF_END, speed))
	var angle_deg := steer_input * spec.steer_angle_max * falloff
	# VehicleWheel3D.steering поворачивает колесо против часовой (влево) при
	# плюсе, а steer_input > 0 — это «вправо». Поэтому знак инвертируем:
	# раньше самокат и колесо ехали в противоположную сторону.
	if front_wheel != null:
		front_wheel.steering = -deg_to_rad(angle_deg)
	if rear_wheel != null:
		rear_wheel.steering = -deg_to_rad(angle_deg * GameConfig.REAR_STEER_FACTOR)


func _apply_aerodynamics() -> void:
	var speed := absf(speed_mps)
	if speed < 0.4:
		return
	var force := GameConfig.AIR_DRAG_COEFFICIENT * speed * speed
	apply_central_force(global_transform.basis.z * signf(speed_mps) * force)


func _apply_drive(delta: float) -> void:
	var is_awd := spec.motor_count == 2 and drive_mode == GameConfig.DriveMode.AWD
	var active_motors := 2 if is_awd else 1
	var top_speed_mps := max_speed_kmh() / 3.6

	# Система батареи убрана: тяга всегда полная.
	var battery_scale := 1.0
	var percent := 100.0
	if percent <= 0.01:
		battery_scale = 0.0
	elif percent < GameConfig.LOW_BATTERY_PERCENT:
		battery_scale = GameConfig.LOW_BATTERY_POWER_SCALE

	var target_force := 0.0
	if throttle_input > 0.001 and speed_mps < top_speed_mps and battery_scale > 0.0:
		var power := spec.power_per_motor_watts * active_motors * battery_scale
		var v_safe := maxf(absf(speed_mps), 1.5)
		var force := minf(power / v_safe, spec.max_traction_force_per_motor * active_motors)
		var taper := 1.0 - inverse_lerp(top_speed_mps * 0.9, top_speed_mps + 0.001, speed_mps)
		force *= clampf(taper, 0.0, 1.0)
		target_force = force * throttle_input

	# Сцепление: на грунте и при пробуксовке тяга падает.
	var grip := lerpf(spec.grip_road, spec.grip_off_road, off_road_amount)
	if throttle_input > 0.75 and speed_kmh() < 25.0 and grip < 1.2:
		target_force *= 0.72
		# пробуксовка рыскает: RWD с большим моментом теряет курс сильнее
		var wheelspin := (target_force / maxf(1.0, normal_load())) * 0.9
		apply_torque(Vector3.UP * randf_range(-wheelspin, wheelspin) * 6.0)

	var ramp := spec.motor_ramp_rate * (spec.torque_ceiling / maxf(0.05, spec.wheel_radius)) * delta
	current_force = move_toward(current_force, target_force, ramp)
	if current_force <= 0.01:
		return
	if not is_grounded():
		return

	var force_vector := -global_transform.basis.z * current_force
	var rear_offset := global_transform.basis * Vector3(0.0, -spec.wheel_radius * 0.6, spec.wheel_base * 0.5)
	if is_awd:
		var front_offset := global_transform.basis * Vector3(0.0, -spec.wheel_radius * 0.6, -spec.wheel_base * 0.5)
		apply_force(force_vector * 0.5, front_offset)
		apply_force(force_vector * 0.5, rear_offset)
	else:
		apply_force(force_vector, rear_offset)


func _apply_brakes() -> void:
	var forward := -global_transform.basis.z
	var rear_offset := global_transform.basis * Vector3(0.0, -spec.wheel_radius * 0.6, spec.wheel_base * 0.5)
	var front_offset := global_transform.basis * Vector3(0.0, -spec.wheel_radius * 0.6, -spec.wheel_base * 0.5)

	var front_force := spec.max_brake_torque * brake_front_input / maxf(0.05, spec.wheel_radius)
	var rear_force := spec.max_brake_torque * brake_rear_input * GameConfig.REAR_BRAKE_SHARE / maxf(0.05, spec.wheel_radius)
	# На высоко поднятом носу задний тормоз почти не работает: иначе сила
	# вбивала заднее колесо сквозь асфальт, и самокат проваливался под карту.
	var brake_pitch_scale := clampf(1.0 - (pitch_deg - 25.0) / 45.0, 0.15, 1.0)
	rear_force *= brake_pitch_scale

	if brake_front_input > 0.01 and front_grounded:
		apply_force(-forward * signf(speed_mps) * front_force, front_offset)
	if brake_rear_input > 0.01 and rear_grounded:
		apply_force(-forward * signf(speed_mps) * rear_force, rear_offset)

	# Рекуперация и сопротивление качению при отпущенном газе.
	if throttle_input < 0.05 and absf(speed_mps) > 0.8:
		var regen_force := spec.regen_brake_torque / maxf(0.05, spec.wheel_radius)
		if rear_grounded:
			apply_force(-forward * signf(speed_mps) * regen_force, rear_offset)
	if throttle_input < 0.05 and brake_front_input < 0.05 and brake_rear_input < 0.05 and is_grounded():
		var coast_force := GameConfig.ROLLING_RESISTANCE_TORQUE / maxf(0.05, spec.wheel_radius)
		apply_central_force(-forward * signf(speed_mps) * coast_force)

	# Резкое торможение только передним тормозом на скорости валит через руль.
	if brake_front_input > GameConfig.FULL_FRONT_BRAKE_THRESHOLD and speed_kmh() > GameConfig.ENDO_RISK_SPEED_KMH:
		apply_nose_up_torque(-GameConfig.ENDO_RISK_TORQUE * brake_front_input)


## Страховка от проваливания под дорогу: если корпус оказался ниже поверхности
## (сложилась подвеска, удар, баг физики) — выталкиваем его вверх.
func _anti_sink() -> void:
	var from := global_position + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0,
		0xFFFFFFFF, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	# В норме корпус стоит в 0.16–0.25 м над дорогой (радиус колеса + ход
	# подвески), поэтому порог берём ниже: сработка = реальный провал.
	var surface: float = hit["position"].y
	var minimum := surface + 0.10
	if global_position.y < minimum:
		var depth := minimum - global_position.y
		apply_central_force(Vector3.UP * depth * spec.mass_kg * 260.0)
		if depth > 0.25:
			var fixed := global_transform
			fixed.origin.y = minimum
			global_transform = fixed
			linear_velocity.y = maxf(linear_velocity.y, 1.5)
	_apply_wheel_limit()


## Колёса по отдельности: при вилли/стоппи рама наклонена, и общая проверка по
## центру тела пропускала заднее колесо сквозь дорогу.
func _apply_wheel_limit() -> void:
	for side in [-1.0, 1.0]:
		var local := Vector3(0.0, 0.0, side * spec.wheel_base * 0.5)
		var probe := global_transform * local
		var reach := spec.wheel_radius + 0.60
		var q := PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.30,
			probe + Vector3.DOWN * reach, 0xFFFFFFFF, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			continue
		var need: float = hit["position"].y + spec.wheel_radius * 0.94
		if probe.y >= need:
			continue
		# Только реальный провал: иначе на поворотах сила дёргала самокат.
		var depth_in := need - probe.y
		if depth_in < 0.035:
			continue
		var push := minf(depth_in, 0.10)
		apply_central_force(Vector3.UP * push * spec.mass_kg * 90.0)
		linear_velocity.y = maxf(linear_velocity.y, 0.0)


func _apply_balance() -> void:
	# Наклон в поворот.
	var speed_abs := absf(speed_mps)
	var lean_factor := clampf(speed_abs / GameConfig.LEAN_INTO_TURN_FULL_SPEED, 0.0, 1.0)
	# Руль догоняет ввод плавно и тем медленнее, чем выше скорость, а на скорости
	# угол ещё и подрезается — иначе самокат дёргало и швыряло в поворотах.
	var dt := get_physics_process_delta_time()
	# Руль должен слушаться: раньше ввод догонялся слишком медленно и на
	# скорости подрезался — поворот ощущался «тугим».
	var steer_rate: float = lerpf(8.5, 4.0, clampf(speed_abs / 20.0, 0.0, 1.0))
	_steer_smooth = move_toward(_steer_smooth, steer_input, dt * steer_rate)
	var steer_gain: float = lerpf(1.0, 0.86, clampf(speed_abs / 24.0, 0.0, 1.0))
	var steer_use: float = _steer_smooth * steer_gain
	var target_roll := -steer_use * GameConfig.LEAN_INTO_TURN_MAX_ANGLE * lean_factor
	var roll_error := deg_to_rad(target_roll - roll_deg)
	# Момент крена положителен вокруг локальной +Z, поэтому и скорость крена
	# считаем по +Z: со знаком минус демпфирование превращалось в раскачку.
	var roll_rate := angular_velocity.dot(global_transform.basis.z)
	# Дополнительное демпфирование крена: убирает раскачку «дёргается и летает».
	var roll_damp := -roll_rate * spec.mass_kg * 0.06
	var support := 1.0 if is_grounded() else 0.12

	var roll_torque := roll_error * GameConfig.ROLL_STABILITY_GAIN - roll_rate * GameConfig.ROLL_STABILITY_DAMPING + roll_damp
	roll_torque *= support
	var roll_limit := GameConfig.ROLL_MAX_TORQUE
	# Самокат не падает от потери равновесия: сильный завал вытягиваем
	# дополнительным моментом, а не аварией.
	if absf(roll_deg) > GameConfig.ROLL_ASSIST_ANGLE:
		var over := clampf((absf(roll_deg) - GameConfig.ROLL_ASSIST_ANGLE) / 25.0, 0.0, 1.0)
		roll_torque -= signf(roll_deg) * over * GameConfig.ROLL_RECOVERY_TORQUE
		roll_limit = GameConfig.ROLL_MAX_TORQUE + GameConfig.ROLL_RECOVERY_TORQUE
	roll_torque = clampf(roll_torque, -roll_limit, roll_limit)
	apply_torque(global_transform.basis * Vector3(0.0, 0.0, roll_torque))

	# Стабилизация тангажа — только когда стант не активен. В станте тангаж
	# целиком на газе, без «спасательных» моментов: иначе самокат держится сам,
	# и газ перестаёт что-либо решать.
	if not (wheelie != null and wheelie.active) and is_grounded():
		var slope_pitch := _slope_pitch()
		var pitch_error := deg_to_rad(slope_pitch - pitch_deg)
		var stability := 0.5 if (brake_front_input > 0.8 and speed_kmh() > GameConfig.ENDO_RISK_SPEED_KMH) else 1.0
		var nose_up := pitch_error * GameConfig.PITCH_STABILITY_GAIN * stability - pitch_rate * GameConfig.PITCH_STABILITY_DAMPING
		nose_up = clampf(nose_up, -GameConfig.PITCH_MAX_TORQUE, GameConfig.PITCH_MAX_TORQUE)
		apply_nose_up_torque(nose_up)

	# Демпфирование рыскания оставлено только для стабильности на прямой:
	# прежний коэффициент гасил сам поворот, и самокат «не хотел» рулиться.
	apply_torque(Vector3.UP * (-angular_velocity.y * GameConfig.YAW_DAMPING * 3.0))


func _slope_pitch() -> float:
	if not is_grounded():
		return pitch_deg
	var projected := ground_normal.slide(global_transform.basis.x)
	var forward_component := projected.dot(-global_transform.basis.z)
	var up_component := maxf(0.0001, projected.dot(Vector3.UP))
	return -rad_to_deg(atan2(forward_component, up_component))


func _tick_wheelie(delta: float) -> void:
	if wheelie == null:
		return
	wheelie.tick(delta, input.wheelie, throttle_input, input.body_pitch,
		speed_kmh(), drive_mode, spec, is_grounded(), is_crashed)
	# Нос опустился (кончился газ) — кнопка гаснет, вилли нужно снова взвести.
	if wheelie.finished and input != null:
		input.clear_wheelie()


func _update_battery(delta: float) -> void:
	var speed := absf(speed_mps)
	var tractive_force := current_force
	var mechanical_watts := tractive_force * speed
	var electrical_watts := mechanical_watts / GameConfig.MOTOR_EFFICIENCY

	if throttle_input > 0.02:
		electrical_watts += GameConfig.MOTOR_SPINUP_LOSS_WATTS * throttle_input
	electrical_watts += GameConfig.IDLE_DRAIN_WATTS

	if throttle_input < 0.05 and speed > 1.0:
		var regen_force := spec.regen_brake_torque / maxf(0.05, spec.wheel_radius)
		electrical_watts -= regen_force * speed * spec.regen_efficiency

	battery_wh -= electrical_watts * delta / 3600.0 * GameConfig.BATTERY_DRAIN_MULTIPLIER
	battery_wh = clampf(battery_wh, 0.0, spec.battery_wh)


var _loop_out_time := 0.0


func _check_failures() -> void:
	if wheelie != null and wheelie.active and pitch_deg > GameConfig.LOOP_OUT_ANGLE:
		# Единственное падение в вилли. Случайный заброс от кочки гасится,
		# а вот удержанная перегазовка или слишком долгий заброс — падение.
		_loop_out_time += get_physics_process_delta_time()
		if _loop_out_time > 0.35:
			crash("Loop out — переворот через заднее колесо")
	elif (is_grounded() and brake_front_input > 0.5 and speed_kmh() > 20.0
			and pitch_deg < GameConfig.ENDO_CRASH_ANGLE):
		# Раньше endo срабатывал в воздухе: любой прыжок в городе считался
		# падением через руль, потому что нос в полёте опускается ниже -26°.
		crash("Endo — через руль")

	# Уехал за край мира — возвращаем на трассу.
	if global_position.y < -6.0:
		crash("Улетел за карту")

	# Застрял в стене с полным газом — сами возвращаем на трассу.
	if throttle_input > 0.85 and absf(speed_mps) < 0.6 and is_grounded():
		stuck_time += get_physics_process_delta_time()
		if stuck_time > 4.0:
			stuck_time = 0.0
			crash("Застрял — авто-респаун")
	else:
		stuck_time = maxf(0.0, stuck_time - get_physics_process_delta_time() * 3.0)

	if not (wheelie != null and wheelie.active and pitch_deg > GameConfig.LOOP_OUT_ANGLE):
		_loop_out_time = maxf(0.0, _loop_out_time - get_physics_process_delta_time() * 2.0)


func crash(reason: String) -> void:
	if is_crashed:
		return
	is_crashed = true
	crash_count += 1
	crash_reason = reason
	if audio != null:
		audio.play_impact()
	last_crash_reason = reason
	crash_timer = 0.0
	set_input_enabled(false)
	if input != null:
		input.clear_wheelie()
	if wheelie != null:
		wheelie.reset()
	apply_torque_impulse(global_transform.basis * Vector3(randf_range(-40.0, 40.0), 15.0, randf_range(40.0, 90.0)))
	apply_central_impulse(Vector3.UP * spec.mass_kg * 1.2)
	crashed.emit(reason)


func _process_crash(delta: float) -> void:
	crash_timer += delta
	current_force = 0.0
	if crash_timer >= GameConfig.RESPAWN_DELAY:
		respawn()


func respawn() -> void:
	is_crashed = false
	crash_timer = 0.0
	crash_reason = ""
	current_force = 0.0
	air_time = 0.0
	stuck_time = 0.0
	_fall_speed = 0.0
	throttle_input = 0.0
	brake_front_input = 0.0
	brake_rear_input = 0.0
	steer_input = 0.0
	if input != null:
		input.clear_wheelie()
	if wheelie != null:
		wheelie.reset()

	var brought := Transform3D(respawn_basis, respawn_position + Vector3.UP * 0.12)
	global_transform = brought
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# Жёсткий телепорт: без него Bullet иногда оставляет тело на старом месте.
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, brought)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	set_input_enabled(true)
	respawned.emit()


# ---- визуал -----------------------------------------------------------------
func _update_audio() -> void:
	if audio != null:
		audio.update_state(speed_kmh(), throttle_input, is_grounded(), is_crashed)


func _update_rider(delta: float) -> void:
	if rider == null:
		return
	var wheelie_blend := 0.0
	if wheelie != null:
		wheelie_blend = clampf(wheelie.lift_progress, 0.0, 1.0)
	rider.update_pose(delta, steer_input, maxf(brake_front_input, brake_rear_input),
		speed_kmh(), is_grounded(), is_crashed, pitch_deg,
		wheelie_blend, throttle_input, pitch_rate)


## Прижать модель к дороге по фактической высоте асфальта.
##
## Смещение считается отдельно для каждого колеса, которое стоит на земле, и
## через поворот корпуса: при вилли «плоская» посадка уводит заднее колесо в
## асфальт на 20–30 см. Затем смещение сглаживается, чтобы не дрожало.
func _align_visual_to_ground(delta: float) -> void:
	if model_root == null or spec == null:
		return
	var tyre := -_model_bottom
	if tyre <= 0.01:
		return
	var basis := global_transform.basis
	# Корпус почти лёг на бок — считать нечего, оставляем прошлое смещение.
	if absf(basis.y.y) < 0.25:
		return
	var space := get_world_3d().direct_space_state
	var exclude_rids: Array[RID] = [get_rid()]
	var wheels := [[front_wheel, -spec.wheel_base * 0.5], [rear_wheel, spec.wheel_base * 0.5]]
	var sum := 0.0
	var found := 0
	for entry in wheels:
		var wheel: VehicleWheel3D = entry[0]
		if wheel == null or not wheel.is_in_contact():
			continue
		var z: float = entry[1]
		var probe := global_transform * Vector3(0.0, 0.0, z)
		var query := PhysicsRayQueryParameters3D.create(
			probe + Vector3.UP * 0.45, probe - Vector3.UP * 0.75)
		query.exclude = exclude_rids
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var point: Vector3 = hit["position"]
		# Низ колеса в системе корпуса — (0, offset - tyre, z); его высота в мире
		# = y корпуса + (ось колеса по вертикали) + (offset - tyre) * basis.y.y.
		var axle_height := (basis * Vector3(0.0, 0.0, z)).y
		sum += tyre + (point.y - global_position.y - axle_height) / basis.y.y
		found += 1
	if found == 0:
		return
	var wanted := sum / float(found)
	_ground_offset = lerpf(_ground_offset, clampf(wanted, -0.35, 0.20), clampf(delta * 12.0, 0.0, 1.0))
	model_root.position.y = _ground_offset


func _update_wheel_visuals(delta: float) -> void:
	_align_visual_to_ground(delta)
	var spin_delta := (speed_mps / maxf(0.02, spec.wheel_radius)) * delta
	_front_spin += spin_delta
	_rear_spin += spin_delta

	# Качение вперёд — вращение вокруг -X, поэтому спин берём со знаком минус.
	if front_visual != null:
		front_visual.rotation = Vector3(-_front_spin, 0.0, 0.0)
	if rear_visual != null:
		rear_visual.rotation = Vector3(-_rear_spin, 0.0, 0.0)
	if front_steer != null:
		# Поворачивается вся передняя сборка: вилка, крыло, стойка, руль.
		# Знак тот же, что у физического колеса, иначе руль смотрит не туда.
		front_steer.rotation = Vector3(0.0, -deg_to_rad(steer_input * spec.steer_angle_max), 0.0)
