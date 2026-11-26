## Трюки, очки и комбо: вилли, стоппи, прыжки, вращения.
## Перенесено из Assets/Scripts/Tricks/TrickSystem.cs.
class_name TrickSystem
extends RefCounted

signal trick_scored(trick_name: String, points: int)

const COMBO_WINDOW := 2.5
const MAX_MULTIPLIER := 5.0
## Чистая езда: за каждые N метров без падений дают очки — это стимул не
## гнать напролом, а держать линию.
const CLEAN_RUN_STEP := 250.0
const CLEAN_RUN_POINTS := 40

var score := 0
var combo := 0
var combo_time_left := 0.0
var last_trick := ""
var last_trick_points := 0
var trick_count := 0

var _wheelie_accum := 0.0
var _stoppie_accum := 0.0
var _air_yaw := 0.0
var _last_landing_counter := 0
var _last_wheelie_floors := 0
var _last_stoppie_floors := 0
var _last_crash_count := 0
var _clean_mark := 0.0


func combo_multiplier() -> float:
	return minf(MAX_MULTIPLIER, 1.0 + combo * 0.15)


func tick(delta: float, scooter: Scooter) -> void:
	if scooter == null:
		return

	if combo_time_left > 0.0:
		combo_time_left -= delta
		if combo_time_left <= 0.0:
			combo_time_left = 0.0
			combo = 0

	_tick_wheelie(delta, scooter)
	_tick_stoppie(delta, scooter)
	_tick_air(delta, scooter)
	_tick_clean_run(scooter)


func _tick_wheelie(delta: float, scooter: Scooter) -> void:
	# Никакой зоны баланса: засчитывается любое время с поднятым носом.
	var nose_up: bool = scooter.wheelie != null and scooter.wheelie.active \
		and scooter.pitch_deg >= Wheelie.SCORE_MIN_ANGLE
	if nose_up:
		_wheelie_accum += delta
		var floors := int(floor(_wheelie_accum / 0.5))
		if floors > _last_wheelie_floors:
			_last_wheelie_floors = floors
			_add_score("WHEELIE", 10)
	else:
		if _wheelie_accum >= 0.45 and not scooter.is_crashed:
			var points := int(round(_wheelie_accum * 35.0))
			_add_score("WHEELIE %.1f c" % _wheelie_accum, points)
		_wheelie_accum = 0.0
		_last_wheelie_floors = 0


func _tick_stoppie(delta: float, scooter: Scooter) -> void:
	if scooter.stoppie_active():
		_stoppie_accum += delta
		var floors := int(floor(_stoppie_accum / 0.4))
		if floors > _last_stoppie_floors:
			_last_stoppie_floors = floors
			_add_score("STOPPIE", 12)
	else:
		if _stoppie_accum >= 0.35 and not scooter.is_crashed:
			var points := int(round(_stoppie_accum * 45.0))
			_add_score("STOPPIE %.1f c" % _stoppie_accum, points)
		_stoppie_accum = 0.0
		_last_stoppie_floors = 0


func _tick_air(delta: float, scooter: Scooter) -> void:
	if not scooter.is_grounded():
		_air_yaw += scooter.yaw_rate * delta
	elif scooter.landing_counter != _last_landing_counter:
		_last_landing_counter = scooter.landing_counter

		var air_time: float = scooter.last_air_time
		if air_time >= 0.3:
			_add_score("JUMP %.1f c" % air_time, int(round(air_time * 110.0)))

		var spins := absf(_air_yaw)
		if spins >= 150.0:
			var half_turns := int(floor(spins / 180.0))
			var trick_name := "SPIN" if half_turns <= 1 else "SPIN x%d" % half_turns
			_add_score(trick_name, 55 * maxi(1, half_turns))

		_air_yaw = 0.0


## Чистая езда: каждые CLEAN_RUN_STEP метров без падений — бонус.
func _tick_clean_run(scooter: Scooter) -> void:
	if scooter.is_crashed:
		return
	if scooter.crash_count != _last_crash_count:
		# Упал — счётчик начинается заново с текущей точки.
		_last_crash_count = scooter.crash_count
		_clean_mark = scooter.distance_meters
		return
	while scooter.distance_meters - _clean_mark >= CLEAN_RUN_STEP:
		_clean_mark += CLEAN_RUN_STEP
		_add_score("CLEAN RUN %.1f км" % (_clean_mark / 1000.0), CLEAN_RUN_POINTS)


## Сколько ещё метров до следующего бонуса за чистую езду (для HUD).
func clean_run_progress(scooter: Scooter) -> float:
	if scooter == null:
		return 0.0
	return clampf((scooter.distance_meters - _clean_mark) / CLEAN_RUN_STEP, 0.0, 1.0)


func _add_score(trick_name: String, points: int) -> void:
	if points <= 0:
		return
	var gained := int(round(points * combo_multiplier()))
	score += gained
	trick_count += 1
	combo = clampi(combo + 1, 0, 999)
	combo_time_left = COMBO_WINDOW
	last_trick = trick_name
	last_trick_points = gained
	trick_scored.emit(trick_name, gained)


func break_combo() -> void:
	combo = 0
	combo_time_left = 0.0
	_wheelie_accum = 0.0
	_stoppie_accum = 0.0
	_last_wheelie_floors = 0
	_last_stoppie_floors = 0
	_air_yaw = 0.0
	_clean_mark = 0.0
