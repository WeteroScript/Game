## Стант (вилли): угол держит только газ.
##
## Кнопка ВИЛЛИ ничего не поднимает и не держит — она лишь включает стант.
## Дальше управление целиком на газе: больше газа — выше нос, меньше — ниже,
## отпустил — самокат опускается на оба колеса. Никаких помощников,
## автоподхватов и «спасательных» моментов: чем больше газа, тем ближе к точке
## переворота, а на кочке можно и перевернуться через заднее колесо.
class_name Wheelie
extends RefCounted

## Угол на полном газу. Заведомо ниже точки переворота (LOOP_OUT_ANGLE),
## чтобы полный газ держал самокат, а не валил его.
const MAX_ANGLE := 58.0
## Ниже этого газа нос не поднимается вообще.
const MIN_GAS := 0.10
const MIN_SPEED_KMH := 4.0
## Нос опустился ниже этого угла — стант закончен, кнопку надо нажимать снова.
const END_ANGLE := 5.0
## Скорость перекладки цели, град/с: нос идёт за газом, но без рывка.
const ANGLE_RATE := 320.0
## Нос поднят выше этого угла — вилли засчитывается как удержанный.
## Никакой «зелёной зоны» нет: держать надо просто нос поднятым, угол задаёт газ.
const SCORE_MIN_ANGLE := 15.0
var active := false
## Кнопка ВИЛЛИ включена.
var armed := false
## 0..1 — насколько поднят нос (для позы райдера и индикации).
var lift_progress := 0.0
var target_pitch := 0.0
## Сигнал: стант закончился сам — защёлку кнопки надо снять.
var finished := false

var _scooter = null


## Тип не указан намеренно: Scooter и Wheelie ссылаются друг на друга,
## а жёсткая типизация даёт циклическую зависимость классов.
func _init(scooter) -> void:
	_scooter = scooter


func reset() -> void:
	active = false
	armed = false
	lift_progress = 0.0
	target_pitch = 0.0
	finished = false


## armed_input — кнопка ВИЛЛИ, throttle — газ 0..1.
func tick(delta: float, armed_input: bool, throttle: float, body_pitch_input: float,
		speed_kmh: float, _drive_mode: int, spec: ScooterSpec, grounded: bool,
		is_crashed: bool) -> void:
	if _scooter == null or spec == null:
		return
	finished = false
	var gas := clampf(throttle, 0.0, 1.0)
	armed = armed_input
	var pitch: float = _scooter.pitch_deg

	# Стант живёт, пока кнопка включена и самокат на земле. Нос опустился на
	# оба колеса или газ убран — стант закончен.
	var ready := armed and grounded and not is_crashed and speed_kmh > MIN_SPEED_KMH
	if ready and (gas >= MIN_GAS or pitch > END_ANGLE):
		active = true
	elif active:
		active = false
		armed = false
		finished = true
		lift_progress = 0.0
		target_pitch = 0.0
		return

	if not active:
		return

	# Угол — прямое продолжение газа: полный газ даёт MAX_ANGLE, половина
	# примерно половину, ноль опускает нос на оба колеса.
	var wanted := MAX_ANGLE * clampf((gas - MIN_GAS) / (1.0 - MIN_GAS), 0.0, 1.0)
	wanted += body_pitch_input * 12.0
	target_pitch = move_toward(target_pitch, wanted, delta * ANGLE_RATE)
	lift_progress = clampf(pitch / MAX_ANGLE, 0.0, 1.0)

	# Прямое управление: момент пропорционален разнице «угол по газу − угол
	# сейчас» и гасится скоростью тангажа. Никаких подпорок моментом тяжести и
	# помощников — чем сильнее газ, тем выше нос, и всё.
	var rate: float = _scooter.pitch_rate
	var error := deg_to_rad(target_pitch - pitch)
	var torque := error * spec.wheelie_balance_gain - rate * spec.wheelie_balance_damping
	torque = clampf(torque, -spec.wheelie_max_torque, spec.wheelie_max_torque)
	_scooter.apply_nose_up_torque(torque)
