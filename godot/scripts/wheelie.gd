## Машина состояний вилли (станта).
##
## Кнопка ВИЛЛИ не держит режим: одно нажатие лишь «взводит» подъём. Нос
## поднимается только вместе с газом, а держится настолько, насколько водитель
## даёт газ. Отпустил газ — самокат мягко встаёт на оба колеса, кнопка гаснет.
##
## Угол задаёт газ: больше газа — выше нос. Если держать газ в упоре на уже
## задранном носу, цель уползает вверх и самокат переворачивается через заднее
## колесо — это единственный способ упасть на вилли.
##
## Режим привода меняет характер:
##   * G4 (RWD)        — поднимается быстрее, чуть менее спокойный баланс.
##   * F3 Pro Max AWD  — передний мотор тянет нос вниз, подъём медленнее,
##                       но демпфирование сильнее, держать легче.
class_name Wheelie
extends RefCounted

const MIN_SPEED_KMH := 5.0
const BALANCE_MIN_ANGLE := 25.0
const BALANCE_MAX_ANGLE := 62.0
const DANGER_ANGLE := 70.0

## Без газа нос не поднимается: кнопка только разрешает подъём.
const LIFT_GAS := 0.18
## Ниже этого газа вилли заканчивается, самокат опускается на оба колеса.
const HOLD_GAS := 0.09

## Сколько градусов добавляет полный газ к углу баланса.
const THROTTLE_ANGLE_RANGE := 26.0
## «Перегазовка»: держишь газ в упоре на высоком носу — цель медленно уползает
## вверх и самокат валится через заднее колесо. Отпустил газ — заряд стекает.
const OVERDRIVE_THROTTLE := 0.82
const OVERDRIVE_PITCH := 62.0
const OVERDRIVE_ANGLE := 28.0
const OVERDRIVE_CHARGE_RATE := 0.42
const OVERDRIVE_DECAY_RATE := 1.6
const MAX_TARGET_ANGLE := 86.0
## На большом угле управление становится легче: усиление растёт, демпфирование
## падает, а запас момента расширяется — иначе перегазовка неизбежно валила нос.
const ASSIST_START := 38.0
const ASSIST_FULL := 74.0
const ASSIST_GAIN := 1.15
const ASSIST_DAMPING_CUT := 0.45
const ASSIST_TORQUE_BOOST := 0.65

var lift_progress := 0.0
var active := false
## Кнопка нажата, ждём газ.
var armed := false
var in_balance_zone := false
var target_pitch := 0.0
## 0..1 — насколько сильно сейчас перегазовано (для HUD и звука).
var overdrive := 0.0
## Сигнал: нос опустился сам (кончился газ) — защёлку кнопки надо снять.
var finished := false
var _overdrive_charge := 0.0

var _scooter = null


## Тип не указан намеренно: Scooter и Wheelie ссылаются друг на друга,
## а жёсткая типизация даёт циклическую зависимость классов.
func _init(scooter) -> void:
	_scooter = scooter


func reset() -> void:
	lift_progress = 0.0
	active = false
	armed = false
	in_balance_zone = false
	target_pitch = 0.0
	overdrive = 0.0
	finished = false
	_overdrive_charge = 0.0


func in_danger_zone() -> bool:
	return _scooter != null and _scooter.pitch_deg > DANGER_ANGLE


## armed_input — нажата ли кнопка, throttle — газ 0..1.
func tick(delta: float, armed_input: bool, throttle: float, body_pitch_input: float,
		speed_kmh: float, drive_mode: int, spec: ScooterSpec, grounded: bool,
		is_crashed: bool) -> void:
	if _scooter == null or spec == null:
		return
	finished = false
	var gas := clampf(throttle, 0.0, 1.0)
	if armed_input and not armed:
		armed = true
	elif not armed_input:
		armed = false

	var is_awd := spec.motor_count == 2 and drive_mode == GameConfig.DriveMode.AWD
	var grounded_ok := grounded and not is_crashed
	var can_lift := armed and grounded_ok and speed_kmh > MIN_SPEED_KMH and gas >= LIFT_GAS
	# Раз поднялись — держимся на газе; совсем без газа нос опускается.
	var can_hold := active and grounded_ok and speed_kmh > 0.4 and gas >= HOLD_GAS

	var lift_time: float = lerpf(spec.wheelie_lift_time * 1.7, spec.wheelie_lift_time * 0.75,
		inverse_lerp(MIN_SPEED_KMH, 46.0, speed_kmh))
	# Чем больше газа, тем охотнее нос идёт вверх.
	lift_time /= 1.0 + 0.55 * clampf(gas, 0.0, 1.0)
	if is_awd:
		lift_time *= 1.55

	if can_lift or can_hold:
		active = true
		lift_progress = move_toward(lift_progress, 1.0, delta / maxf(0.18, lift_time))
	else:
		var was_active := active
		lift_progress = move_toward(lift_progress, 0.0, delta / 0.45)
		if lift_progress <= 0.001:
			lift_progress = 0.0
			active = false
			in_balance_zone = false
			target_pitch = 0.0
			overdrive = 0.0
			_overdrive_charge = 0.0
			# Были на колесе и опустились сами — снимаем защёлку с кнопки.
			if was_active:
				finished = true
				armed = false
			return

	var pitch: float = _scooter.pitch_deg

	# База — угол баланса, плюс вклад газа: больше газа — выше нос.
	var target := spec.wheelie_equilibrium + gas * THROTTLE_ANGLE_RANGE
	target += body_pitch_input * 20.0
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
	var pivot_distance := 0.5
	var gravity_torque := spec.mass_kg * GameConfig.GRAVITY * pivot_distance \
		* cos(deg_to_rad(clampf(pitch, 0.0, 89.0))) * clampf(lift_progress, 0.0, 1.0)

	var error := deg_to_rad(target_pitch - pitch)
	var rate: float = _scooter.pitch_rate

	# Помощь на большом угле: ближе к точке падения угол берётся легче.
	var assist := smoothstep(ASSIST_START, ASSIST_FULL, pitch)
	var gain: float = spec.wheelie_balance_gain * (1.0 + ASSIST_GAIN * assist)
	var damping: float = spec.wheelie_balance_damping * (1.0 - ASSIST_DAMPING_CUT * assist)
	var torque: float = gravity_torque + error * gain - rate * damping
	var max_torque: float = spec.wheelie_max_torque * (1.0 + ASSIST_TORQUE_BOOST * assist)
	torque = clampf(torque, -max_torque, max_torque)
	_scooter.apply_nose_up_torque(torque)

	in_balance_zone = pitch >= BALANCE_MIN_ANGLE and pitch <= BALANCE_MAX_ANGLE
