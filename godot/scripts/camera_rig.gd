## Камера: третье лицо со свободной орбитой и вид от первого лица.
##
## Третье лицо — плавная камера за спиной, FOV растёт со скоростью. Камеру можно
## крутить мышью (ЛКМ), свайпом по экрану или стиком-свайпом, а через пару секунд
## без ввода она сама возвращается за спину.
##
## Первое лицо — камера на уровне шлема: поворот мышью/свайпом смотрит вокруг,
## райдер скрыт, чтобы не загораживать обзор.
class_name CameraRig
extends Camera3D

## Через сколько секунд без ввода камера от третьего лица возвращается назад.
const ORBIT_IDLE_TIME := 2.5
const ORBIT_PITCH_MIN := -0.30
const ORBIT_PITCH_MAX := 1.00
const FP_PITCH_LIMIT := 1.15
const FP_EYE_HEIGHT := 1.44
const FP_EYE_FORWARD := -0.12
const FP_FOV := 78.0

var target: Scooter
var current_fov := GameConfig.CAMERA_FOV_BASE
## Смещение камеры вокруг самоката (радианы): yaw — по кругу, pitch — вверх.
var orbit_yaw := 0.0
var orbit_pitch := 0.0
var first_person := false

var _yaw := 0.0
var _smooth_position := Vector3.ZERO
var _orbit_idle := 0.0


func setup(scooter: Scooter) -> void:
	target = scooter
	if target != null:
		_yaw = rad_to_deg(target.global_rotation.y)
		orbit_yaw = 0.0
		orbit_pitch = 0.0
		_orbit_idle = ORBIT_IDLE_TIME
		snap_behind()
		apply_view()


## Синхронизирует видимость райдера с текущим видом (после пересборки мира).
func apply_view() -> void:
	if target != null and target.rider != null:
		target.rider.visible = not first_person


## Переключение вида. Возвращает true, если включился вид от первого лица.
func toggle_view() -> bool:
	first_person = not first_person
	orbit_yaw = 0.0
	orbit_pitch = 0.0
	_orbit_idle = ORBIT_IDLE_TIME
	if target != null and target.rider != null:
		target.rider.visible = not first_person
	if first_person and target != null:
		_smooth_position = target.global_position
		_yaw = rad_to_deg(target.global_rotation.y)
	return first_person


## Крутить камеру: dy > 0 — взгляд вправо, dp > 0 — взгляд вверх.
func orbit_input(dy: float, dp: float) -> void:
	orbit_yaw = wrapf(orbit_yaw - dy, -PI, PI)
	if first_person:
		orbit_pitch = clampf(orbit_pitch + dp, -FP_PITCH_LIMIT, FP_PITCH_LIMIT)
	else:
		orbit_pitch = clampf(orbit_pitch + dp, ORBIT_PITCH_MIN, ORBIT_PITCH_MAX)
	_orbit_idle = 0.0


func reset_orbit() -> void:
	orbit_yaw = 0.0
	orbit_pitch = 0.0
	_orbit_idle = ORBIT_IDLE_TIME


func snap_behind() -> void:
	if target == null:
		return
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(_yaw))
	_smooth_position = target.global_position + yaw_basis.z * GameConfig.CAMERA_DISTANCE + Vector3.UP * GameConfig.CAMERA_HEIGHT
	global_position = _smooth_position
	look_at(target.global_position + Vector3.UP * 0.9, Vector3.UP)


func _process(delta: float) -> void:
	# Страховка: если цель пропала или камера ушла слишком далеко, возвращаемся.
	if target != null and is_instance_valid(target):
		var away := global_position.distance_to(target.global_position)
		if away > 14.0:
			global_position = target.global_position + Vector3(0.0, 1.4, 3.2)
		if away < 0.05:
			global_position = target.global_position + Vector3(0.0, 1.2, 2.6)
	if target == null or not is_instance_valid(target):
		return
	if delta <= 0.0:
		return

	var target_yaw := rad_to_deg(target.global_rotation.y)
	var yaw_speed := 1.5 if target.is_crashed else 3.2
	_yaw = lerp_angle(deg_to_rad(_yaw), deg_to_rad(target_yaw), clampf(delta * yaw_speed, 0.0, 1.0))
	_yaw = rad_to_deg(_yaw)

	if first_person:
		_process_first_person(delta)
		return

	# Автовозврат: отпустил — камера сама встаёт за спину.
	_orbit_idle += delta
	if _orbit_idle > ORBIT_IDLE_TIME:
		var back := clampf(delta * 1.8, 0.0, 1.0)
		orbit_yaw = lerp_angle(orbit_yaw, 0.0, back)
		orbit_pitch = lerpf(orbit_pitch, 0.0, back)

	var speed_factor := clampf(target.speed_kmh() / 65.0, 0.0, 1.0)
	var yaw_total := deg_to_rad(_yaw) + orbit_yaw
	var yaw_basis := Basis(Vector3.UP, yaw_total)

	# Базовый подъём камеры + ручной наклон по вертикали.
	var base_elev := atan2(GameConfig.CAMERA_HEIGHT, GameConfig.CAMERA_DISTANCE)
	var elev := clampf(base_elev + orbit_pitch + speed_factor * 0.06, -0.2, 1.35)
	var orbit_radius := sqrt(GameConfig.CAMERA_HEIGHT * GameConfig.CAMERA_HEIGHT
		+ GameConfig.CAMERA_DISTANCE * GameConfig.CAMERA_DISTANCE) + speed_factor * 0.9
	var dir := yaw_basis.z * cos(elev) + Vector3.UP * sin(elev)

	var desired := target.global_position + dir * orbit_radius
	desired.y = maxf(desired.y, 0.35)

	_smooth_position = _smooth_position.lerp(desired, clampf(delta * 9.0, 0.0, 1.0))
	global_position = _smooth_position

	# Точка взгляда строится по горизонтали: иначе на вилли камера задирается
	# в небо вместе с носом самоката.
	var flat_forward := -yaw_basis.z
	var look_point := target.global_position + Vector3.UP * (0.95 + speed_factor * 0.1) \
		+ flat_forward * (GameConfig.CAMERA_LOOK_AHEAD + speed_factor * 1.6)
	var look_dir := look_point - global_position
	if look_dir.length() > 0.05:
		var wanted_basis := Basis.looking_at(look_dir.normalized(), Vector3.UP)
		var blend := clampf(delta * 7.0 * (1.6 if target.is_crashed else 1.0), 0.0, 1.0)
		var new_transform := global_transform
		new_transform.basis = new_transform.basis.slerp(wanted_basis, blend).orthonormalized()
		global_transform = new_transform

	var target_fov: float = lerpf(GameConfig.CAMERA_FOV_BASE, GameConfig.CAMERA_FOV_MAX, speed_factor)
	current_fov = lerpf(current_fov, target_fov, clampf(delta * 3.0, 0.0, 1.0))
	fov = current_fov


## Вид от первого лица: камера на уровне шлема, смотрит туда, куда повернул игрок.
func _process_first_person(delta: float) -> void:
	var basis := target.global_transform.basis
	var eye_local := Vector3(0.0, FP_EYE_HEIGHT, FP_EYE_FORWARD)
	var desired := target.global_position + basis * eye_local
	_smooth_position = desired
	global_position = _smooth_position

	# Наклон головы вслед за тангажом самоката: на вилли видно небо, но не
	# полностью — иначе теряется горизонт.
	var body_pitch := deg_to_rad(clampf(target.pitch_deg, -40.0, 70.0) * 0.55)
	var yaw_total := deg_to_rad(_yaw) + orbit_yaw
	var view_basis := Basis(Vector3.UP, yaw_total) \
		* Basis(Vector3.RIGHT, orbit_pitch + body_pitch)
	global_transform = Transform3D(view_basis, _smooth_position)

	var speed_factor := clampf(target.speed_kmh() / 65.0, 0.0, 1.0)
	current_fov = lerpf(current_fov, FP_FOV + speed_factor * 8.0, clampf(delta * 4.0, 0.0, 1.0))
	fov = current_fov
