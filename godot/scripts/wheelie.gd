## Машина состояний вилли. Вилли включается кнопкой (защёлка), а не удержанием:
## одно нажатие поднимает нос, второе — опускает. Пока вилли включено, самокат
## сам держит угол баланса даже без газа, а **газ задаёт угол**: больше газа —
## выше нос. Если перегазовать на уже большом угле, тяга уводит нос за предел
## и самокат переворачивается через заднее колесо — это единственный способ
## упасть в вилли, балансом уронить самокат нельзя.
##
## Режим привода меняет характер:
##   * G4 (RWD)        — поднимается быстрее, чуть менее спокойный баланс.
##   * F3 Pro Max AWD  — передний мотор тянет нос вниз, подъём медленнее,
##                       но демпфирование сильнее, держать легче.
class_name Wheelie
extends RefCounted

const MIN_SPEED_KMH := 6.0
const BALANCE_MIN_ANGLE := 25.0
const BALANCE_MAX_ANGLE := 62.0
const DANGER_ANGLE := 60.0

## Сколько градусов добавляет полный газ к углу баланса.
const THROTTLE_ANGLE_RANGE := 20.0
## «Перегазовка»: если держать газ в упоре, когда нос уже высоко, цель медленно
## уползает вверх и самокат валится через заднее колесо. Отпустил газ — заряд
## перегазовки быстро стекает.
const OVERDRIVE_THROTTLE := 0.85
const OVERDRIVE_PITCH := 56.0
const OVERDRIVE_ANGLE := 24.0
const OVERDRIVE_CHARGE_RATE := 0.5
const OVERDRIVE_DECAY_RATE := 1.6
const MAX_TARGET_ANGLE := 88.0

var lift_progress := 0.0
var active := false
var in_balance_zone := false
var target_pitch := 0.0
## 0..1 — насколько сильно сейчас перегазовано (для HUD и звука).
var overdrive := 0.0
var _overdrive_charge := 0.0

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
	overdrive = 0.0
	_overdrive_charge = 0.0


func in_danger_zone() -> bool:
	return _scooter != null and _scooter.pitch_deg > DANGER_ANGLE


## held — состояние защёлки (включено ли вилли), throttle — газ 0..1.
func tick(delta: float, held: bool, throttle: float, body_pitch_input: float,
		speed_kmh: float, drive_mode: int, spec: ScooterSpec, grounded: bool,
		is_crashed: bool) -> void:
	if _scooter == null or spec == null:
		return

	var is_awd := spec.motor_count == 2 and drive_mode == GameConfig.DriveMode.AWD
	# Поднять нос можно и почти с места: на медленном ходу подъём идёт плавнее.
	var can_lift := grounded and not is_crashed and speed_kmh > MIN_SPEED_KMH
	# Уже поднятый самокат не роняем, если скорость чуть просела.
	var can_hold := active and grounded and not is_crashed and speed_kmh > 2.0

	var lift_time: float = lerpf(spec.wheelie_lift_time * 1.7, spec.wheelie_lift_time * 0.75,
		inverse_lerp(MIN_SPEED_KMH, 46.0, speed_kmh))
	if is_awd:
		lift_time *= 1.55

	if held and (can_lift or can_hold):
		active = true
		lift_progress = move_toward(lift_progress, 1.0, delta / maxf(0.18, lift_time))
	else:
		lift_progress = move_toward(lift_progress, 0.0, delta / 0.55)
		if lift_progress <= 0.001:
			active = false
			in_balance_zone = false
			target_pitch = 0.0
			overdrive = 0.0
			_overdrive_charge = 0.0
			return

	var pitch: float = _scooter.pitch_deg
	var gas := clampf(throttle, 0.0, 1.0)

	# База — угол баланса: без газа вилли всё равно держится.
	var target := spec.wheelie_equilibrium + gas * THROTTLE_ANGLE_RANGE
	target += body_pitch_input * 20.0
	# Перегазовка на уже задранном носу постепенно уводит нос через предел.
	if gas > OVERDRIVE_THROTTLE and pitch > OVERDRIVE_PITCH and active:
		_overdrive_charge = minf(1.0, _overdrive_charge + delta * OVERDRIVE_CHARGE_RATE)
	else:
		_overdrive_charge = maxf(0.0, _overdrive_charge - delta * OVERDRIVE_DECAY_RATE)
	overdrive = _overdrive_charge
	target += _overdrive_charge * OVERDRIVE_ANGLE
	target = clampf(target, 0.0, MAX_TARGET_ANGLE)
	# Пока идёт подъём, цель растёт вместе с lift_progress — без рывка.
	target_pitch = target * clampf(lift_progress, 0.0, 1.0)

	# Статический момент: столько нужно, чтобы держать раму поднятой.
	# Растёт вместе с подъёмом, иначе первый кадр дёргает самокат.
	var pivot_distance := 0.5
	var gravity_torque := spec.mass_kg * GameConfig.GRAVITY * pivot_distance \
		* cos(deg_to_rad(clampf(pitch, 0.0, 89.0))) * clampf(lift_progress, 0.0, 1.0)

	var error := deg_to_rad(target_pitch - pitch)
	var rate: float = _scooter.pitch_rate

	var torque: float = gravity_torque + error * spec.wheelie_balance_gain - rate * spec.wheelie_balance_damping
	torque = clampf(torque, -spec.wheelie_max_torque, spec.wheelie_max_torque)
	_scooter.apply_nose_up_torque(torque)

	in_balance_zone = pitch >= BALANCE_MIN_ANGLE and pitch <= BALANCE_MAX_ANGLE
