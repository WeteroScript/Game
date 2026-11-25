## Объединённое состояние управления: экранные кнопки + клавиатура.
## Аналог PlayerInput/TouchState из Unity-версии.
class_name InputState
extends RefCounted

# Сглаженные значения, которые читает самокат.
var throttle := 0.0
var brake_front := 0.0
var brake_rear := 0.0
var steer := 0.0
var body_pitch := 0.0
var wheelie := false
var enabled := true

# Разовые события (сбрасываются после обработки).
var drive_toggle_pressed := false
var speed_mode_request := -1
var respawn_pressed := false
var menu_pressed := false

# Значения, которые выставляют экранные кнопки HUD.
var touch_throttle := 0.0
var touch_brake_front := 0.0
var touch_brake_rear := 0.0
var touch_steer := 0.0
var touch_body_pitch := 0.0
var touch_wheelie := false


func clear_touch() -> void:
	touch_throttle = 0.0
	touch_brake_front = 0.0
	touch_brake_rear = 0.0
	touch_steer = 0.0
	touch_body_pitch = 0.0
	touch_wheelie = false


## Читает клавиатуру и смешивает её с экранными кнопками. Вызывается каждый кадр.
func poll_keyboard() -> void:
	if not enabled:
		throttle = 0.0
		brake_front = 0.0
		brake_rear = 0.0
		steer = 0.0
		body_pitch = 0.0
		wheelie = false
		return

	var key_throttle := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		key_throttle = 1.0
	var key_rear_brake := 0.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		key_rear_brake = 1.0
	var key_front_brake := 0.0
	if Input.is_key_pressed(KEY_SHIFT):
		key_front_brake = 1.0

	var key_steer := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		key_steer -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		key_steer += 1.0

	var key_pitch := 0.0
	if Input.is_key_pressed(KEY_Q):
		key_pitch += 1.0
	if Input.is_key_pressed(KEY_E):
		key_pitch -= 1.0

	var key_wheelie := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_CTRL)

	throttle = clampf(maxf(key_throttle, touch_throttle), 0.0, 1.0)
	brake_rear = clampf(maxf(key_rear_brake, touch_brake_rear), 0.0, 1.0)
	brake_front = clampf(maxf(key_front_brake, touch_brake_front), 0.0, 1.0)
	steer = clampf(key_steer + touch_steer, -1.0, 1.0)
	body_pitch = clampf(key_pitch + touch_body_pitch, -1.0, 1.0)
	wheelie = key_wheelie or touch_wheelie


func handle_key_events(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_TAB:
			drive_toggle_pressed = true
		KEY_1:
			speed_mode_request = 0
		KEY_2:
			speed_mode_request = 1
		KEY_3:
			speed_mode_request = 2
		KEY_R:
			respawn_pressed = true
		KEY_ESCAPE:
			menu_pressed = true


func consume_drive_toggle() -> bool:
	var value := drive_toggle_pressed
	drive_toggle_pressed = false
	return value


func consume_speed_mode_request() -> int:
	var value := speed_mode_request
	speed_mode_request = -1
	return value


func consume_respawn() -> bool:
	var value := respawn_pressed
	respawn_pressed = false
	return value


func consume_menu() -> bool:
	var value := menu_pressed
	menu_pressed = false
	return value
