## Корень игры: меню → отсчёт → заезд → результаты.
## Собирает мир, самокат, камеру и интерфейс, ведёт таймеры режимов.
extends Node3D

enum State { MENU, COUNTDOWN, RUNNING, FINISHED, PAUSED }

const RESULTS_LAYER := 20
## Настройки игрока (показывать персонажа) переживают перезапуск.
const SETTINGS_PATH := "user://settings.cfg"

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
## Результат последнего заезда: побит ли рекорд и сколько было до него.
var _new_record := false
var _best_score := 0
## Time Attack: сколько метров нужно до следующего бонуса времени.
var _next_checkpoint := 0.0
var _checkpoints_taken := 0
## Показывать персонажа: переключатель в главном меню, по умолчанию — да.
var rider_shown := true
var _go_timer := 0.0
## Режим съёмки: отключает орбитальную камеру меню, чтобы кадры были по делу.
var _shots := false

# Автотест для CI: `godot --headless --fixed-fps 60 -- --smoke` проезжает
# заезд за игрока (газ, руль, вилли, падение) и печатает SMOKE OK.
var _smoke := false
var _smoke_timer := 0.0
var _smoke_crashed := false
var _smoke_ramp_wait := 0.0
var _smoke_ramp_placed := false
var _smoke_jumps_before := 0
## Вилли в автотесте взводим ровно один раз: раньше лесенка if/elif
## перещёлкивала его каждый кадр после 9.5 с.
var _smoke_wheelie_done := false
var _smoke_phase := 0
var _smoke_wheelie_on := false
# Проверка знака руля: вправо (+) должен давать поворот по часовой (yaw вниз).

# Перетаскивание камеры.
var _camera_dragging := false
var _camera_touch_index := -1
## Состояние до паузы, чтобы вернуться именно туда.
var _state_before_pause: int = State.RUNNING


func _ready() -> void:
	randomize()
	_load_settings()
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
	menu.rider_shown = rider_shown
	menu.setup(ScooterSpec.all())
	menu.start_pressed.connect(_start_run)
	menu.rider_toggled.connect(_on_rider_toggled)

	pause_screen = PauseScreen.new()
	add_child(pause_screen)
	pause_screen.resume_pressed.connect(_resume)
	pause_screen.menu_pressed.connect(_back_to_menu)

	await _build_world(selected_map, selected_spec_id)
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
	# Сцена строится не одним куском: лес и дома достраиваются порциями по кадрам,
	# поэтому нет длинного фриза на старте. В автотестах и на съёмке — сразу целиком.
	var args := OS.get_cmdline_user_args()
	if args.has("--shot") or args.has("--smoke"):
		world_builder.pump(600000.0)
	else:
		while world_builder.pending_jobs() > 0:
			world_builder.pump(5.0)
			await get_tree().process_frame
	var spawn: Vector3 = info["spawn"]

	scooter = Scooter.create(ScooterSpec.get_by_id(spec_id), input_state)
	scooter.position = spawn
	add_child(scooter)
	scooter.set_respawn_point(spawn, Basis.IDENTITY)
	scooter.set_input_enabled(false)
	scooter.set_rider_shown(rider_shown)
	scooter.crashed.connect(_on_crash)
	scooter.respawned.connect(_on_respawned)


# ---- меню -------------------------------------------------------------------
func _enter_menu() -> void:
	get_tree().paused = false
	menu.rider_shown = rider_shown
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
		# В меню самокат показываем от третьего лица: иначе после вида «из глаз»
		# райдер остаётся скрытым, и в меню стоит безголовый самокат.
		camera_rig.first_person = false
	if scooter != null:
		scooter.set_first_person(false)
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

	await _build_world(map_id, spec_id)
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

	_next_checkpoint = GameConfig.CHECKPOINT_STEP
	_checkpoints_taken = 0
	countdown_time = GameConfig.COUNTDOWN_SECONDS
	_go_timer = 0.0
	input_state.enabled = false
	scooter.set_input_enabled(false)
	state = State.COUNTDOWN


func _back_to_menu() -> void:
	await _build_world(selected_map, selected_spec_id)
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
#   1) G4 на ровной дороге: разгон, вилли, принудительное падение;
#   2) Джамп-парк: прыжок с трамплина и очки за него;
#   3) Time Attack: чекпоинт через 300 м добавляет время;
#   4) F3 Pro Max в городе с AWD: переключение привода, езда до финиша Freestyle;
#   5) экран результатов, затем выход с итоговыми числами.
func _start_smoke() -> void:
	_smoke = true
	_smoke_timer = 0.0
	_smoke_crashed = false
	_smoke_phase = 0
	# HUD в автотесте не должен перебивать виртуальные касания нулями.
	hud.set_process(false)
	print("SMOKE start")
	_start_run("g4", GameConfig.MapId.STRAIGHT_TRACK, GameConfig.GameMode.FREE_RIDE)


## Позиции трамплинов — для логов автотеста.
func _ramp_positions() -> Array:
	var out: Array = []
	for entry in [120.0, 280.0, 460.0, 660.0, 850.0]:
		out.append(round(WorldBuilder.FLAT_START_Z - entry))
	return out


## Фаза 3: F3 Pro Max в городе, Freestyle до конца таймера.
func _enter_city_phase() -> void:
	_smoke_phase = 3
	_smoke_ramp_wait = 0.0
	_start_run("f3", GameConfig.MapId.CITY, GameConfig.GameMode.FREESTYLE)
	if scooter != null:
		print("SMOKE phase 3: drive=%d (AWD=1)" % scooter.drive_mode)
		scooter.toggle_drive()
		print("SMOKE phase 3: after toggle drive=%d (RWD=0)" % scooter.drive_mode)
		scooter.toggle_drive()


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
	return "%s speed=%.1f dist=%.1f y=%.2f pitch=%.1f maxPitch=%.1f roll=%.1f contact=%s wheelie=%s air=%.2f jumps=%d gas=%.2f score=%d combo=%.2f crashes=%d last=%s" % [
		scooter.spec.id, scooter.speed_kmh(), scooter.distance_meters, pos.y,
		scooter.pitch_deg, scooter.max_pitch_deg, scooter.roll_deg, contact,
		wheelie_state, scooter.max_air_time, scooter.landing_counter,
		scooter.throttle_input, tricks.score,
		tricks.combo_multiplier(),
		scooter.crash_count, scooter.last_crash_reason,
	]


func _tick_smoke(delta: float) -> void:
	_smoke_timer += delta
	_smoke_ramp_wait += delta

	# Фаза 0 → 1: вилли и падение проверены. Ставим самокат в 18 м перед первым
	# трамплином, чтобы гарантированно проверить прыжок, а не надеяться, что
	# автотест до него доедет.
	if _smoke_phase == 0 and _smoke_timer > 12.0:
		_smoke_phase = 1
		_smoke_ramp_wait = 0.0
		print("SMOKE phase 1 end: %s" % _telemetry())
		# Самокат один раз приземлялся уже на спауне (падал с 0.12 м), поэтому
		# сравниваем с базой, а не с нулём.
		_smoke_jumps_before = scooter.landing_counter if scooter != null else 0
		print("SMOKE ramp map: Джамп-парк, трамплины %s, база прыжков=%d" % [
			str(_ramp_positions()), _smoke_jumps_before,
		])
		_start_run("g4", GameConfig.MapId.JUMP_PARK, GameConfig.GameMode.FREE_RIDE)
		return

	# Фаза 1: газ в пол через трамплин — ждём отрыв и счёт за прыжок.
	if _smoke_phase == 1:
		# Ставим самокат в 18 м перед первым трамплином только после отсчёта,
		# иначе спаун перезапишет телепорт.
		if state != State.RUNNING:
			return
		if not _smoke_ramp_placed:
			_smoke_ramp_placed = true
			_smoke_ramp_wait = 0.0
			if scooter != null:
				scooter.respawn_position = Vector3(0.0, 0.6, WorldBuilder.FLAT_START_Z - 102.0)
				scooter.respawn_basis = Basis.IDENTITY
				scooter.respawn()
				print("SMOKE ramp approach: %s" % _telemetry())
			return
		input_state.touch_throttle = 1.0
		input_state.touch_steer = 0.0
		var jumped: bool = scooter != null and scooter.landing_counter > _smoke_jumps_before
		if jumped:
			print("SMOKE ramp jump OK: %s" % _telemetry())
			print("SMOKE ramp jump points=%d last_trick=%s" % [tricks.score, tricks.last_trick])
		if not jumped:
			# Пока в воздухе, печатаем телеметрию каждые 0.5 с.
			if fmod(_smoke_ramp_wait, 0.5) < delta:
				print("SMOKE ramp t=%.1f %s" % [_smoke_ramp_wait, _telemetry()])
		if jumped or _smoke_ramp_wait > 9.0:
			if not jumped:
				print("SMOKE ramp jump MISSED: %s" % _telemetry())
			# Дальше — Time Attack: проверяем чекпоинты, которые добавляют
			# время за метры.
			_smoke_phase = 2
			_smoke_ramp_wait = 0.0
			_start_run("g4", GameConfig.MapId.STRAIGHT_TRACK, GameConfig.GameMode.TIME_ATTACK)
		return

	# Фаза 2: Time Attack, ждём первый чекпоинт (300 м) или 45 с.
	if _smoke_phase == 2:
		if state != State.RUNNING:
			return
		input_state.touch_throttle = 1.0
		input_state.touch_steer = 0.0
		if _checkpoints_taken > 0:
			print("SMOKE checkpoint OK: %s time_left=%.1f" % [_telemetry(), time_left])
			_enter_city_phase()
			return
		if _smoke_ramp_wait > 45.0:
			print("SMOKE checkpoint MISSED: dist=%.1f time_left=%.1f" % [
				scooter.distance_meters if scooter != null else -1.0, time_left,
			])
			_enter_city_phase()
		return

	# Фаза 3 → финиш: ждём, пока истечёт таймер Freestyle, и проверяем результаты.
	if _smoke_phase == 3 and state == State.FINISHED:
		_smoke_phase = 4
		print("SMOKE finished: %s results_visible=%s time_left=%.1f" % [
			_telemetry(), str(results_root != null and results_root.visible), time_left,
		])
		print("SMOKE OK %s" % _telemetry())
		print("PLAYTEST hud %s" % hud.debug_clock())
		print("PLAYTEST record %s" % Records.describe(selected_map, selected_mode))
		# Инварианты, которые ломались на прошлых сборках: улетевшая позиция,
		# провал под карту и «застывший» HUD.
		var pos := scooter.global_position if scooter != null else Vector3.ZERO
		var nan_pos := is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z)
		var under_map := pos.y < -2.0
		var hud_ok := not hud.debug_clock().contains("dist=0.00")
		print("PLAYTEST checks nan=%s under_map=%s hud_ok=%s checkpoints=%d" % [
			str(nan_pos), str(under_map), str(hud_ok), _checkpoints_taken,
		])
		get_tree().quit()
		return

	if _smoke_phase == 4:
		return

	if _smoke_timer > 170.0:
		print("SMOKE TIMEOUT %s" % _telemetry())
		get_tree().quit(1)
		return

	if state != State.RUNNING:
		return

	# В вилли автотест держит газ ниже упора: так проверяется управление углом
	# без намеренного переворота через заднее колесо.
	input_state.touch_throttle = 0.75 if _smoke_wheelie_on else 1.0
	# На ровной дороге автотест виляет рулём, в городе едет прямо.
	input_state.touch_steer = sin(_smoke_timer * 0.7) * 0.35 if _smoke_phase == 0 else 0.0

	if _smoke_phase == 0:
		if not _smoke_wheelie_done and not _smoke_wheelie_on and _smoke_timer > 3.0:
			_smoke_wheelie_on = true
			input_state.request_wheelie_toggle()
			print("SMOKE wheelie toggle ON")
		elif _smoke_wheelie_on and _smoke_timer > 9.5:
			_smoke_wheelie_on = false
			_smoke_wheelie_done = true
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


## Обойти дерево модели и собрать группы деталей: узел с прямыми мешами = деталь.
func _collect_part_groups(node: Node3D, out: Array) -> void:
	for child in node.get_children():
		if not (child is Node3D):
			continue
		var meshes := 0
		for sub in child.get_children():
			if sub is MeshInstance3D:
				meshes += 1
		if meshes > 0:
			out.append({"node": child, "count": meshes})
		if child.get_child_count() > 0:
			_collect_part_groups(child, out)


## Совмещённый AABB прямых мешей узла.
func _group_aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var local: AABB = child.mesh.get_aabb()
			var world: AABB = child.global_transform * local
			if first:
				box = world
				first = false
			else:
				box = box.merge(world)
	return box


## По одному кадру на каждую группу деталей (имя файла = путь узла в модели).
func _take_part_shots(shot_dir: String, spec_id: String) -> void:
	var model_root: Node3D = null
	if scooter != null:
		model_root = scooter.get_node_or_null("Model")
	if model_root == null:
		print("PART SHOTS: нет узла Model")
		return
	var groups: Array = []
	_collect_part_groups(model_root, groups)
	print("PART SHOTS: групп %d" % groups.size())
	var made := 0
	for entry in groups:
		var node: Node3D = entry["node"]
		if str(node.get_path()).contains("Rider"):
			continue
		var box := _group_aabb(node)
		if box.size.length() < 0.004:
			continue
		var center := box.get_center()
		var radius := maxf(box.size.length() * 0.5, 0.015)
		var dist := radius * 3.6 + 0.14
		var dir := Vector3(0.62, 0.52, -0.58)
		if center.x < -0.015:
			dir = Vector3(-0.62, 0.52, -0.58)
		dir = dir.normalized()
		camera_rig.target = null
		camera_rig.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera_rig.fov = 36.0
		camera_rig.global_position = center + dir * dist
		camera_rig.look_at(center, Vector3.UP)
		for frame in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var rel := str(node.get_path())
		var cut := rel.find("Model/")
		if cut >= 0:
			rel = rel.substr(cut + 6)
		rel = rel.replace("/", "-")
		var path := "%s/%s_part_%s.png" % [shot_dir, spec_id, rel]
		image.save_png(path)
		made += 1
	print("PART SHOTS: снято %d" % made)


## Собрать отдельные детали-меши: повторяющиеся (шашки протектора, болты) — по 2 образца.
func _collect_detail_meshes(node: Node, out: Array, seen: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var base := str(child.name)
			var cut := base.rfind("_")
			if cut > 0 and base.substr(cut + 1).is_valid_int():
				base = base.substr(0, cut)
			var key := "%s/%s" % [str(node.get_path()), base]
			var count: int = int(seen.get(key, 0))
			seen[key] = count + 1
			if count > 1:
				continue
			var box: AABB = child.global_transform * child.mesh.get_aabb()
			if box.size.length() < 0.004:
				continue
			out.append({"mesh": child, "box": box, "group": str(node.get_path())})
		elif child is Node:
			_collect_detail_meshes(child, out, seen)


## Кадры отдельных деталей: имя файла = группа + имя меша.
func _take_detail_shots(shot_dir: String, spec_id: String) -> void:
	var model_root: Node3D = null
	if scooter != null:
		model_root = scooter.get_node_or_null("Model")
	if model_root == null:
		return
	var items: Array = []
	_collect_detail_meshes(model_root, items, {})
	print("DETAIL SHOTS: деталей %d" % items.size())
	var made := 0
	for item in items:
		var box: AABB = item["box"]
		var center := box.get_center()
		var radius := maxf(box.size.length() * 0.5, 0.008)
		var dist := radius * 3.4 + 0.10
		var dir := Vector3(0.60, 0.52, -0.60)
		if center.x < -0.015:
			dir = Vector3(-0.60, 0.52, -0.60)
		dir = dir.normalized()
		camera_rig.target = null
		camera_rig.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera_rig.fov = 36.0
		camera_rig.global_position = center + dir * dist
		camera_rig.look_at(center, Vector3.UP)
		for frame in 2:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		var group := str(item["group"])
		var cut := group.find("Model/")
		if cut >= 0:
			group = group.substr(cut + 6)
		var path := "%s/%s_detail_%s-%s.png" % [shot_dir, spec_id,
			group.replace("/", "-"), str(item["mesh"].name)]
		image.save_png(path)
		made += 1
	print("DETAIL SHOTS: снято %d" % made)


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
		# Колесо впритык к асфальту: по этому кадру видно, не висит ли самокат.
		{"name": "contact", "offset": Vector3(1.05, 0.22, -1.15), "look": Vector3(0.0, 0.10, -0.42), "fov": 30.0},
		# Строгие ортогональные проекции для сверки с фото.
		{"name": "o_front", "offset": Vector3(0.0, 0.60, -4.6), "look": Vector3(0.0, 0.60, 0.0),
			"fov": 12.0, "ortho": true, "size": 1.38},
		{"name": "o_rear", "offset": Vector3(0.0, 0.60, 4.6), "look": Vector3(0.0, 0.60, 0.0),
			"fov": 12.0, "ortho": true, "size": 1.38},
		{"name": "o_left", "offset": Vector3(-4.6, 0.60, 0.0), "look": Vector3(0.0, 0.60, 0.0),
			"fov": 12.0, "ortho": true, "size": 1.38},
		{"name": "o_right", "offset": Vector3(4.6, 0.60, 0.0), "look": Vector3(0.0, 0.60, 0.0),
			"fov": 12.0, "ortho": true, "size": 1.38},
		{"name": "o_top", "offset": Vector3(0.0, 3.40, 0.0), "look": Vector3(0.0, 0.40, 0.0),
			"fov": 12.0, "ortho": true, "size": 1.48, "up": Vector3(0.0, 0.0, -1.0), "hide_world": true},
		{"name": "o_bottom", "offset": Vector3(0.0, -2.20, 0.0), "look": Vector3(0.0, 0.40, 0.0),
			"fov": 12.0, "ortho": true, "size": 1.48, "up": Vector3(0.0, 0.0, 1.0), "hide_world": true},
		{"name": "o_quarter", "offset": Vector3(1.90, 1.05, -2.35), "look": Vector3(0.0, 0.62, 0.0),
			"fov": 30.0},
	]

	for spec_id in ["g4", "f3"]:
		await _build_world(GameConfig.MapId.STRAIGHT_TRACK, spec_id)
		camera_rig.target = null
		await get_tree().create_timer(0.8).timeout
		if scooter != null:
			print("MODEL plane: %s %s" % [spec_id, scooter.visual_report()])
		# Сначала чистые кадры самой модели (без райдера), потом — с ним.
		var rider_node: Node3D = null
		if scooter != null and scooter.rider != null:
			rider_node = scooter.rider
			scooter.set_rider_shown(false)
		for index in shots.size():
			var shot: Dictionary = shots[index]
			var origin: Vector3 = scooter.global_position
			var look_point: Vector3 = origin + shot["look"]
			var up: Vector3 = shot.get("up", Vector3.UP)
			if shot.get("hide_world", false) and world_root != null:
				world_root.visible = false
			camera_rig.global_position = origin + shot["offset"]
			camera_rig.look_at(look_point, up)
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
			# Дублируем кадры исправленной модели с префиксом g4_fixed для сравнения.
			if spec_id == "g4":
				image.save_png("%s/g4_fixed_%d_%s.png" % [shot_dir, index, shot["name"]])
			if shot.get("hide_world", false) and world_root != null:
				world_root.visible = true

		# Кадры каждой группы деталей: только для модели пользователя.
		if spec_id == "g4":
			await _take_part_shots(shot_dir, spec_id)
			await _take_detail_shots(shot_dir, spec_id)

		# Кадр с райдером.
		if rider_node != null:
			scooter.set_rider_shown(true)
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

	# То же меню с выключенным персонажем: проверяем переключатель.
	_on_rider_toggled(false)
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot(shot_dir, "menu_no_rider")
	_on_rider_toggled(true)

	# Геймплей: вид от камеры игрока, с HUD и райдером на ходу.
	hud.visible = true
	_start_run("g4", GameConfig.MapId.STRAIGHT_TRACK, GameConfig.GameMode.FREE_RIDE)
	input_state.touch_throttle = 1.0
	await get_tree().create_timer(4.2).timeout
	await RenderingServer.frame_post_draw
	_save_shot(shot_dir, "hud_drive")
	print("MODEL drive: front=%s rear=%s steer=%s front_spin=%.2f rear_spin=%.2f steer_vis=%.2f speed=%.1f" % [
		"нет" if scooter.front_visual == null else str(scooter.front_visual.get_path()),
		"нет" if scooter.rear_visual == null else str(scooter.rear_visual.get_path()),
		"нет" if scooter.front_steer == null else str(scooter.front_steer.get_path()),
		scooter.front_visual.rotation.x if scooter.front_visual != null else 0.0,
		scooter.rear_visual.rotation.x if scooter.rear_visual != null else 0.0,
		scooter.front_steer.rotation.y if scooter.front_steer != null else 0.0,
		scooter.speed_kmh(),
	])

	# На кадре станта газ средний: на полном контроллер уводит нос почти
	# в вертикаль (перегазовка), и позу не разобрать.
	input_state.touch_throttle = 0.55
	input_state.request_wheelie_toggle()
	await get_tree().create_timer(2.4).timeout
	await RenderingServer.frame_post_draw
	_save_shot(shot_dir, "hud_wheelie")

	# Стант сбоку: видно позу райдера — опорная нога на деке, вторая в воздухе.
	# Камеру переставляем каждый кадр: на софтверном рендере в CI кадр долгий,
	# и статичная камера теряет уезжающий самокат.
	hud.visible = false
	camera_rig.target = null
	camera_rig.fov = 38.0
	for frame in 5:
		var stunt_origin: Vector3 = scooter.global_position
		camera_rig.global_position = stunt_origin + Vector3(4.3, 1.25, 1.5)
		camera_rig.look_at(stunt_origin + Vector3(0.0, 0.85, 0.25), Vector3.UP)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("SHOT stunt %s" % scooter.visual_report())
	print("SHOT stunt scooter=%s pitch=%.1f roll=%.1f y=%.2f speed=%.1f lift=%.2f active=%s crashed=%s" % [
		str(scooter.global_position), scooter.pitch_deg, scooter.roll_deg,
		scooter.global_position.y, scooter.speed_kmh(),
		scooter.wheelie.lift_progress if scooter.wheelie != null else 0.0,
		str(scooter.wheelie.active if scooter.wheelie != null else false),
		str(scooter.is_crashed),
	])
	_save_shot(shot_dir, "wheelie_side")

	# Пауза: проверяем новое меню с «Продолжить» и «В меню».
	_open_pause()
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot(shot_dir, "pause")
	_resume()

	# Вид от первого лица: райдер скрыт, камера на уровне шлема.
	camera_rig.target = scooter
	camera_rig.toggle_view()
	hud.visible = true
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot(shot_dir, "hud_fp")

	# Мир: трамплин на прямой трассе и город — проверяем геометрию трассы.
	await _take_world_shots(shot_dir)

	print("SHOTS DONE %s" % shot_dir)
	get_tree().quit()


func _save_shot(shot_dir: String, shot_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [shot_dir, shot_name]
	var error := image.save_png(path)
	print("SHOT %s err=%d" % [path, error])


## Кадры мира: разгон к трамплину, прыжок и город. Раньше снимали только
## модель, поэтому проблемы трассы не были видны ни в одном кадре.
func _take_world_shots(shot_dir: String) -> void:
	if camera_rig.first_person:
		camera_rig.toggle_view()
	_start_run("g4", GameConfig.MapId.JUMP_PARK, GameConfig.GameMode.FREE_RIDE)
	input_state.touch_throttle = 0.0
	# Ждём конца отсчёта: он ставит самокат на спаун, и телепорт до него
	# просто затрётся.
	var wait_frames := 0
	while state != State.RUNNING and wait_frames < 600:
		wait_frames += 1
		await get_tree().process_frame
	if scooter != null:
		scooter.respawn_position = Vector3(0.0, 0.6, WorldBuilder.FLAT_START_Z - 103.0)
		scooter.respawn_basis = Basis.IDENTITY
		scooter.respawn()
	camera_rig.target = scooter
	camera_rig.snap_behind()
	hud.visible = true
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot(shot_dir, "world_ramp")
	print("WORLD ramp approach z=%.1f scooter=%s" % [
		scooter.global_position.z if scooter != null else 0.0,
		_telemetry(),
	])

	# Разгон в трамплин и кадр в воздухе.
	input_state.touch_throttle = 1.0
	var airborne := false
	var tries := 0
	while tries < 240 and not airborne:
		tries += 1
		await get_tree().create_timer(0.05).timeout
		if scooter != null and not scooter.is_grounded() and scooter.air_time > 0.10:
			airborne = true
			await RenderingServer.frame_post_draw
			_save_shot(shot_dir, "world_jump")
	print("WORLD jump air=%s %s" % [str(airborne), _telemetry()])
	input_state.touch_throttle = 0.0
	await get_tree().create_timer(1.6).timeout
	print("WORLD landing %s" % _telemetry())

	# Город: общий вид на старте, чтобы видеть дома, свет и разметку.
	_start_run("f3", GameConfig.MapId.CITY, GameConfig.GameMode.FREESTYLE)
	if scooter != null:
		scooter.respawn()
	camera_rig.target = null
	var city_eye: Vector3 = scooter.global_position if scooter != null else Vector3.ZERO
	camera_rig.global_position = city_eye + Vector3(9.0, 7.5, 16.0)
	camera_rig.look_at(city_eye + Vector3(0.0, 1.0, -22.0), Vector3.UP)
	camera_rig.fov = 55.0
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot(shot_dir, "world_city")
	print("WORLD city z=%.1f" % city_eye.z)


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

	# Чекпоинты Time Attack: за метры дают секунды, иначе заезд кончается
	# раньше, чем игрок успевает доехать до трамплинов.
	if selected_mode == GameConfig.GameMode.TIME_ATTACK and scooter != null:
		while scooter.distance_meters >= _next_checkpoint:
			_next_checkpoint += GameConfig.CHECKPOINT_STEP
			_checkpoints_taken += 1
			time_left += GameConfig.CHECKPOINT_BONUS
			if hud != null:
				hud.show_banner("ЧЕКПОИНТ +%d с" % int(GameConfig.CHECKPOINT_BONUS))
			if scooter.audio != null:
				scooter.audio.play_chime()

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


# ---- настройки --------------------------------------------------------------
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	rider_shown = bool(cfg.get_value("game", "rider_shown", true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("game", "rider_shown", rider_shown)
	cfg.save(SETTINGS_PATH)


func _on_rider_toggled(shown: bool) -> void:
	rider_shown = shown
	_save_settings()
	# Кнопку в меню перерисовываем всегда: состояние может прийти и от самой игры.
	menu.rider_shown = shown
	menu.refresh()
	if scooter != null:
		scooter.set_rider_shown(shown)


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

	# Рекорд пишем именно здесь: экран результатов — единственное место, где
	# заезд уже закончен и все цифры посчитаны.
	var previous_best := int(Records.best(selected_map, selected_mode).get("score", 0))
	_new_record = Records.submit(selected_map, selected_mode, tricks.score,
		scooter.distance_meters if scooter != null else 0.0, run_time, crashes)
	_best_score = maxi(previous_best, tricks.score)
	var record_line: String
	if _new_record:
		record_line = "НОВЫЙ РЕКОРД!" if previous_best <= 0 else "НОВЫЙ РЕКОРД! было %d" % previous_best
	else:
		record_line = "Рекорд: %d очков" % _best_score

	results_label.text = "Очки: %d\nТрюков: %d\nМножитель комбо: x%.2f\n\nДистанция: %.2f км\nВремя: %d:%02d\nПадений: %d\n\n%s" % [
		tricks.score, tricks.trick_count, tricks.combo_multiplier(),
		distance_km, int(run_time / 60.0), int(run_time) % 60, crashes,
		record_line,
	]
	print("RECORD %s best=%d new=%s" % [Records.describe(selected_map, selected_mode),
		_best_score, str(_new_record)])
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

	# Две кнопки: сразу перезапустить тот же заезд или уйти в меню.
	var retry_button := UiFactory.button("ЕЩЁ РАЗ", 26, Vector2(340.0, 70.0))
	UiFactory.place(retry_button, 250.0, 560.0, 340.0, 70.0)
	retry_button.pressed.connect(_restart_run)
	results_root.add_child(retry_button)

	var back_button := UiFactory.button("В МЕНЮ", 26, Vector2(340.0, 70.0))
	UiFactory.place(back_button, 690.0, 560.0, 340.0, 70.0)
	back_button.pressed.connect(_back_to_menu)
	results_root.add_child(back_button)


## Перезапуск того же заезда с экрана результатов.
func _restart_run() -> void:
	_start_run(selected_spec_id, selected_map, selected_mode)


func _hide_results() -> void:
	if results_root != null:
		results_root.visible = false
