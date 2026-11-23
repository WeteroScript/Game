## Корень игры: меню → отсчёт → заезд → результаты.
## Собирает мир, самокат, камеру и интерфейс, ведёт таймеры режимов.
extends Node3D

enum State { MENU, COUNTDOWN, RUNNING, FINISHED, PAUSED }

const RESULTS_LAYER := 20

var state: int = State.MENU

var input_state := InputState.new()
var tricks := TrickSystem.new()
var world_builder: WorldBuilder

var world_root: Node3D
var scooter: Scooter
var camera_rig: CameraRig
var hud: Hud
var menu: MenuScreen
var pause_screen: PauseScreen
var results_root: Control
var results_label: Label
var _results_built := false

var selected_spec_id := "g4"
var selected_map: int = GameConfig.MapId.STRAIGHT_TRACK
var selected_mode: int = GameConfig.GameMode.FREE_RIDE

var countdown_time := 0.0
var time_left := 0.0
var menu_angle := 0.0
var _go_timer := 0.0
## Режим съёмки: отключает орбитальную камеру меню, чтобы кадры были по делу.
var _shots := false

# Автотест для CI: `godot --headless --fixed-fps 60 -- --smoke` проезжает
# заезд за игрока (газ, руль, вилли, падение) и печатает SMOKE OK.
var _smoke := false
var _smoke_timer := 0.0
var _smoke_crashed := false
var _smoke_phase := 0
var _smoke_wheelie_on := false

# Перетаскивание камеры.
var _camera_dragging := false
var _camera_touch_index := -1
## Состояние до паузы, чтобы вернуться именно туда.
var _state_before_pause: int = State.RUNNING


func _ready() -> void:
	randomize()
	_setup_environment()

	world_builder = WorldBuilder.new()

	camera_rig = CameraRig.new()
	camera_rig.fov = GameConfig.CAMERA_FOV_BASE
	add_child(camera_rig)
	camera_rig.make_current()

	hud = Hud.new()
	add_child(hud)
	hud.setup(input_state)
	hud.visible = false
	hud.menu_pressed.connect(_on_menu_pressed)
	hud.drive_toggled.connect(_toggle_drive)
	hud.speed_mode_changed.connect(_on_speed_mode_button)
	hud.respawn_pressed.connect(_respawn)
	hud.view_toggled.connect(_toggle_view)

	menu = MenuScreen.new()
	add_child(menu)
	menu.setup(ScooterSpec.all())
	menu.start_pressed.connect(_start_run)

	pause_screen = PauseScreen.new()
	add_child(pause_screen)
	pause_screen.resume_pressed.connect(_resume)
	pause_screen.menu_pressed.connect(_back_to_menu)

	_build_world(selected_map, selected_spec_id)
	_enter_menu()

	if OS.get_cmdline_user_args().has("--smoke"):
		_start_smoke()
	elif OS.get_cmdline_user_args().has("--shot"):
		_start_screenshots()


# ---- окружение --------------------------------------------------------------
func _setup_environment() -> void:
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.26, 0.48, 0.85)
	sky_material.sky_horizon_color = Color(0.76, 0.84, 0.92)
	sky_material.ground_bottom_color = Color(0.18, 0.2, 0.19)
	sky_material.ground_horizon_color = Color(0.55, 0.6, 0.6)
	sky_material.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.8, 0.88)
	env.fog_density = 0.0012
	env.glow_enabled = true
	env.glow_intensity = 0.5

	var world_environment := WorldEnvironment.new()
	world_environment.environment = env
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-46.0), deg_to_rad(-38.0), 0.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)


# ---- сцена ------------------------------------------------------------------
func _build_world(map_id: int, spec_id: String) -> void:
	if world_root != null:
		remove_child(world_root)
		world_root.queue_free()
		world_root = null
	if scooter != null:
		remove_child(scooter)
		scooter.queue_free()
		scooter = null

	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)

	var info := world_builder.build(map_id, world_root)
	var spawn: Vector3 = info["spawn"]

	scooter = Scooter.create(ScooterSpec.get_by_id(spec_id), input_state)
	scooter.position = spawn
	add_child(scooter)
	scooter.set_respawn_point(spawn, Basis.IDENTITY)
	scooter.set_input_enabled(false)
	scooter.crashed.connect(_on_crash)
	scooter.respawned.connect(_on_respawned)


# ---- меню -------------------------------------------------------------------
func _enter_menu() -> void:
	get_tree().paused = false
	if pause_screen != null:
		pause_screen.close()
	state = State.MENU
	menu.visible = true
	menu.refresh()
	hud.visible = false
	_hide_results()
	input_state.enabled = false
	if scooter != null:
		scooter.set_input_enabled(false)
	if camera_rig != null:
		camera_rig.target = null
	menu_angle = 0.4
	_update_menu_camera(0.0)


func _update_menu_camera(delta: float) -> void:
	if scooter == null or camera_rig == null:
		return
	menu_angle += delta * 0.22
	var center := scooter.global_position + Vector3.UP * 0.75
	var offset := Vector3(sin(menu_angle), 0.0, cos(menu_angle)) * 4.2 + Vector3.UP * 1.5
	camera_rig.global_position = center + offset
	camera_rig.look_at(center, Vector3.UP)


func _start_run(spec_id: String, map_id: int, mode_id: int) -> void:
	get_tree().paused = false
	if pause_screen != null:
		pause_screen.close()
	selected_spec_id = spec_id
	selected_map = map_id
	selected_mode = mode_id

	_build_world(map_id, spec_id)
	tricks = TrickSystem.new()
	tricks.trick_scored.connect(_on_trick)

	menu.visible = false
	hud.visible = true
	hud.clear_crash()
	hud.set_countdown("")
	_hide_results()

	camera_rig.target = scooter
	camera_rig.setup(scooter)
	camera_rig.apply_view()

	match mode_id:
		GameConfig.GameMode.FREESTYLE:
			time_left = GameConfig.FREESTYLE_DURATION
		GameConfig.GameMode.TIME_ATTACK:
			time_left = GameConfig.TIME_ATTACK_LIMIT
		_:
			time_left = 0.0

	countdown_time = GameConfig.COUNTDOWN_SECONDS
	_go_timer = 0.0
	input_state.enabled = false
	scooter.set_input_enabled(false)
	state = State.COUNTDOWN


func _back_to_menu() -> void:
	_build_world(selected_map, selected_spec_id)
	_enter_menu()


## Кнопка МЕНЮ / Esc: во время заезда открывает паузу, на результатах — в меню.
func _on_menu_pressed() -> void:
	if state == State.FINISHED:
		_back_to_menu()
	else:
		_open_pause()


func _open_pause() -> void:
	if state != State.RUNNING and state != State.COUNTDOWN:
		return
	_state_before_pause = state
	state = State.PAUSED
	input_state.enabled = false
	if hud != null:
		hud.release_touches()
	if scooter != null:
		scooter.set_input_enabled(false)
	if pause_screen != null:
		pause_screen.open()
	get_tree().paused = true


func _resume() -> void:
	if state != State.PAUSED:
		return
	if pause_screen != null:
		pause_screen.close()
	get_tree().paused = false
	state = _state_before_pause
	if state == State.RUNNING:
		input_state.enabled = true
		if scooter != null:
			scooter.set_input_enabled(true)


# ---- автотест ---------------------------------------------------------------
# Сценарий для CI (`godot --headless --fixed-fps 60 -- --smoke`):
#   1) G4 на прямой трассе: разгон, удержание вилли, принудительное падение;
#   2) F3 Pro Max в городе с AWD: переключение привода, езда до финиша Freestyle;
#   3) экран результатов, затем выход с итоговыми числами.
func _start_smoke() -> void:
	_smoke = true
	_smoke_timer = 0.0
	_smoke_crashed = false
	_smoke_phase = 0
	# HUD в автотесте не должен перебивать виртуальные касания нулями.
	hud.set_process(false)
	print("SMOKE start")
	_start_run("g4", GameConfig.MapId.STRAIGHT_TRACK, GameConfig.GameMode.FREE_RIDE)


func _telemetry() -> String:
	if scooter == null:
		return "no scooter"
	var pos := scooter.global_position
	var contact := "%s/%s" % [
		str(scooter.front_wheel.is_in_contact() if scooter.front_wheel != null else false),
		str(scooter.rear_wheel.is_in_contact() if scooter.rear_wheel != null else false),
	]
	var wheelie_state := "off"
	if scooter.wheelie != null:
		wheelie_state = "on" if scooter.wheelie.active else "off"
		if scooter.wheelie.in_balance_zone:
			wheelie_state = "zone"
	return "%s speed=%.1f dist=%.1f y=%.2f pitch=%.1f maxPitch=%.1f roll=%.1f contact=%s wheelie=%s gas=%.2f score=%d combo=%.2f battery=%.0f%% crashes=%d last=%s" % [
		scooter.spec.id, scooter.speed_kmh(), scooter.distance_meters, pos.y,
		scooter.pitch_deg, scooter.max_pitch_deg, scooter.roll_deg, contact,
		wheelie_state, scooter.throttle_input, tricks.score,
		tricks.combo_multiplier(), scooter.battery_percent(),
		scooter.crash_count, scooter.last_crash_reason,
	]


func _tick_smoke(delta: float) -> void:
	_smoke_timer += delta

	# Фаза 1 → фаза 2: другой самокат, другая карта, режим с таймером.
	if _smoke_phase == 0 and _smoke_timer > 12.0:
		_smoke_phase = 1
		print("SMOKE phase 1 end: %s" % _telemetry())
		_start_run("f3", GameConfig.MapId.CITY, GameConfig.GameMode.FREESTYLE)
		if scooter != null:
			print("SMOKE phase 2: drive=%d (AWD=1)" % scooter.drive_mode)
			scooter.toggle_drive()
			print("SMOKE phase 2: after toggle drive=%d (RWD=0)" % scooter.drive_mode)
			scooter.toggle_drive()
		return

	# Фаза 2 → финиш: ждём, пока истечёт таймер Freestyle, и проверяем результаты.
	if _smoke_phase == 1 and state == State.FINISHED:
		_smoke_phase = 2
		print("SMOKE finished: %s results_visible=%s time_left=%.1f" % [
			_telemetry(), str(results_root != null and results_root.visible), time_left,
		])
		print("SMOKE OK %s" % _telemetry())
		get_tree().quit()
		return

	if _smoke_timer > 150.0:
		print("SMOKE TIMEOUT %s" % _telemetry())
		get_tree().quit(1)
		return

	if state != State.RUNNING:
		return

	# В вилли автотест держит газ ниже упора: так проверяется управление углом
	# без намеренного переворота через заднее колесо.
	input_state.touch_throttle = 0.75 if _smoke_wheelie_on else 1.0
	input_state.touch_steer = sin(_smoke_timer * 0.7) * 0.35

	if _smoke_phase == 0:
		if not _smoke_wheelie_on and _smoke_timer > 3.0:
			_smoke_wheelie_on = true
			input_state.request_wheelie_toggle()
			print("SMOKE wheelie toggle ON")
		elif _smoke_wheelie_on and _smoke_timer > 9.5:
			_smoke_wheelie_on = false
			input_state.request_wheelie_toggle()
			print("SMOKE wheelie toggle OFF")
		if not _smoke_crashed and _smoke_timer > 10.5 and scooter != null:
			_smoke_crashed = true
			scooter.crash("smoke test")
			print("SMOKE forced crash")

	# Во время вилли печатаем чаще: нужно видеть траекторию угла.
	var period := 1.0 if _smoke_wheelie_on else 3.0
	if fmod(_smoke_timer, period) < delta:
		print("SMOKE t=%.1f %s" % [_smoke_timer, _telemetry()])


# ---- скриншоты для CI --------------------------------------------------------
# `godot --rendering-driver opengl3 -- --shot` под xvfb снимает оба самоката
# с трёх ракурсов и складывает PNG в каталог из переменной SHOT_DIR.
func _start_screenshots() -> void:
	_shots = true
	# Студийный свет для рендеров: два мягких источника без теней, чтобы детали
	# моделей читались на снимках, плюс поднятая засветка окружения.
	for yaw in [-70.0, 110.0]:
		var fill := DirectionalLight3D.new()
		fill.rotation = Vector3(deg_to_rad(-28.0), deg_to_rad(yaw), 0.0)
		fill.light_energy = 0.58
		fill.shadow_enabled = false
		add_child(fill)
	for child in get_children():
		if child is WorldEnvironment and child.environment != null:
			var env: Environment = child.environment
			# Нейтральная засветка вместо неба: иначе серый корпус уходит в синеву,
			# а на фото он тёплый нейтральный.
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.62, 0.62, 0.62)
			env.ambient_light_energy = 0.52
			env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	menu.visible = false
	hud.visible = false
	# HUD не должен затирать виртуальные касания нулями при съёмке.
	hud.set_process(false)
	_take_screenshots()


func _take_screenshots() -> void:
	var shot_dir := OS.get_environment("SHOT_DIR")
	if shot_dir.is_empty():
		shot_dir = "/tmp/kugoo-shots"
	DirAccess.make_dir_recursive_absolute(shot_dir)

	# offset — где стоит камера, look — куда смотрит, fov — угол.
	var shots := [
		{"name": "front", "offset": Vector3(1.45, 0.92, -2.25), "look": Vector3(0.0, 0.58, -0.05), "fov": 34.0},
		{"name": "side", "offset": Vector3(6.20, 0.62, 0.0), "look": Vector3(0.0, 0.62, 0.0), "fov": 15.0, "ortho": true, "size": 1.55},
		{"name": "rear", "offset": Vector3(-1.35, 0.78, 1.95), "look": Vector3(0.0, 0.50, 0.02), "fov": 34.0},
		{"name": "bar", "offset": Vector3(0.62, 1.42, -0.85), "look": Vector3(0.0, 1.10, -0.28), "fov": 34.0},
		{"name": "wheel", "offset": Vector3(0.70, 0.26, -0.95), "look": Vector3(0.0, 0.13, -0.50), "fov": 34.0},
		{"name": "dash", "offset": Vector3(0.10, 1.34, 0.78), "look": Vector3(0.0, 1.10, -0.20), "fov": 34.0},
		{"name": "deck", "offset": Vector3(0.78, 0.46, 0.16), "look": Vector3(0.0, 0.22, 0.02), "fov": 34.0},
	]

	for spec_id in ["g4", "f3"]:
		_build_world(GameConfig.MapId.STRAIGHT_TRACK, spec_id)
		camera_rig.target = null
		await get_tree().create_timer(0.8).timeout
		# Сначала чистые кадры самой модели (без райдера), потом — с ним.
		var rider_node: Node3D = null
		if scooter != null and scooter.rider != null:
			rider_node = scooter.rider
			rider_node.visible = false
		for index in shots.size():
			var shot: Dictionary = shots[index]
			var origin: Vector3 = scooter.global_position
			var look_point: Vector3 = origin + shot["look"]
			camera_rig.global_position = origin + shot["offset"]
			camera_rig.look_at(look_point, Vector3.UP)
			camera_rig.fov = shot["fov"]
			# Ортокамера для кадров, по которым сверяем силуэт с фото.
			if shot.get("ortho", false):
				camera_rig.projection = Camera3D.PROJECTION_ORTHOGONAL
				camera_rig.size = shot["size"]
			else:
				camera_rig.projection = Camera3D.PROJECTION_PERSPECTIVE
			for frame in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var path := "%s/%s_%d_%s.png" % [shot_dir, spec_id, index, shot["name"]]
			var error := image.save_png(path)
			print("SHOT %s err=%d" % [path, error])

		# Кадр с райдером.
		if rider_node != null:
			rider_node.visible = true
			var origin2: Vector3 = scooter.global_position
			camera_rig.global_position = origin2 + Vector3(1.95, 0.90, -2.50)
			camera_rig.look_at(origin2 + Vector3(0.0, 0.98, -0.1), Vector3.UP)
			camera_rig.fov = 32.0
			for frame in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_save_shot(shot_dir, "%s_rider" % spec_id)

	# Меню: проверяем вёрстку кнопок и карточку характеристик.
	_enter_menu()
	camera_rig.target = null
	camera_rig.global_position = scooter.global_position + Vector3(1.95, 1.25, 2.55)
	camera_rig.look_at(scooter.global_position + Vector3.UP * 0.60, Vector3.UP)
	camera_rig.fov = 40.0
	for frame in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot(shot_dir, "menu")

	# Геймплей: вид от камеры игрока, с HUD и райдером на ходу.
	hud.visible = true
	_start_run("g4", GameConfig.MapId.STRAIGHT_TRACK, GameConfig.GameMode.FREE_RIDE)
	input_state.touch_throttle = 1.0
	await get_tree().create_timer(4.2).timeout
	await RenderingServer.frame_post_draw
	_save_shot(shot_dir, "hud_drive")

	input_state.request_wheelie_toggle()
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	_save_shot(shot_dir, "hud_wheelie")

	print("SHOTS DONE %s" % shot_dir)
	get_tree().quit()


func _save_shot(shot_dir: String, shot_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [shot_dir, shot_name]
	var error := image.save_png(path)
	print("SHOT %s err=%d" % [path, error])


# ---- кадр -------------------------------------------------------------------
func _process(delta: float) -> void:
	if _smoke:
		_tick_smoke(delta)

	input_state.poll_keyboard()

	match state:
		State.MENU:
			if not _shots:
				_update_menu_camera(delta)
		State.COUNTDOWN:
			_process_countdown(delta)
		State.RUNNING:
			_process_running(delta)
		State.FINISHED:
			if scooter != null:
				hud.update_stats(scooter, tricks, time_left, _has_timer())


func _process_countdown(delta: float) -> void:
	countdown_time -= delta
	if countdown_time > 0.0:
		hud.set_countdown("%d" % int(ceil(countdown_time)))
	else:
		state = State.RUNNING
		input_state.enabled = true
		if scooter != null:
			scooter.set_input_enabled(true)
		hud.set_countdown("ПОЕХАЛИ")
		_go_timer = 1.0
	_handle_actions()
	if scooter != null:
		hud.update_stats(scooter, tricks, time_left, _has_timer())


func _process_running(delta: float) -> void:
	if _go_timer > 0.0:
		_go_timer -= delta
		if _go_timer <= 0.0:
			hud.set_countdown("")

	if scooter != null:
		tricks.tick(delta, scooter)
		hud.update_stats(scooter, tricks, time_left, _has_timer())

	_handle_actions()

	if _has_timer():
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_finish_run()


func _handle_actions() -> void:
	if scooter == null:
		return
	if input_state.consume_drive_toggle():
		_toggle_drive()
	var requested_mode := input_state.consume_speed_mode_request()
	if requested_mode >= 0:
		scooter.set_speed_mode(requested_mode)
	if input_state.consume_respawn():
		_respawn()
	if input_state.consume_view_toggle():
		_toggle_view()
	if input_state.consume_menu():
		_on_menu_pressed()


## Камера: тащим мышью с зажатой ЛКМ или свайпом по экрану, где нет кнопок.
func _unhandled_input(event: InputEvent) -> void:
	input_state.handle_key_events(event)

	if camera_rig == null or state == State.MENU or _shots:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_camera_dragging = not _over_controls(event.position)
		else:
			_camera_dragging = false
	elif event is InputEventMouseMotion and _camera_dragging:
		camera_rig.orbit_input(event.relative.x * 0.005, -event.relative.y * 0.004)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_camera_touch_index = event.index if not _over_controls(event.position) else -1
		elif event.index == _camera_touch_index:
			_camera_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _camera_touch_index:
		camera_rig.orbit_input(event.relative.x * 0.006, -event.relative.y * 0.005)


func _over_controls(point: Vector2) -> bool:
	return hud != null and hud.is_over_controls(point)


func _has_timer() -> bool:
	return selected_mode == GameConfig.GameMode.FREESTYLE or selected_mode == GameConfig.GameMode.TIME_ATTACK


# ---- действия ---------------------------------------------------------------
func _toggle_drive() -> void:
	if scooter != null:
		scooter.toggle_drive()


func _on_speed_mode_button(_mode: int) -> void:
	if scooter != null:
		scooter.cycle_speed_mode()


func _respawn() -> void:
	if scooter == null or state != State.RUNNING:
		return
	scooter.respawn()
	# Камера снова за спиной, иначе после телепорта она «улетает».
	if camera_rig != null:
		camera_rig.reset_orbit()
		camera_rig.snap_behind()
	if hud != null:
		hud.clear_crash()


## Переключение вида: третье лицо ⇄ первое.
func _toggle_view() -> void:
	if camera_rig == null or scooter == null or state == State.MENU:
		return
	camera_rig.toggle_view()


func _on_crash(reason: String) -> void:
	tricks.break_combo()
	if hud != null:
		hud.show_crash("%s\nреспаун..." % reason)


func _on_respawned() -> void:
	if hud != null:
		hud.clear_crash()


func _on_trick(trick_name: String, points: int) -> void:
	if hud != null:
		hud.show_trick(trick_name, points)
	# «Дзынь» только за прыжки и вращения. Вилли и стоппи начисляются каждые
	# полсекунды, и писк на них раздражал больше, чем радовал.
	var quiet := trick_name.begins_with("WHEELIE") or trick_name.begins_with("STOPPIE")
	if not quiet and scooter != null and scooter.audio != null:
		scooter.audio.play_chime()


# ---- финиш ------------------------------------------------------------------
func _finish_run() -> void:
	state = State.FINISHED
	input_state.enabled = false
	if scooter != null:
		scooter.set_input_enabled(false)
	_show_results()


func _show_results() -> void:
	if not _results_built:
		_build_results_ui()
		_results_built = true

	var distance_km := 0.0
	var run_time := 0.0
	var crashes := 0
	if scooter != null:
		distance_km = scooter.distance_meters / 1000.0
		run_time = scooter.run_time
		crashes = scooter.crash_count

	results_label.text = "Очки: %d\nТрюков: %d\nМножитель комбо: x%.2f\n\nДистанция: %.2f км\nВремя: %d:%02d\nПадений: %d" % [
		tricks.score, tricks.trick_count, tricks.combo_multiplier(),
		distance_km, int(run_time / 60.0), int(run_time) % 60, crashes,
	]
	results_root.visible = true


func _build_results_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = RESULTS_LAYER
	add_child(layer)

	results_root = Control.new()
	results_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(results_root)

	var backdrop := UiFactory.panel(Color(0.02, 0.03, 0.05, 0.9))
	UiFactory.place(backdrop, 0.0, 0.0, 1280.0, 720.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	results_root.add_child(backdrop)

	var title := UiFactory.label("ЗАЕЗД ОКОНЧЕН", 48, Color(1.0, 0.95, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	UiFactory.place(title, 240.0, 110.0, 800.0, 60.0)
	results_root.add_child(title)

	results_label = UiFactory.label("", 26, Color(1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	results_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	UiFactory.place(results_label, 240.0, 190.0, 800.0, 330.0)
	results_root.add_child(results_label)

	var back_button := UiFactory.button("В МЕНЮ", 26, Vector2(340.0, 70.0))
	UiFactory.place(back_button, 470.0, 560.0, 340.0, 70.0)
	back_button.pressed.connect(_back_to_menu)
	results_root.add_child(back_button)


func _hide_results() -> void:
	if results_root != null:
		results_root.visible = false
