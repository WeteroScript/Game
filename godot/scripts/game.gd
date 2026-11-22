## Корень игры: меню → отсчёт → заезд → результаты.
## Собирает мир, самокат, камеру и интерфейс, ведёт таймеры режимов.
extends Node3D

enum State { MENU, COUNTDOWN, RUNNING, FINISHED }

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

# Автотест для CI: `godot --headless --fixed-fps 60 -- --smoke` проезжает
# заезд за игрока (газ, руль, вилли, падение) и печатает SMOKE OK.
var _smoke := false
var _smoke_timer := 0.0
var _smoke_crashed := false
var _smoke_phase := 0


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
	hud.menu_pressed.connect(_back_to_menu)
	hud.drive_toggled.connect(_toggle_drive)
	hud.speed_mode_changed.connect(_on_speed_mode_button)
	hud.respawn_pressed.connect(_respawn)

	menu = MenuScreen.new()
	add_child(menu)
	menu.setup(ScooterSpec.all())
	menu.start_pressed.connect(_start_run)

	_build_world(selected_map, selected_spec_id)
	_enter_menu()

	if OS.get_cmdline_user_args().has("--smoke"):
		_start_smoke()


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
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.8, 0.88)
	env.fog_density = 0.005
	env.glow_enabled = true
	env.glow_intensity = 0.5

	var world_environment := WorldEnvironment.new()
	world_environment.environment = env
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(38.0), 0.0)
	sun.light_energy = 1.2
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


# ---- автотест ---------------------------------------------------------------
func _start_smoke() -> void:
	_smoke = true
	_smoke_timer = 0.0
	_smoke_crashed = false
	_smoke_phase = 0
	# HUD в автотесте не должен перебивать виртуальные касания нулями.
	hud.set_process(false)
	print("SMOKE start")
	_start_run("g4", GameConfig.MapId.STRAIGHT_TRACK, GameConfig.GameMode.FREE_RIDE)


func _tick_smoke(delta: float) -> void:
	_smoke_timer += delta

	# Фаза 1: G4 на трассе. Фаза 2: F3 Pro Max в городе с полным приводом.
	if _smoke_phase == 0 and _smoke_timer > 9.0:
		_smoke_phase = 1
		_start_run("f3_pro_max", GameConfig.MapId.CITY, GameConfig.GameMode.FREESTYLE)
		if scooter != null:
			scooter.toggle_drive()
			print("SMOKE phase 2: F3 Pro Max, city, drive=%d" % scooter.drive_mode)

	if state != State.RUNNING:
		return

	input_state.touch_throttle = 1.0
	input_state.touch_steer = sin(_smoke_timer * 0.9) * 0.7
	input_state.touch_wheelie = _smoke_timer > 3.0 and _smoke_timer < 6.0

	if not _smoke_crashed and _smoke_timer > 7.0 and scooter != null:
		_smoke_crashed = true
		scooter.crash("smoke test")
		print("SMOKE forced crash")

	if _smoke_timer > 18.0:
		print("SMOKE OK speed=%.1f km/h distance=%.1f m score=%d tricks=%d crashes=%d state=%d" % [
			scooter.speed_kmh() if scooter != null else 0.0,
			scooter.distance_meters if scooter != null else 0.0,
			tricks.score, tricks.trick_count,
			scooter.crash_count if scooter != null else 0,
			state,
		])
		get_tree().quit()


# ---- кадр -------------------------------------------------------------------
func _process(delta: float) -> void:
	if _smoke:
		_tick_smoke(delta)

	input_state.poll_keyboard()

	match state:
		State.MENU:
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
	if input_state.consume_menu():
		_back_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	input_state.handle_key_events(event)


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
	if scooter != null and state == State.RUNNING:
		scooter.respawn()


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
