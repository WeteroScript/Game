## Плавная камера от третьего лица со FOV, зависящим от скорости.
class_name CameraRig
extends Camera3D

var target: Scooter
var current_fov := GameConfig.CAMERA_FOV_BASE

var _yaw := 0.0
var _smooth_position := Vector3.ZERO


func setup(scooter: Scooter) -> void:
	target = scooter
	if target != null:
		_yaw = rad_to_deg(target.global_rotation.y)
		snap_behind()


func snap_behind() -> void:
	if target == null:
		return
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(_yaw))
	_smooth_position = target.global_position + yaw_basis.z * GameConfig.CAMERA_DISTANCE + Vector3.UP * GameConfig.CAMERA_HEIGHT
	global_position = _smooth_position
	look_at(target.global_position + Vector3.UP * 0.9, Vector3.UP)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if delta <= 0.0:
		return

	var target_yaw := rad_to_deg(target.global_rotation.y)
	var yaw_speed := 1.5 if target.is_crashed else 3.2
	_yaw = lerp_angle(deg_to_rad(_yaw), deg_to_rad(target_yaw), clampf(delta * yaw_speed, 0.0, 1.0))
	_yaw = rad_to_deg(_yaw)

	var speed_factor := clampf(target.speed_kmh() / 65.0, 0.0, 1.0)
	var distance := GameConfig.CAMERA_DISTANCE + speed_factor * 0.9
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(_yaw))

	var desired := target.global_position + yaw_basis.z * distance \
		+ Vector3.UP * (GameConfig.CAMERA_HEIGHT + speed_factor * 0.25)
	desired.y = maxf(desired.y, 0.55)

	_smooth_position = _smooth_position.lerp(desired, clampf(delta * 9.0, 0.0, 1.0))
	global_position = _smooth_position

	# Точка взгляда строится по горизонтали: иначе на вилли камера задирается
	# в небо вместе с носом самоката.
	var flat_forward := -yaw_basis.z
	var look_point := target.global_position + Vector3.UP * (0.95 + speed_factor * 0.1) \
		+ flat_forward * (GameConfig.CAMERA_LOOK_AHEAD + speed_factor * 1.6)
	var dir := look_point - global_position
	if dir.length() > 0.05:
		var wanted_basis := Basis.looking_at(dir.normalized(), Vector3.UP)
		var blend := clampf(delta * 7.0 * (1.6 if target.is_crashed else 1.0), 0.0, 1.0)
		var new_transform := global_transform
		new_transform.basis = new_transform.basis.slerp(wanted_basis, blend).orthonormalized()
		global_transform = new_transform

	var target_fov: float = lerpf(GameConfig.CAMERA_FOV_BASE, GameConfig.CAMERA_FOV_MAX, speed_factor)
	current_fov = lerpf(current_fov, target_fov, clampf(delta * 3.0, 0.0, 1.0))
	fov = current_fov
