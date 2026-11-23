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
	respawn_position = global_position
	respawn_basis = global_transform.basis


# ---- публичные свойства -----------------------------------------------------
func speed_kmh() -> float:
	return absf(speed_mps) * 3.6


func signed_speed_kmh() -> float:
	return speed_mps * 3.6


func battery_percent() -> float:
	return clampf(battery_wh / maxf(1.0, spec.battery_wh), 0.0, 1.0) * 100.0


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
		_update_wheel_visuals(delta)
		return

	run_time += delta
	_read_inputs(delta)
	_apply_steering()
	_apply_aerodynamics()
	_apply_drive(delta)
	_apply_brakes()
	_apply_balance()
	_tick_wheelie(delta)
	_update_battery(delta)
	_check_failures()
	_update_rider(delta)
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
	if front_wheel != null:
		front_wheel.steering = deg_to_rad(angle_deg)
	if rear_wheel != null:
		rear_wheel.steering = deg_to_rad(angle_deg * GameConfig.REAR_STEER_FACTOR)


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

	var battery_scale := 1.0
	var percent := battery_percent()
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


func _apply_balance() -> void:
	# Наклон в поворот.
	var speed_abs := absf(speed_mps)
	var lean_factor := clampf(speed_abs / GameConfig.LEAN_INTO_TURN_FULL_SPEED, 0.0, 1.0)
	var target_roll := -steer_input * GameConfig.LEAN_INTO_TURN_MAX_ANGLE * lean_factor
	var roll_error := deg_to_rad(target_roll - roll_deg)
	# Момент крена положителен вокруг локальной +Z, поэтому и скорость крена
	# считаем по +Z: со знаком минус демпфирование превращалось в раскачку.
	var roll_rate := angular_velocity.dot(global_transform.basis.z)
	var support := 1.0 if is_grounded() else 0.12

	var roll_torque := roll_error * GameConfig.ROLL_STABILITY_GAIN - roll_rate * GameConfig.ROLL_STABILITY_DAMPING
	roll_torque *= support
	roll_torque = clampf(roll_torque, -GameConfig.ROLL_MAX_TORQUE, GameConfig.ROLL_MAX_TORQUE)
	apply_torque(global_transform.basis * Vector3(0.0, 0.0, roll_torque))

	# Стабилизация тангажа, когда вилли не активно.
	var wheelie_active := wheelie != null and wheelie.active
	if not wheelie_active and is_grounded():
		var slope_pitch := _slope_pitch()
		var pitch_error := deg_to_rad(slope_pitch - pitch_deg)
		var stability := 0.5 if (brake_front_input > 0.8 and speed_kmh() > GameConfig.ENDO_RISK_SPEED_KMH) else 1.0
		var nose_up := pitch_error * GameConfig.PITCH_STABILITY_GAIN * stability - pitch_rate * GameConfig.PITCH_STABILITY_DAMPING
		nose_up = clampf(nose_up, -GameConfig.PITCH_MAX_TORQUE, GameConfig.PITCH_MAX_TORQUE)
		apply_nose_up_torque(nose_up)

	apply_torque(Vector3.UP * (-angular_velocity.y * GameConfig.YAW_DAMPING * 8.0))


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


func _check_failures() -> void:
	if wheelie != null and wheelie.active and pitch_deg > GameConfig.LOOP_OUT_ANGLE:
		crash("Loop out — переворот через заднее колесо")
	elif absf(roll_deg) > GameConfig.FALL_ROLL_ANGLE:
		crash("Потеря равновесия")
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


func crash(reason: String) -> void:
	if is_crashed:
		return
	is_crashed = true
	crash_count += 1
	crash_reason = reason
	last_crash_reason = reason
	crash_timer = 0.0
	set_input_enabled(false)
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
	if wheelie != null:
		wheelie.reset()

	global_transform = Transform3D(respawn_basis, respawn_position)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	set_input_enabled(true)
	respawned.emit()


# ---- визуал -----------------------------------------------------------------
func _update_rider(delta: float) -> void:
	if rider == null:
		return
	rider.update_pose(delta, steer_input, maxf(brake_front_input, brake_rear_input),
		speed_kmh(), is_grounded(), is_crashed)


func _update_wheel_visuals(delta: float) -> void:
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
		front_steer.rotation = Vector3(0.0, deg_to_rad(steer_input * spec.steer_angle_max), 0.0)
