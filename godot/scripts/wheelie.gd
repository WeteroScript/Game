## Машина состояний вилли. Подъём никогда не мгновенный: целевой угол растёт
## за 0.5–1.5 с в зависимости от скорости, а режим привода меняет и силу подъёма,
## и устойчивость баланса:
##   * G4 (RWD)        — легко задрать, слабое демпфирование, труднее удержать.
##   * F3 Pro Max AWD  — передний мотор тянет нос вниз (подъём в 1.55 раза медленнее),
##                       но демпфирование сильнее, баланс спокойнее.
##   * F3 Pro Max RWD  — ведёт себя как G4.
class_name Wheelie
extends RefCounted

const MIN_SPEED_KMH := 15.0
const BALANCE_MIN_ANGLE := 25.0
const BALANCE_MAX_ANGLE := 55.0
const DANGER_ANGLE := 60.0

var lift_progress := 0.0
var active := false
var in_balance_zone := false
var target_pitch := 0.0

var _scooter = null


## Тип не указан намеренно: Scooter и Wheelie ссылаются друг на друга,
## а жёсткая типизация даёт циклическую зависимость классов.
func _init(scooter) -> void:
	_scooter = scooter


func reset() -> void:
	lift_progress = 0.0
	active = false
	in_balance_zone = false
	target_pitch = 0.0


func in_danger_zone() -> bool:
	return _scooter != null and _scooter.pitch_deg > DANGER_ANGLE


func tick(delta: float, held: bool, throttle: float, body_pitch_input: float,
		speed_kmh: float, drive_mode: int, spec: ScooterSpec, grounded: bool,
		is_crashed: bool) -> void:
	if _scooter == null or spec == null:
		return

	var is_awd := spec.motor_count == 2 and drive_mode == GameConfig.DriveMode.AWD
	var can_lift := grounded and not is_crashed and speed_kmh > MIN_SPEED_KMH

	var lift_time: float = lerpf(spec.wheelie_lift_time * 1.7, spec.wheelie_lift_time * 0.75,
		inverse_lerp(MIN_SPEED_KMH, 46.0, speed_kmh))
	if is_awd:
		lift_time *= 1.55

	if held and can_lift:
		active = true
		lift_progress = move_toward(lift_progress, 1.0, delta / maxf(0.18, lift_time))
	else:
		lift_progress = move_toward(lift_progress, 0.0, delta / 0.45)
		if lift_progress <= 0.001:
			active = false
			in_balance_zone = false
			target_pitch = 0.0
			return

	var pitch: float = _scooter.pitch_deg
	var throttle_factor := 0.55 + 0.45 * clampf(throttle, 0.0, 1.0)
	# Наклон назад осознанно выводит за зону баланса — только так можно дойти
	# до переворота на 70–80 градусах.
	var target := spec.wheelie_equilibrium * throttle_factor
	target += body_pitch_input * 34.0
	if throttle > 0.85:
		target += 5.0
	target = clampf(target * clampf(lift_progress, 0.0, 1.0), 0.0, 80.0)
	target_pitch = target

	# Только PD по углу: постоянный «гравитационный» момент раньше переворачивал
	# самокат за долю секунды, потому что его нечем было уравновесить.
	var error := deg_to_rad(target - pitch)
	var rate: float = _scooter.pitch_rate

	var torque: float = error * spec.wheelie_balance_gain - rate * spec.wheelie_balance_damping
	torque = clampf(torque, -spec.wheelie_max_torque, spec.wheelie_max_torque)
	_scooter.apply_nose_up_torque(torque)

	in_balance_zone = pitch >= BALANCE_MIN_ANGLE and pitch <= BALANCE_MAX_ANGLE
