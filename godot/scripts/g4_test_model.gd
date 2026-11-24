## KuKirin G4 TEST — вторая, полностью независимая модель KuKirin G4.
## Написана с нуля: свои материалы, свои примитивы (лофт, тело вращения,
## труба по кривой), свой шрифт для наклеек, свой экран приборки.
## Старая G4Model не тронута и продолжает работать как раньше.
##
## Масштаб снят с ортопрофиля kugookirin-g4-electric-scooter-side-view-2
## по известной длине 1210 мм и проверен по осям колёс:
##   шина Ø 0.306 м → R = 0.153 м, база 0.905 м, общая длина 1.211 м,
##   верх деки 0.089 м над осями (низ — на 0.02 м ниже осей),
##   толщина деки 0.109 м, длина 0.477 м,
##   шарнир стойки: 0.08 м позади передней оси, 0.346 м над осями,
##   верх руля 0.962 м над осями, наклон стойки 11.5°.
##
## Иерархия (важно для экспорта в GLB и для анимации):
##   Model
##   ├ Frame (дека, горловина, стакан, задняя площадка, крыло, подножка)
##   ├ FrontSuspension (рычаг, пружина)      ├ RearSuspension (маятник, пружины)
##   ├ RearWheel (шина, обод, мотор-ступица, диск, суппорт)
##   └ Steer (поворачивается игрой)
##      ├ Stem, FoldClamp, Headlight, Bar, GripL/R, LeverL/R, Throttle, Dash
##      └ Wheel (переднее колесо, крутится игрой)
class_name G4TestModel
extends RefCounted

# ---- размеры, м --------------------------------------------------------------
const R := 0.153
const BASE := 0.905
const AXLE_F := -0.4525
const AXLE_R := 0.4525
const DECK_TOP := 0.089
const DECK_BOT := -0.020
const DECK_W := 0.215
const DECK_FRONT := -0.237
const DECK_REAR := 0.2395
const STEP_TOP := 0.147
const STEP_REAR := 0.344
## Шарнир стойки стоит на 0.08 м позади передней оси — как на ортопрофиле.
const HEAD_Z := -0.373
const HEAD_BASE_Y := 0.28
const HINGE_Y := 0.346
const RAKE := 0.2007  # 11.5°
const BAR_Y := 0.962
const BAR_HALF := 0.290
const GRIP_IN := 0.196
const TIRE_HW := 0.040

# ---- цвета ------------------------------------------------------------------
const C_FRAME := Color(0.452, 0.462, 0.452)   # серый порошок рамы (sRGB)
const C_FRAME_D := Color(0.330, 0.340, 0.332)
const C_BLACK := Color(0.055, 0.057, 0.062)   # чёрный окрашенный металл
const C_STEEL := Color(0.560, 0.575, 0.600)   # тёмно-серый металл
const C_ALU := Color(0.660, 0.672, 0.690)
const C_RUBBER := Color(0.058, 0.057, 0.060)
const C_PLASTIC := Color(0.075, 0.078, 0.086)
const C_ORANGE := Color(0.980, 0.400, 0.030)
const C_LAMP := Color(1.000, 0.960, 0.880)
const C_TAIL := Color(1.000, 0.100, 0.060)
const C_CALIPER := Color(0.620, 0.080, 0.060)

var spec: ScooterSpec

var _m_frame: StandardMaterial3D
var _m_frame_d: StandardMaterial3D
var _m_black: StandardMaterial3D
var _m_black_d: StandardMaterial3D
var _m_steel: StandardMaterial3D
var _m_alu: StandardMaterial3D
var _m_rotor: StandardMaterial3D
var _m_rubber: StandardMaterial3D
var _m_plastic: StandardMaterial3D
var _m_glass: StandardMaterial3D
var _m_orange: StandardMaterial3D
var _m_lamp: StandardMaterial3D
var _m_tail: StandardMaterial3D
var _m_amber: StandardMaterial3D
var _m_caliper: StandardMaterial3D
var _m_tape: StandardMaterial3D
var _m_screen: StandardMaterial3D

var _decal_cache := {}


# ---- сборка ------------------------------------------------------------------
func build_model(new_spec: ScooterSpec) -> Dictionary:
	spec = new_spec
	_make_materials()
	var root := Node3D.new()
	root.name = "Model"

	var frame := _node(root, "Frame")
	_build_deck(frame)
	_build_neck(frame)
	_build_head_tube(frame)
	_build_rear_platform(frame)
	_build_rear_fender(frame)
	_build_kickstand(frame)
	_build_rear_suspension(frame)

	var rear := _node(root, "RearWheel")
	rear.position = Vector3(0.0, 0.0, AXLE_R)
	_build_wheel(rear, true, true)
	_build_rear_brake(frame)

	var steer := _node(root, "Steer")
	steer.position = Vector3(0.0, HINGE_Y, HEAD_Z)
	_build_stem(steer)
	_build_bar(steer)
	_build_dash(steer)
	_build_headlight(steer)
	_build_front_suspension(steer)
	_build_front_brake(steer)
	var wheel := _node(steer, "Wheel")
	wheel.position = Vector3(0.0, -HINGE_Y, AXLE_F - HEAD_Z)
	_build_wheel(wheel, false, false)

	var bar := _bar_local()
	_marker(steer, "BarLeft", Vector3(-GRIP_IN - 0.02, bar.y - 0.004, bar.z + 0.010))
	_marker(steer, "BarRight", Vector3(GRIP_IN + 0.02, bar.y - 0.004, bar.z + 0.010))
	_marker(root, "FootLeft", Vector3(-0.070, DECK_TOP + 0.012, -0.08))
	_marker(root, "FootRight", Vector3(0.070, DECK_TOP + 0.012, 0.11))

	return {
		"root": root,
		"front_steer": steer,
		"front_wheel": wheel,
		"rear_wheel": rear,
		"bar_left": steer.get_node("BarLeft"),
		"bar_right": steer.get_node("BarRight"),
		"foot_left": root.get_node("FootLeft"),
		"foot_right": root.get_node("FootRight"),
	}


## Центр руля в системе координат узла Steer (его начало — шарнир стойки).
func _bar_local() -> Vector3:
	return Vector3(0.0, BAR_Y - HINGE_Y, tan(RAKE) * (BAR_Y - HINGE_Y) + 0.010)


# ---- материалы ----------------------------------------------------------------
func _make_materials() -> void:
	var grain := _grain_texture(64, C_FRAME, 0.05, 11)
	var grain_dark := _grain_texture(64, C_BLACK, 0.05, 23)
	var nrm_soft := _noise_normal(64, 0.09, 2.2, 7)
	var nrm_fine := _noise_normal(64, 0.22, 1.6, 19)

	_m_frame = _mat(C_FRAME, 0.10, 0.52)
	_m_frame.resource_name = "FrameGrey"
	_m_frame.albedo_texture = grain
	_m_frame.normal_enabled = true
	_m_frame.normal_texture = nrm_soft
	_m_frame.normal_scale = 0.10
	_m_frame.uv1_scale = Vector3(2.0, 2.0, 2.0)

	_m_frame_d = _mat(C_FRAME_D, 0.12, 0.50)
	_m_frame_d.resource_name = "FrameGreyDark"
	_m_frame_d.albedo_texture = grain
	_m_frame_d.uv1_scale = Vector3(3.0, 3.0, 3.0)

	_m_black = _mat(C_BLACK, 0.14, 0.46)
	_m_black.resource_name = "PaintedBlack"
	_m_black.albedo_texture = grain_dark
	_m_black.normal_enabled = true
	_m_black.normal_texture = nrm_soft
	_m_black.normal_scale = 0.10
	_m_black.uv1_scale = Vector3(3.0, 3.0, 3.0)
	_m_black.clearcoat_enabled = true
	_m_black.clearcoat = 0.18
	_m_black.clearcoat_roughness = 0.40

	_m_black_d = _mat(C_BLACK.darkened(0.20), 0.12, 0.52)
	_m_black_d.resource_name = "PaintedBlackMatte"

	_m_steel = _mat(C_STEEL, 0.72, 0.30)
	_m_steel.resource_name = "Steel"
	_m_steel.normal_enabled = true
	_m_steel.normal_texture = nrm_fine
	_m_steel.normal_scale = 0.08

	_m_alu = _mat(C_ALU, 0.70, 0.34)
	_m_alu.resource_name = "Aluminium"
	_m_rotor = _mat(Color(0.120, 0.126, 0.135), 0.55, 0.42)
	_m_rotor.resource_name = "BrakeRotor"

	_m_rubber = _mat(C_RUBBER, 0.0, 0.93)
	_m_rubber.resource_name = "Rubber"
	_m_rubber.albedo_texture = _grain_texture(64, C_RUBBER, 0.06, 31)
	_m_rubber.normal_enabled = true
	_m_rubber.normal_texture = nrm_fine
	_m_rubber.normal_scale = 0.30
	_m_rubber.uv1_scale = Vector3(6.0, 6.0, 6.0)

	_m_plastic = _mat(C_PLASTIC, 0.08, 0.55)
	_m_plastic.resource_name = "Plastic"
	_m_plastic.normal_enabled = true
	_m_plastic.normal_texture = nrm_soft
	_m_plastic.normal_scale = 0.22

	_m_glass = _mat(Color(0.012, 0.020, 0.030), 0.30, 0.06)
	_m_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m_glass.resource_name = "ScreenGlass"
	_m_glass.albedo_color.a = 0.14
	_m_glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	_m_orange = _mat(C_ORANGE, 0.55, 0.34)
	_m_orange.resource_name = "OrangeMetal"
	_m_orange.clearcoat_enabled = true
	_m_orange.clearcoat = 0.35
	_m_orange.clearcoat_roughness = 0.25

	_m_lamp = _mat(C_LAMP, 0.05, 0.16, C_LAMP, 1.05)
	_m_lamp.resource_name = "LampLens"
	_m_tail = _mat(C_TAIL.darkened(0.55), 0.10, 0.28, C_TAIL, 3.4)
	_m_tail.resource_name = "TailLight"
	_m_amber = _mat(Color(0.42, 0.18, 0.02), 0.10, 0.30, Color(1.0, 0.52, 0.05), 1.8)
	_m_amber.resource_name = "Reflector"
	_m_caliper = _mat(C_CALIPER, 0.45, 0.34)
	_m_caliper.resource_name = "CaliperRed"

	_m_tape = _mat(Color(0.048, 0.048, 0.052), 0.0, 0.94)
	_m_tape.resource_name = "GripTape"
	_m_tape.albedo_texture = _tape_texture()
	_m_tape.uv1_scale = Vector3(3.0, 3.0, 3.0)

	var screen_tex := _screen_texture()
	_m_screen = _mat(Color(0.02, 0.02, 0.03), 0.05, 0.20)
	_m_screen.resource_name = "DashScreen"
	_m_screen.albedo_texture = screen_tex
	_m_screen.emission_enabled = true
	_m_screen.emission_texture = screen_tex
	_m_screen.emission = Color(1.0, 1.0, 1.0)
	_m_screen.emission_energy_multiplier = 1.85


func _mat(color: Color, metallic: float, rough: float,
		emission := Color(0, 0, 0), emission_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	# Мягкие грани без «мыла»: детали читаются на любом ракурсе.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m


# ---- процедурные текстуры -----------------------------------------------------
func _grain_texture(size: int, base: Color, amount: float, seed_value: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.35
	noise.fractal_octaves = 3
	for y in size:
		for x in size:
			var n := noise.get_noise_2d(float(x), float(y)) * amount
			var c := Color(
				clampf(base.r + n, 0.0, 1.0),
				clampf(base.g + n, 0.0, 1.0),
				clampf(base.b + n, 0.0, 1.0))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _noise_normal(size: int, freq: float, strength: float, seed_value: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = freq
	noise.fractal_octaves = 4
	var h := PackedFloat32Array()
	h.resize(size * size)
	for y in size:
		for x in size:
			h[y * size + x] = noise.get_noise_2d(float(x), float(y))
	for y in size:
		for x in size:
			var xl := h[y * size + maxi(x - 1, 0)]
			var xr := h[y * size + mini(x + 1, size - 1)]
			var yu := h[maxi(y - 1, 0) * size + x]
			var yd := h[mini(y + 1, size - 1) * size + x]
			var n := Vector3((xl - xr) * strength, (yu - yd) * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return ImageTexture.create_from_image(img)


## Гриптейп: мелкая «шкурка» из точек плюс лёгкий шум.
func _tape_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.6
	for y in size:
		for x in size:
			var v := 0.050 + noise.get_noise_2d(float(x), float(y)) * 0.010
			if (x % 2 == 0 and y % 2 == 0) or (x % 3 == 1 and y % 4 == 2):
				v += 0.010
			img.set_pixel(x, y, Color(v, v, v * 1.02))
	return ImageTexture.create_from_image(img)


# ---- шрифт для наклеек --------------------------------------------------------
## Пиксельный шрифт 5×7: наклейки рисуются в текстуру, поэтому они видны
## и в игре, и в экспортированном GLB (Label3D в GLB не попадает).
const GLYPHS := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01110"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
	":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
	"/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
	"+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
	"°": ["01100", "10010", "10010", "01100", "00000", "00000", "00000"],
	"#": ["01010", "01010", "11111", "01010", "11111", "01010", "01010"],
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}


func _text_image(text: String, cell: int, color: Color) -> Image:
	var cols := 0
	for i in text.length():
		cols += 6
	var w := maxi(cols - 1, 1) * cell
	var h := 7 * cell
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var x := 0
	for i in text.length():
		var ch := text.substr(i, 1).to_upper()
		var glyph: Array = GLYPHS.get(ch, GLYPHS[" "])
		for row in 7:
			var line: String = glyph[row]
			for col in 5:
				if line[col] == "1":
					img.fill_rect(Rect2i(x + col * cell, row * cell, cell, cell), color)
		x += 6 * cell
	return img


## Наклейка: плоскость с текстом, прижатая к поверхности.
func _decal(parent: Node3D, node_name: String, text: String, height_m: float,
		color: Color, xform: Transform3D, cell := 6, mirror := false) -> MeshInstance3D:
	var key := "%s|%f|%s|%d" % [text, color.to_html(), str(cell), str(mirror)]
	var tex: ImageTexture = _decal_cache.get(key)
	if tex == null:
		var img := _text_image(text, cell, color)
		if mirror:
			img.flip_x()
		tex = ImageTexture.create_from_image(img)
		_decal_cache[key] = tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var w := height_m * float(tex.get_width()) / float(tex.get_height())
	var quad := QuadMesh.new()
	quad.size = Vector2(w, height_m)
	var inst := MeshInstance3D.new()
	inst.name = _unique_name(parent, node_name)
	inst.mesh = quad
	inst.material_override = mat
	inst.transform = xform
	parent.add_child(inst)
	return inst


## Шахматный «флажок» KuKirin на корпусе.
func _chevron_texture(side := 6) -> ImageTexture:
	var size := side * 5
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in side:
		for x in side:
			if (x + y) % 2 == 0:
				img.fill_rect(Rect2i(x * 5, y * 5, 5, 5), C_ORANGE)
	return ImageTexture.create_from_image(img)


func _chevron(parent: Node3D, node_name: String, size_m: float, xform: Transform3D) -> MeshInstance3D:
	var key := "chevron"
	var tex: ImageTexture = _decal_cache.get(key)
	if tex == null:
		tex = _chevron_texture()
		_decal_cache[key] = tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	var quad := QuadMesh.new()
	quad.size = Vector2(size_m, size_m)
	var inst := MeshInstance3D.new()
	inst.name = _unique_name(parent, node_name)
	inst.mesh = quad
	inst.material_override = mat
	inst.transform = xform
	parent.add_child(inst)
	return inst


# ---- экран приборной панели ---------------------------------------------------
func _screen_texture() -> ImageTexture:
	var w := 512
	var h := 208
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.015, 0.020, 0.026))
	# верхняя полоса с логотипом
	img.fill_rect(Rect2i(0, 0, w, 26), Color(0.035, 0.045, 0.055))
	var brand := _text_image("KUKIRIN", 2, Color(0.98, 0.45, 0.08))
	img.blend_rect(brand, Rect2i(0, 0, brand.get_width(), brand.get_height()), Vector2i(10, 4))
	var mode := _text_image("SPORT", 2, Color(0.55, 0.95, 1.0))
	img.blend_rect(mode, Rect2i(0, 0, mode.get_width(), mode.get_height()),
		Vector2i(w - mode.get_width() - 10, 4))

	# скорость: две семисегментные цифры
	_draw_seven_seg(img, 42, 46, 86, 132, "3", Color(0.80, 0.98, 1.0))
	_draw_seven_seg(img, 146, 46, 86, 132, "8", Color(0.80, 0.98, 1.0))
	var unit := _text_image("KM/H", 2, Color(0.60, 0.72, 0.80))
	img.blend_rect(unit, Rect2i(0, 0, unit.get_width(), unit.get_height()), Vector2i(44, 182))

	# шкала батареи
	var bars := 5
	for i in bars:
		var x := 300 + i * 38
		var on := i < 4
		var col := Color(0.30, 0.95, 0.45) if on else Color(0.10, 0.20, 0.14)
		img.fill_rect(Rect2i(x, 52, 30, 58), col)
	img.fill_rect(Rect2i(296, 46, 2, 70), Color(0.45, 0.55, 0.60))
	img.fill_rect(Rect2i(486, 46, 2, 70), Color(0.45, 0.55, 0.60))
	img.fill_rect(Rect2i(296, 46, 192, 2), Color(0.45, 0.55, 0.60))
	img.fill_rect(Rect2i(296, 114, 192, 2), Color(0.45, 0.55, 0.60))
	var pct := _text_image("78", 2, Color(0.60, 0.75, 0.85))
	img.blend_rect(pct, Rect2i(0, 0, pct.get_width(), pct.get_height()), Vector2i(384, 60))

	# индикаторы: фара, поворотники, режимы
	img.fill_rect(Rect2i(300, 132, 24, 24), Color(0.25, 0.85, 1.0))
	img.fill_rect(Rect2i(336, 132, 24, 24), Color(0.99, 0.62, 0.10))
	img.fill_rect(Rect2i(372, 132, 24, 24), Color(0.15, 0.28, 0.34))
	img.fill_rect(Rect2i(408, 132, 24, 24), Color(0.15, 0.28, 0.34))
	var labels := _text_image("S D T", 2, Color(0.62, 0.74, 0.82))
	img.blend_rect(labels, Rect2i(0, 0, labels.get_width(), labels.get_height()),
		Vector2i(300, 166))
	var odo := _text_image("ODO 1204 KM", 2, Color(0.50, 0.62, 0.70))
	img.blend_rect(odo, Rect2i(0, 0, odo.get_width(), odo.get_height()), Vector2i(396, 168))
	# лёгкая сетка-подложка, чтобы экран не выглядел плоской заливкой
	for y in range(0, h, 8):
		img.fill_rect(Rect2i(0, y, w, 1), Color(0.020, 0.028, 0.036))
	return ImageTexture.create_from_image(img)


func _draw_seven_seg(img: Image, x: int, y: int, dw: int, dh: int, digit: String,
		color: Color) -> void:
	var t := int(dw * 0.17)
	var segs := {
		"0": "abcedf", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
		"5": "afgcd", "6": "afgecd", "7": "abc", "8": "abcdefg", "9": "abfgcd",
	}
	var on: String = segs.get(digit, "")
	var hw := dw / 2
	var hh := dh / 2
	var rects := {
		"a": Rect2i(x, y, dw, t),
		"g": Rect2i(x, y + hh - t / 2, dw, t),
		"d": Rect2i(x, y + dh - t, dw, t),
		"f": Rect2i(x, y, t, hh),
		"b": Rect2i(x + dw - t, y, t, hh),
		"e": Rect2i(x, y + hh - t / 2, t, hh + t / 2),
		"c": Rect2i(x + dw - t, y + hh - t / 2, t, hh + t / 2),
	}
	for key in ["a", "b", "c", "d", "e", "f", "g"]:
		var r: Rect2i = rects[key]
		var col := color if on.contains(key) else Color(0.075, 0.10, 0.12)
		img.fill_rect(r, col)


# ---- узлы и меши --------------------------------------------------------------
func _node(parent: Node3D, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = _unique_name(parent, node_name)
	parent.add_child(n)
	return n


func _marker(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = _unique_name(parent, node_name)
	n.position = pos
	parent.add_child(n)
	return n


func _unique_name(parent: Node3D, node_name: String) -> String:
	# Имена должны быть уникальны внутри родителя: иначе в GLB они станут
	# безликими _MeshInstance3D_N и по ним нельзя будет анимировать.
	if not parent.has_node(NodePath(node_name)):
		return node_name
	var index := 1
	while parent.has_node(NodePath("%s_%d" % [node_name, index])):
		index += 1
	return "%s_%d" % [node_name, index]


func _mesh(parent: Node3D, node_name: String, mesh: Mesh, mat: Material,
		xform := Transform3D.IDENTITY) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = _unique_name(parent, node_name)
	inst.mesh = mesh
	if mat != null:
		inst.material_override = mat
	inst.transform = xform
	parent.add_child(inst)
	return inst


func _box(parent: Node3D, node_name: String, size: Vector3, xform: Transform3D,
		mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(parent, node_name, m, mat, xform)


func _cyl(parent: Node3D, node_name: String, radius: float, height: float,
		xform: Transform3D, mat: Material, top_radius := -1.0, segs := 24) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = segs
	m.rings = 1
	return _mesh(parent, node_name, m, mat, xform)


func _sphere(parent: Node3D, node_name: String, radius: float, xform: Transform3D,
		mat: Material, segs := 16) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segs
	m.rings = maxi(segs / 2, 6)
	return _mesh(parent, node_name, m, mat, xform)


func _basis_y(dir: Vector3, up_hint := Vector3.RIGHT) -> Basis:
	var y := dir.normalized()
	var x := up_hint.cross(y)
	if x.length() < 0.001:
		x = Vector3.RIGHT.cross(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _basis_x(dir: Vector3, up_hint := Vector3.UP) -> Basis:
	var x := dir.normalized()
	var z := x.cross(up_hint)
	if z.length() < 0.001:
		z = x.cross(Vector3.FORWARD)
	z = z.normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


# ---- примитивы ----------------------------------------------------------------
func _rect_ring(center: Vector3, side: Vector3, up: Vector3, w: float, h: float,
		rad: float, per_corner := 3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var hw := maxf(w, 0.001) * 0.5
	var hh := maxf(h, 0.001) * 0.5
	var rr := clampf(rad, 0.0, minf(hw, hh) * 0.95)
	var cx := hw - rr
	var cy := hh - rr
	var corners := [Vector2(cx, cy), Vector2(-cx, cy), Vector2(-cx, -cy), Vector2(cx, -cy)]
	var starts := [0.0, PI * 0.5, PI, PI * 1.5]
	var steps := maxi(1, per_corner if rr > 0.0 else 1)
	for i in 4:
		for s in steps:
			var ang: float = starts[i] + PI * 0.5 * float(s) / float(steps)
			var off: Vector2 = corners[i] + Vector2(cos(ang), sin(ang)) * rr
			pts.append(center + side * off.x + up * off.y)
	return pts


func _circle_ring(center: Vector3, side: Vector3, up: Vector3, radius: float,
		segs: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for s in segs:
		var a := TAU * float(s) / float(segs)
		pts.append(center + side * (cos(a) * radius) + up * (sin(a) * radius))
	return pts


func _add_v(st: SurfaceTool, p: Vector3, uv: Vector2) -> void:
	st.set_uv(uv)
	st.add_vertex(p)


func _loft_mesh(rings: Array, cap_start: bool, cap_end: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := rings.size()
	for i in count - 1:
		var a: PackedVector3Array = rings[i]
		var b: PackedVector3Array = rings[i + 1]
		var n := a.size()
		var v0 := float(i) / float(maxi(count - 1, 1))
		var v1 := float(i + 1) / float(maxi(count - 1, 1))
		for j in n:
			var k := (j + 1) % n
			var u0 := float(j) / float(n)
			var u1 := float(j + 1) / float(n)
			_add_v(st, a[j], Vector2(u0, v0))
			_add_v(st, a[k], Vector2(u1, v0))
			_add_v(st, b[k], Vector2(u1, v1))
			_add_v(st, a[j], Vector2(u0, v0))
			_add_v(st, b[k], Vector2(u1, v1))
			_add_v(st, b[j], Vector2(u0, v1))
	if cap_start:
		_cap(st, rings[0], true)
	if cap_end:
		_cap(st, rings[count - 1], false)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _cap(st: SurfaceTool, ring: PackedVector3Array, flip: bool) -> void:
	var center := Vector3.ZERO
	for p in ring:
		center += p
	center /= float(ring.size())
	var n := ring.size()
	for j in n:
		var k := (j + 1) % n
		if flip:
			_add_v(st, center, Vector2(0.5, 0.5))
			_add_v(st, ring[k], Vector2(0.0, 0.0))
			_add_v(st, ring[j], Vector2(1.0, 1.0))
		else:
			_add_v(st, center, Vector2(0.5, 0.5))
			_add_v(st, ring[j], Vector2(1.0, 1.0))
			_add_v(st, ring[k], Vector2(0.0, 0.0))


## Тело по траектории: точки, ширины, высоты, радиусы скруглений.
func _sweep(parent: Node3D, node_name: String, mat: Material, points: Array,
		widths: Array, heights: Array, radii: Array, up_hint: Vector3,
		cap := true) -> MeshInstance3D:
	var rings: Array = []
	var n := points.size()
	for i in n:
		var p: Vector3 = points[i]
		var prev: Vector3 = points[maxi(i - 1, 0)]
		var next: Vector3 = points[mini(i + 1, n - 1)]
		var t := (next - prev)
		if t.length() < 0.0001:
			t = Vector3.FORWARD
		t = t.normalized()
		var side := t.cross(up_hint)
		if side.length() < 0.001:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(t).normalized()
		rings.append(_rect_ring(p, side, up, widths[i], heights[i], radii[i]))
	return _mesh(parent, node_name, _loft_mesh(rings, cap, cap), mat)


## Тело вращения вокруг оси X; profile — точки (радиус, смещение по X).
func _lathe_mesh(profile: Array, segs: int) -> ArrayMesh:
	var rings: Array = []
	var count := profile.size()
	for i in count:
		var p: Vector2 = profile[i]
		var r := maxf(p.x, 0.0005)
		var ring := PackedVector3Array()
		for s in segs:
			var a := TAU * float(s) / float(segs)
			ring.append(Vector3(p.y, r * cos(a), r * sin(a)))
		rings.append(ring)
	return _loft_mesh(rings, false, false)


func _lathe(parent: Node3D, node_name: String, mat: Material, profile: Array,
		segs: int, xform := Transform3D.IDENTITY) -> MeshInstance3D:
	return _mesh(parent, node_name, _lathe_mesh(profile, segs), mat, xform)


## Плоская пластина: многоугольник в плоскости XY, толщина по Z.
func _plate(parent: Node3D, node_name: String, mat: Material,
		poly: PackedVector2Array, thickness: float, xform: Transform3D) -> MeshInstance3D:
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for p in poly:
		front.append(Vector3(p.x, p.y, thickness * 0.5))
		back.append(Vector3(p.x, p.y, -thickness * 0.5))
	var rings: Array = [back, front]
	return _mesh(parent, node_name, _loft_mesh(rings, true, true), mat, xform)


## Труба по ломаной (тросы, тормозные шланги, пружины).
func _tube(parent: Node3D, node_name: String, mat: Material, path: Array,
		radius: float, sides := 8, cap := true) -> MeshInstance3D:
	var rings: Array = []
	var up_hint := Vector3.UP
	for i in path.size():
		var p: Vector3 = path[i]
		var prev: Vector3 = path[maxi(i - 1, 0)]
		var next: Vector3 = path[mini(i + 1, path.size() - 1)]
		var t := (next - prev)
		if t.length() < 0.0001:
			t = Vector3.FORWARD
		t = t.normalized()
		var side := t.cross(up_hint)
		if side.length() < 0.01:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(t).normalized()
		rings.append(_circle_ring(p, side, up, radius, sides))
	return _mesh(parent, node_name, _loft_mesh(rings, cap, cap), mat)


func _bolt(parent: Node3D, node_name: String, pos: Vector3, dir: Vector3,
		radius: float, length: float, mat: Material) -> void:
	var b := _basis_x(dir)
	_cyl(parent, node_name, radius, length, Transform3D(b, pos), mat, -1.0, 6)
	_cyl(parent, node_name + "_Washer", radius * 1.55, length * 0.22,
		Transform3D(b, pos - dir.normalized() * (length * 0.42)), mat, -1.0, 10)


func _spring(parent: Node3D, node_name: String, from: Vector3, to: Vector3,
		radius: float, wire: float, turns: int, mat: Material) -> void:
	var axis := (to - from)
	var length := axis.length()
	if length < 0.001:
		return
	var dir := axis / length
	var b := _basis_y(dir)
	var path: Array = []
	var steps := turns * 12
	for i in steps + 1:
		var t := float(i) / float(steps)
		var a := TAU * t * float(turns)
		var p := from + dir * (t * length) + b.x * (cos(a) * radius) + b.z * (sin(a) * radius)
		path.append(p)
	_tube(parent, node_name, mat, path, wire, 6)


# ---- колесо -------------------------------------------------------------------
func _tire_profile() -> Array:
	# Замкнутый контур покрышки: борт с гребешком, боковина, плечо, беговая дорожка.
	return [
		Vector2(0.0995, 0.0295), Vector2(0.1035, 0.0335), Vector2(0.1085, 0.0330),
		Vector2(0.1125, 0.0358), Vector2(0.1260, 0.0388), Vector2(0.1380, 0.0368),
		Vector2(0.1470, 0.0278), Vector2(0.1522, 0.0158), Vector2(0.1535, 0.0000),
		Vector2(0.1522, -0.0158), Vector2(0.1470, -0.0278), Vector2(0.1380, -0.0368),
		Vector2(0.1260, -0.0388), Vector2(0.1125, -0.0358), Vector2(0.1085, -0.0330),
		Vector2(0.1035, -0.0335), Vector2(0.0995, -0.0295), Vector2(0.0935, -0.0230),
		Vector2(0.0935, 0.0230),
	]
func _tread(parent: Node3D) -> void:
	# Направленный рисунок: две дорожки центральных шашек с канавкой по центру,
	# плечевые грунтозацепы и мелкая насечка на плече.
	var count := 26
	for i in count:
		var ang := TAU * float(i) / float(count)
		for s in [-1.0, 1.0]:
			var b := Basis(Vector3.RIGHT, ang) * Basis(Vector3.UP, 0.30 * float(s))
			var mid := b * Vector3(0.0, 0.1522, 0.0) + Vector3(0.0125 * float(s), 0.0, 0.0)
			_box(parent, "TreadCenter", Vector3(0.0220, 0.0025, 0.0165), Transform3D(b, mid), _m_rubber)
			var shoulder := b * Vector3(0.0, 0.1452, 0.0) + Vector3(0.0300 * float(s), 0.0, 0.0)
			_box(parent, "TreadShoulder", Vector3(0.0135, 0.0030, 0.0150), Transform3D(b, shoulder), _m_rubber)
			var bevel := b * Vector3(0.0, 0.1378, 0.0) + Vector3(0.0355 * float(s), 0.0, 0.0)
			_box(parent, "TreadBevel", Vector3(0.0075, 0.0022, 0.0090), Transform3D(b, bevel), _m_rubber)
func _build_wheel(parent: Node3D, motor: bool, drive: bool) -> void:
	var tire := _node(parent, "Tire")
	_lathe(tire, "Carcass", _m_rubber, _tire_profile(), 56)
	_tread(tire)

	# Обод: два бортовых кольца, пять сдвоенных спиц, лицо обода.
	var rim := _node(parent, "Rim")
	var axis := Basis(Vector3.BACK, PI * 0.5)
	_cyl(rim, "FlangeL", 0.1015, 0.0075, Transform3D(axis, Vector3(0.0285, 0.0, 0.0)), _m_black, -1.0, 44)
	_cyl(rim, "FlangeR", 0.1015, 0.0075, Transform3D(axis, Vector3(-0.0285, 0.0, 0.0)), _m_black, -1.0, 44)
	_lathe(rim, "RimLip", _m_black, [
		Vector2(0.0985, 0.0300), Vector2(0.1035, 0.0300),
		Vector2(0.1035, 0.0240), Vector2(0.0985, 0.0240),
	], 44)
	_lathe(rim, "RimLipR", _m_black, [
		Vector2(0.0985, -0.0240), Vector2(0.1035, -0.0240),
		Vector2(0.1035, -0.0300), Vector2(0.0985, -0.0300),
	], 44)
	for i in 5:
		var ang := TAU * float(i) / 5.0
		var dir := Vector3(0.0, cos(ang), sin(ang))
		var tang := Vector3(0.0, -sin(ang), cos(ang))
		for s in [-1.0, 1.0]:
			# сдвоенная спица: две ветви от ступицы к ободу
			var p0 := dir * 0.030 + tang * (0.010 * float(s))
			var p1 := dir * 0.064 + tang * (0.026 * float(s))
			var p2 := dir * 0.090 + tang * (0.034 * float(s))
			_sweep(rim, "Spoke", _m_black, [p0, p1, p2],
				[0.017, 0.024, 0.032], [0.019, 0.017, 0.014], [0.004, 0.004, 0.003],
				Vector3.RIGHT)
		# перемычка у обода и литой «палец» у ступицы
		_box(rim, "SpokeBridge", Vector3(0.030, 0.030, 0.016),
			Transform3D(Basis(Vector3.RIGHT, ang), dir * 0.0855), _m_black)
		_box(rim, "SpokeFoot", Vector3(0.014, 0.020, 0.020),
			Transform3D(Basis(Vector3.RIGHT, ang), dir * 0.034), _m_black)
		_bolt(rim, "SpokeBolt", Vector3(0.014, cos(ang) * 0.0825, sin(ang) * 0.0825),
			Vector3.RIGHT, 0.0035, 0.008, _m_steel)
	# лицо обода: кольцо с фаской
	_lathe(rim, "FaceRing", _m_black, [
		Vector2(0.086, 0.0130), Vector2(0.0965, 0.0130),
		Vector2(0.0965, 0.0175), Vector2(0.086, 0.0175),
	], 44)

	# Ступица.
	var hub := _node(parent, "Hub")
	_cyl(hub, "HubBody", 0.040, 0.080, Transform3D(axis, Vector3.ZERO), _m_black, -1.0, 28)
	_cyl(hub, "HubFace", 0.0345, 0.010, Transform3D(axis, Vector3(0.045, 0.0, 0.0)), _m_black_d, -1.0, 28)
	_cyl(hub, "HubFaceR", 0.0345, 0.010, Transform3D(axis, Vector3(-0.045, 0.0, 0.0)), _m_black_d, -1.0, 28)
	if motor:
		_cyl(hub, "MotorShell", 0.0555, 0.098, Transform3D(axis, Vector3.ZERO), _m_black, -1.0, 32)
		# рёбра охлаждения по всей окружности
		for i in 12:
			var a := TAU * float(i) / 12.0
			_box(hub, "MotorFin", Vector3(0.086, 0.004, 0.008),
				Transform3D(Basis(Vector3.RIGHT, a), Vector3(0.0, cos(a) * 0.0555, sin(a) * 0.0555)),
				_m_black_d)
		_cyl(hub, "MotorCover", 0.0485, 0.006, Transform3D(axis, Vector3(0.051, 0.0, 0.0)), _m_black_d, -1.0, 32)
		_cyl(hub, "MotorRing", 0.0455, 0.004, Transform3D(axis, Vector3(0.054, 0.0, 0.0)), _m_black_d, -1.0, 32)
		_decal(hub, "MotorLabel", "1000W", 0.008, Color(0.70, 0.72, 0.76),
			Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0575, 0.0, 0.022)))
		# вывод кабеля с громметом
		_cyl(hub, "CableBoss", 0.010, 0.016,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.040, -0.030, -0.042)), _m_black_d, -1.0, 12)
		_cyl(hub, "CableGrommet", 0.0065, 0.008,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.049, -0.030, -0.042)), _m_plastic, -1.0, 10)
	for i in 5:
		var a := TAU * float(i) / 5.0
		_bolt(hub, "HubBolt", Vector3(0.049, cos(a) * 0.026, sin(a) * 0.026), Vector3.RIGHT,
			0.0035, 0.008, _m_steel)
	_cyl(hub, "Axle", 0.0095, 0.156, Transform3D(axis, Vector3.ZERO), _m_steel, -1.0, 14)
	_bolt(hub, "AxleNutL", Vector3(0.076, 0.0, 0.0), Vector3.RIGHT, 0.0145, 0.014, _m_steel)
	_bolt(hub, "AxleNutR", Vector3(-0.076, 0.0, 0.0), Vector3.LEFT, 0.0145, 0.014, _m_steel)
	_cyl(hub, "Valve", 0.0038, 0.022, Transform3D(Basis(Vector3.BACK, PI * 0.35),
		Vector3(0.026, 0.0, 0.074)), _m_steel, -1.0, 8)

	# Тормозной диск: несущее кольцо, волновой венец, паук, болты.
	var brake := _node(parent, "BrakeDisc")
	var rotor_x := 0.020
	_lathe(brake, "RotorCarrier", _m_rotor, [
		Vector2(0.048, rotor_x - 0.0016), Vector2(0.057, rotor_x - 0.0016),
		Vector2(0.057, rotor_x + 0.0016), Vector2(0.048, rotor_x + 0.0016),
	], 56)
	_lathe(brake, "Rotor", _m_rotor, [
		Vector2(0.056, rotor_x - 0.0014), Vector2(0.0755, rotor_x - 0.0014),
		Vector2(0.0755, rotor_x + 0.0014), Vector2(0.056, rotor_x + 0.0014),
	], 72)
	for i in 12:
		var ang := TAU * float(i) / 12.0 + 0.12
		# прорези в венце
		var slot := Vector3(rotor_x, cos(ang) * 0.0665, sin(ang) * 0.0665)
		_box(brake, "RotorSlot", Vector3(0.0034, 0.0145, 0.0026),
			Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, ang), slot), _m_black_d)
		_bolt(brake, "RotorBolt", Vector3(rotor_x + 0.003, cos(ang) * 0.0525, sin(ang) * 0.0525),
			Vector3.RIGHT, 0.0032, 0.010, _m_steel)
	_cyl(brake, "RotorSpider", 0.030, 0.005,
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(rotor_x, 0.0, 0.0)), _m_rotor, -1.0, 24)
	for i in 5:
		var ang := TAU * float(i) / 5.0 + 0.2
		var inner := Vector3(rotor_x, cos(ang) * 0.030, sin(ang) * 0.030)
		var outer := Vector3(rotor_x, cos(ang) * 0.058, sin(ang) * 0.058)
		_cyl_between(brake, "RotorSpoke", inner, outer, 0.0050, _m_rotor, 6)
func _deck_profile() -> Array:
	# (z, полуширина, полувысота, радиус скругления)
	return [
		[-0.2370, 0.070, 0.038, 0.018],
		[-0.2260, 0.092, 0.047, 0.017],
		[-0.1950, 0.104, 0.053, 0.014],
		[-0.1200, 0.1075, 0.0545, 0.012],
		[0.0000, 0.1075, 0.0545, 0.012],
		[0.1300, 0.1070, 0.0540, 0.012],
		[0.2000, 0.1050, 0.0520, 0.013],
		[0.2395, 0.0975, 0.0470, 0.016],
	]


func _build_deck(root: Node3D) -> void:
	var deck := _node(root, "Deck")
	var mid_y := (DECK_TOP + DECK_BOT) * 0.5
	var pts: Array = []
	var wid: Array = []
	var hei: Array = []
	var rad: Array = []
	for row in _deck_profile():
		pts.append(Vector3(0.0, mid_y, row[0]))
		wid.append(row[1] * 2.0)
		hei.append(row[2] * 2.0)
		rad.append(row[3])
	_sweep(deck, "Shell", _m_frame, pts, wid, hei, rad, Vector3.UP)

	# Настил: гриптейп с буртиком по борту.
	_sweep(deck, "TopPad", _m_tape,
		[Vector3(0.0, DECK_TOP + 0.001, -0.198), Vector3(0.0, DECK_TOP + 0.001, 0.0),
			Vector3(0.0, DECK_TOP + 0.001, 0.218)],
		[0.152, 0.172, 0.158], [0.005, 0.006, 0.005], [0.010, 0.010, 0.010], Vector3.UP)
	# кант настила по периметру
	for side in [-1.0, 1.0]:
		_sweep(deck, "TapeEdge", _m_black_d,
			[Vector3(0.074 * float(side), DECK_TOP + 0.002, -0.196),
				Vector3(0.085 * float(side), DECK_TOP + 0.002, 0.0),
				Vector3(0.078 * float(side), DECK_TOP + 0.002, 0.216)],
			[0.006, 0.006, 0.006], [0.004, 0.004, 0.004], [0.002, 0.002, 0.002], Vector3.UP)

	# Нижняя панель батарейного отсека с рёбрами и крепежом.
	_sweep(deck, "BottomPanel", _m_frame_d,
		[Vector3(0.0, DECK_BOT - 0.001, -0.206), Vector3(0.0, DECK_BOT - 0.001, 0.208)],
		[0.168, 0.162], [0.007, 0.007], [0.008, 0.008], Vector3.UP)
	for i in 4:
		var z := -0.150 + i * 0.100
		_box(deck, "BottomRib", Vector3(0.150, 0.006, 0.012),
			Transform3D(Basis.IDENTITY, Vector3(0.0, DECK_BOT - 0.005, z)), _m_frame_d)
	for side in [-1.0, 1.0]:
		for i in 4:
			var z := -0.180 + i * 0.120
			_bolt(deck, "BottomScrew", Vector3(0.070 * float(side), DECK_BOT - 0.006, z),
				Vector3.DOWN, 0.0038, 0.006, _m_steel)

	# Резиновый кант по нижней кромке корпуса.
	var trim_pts: Array = []
	var trim_wid: Array = []
	for row in _deck_profile():
		trim_pts.append(Vector3(0.0, DECK_BOT + 0.011, row[0] * 0.995))
		trim_wid.append(row[1] * 2.0 + 0.006)
	_sweep(deck, "EdgeTrim", _m_plastic, trim_pts, trim_wid,
		[0.016, 0.016, 0.016, 0.016, 0.016, 0.016, 0.016, 0.016],
		[0.007, 0.007, 0.007, 0.007, 0.007, 0.007, 0.007, 0.007], Vector3.UP)

	# Боковые панели: шов, болты, шильдик, наклейки.
	for side in [-1.0, 1.0]:
		var sx: float = 0.1075 * float(side)
		var basis := Basis(Vector3.UP, -PI * 0.5 * float(side))
		_box(deck, "Seam", Vector3(0.004, 0.050, 0.418),
			Transform3D(Basis.IDENTITY, Vector3(sx * 1.005, 0.040, 0.0)), _m_frame_d)
		for i in 5:
			var z := -0.160 + i * 0.088
			_bolt(deck, "DeckBolt", Vector3(sx * 1.012, DECK_TOP - 0.014, z),
				Vector3(float(side), 0.0, 0.0), 0.0045, 0.008, _m_steel)
		# шильдик с заклёпками
		_box(deck, "NamePlate", Vector3(0.003, 0.019, 0.052),
			Transform3D(basis, Vector3(sx * 1.014, 0.054, 0.170)), _m_black_d)
		for i in 2:
			for j in 2:
				_cyl(deck, "Rivet", 0.0022, 0.0025,
					Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 1.018,
						0.054 - 0.006 + i * 0.012, 0.150 + j * 0.040)), _m_alu, -1.0, 8)
		# наклейки на борту
		_decal(deck, "DeckBrand", "KUKIRIN", 0.020, Color(0.86, 0.87, 0.88),
			Transform3D(basis, Vector3(sx * 1.02, 0.042, -0.080)))
		_decal(deck, "DeckG4", "G4", 0.040, C_ORANGE,
			Transform3D(basis, Vector3(sx * 1.02, 0.050, 0.108)))
		_decal(deck, "DeckCode", "B-05-1", 0.013, C_ORANGE,
			Transform3D(basis, Vector3(sx * 1.02, 0.014, -0.160)))
		_chevron(deck, "DeckChevron", 0.032,
			Transform3D(basis, Vector3(sx * 1.02, 0.010, 0.176)))
		_decal(deck, "DeckWarn", "MAX 120KG", 0.008, Color(0.92, 0.92, 0.90),
			Transform3D(basis, Vector3(sx * 1.02, 0.066, 
				0.020)))
	# табличка с характеристиками сзади
	_decal(deck, "DeckSpec", "60V 20AH", 0.009, Color(0.90, 0.90, 0.88),
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.1, 0.048, 0.202)))
	# разъём зарядки слева
	_cyl(deck, "ChargePort", 0.019, 0.008,
		Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.108, 0.044, -0.130)),
		_m_black_d, -1.0, 20)
	_cyl(deck, "ChargeCap", 0.015, 0.010,
		Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.112, 0.044, -0.130)),
		_m_rubber, -1.0, 20)
func _build_neck(root: Node3D) -> void:
	var neck := _node(root, "Neck")
	# Вертикальная нога рулевой колонки: от шарнира вниз к рычагу подвески.
	_sweep(neck, "ForkLeg", _m_frame, [
		Vector3(0.0, 0.040, -0.3490),
		Vector3(0.0, 0.150, -0.3560),
		Vector3(0.0, 0.260, -0.3630),
		Vector3(0.0, 0.346, -0.3710),
	], [0.070, 0.070, 0.066, 0.060],
		[0.066, 0.068, 0.064, 0.058], [0.014, 0.014, 0.013, 0.012], Vector3.UP)
	# Косынка от носа деки к ноге вилки.
	_sweep(neck, "Gusset", _m_frame, [
		Vector3(0.0, 0.056, -0.2180),
		Vector3(0.0, 0.130, -0.2820),
		Vector3(0.0, 0.212, -0.3380),
	], [0.070, 0.064, 0.060],
		[0.070, 0.064, 0.058], [0.014, 0.013, 0.012], Vector3.UP)
	# усиливающее ребро по борту горловины
	for side in [-1.0, 1.0]:
		_box(neck, "NeckRib", Vector3(0.006, 0.016, 0.130),
			Transform3D(Basis(Vector3.RIGHT, -1.35), Vector3(0.034 * float(side), 0.176, -0.336)),
			_m_frame_d)
	# кронштейн передней подвески
	_box(neck, "FrontPivot", Vector3(0.106, 0.048, 0.062),
		Transform3D(Basis(Vector3.RIGHT, -0.20), Vector3(0.0, 0.060, -0.306)), _m_black)
	_bolt(neck, "FrontPivotBolt", Vector3(0.058, 0.060, -0.306), Vector3.RIGHT, 0.013, 0.024, _m_steel)
	_bolt(neck, "FrontPivotBoltR", Vector3(-0.058, 0.060, -0.306), Vector3.LEFT, 0.013, 0.024, _m_steel)


func _build_head_tube(root: Node3D) -> void:
	var head := _node(root, "HeadTube")
	var axis := Basis(Vector3.BACK, PI * 0.5)
	_cyl(head, "Boss", 0.030, 0.060, Transform3D(axis, Vector3(0.0, HINGE_Y, HEAD_Z)), _m_black, -1.0, 20)
	_cyl(head, "Collar", 0.036, 0.016, Transform3D(axis, Vector3(0.024, HINGE_Y, HEAD_Z)), _m_steel, -1.0, 20)
	_cyl(head, "CollarR", 0.036, 0.016, Transform3D(axis, Vector3(-0.024, HINGE_Y, HEAD_Z)), _m_steel, -1.0, 20)
	_cyl(head, "HingePin", 0.010, 0.110, Transform3D(axis, Vector3(0.0, HINGE_Y, HEAD_Z)), _m_steel, -1.0, 12)
	# щёки шарнира
	for side in [-1.0, 1.0]:
		_box(head, "HingeCheek", Vector3(0.012, 0.070, 0.058),
			Transform3D(Basis(Vector3.RIGHT, 0.10), Vector3(0.035 * float(side), HINGE_Y + 0.004, HEAD_Z)),
			_m_black)


# ---- задняя площадка, крыло, подножка -----------------------------------------
func _build_rear_platform(root: Node3D) -> void:
	var step := _node(root, "RearPlatform")
	var mid_y := STEP_TOP - 0.028
	_sweep(step, "Plate", _m_frame, [
		Vector3(0.0, mid_y, DECK_REAR - 0.004),
		Vector3(0.0, mid_y, 0.296),
		Vector3(0.0, mid_y - 0.006, STEP_REAR),
	], [0.192, 0.198, 0.176], [0.058, 0.054, 0.042],
		[0.010, 0.010, 0.012], Vector3.UP)
	# накладка площадки с ромбическим рисунком и бортиком
	var pad_tilt := Basis(Vector3.RIGHT, -0.045)
	_sweep(step, "Pad", _m_tape,
		[Vector3(0.0, STEP_TOP + 0.002, 0.252), Vector3(0.0, STEP_TOP + 0.001, 0.300),
			Vector3(0.0, STEP_TOP - 0.002, 0.342)],
		[0.152, 0.150, 0.134], [0.005, 0.005, 0.005], [0.008, 0.008, 0.010], Vector3.UP)
	for side in [-1.0, 1.0]:
		_box(step, "PadRib", Vector3(0.098, 0.003, 0.006),
			Transform3D(Basis(Vector3.RIGHT, -0.045) * Basis(Vector3.UP, 0.62 * float(side)),
				Vector3(0.0, STEP_TOP + 0.006, 0.298)), _m_plastic)
		for i in 2:
			_bolt(step, "PadBolt", Vector3(0.062 * float(side), STEP_TOP + 0.004,
				0.264 + i * 0.062), Vector3.UP, 0.0035, 0.006, _m_steel)
	# стойки-кронштейны от деки к площадке
	for side in [-1.0, 1.0]:
		_box(step, "Post", Vector3(0.016, 0.086, 0.030),
			Transform3D(Basis(Vector3.RIGHT, 0.10), Vector3(0.092 * float(side), 0.092, 0.262)), _m_frame_d)
		_bolt(step, "PostBolt", Vector3(0.092 * float(side), 0.126, 0.262),
			Vector3(float(side), 0.0, 0.0), 0.006, 0.010, _m_steel)
	# подкос от деки к носу площадки
	_box(step, "Brace", Vector3(0.014, 0.030, 0.062),
		Transform3D(Basis(Vector3.RIGHT, 0.42), Vector3(0.070, 0.108, 0.238)), _m_frame_d)
	# хвостовик с фонарём и отражателем
	_box(step, "Tail", Vector3(0.120, 0.026, 0.026),
		Transform3D(Basis(Vector3.RIGHT, 0.30), Vector3(0.0, STEP_TOP - 0.024, STEP_REAR + 0.010)), _m_black)
	_box(step, "TailBezel", Vector3(0.100, 0.020, 0.008),
		Transform3D(Basis(Vector3.RIGHT, 0.30), Vector3(0.0, STEP_TOP - 0.026, STEP_REAR + 0.024)), _m_black_d)
	_box(step, "TailLamp", Vector3(0.086, 0.012, 0.006),
		Transform3D(Basis(Vector3.RIGHT, 0.30), Vector3(0.0, STEP_TOP - 0.026, STEP_REAR + 0.029)), _m_tail)
	_box(step, "Reflector", Vector3(0.026, 0.010, 0.004),
		Transform3D(Basis(Vector3.RIGHT, 0.30), Vector3(0.056, STEP_TOP - 0.030, STEP_REAR + 0.026)), _m_amber)
func _build_rear_fender(root: Node3D) -> void:
	var fender := _node(root, "RearFender")
	var center := Vector3(0.0, 0.0, AXLE_R)
	var pts: Array = []
	var wid: Array = []
	var hei: Array = []
	var rad: Array = []
	var a0 := -1.12
	var a1 := 1.08
	var steps := 12
	for i in steps + 1:
		var t := float(i) / float(steps)
		var ang := lerpf(a0, a1, t)
		var r := R + 0.021
		pts.append(center + Vector3(0.0, cos(ang) * r, sin(ang) * r))
		var taper := 1.0 - 0.16 * absf(t - 0.45) * 2.0
		wid.append(0.011)
		hei.append(0.106 * taper)
		rad.append(0.005)
	_sweep(fender, "Hugger", _m_black, pts, wid, hei, rad, Vector3.RIGHT)
	# отбортовка по торцам и рёбра внутри
	for a in [a0, a1]:
		var p := center + Vector3(0.0, cos(a) * (R + 0.021), sin(a) * (R + 0.021))
		_box(fender, "Lip", Vector3(0.100, 0.008, 0.014),
			Transform3D(Basis(Vector3.RIGHT, -a), p), _m_black_d)
	for i in 3:
		var ang := lerpf(a0 + 0.35, a1 - 0.35, float(i) * 0.5)
		var p := center + Vector3(0.0, cos(ang) * (R + 0.014), sin(ang) * (R + 0.014))
		_box(fender, "Fin", Vector3(0.090, 0.010, 0.006),
			Transform3D(Basis(Vector3.RIGHT, -ang), p), _m_black_d)
	# шевроны на бортах крыла
	for side in [-1.0, 1.0]:
		var ang := 0.35
		var tang := Vector3(0.0, -sin(ang), cos(ang))
		var radial := Vector3(0.0, cos(ang), sin(ang))
		var x_axis := -tang if float(side) > 0.0 else tang
		var b := Basis(x_axis, radial, Vector3(float(side), 0.0, 0.0))
		var p := center + Vector3(0.054 * float(side), cos(ang) * (R + 0.021), sin(ang) * (R + 0.021))
		_chevron(fender, "FenderChevron", 0.024, Transform3D(b, p))
	# стоп-сигнал на хвосте крыла
	var tail_pos := center + Vector3(0.0, cos(a1) * (R + 0.034), sin(a1) * (R + 0.034))
	_box(fender, "TailBezel", Vector3(0.098, 0.026, 0.012),
		Transform3D(Basis(Vector3.RIGHT, -a1), tail_pos), _m_black)
	_box(fender, "TailLight", Vector3(0.084, 0.014, 0.006),
		Transform3D(Basis(Vector3.RIGHT, -a1), tail_pos + Vector3(0.0, -0.002, 0.008)), _m_tail)
	for side in [-1.0, 1.0]:
		_bolt(fender, "TailBolt", tail_pos + Vector3(0.040 * float(side), 0.010, 0.002),
			Vector3(0.0, cos(a1), sin(a1)), 0.0035, 0.008, _m_steel)
	# кронштейн крепления к маятнику
	for side in [-1.0, 1.0]:
		_box(fender, "FenderStay", Vector3(0.008, 0.048, 0.016),
			Transform3D(Basis(Vector3.RIGHT, 0.70),
				Vector3(0.058 * float(side), 0.075, AXLE_R - 0.070)), _m_black_d)
func _build_kickstand(root: Node3D) -> void:
	var stand := _node(root, "Kickstand")
	_box(stand, "Bracket", Vector3(0.030, 0.020, 0.040),
		Transform3D(Basis.IDENTITY, Vector3(-0.040, DECK_BOT - 0.008, 0.150)), _m_black_d)
	var pts: Array = [
		Vector3(-0.040, DECK_BOT - 0.014, 0.150),
		Vector3(-0.052, DECK_BOT - 0.016, 0.238),
		Vector3(-0.058, DECK_BOT - 0.014, 0.300),
	]
	_sweep(stand, "Leg", _m_black, pts, [0.018, 0.017, 0.016], [0.014, 0.013, 0.012],
		[0.005, 0.005, 0.005], Vector3.UP)
	_box(stand, "Foot", Vector3(0.024, 0.010, 0.030),
		Transform3D(Basis.IDENTITY, Vector3(-0.058, DECK_BOT - 0.022, 0.322)), _m_plastic)


# ---- подвеска ------------------------------------------------------------------
## Передний рычаг поворачивается вместе с колесом, поэтому живёт в узле Steer.
## Внутри — мировые координаты: смещение возвращает начало в ноль самоката.
func _build_front_suspension(root: Node3D) -> void:
	var susp := _node(root, "FrontSuspension")
	susp.position = Vector3(0.0, -HINGE_Y, -HEAD_Z)
	# Траверса: связывает обе стойки с кронштейном рамы.
	_box(susp, "Crown", Vector3(0.136, 0.028, 0.054),
		Transform3D(Basis(Vector3.RIGHT, -0.22), Vector3(0.0, 0.072, -0.298)), _m_black)
	for side in [-1.0, 1.0]:
		_bolt(susp, "CrownBolt", Vector3(0.048 * float(side), 0.086, -0.284),
			Vector3.UP, 0.0055, 0.014, _m_steel)
	for side in [-1.0, 1.0]:
		var sx := 0.060 * float(side)
		var n := Vector3(float(side), 0.0, 0.0)
		# Рычаг вилки: литая стойка от проушины качания к оси колеса.
		_sweep(susp, "ForkLeg", _m_frame_d, [
			Vector3(sx, 0.062, -0.300),
			Vector3(sx * 1.03, 0.036, -0.380),
			Vector3(sx * 1.05, 0.008, -0.446),
		], [0.078, 0.070, 0.058], [0.026, 0.025, 0.023], [0.010, 0.010, 0.014], Vector3.RIGHT)
		# проушина качания: бобышка, ось, гайка, шайба
		_cyl(susp, "PivotEye", 0.0215, 0.034,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx, 0.062, -0.300)), _m_frame_d, -1.0, 18)
		_cyl(susp, "PivotBush", 0.0150, 0.040,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx, 0.062, -0.300)), _m_black_d, -1.0, 14)
		_bolt(susp, "PivotBolt", Vector3(sx + 0.021 * float(side), 0.062, -0.300), n,
			0.0075, 0.014, _m_steel)
		# ребро жёсткости по наружному борту рычага
		_sweep(susp, "Rib", _m_frame_d, [
			Vector3(sx * 1.06, 0.056, -0.316),
			Vector3(sx * 1.09, 0.032, -0.372),
			Vector3(sx * 1.10, 0.012, -0.424),
		], [0.030, 0.026, 0.020], [0.009, 0.008, 0.007], [0.004, 0.004, 0.004], Vector3.RIGHT)
		# проушина у оси колеса и тормозной кронштейн
		_cyl(susp, "AxleEye", 0.0205, 0.026,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 1.05, 0.0, AXLE_F)),
			_m_frame_d, -1.0, 18)
		_bolt(susp, "ArmBoltA", Vector3(sx * 1.06 + 0.012 * float(side), 0.050, -0.336), n,
			0.006, 0.012, _m_steel)
		_bolt(susp, "ArmBoltB", Vector3(sx * 1.06 + 0.012 * float(side), 0.022, -0.408), n,
			0.006, 0.012, _m_steel)
		_decal(susp, "ArmCode", "B-01", 0.011, C_ORANGE,
			Transform3D(Basis(Vector3.UP, PI * 0.5 * float(side)),
				Vector3(sx * 1.06 + 0.0135 * float(side), 0.018, -0.372)))
		# кронштейн амортизатора на горловине
		var top := Vector3(sx * 1.02, 0.196, -0.360)
		var bot := Vector3(sx * 1.06, 0.044, -0.372)
		_sweep(susp, "DamperMount", _m_frame_d, [
			Vector3(sx * 0.50, 0.212, -0.352),
			Vector3(sx * 0.86, 0.204, -0.356),
			top,
		], [0.030, 0.026, 0.022], [0.048, 0.040, 0.032], [0.006, 0.006, 0.008], Vector3.RIGHT)
		_cyl(susp, "DamperEyeTop", 0.0135, 0.026,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), top), _m_black, -1.0, 14)
		_bolt(susp, "DamperBoltTop", Vector3(top.x + 0.017 * float(side), top.y, top.z), n,
			0.0055, 0.012, _m_steel)
		# амортизатор: корпус сверху, шток снизу, пружина на опорах
		var axis := bot - top
		var dir := axis.normalized()
		_cyl(susp, "DamperBody", 0.0150, 0.074,
			Transform3D(_basis_y(dir), top + dir * 0.046), _m_black, -1.0, 16)
		_cyl(susp, "DamperRod", 0.0078, 0.072,
			Transform3D(_basis_y(dir), top + dir * 0.116), _m_steel, -1.0, 12)
		_cyl(susp, "SpringSeat", 0.0225, 0.006,
			Transform3D(_basis_y(dir), top + dir * 0.014), _m_black_d, -1.0, 20)
		_cyl(susp, "SpringSeatBot", 0.0225, 0.006,
			Transform3D(_basis_y(dir), bot - dir * 0.010), _m_black_d, -1.0, 20)
		_spring(susp, "DamperSpring", top + dir * 0.017, bot - dir * 0.013,
			0.0192, 0.0044, 11, _m_black_d)
		# вилка-проушина снизу и её болт
		_cyl(susp, "DamperEyeBot", 0.0135, 0.026,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), bot), _m_black, -1.0, 14)
		_bolt(susp, "DamperBoltBot", Vector3(bot.x + 0.017 * float(side), bot.y, bot.z), n,
			0.0055, 0.012, _m_steel)
		# отбойник на штоке
		_cyl(susp, "BumpStop", 0.0125, 0.014,
			Transform3D(_basis_y(dir), bot - dir * 0.030), _m_plastic, -1.0, 12)
func _build_rear_suspension(root: Node3D) -> void:
	var susp := _node(root, "RearSuspension")
	# Поперечина маятника у шарнира.
	_box(susp, "SwingBridge", Vector3(0.128, 0.030, 0.034),
		Transform3D(Basis(Vector3.RIGHT, 0.55), Vector3(0.0, 0.036, 0.252)), _m_frame_d)
	_cyl(susp, "SwingPivot", 0.0105, 0.150,
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 0.040, 0.248)), _m_steel, -1.0, 14)
	for side in [-1.0, 1.0]:
		var sx := 0.062 * float(side)
		var n := Vector3(float(side), 0.0, 0.0)
		_sweep(susp, "SwingArm", _m_frame_d, [
			Vector3(sx, 0.040, 0.248),
			Vector3(sx * 1.02, 0.020, 0.336),
			Vector3(sx * 1.05, 0.002, AXLE_R - 0.008),
		], [0.056, 0.052, 0.046], [0.020, 0.019, 0.018], [0.010, 0.010, 0.014], Vector3.RIGHT)
		# проушина шарнира с болтом
		_cyl(susp, "SwingEye", 0.0175, 0.028,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx, 0.040, 0.248)), _m_frame_d, -1.0, 16)
		_bolt(susp, "SwingBolt", Vector3(sx + 0.018 * float(side), 0.040, 0.248), n,
			0.0070, 0.012, _m_steel)
		# проушина оси колеса
		_cyl(susp, "AxleEye", 0.0205, 0.024,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 1.05, 0.0, AXLE_R)),
			_m_frame_d, -1.0, 18)
		_bolt(susp, "ArmBoltA", Vector3(sx * 1.06 + 0.012 * float(side), 0.026, 0.316), n,
			0.006, 0.012, _m_steel)
		_decal(susp, "ArmCode", "B-06", 0.011, C_ORANGE,
			Transform3D(Basis(Vector3.UP, PI * 0.5 * float(side)),
				Vector3(sx * 1.05 + 0.0135 * float(side), 0.006, 0.352)))
		# амортизатор сзади: опора на раме, корпус, шток, пружина
		var top := Vector3(sx * 1.10, 0.132, 0.292)
		var bot := Vector3(sx * 1.08, 0.030, 0.348)
		var dir := (bot - top).normalized()
		_sweep(susp, "DamperMount", _m_frame_d, [
			Vector3(sx * 0.55, 0.152, 0.276),
			Vector3(sx * 0.88, 0.140, 0.286),
			top,
		], [0.028, 0.024, 0.020], [0.044, 0.036, 0.030], [0.006, 0.006, 0.008], Vector3.RIGHT)
		_cyl(susp, "DamperEyeTop", 0.0140, 0.028,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), top), _m_black, -1.0, 14)
		_bolt(susp, "DamperBoltTop", Vector3(top.x + 0.018 * float(side), top.y, top.z), n,
			0.0055, 0.012, _m_steel)
		_cyl(susp, "DamperBody", 0.0165, 0.056,
			Transform3D(_basis_y(dir), top + dir * 0.036), _m_black, -1.0, 16)
		_cyl(susp, "DamperRod", 0.0082, 0.054,
			Transform3D(_basis_y(dir), top + dir * 0.088), _m_steel, -1.0, 12)
		_cyl(susp, "SpringSeat", 0.0245, 0.006,
			Transform3D(_basis_y(dir), top + dir * 0.012), _m_black_d, -1.0, 20)
		_cyl(susp, "SpringSeatBot", 0.0245, 0.006,
			Transform3D(_basis_y(dir), bot - dir * 0.010), _m_black_d, -1.0, 20)
		_spring(susp, "DamperSpring", top + dir * 0.015, bot - dir * 0.013,
			0.0212, 0.0046, 10, _m_black_d)
		_cyl(susp, "DamperEyeBot", 0.0140, 0.028,
			Transform3D(Basis(Vector3.BACK, PI * 0.5), bot), _m_black, -1.0, 14)
		_bolt(susp, "DamperBoltBot", Vector3(bot.x + 0.018 * float(side), bot.y, bot.z), n,
			0.0055, 0.012, _m_steel)
		_cyl(susp, "BumpStop", 0.0130, 0.014,
			Transform3D(_basis_y(dir), bot - dir * 0.030), _m_plastic, -1.0, 12)
func _cyl_between(parent: Node3D, node_name: String, from: Vector3, to: Vector3,
		radius: float, mat: Material, segs := 12) -> MeshInstance3D:
	var dir := to - from
	var length := dir.length()
	var b := _basis_y(dir / maxf(length, 0.0001))
	return _cyl(parent, node_name, radius, length, Transform3D(b, (from + to) * 0.5), mat,
		-1.0, segs)


func _caliper(parent: Node3D, node_name: String, center: Vector3, angle: float,
		side: float) -> void:
	var basis := Basis(Vector3.RIGHT, angle) * Basis(Vector3.UP, PI * 0.5 * float(side))
	# корпус суппорта сидит на тормозном диске (x = 0.020), колодки — по обе стороны
	_box(parent, node_name, Vector3(0.026, 0.064, 0.034),
		Transform3D(basis, center), _m_black_d)
	for s in [-1.0, 1.0]:
		_box(parent, node_name + "_Pad", Vector3(0.008, 0.030, 0.022),
			Transform3D(basis, center + basis.z * (0.0115 * float(s))), _m_black_d)
	_box(parent, node_name + "_Bridge", Vector3(0.030, 0.014, 0.020),
		Transform3D(basis, center + Vector3(0.0, 0.038, 0.0)), _m_black_d)
	# скоба-держатель к рычагу
	_box(parent, node_name + "_Bracket", Vector3(0.030, 0.030, 0.012),
		Transform3D(basis, center + Vector3(0.026 * float(side), 0.026, 0.0)), _m_steel)
	for b in [-1.0, 1.0]:
		_bolt(parent, node_name + "_Bolt", center + Vector3(0.020 * float(side),
			0.020 * float(b), 0.014), Vector3(float(side), 0.0, 0.0), 0.0046, 0.012, _m_steel)
	_cyl(parent, node_name + "_Bleed", 0.0048, 0.012,
		Transform3D(Basis(Vector3.BACK, PI * 0.5), center + Vector3(0.0, 0.030, -0.020)),
		_m_steel, -1.0, 8)
func _build_front_brake(root: Node3D) -> void:
	var holder := _node(root, "FrontBrake")
	holder.position = Vector3(0.0, -HINGE_Y, -HEAD_Z)
	# суппорт на диске, над осью и позади неё, за рычагом вилки
	var c := Vector3(0.020, 0.052, AXLE_F + 0.068)
	_caliper(holder, "FrontCaliper", c, -0.45, 1.0)
	# шланг от суппорта вверх по рычагу к раме
	var hose: Array = [
		c + Vector3(0.016, 0.026, -0.014),
		Vector3(0.046, 0.070, -0.372),
		Vector3(0.056, 0.104, -0.336),
		Vector3(0.050, 0.140, -0.300),
		Vector3(0.032, 0.158, -0.286),
	]
	_tube(holder, "FrontBrakeHose", _m_black_d, hose, 0.0046, 8)
	_box(holder, "HoseGuide", Vector3(0.012, 0.008, 0.036),
		Transform3D(Basis(Vector3.RIGHT, -0.62), Vector3(0.054, 0.112, -0.322)), _m_black_d)
func _build_rear_brake(root: Node3D) -> void:
	# суппорт заднего диска: над осью, со стороны маятника
	var c := Vector3(0.020, 0.050, AXLE_R + 0.070)
	_caliper(root, "RearCaliper", c, 0.45, -1.0)
func _stem_points() -> Array:
	var out: Array = []
	for y in [0.0, 0.10, 0.30, 0.50, BAR_Y - HINGE_Y]:
		out.append(Vector3(0.0, y, tan(RAKE) * y))
	return out


func _build_stem(steer: Node3D) -> void:
	var stem := _node(steer, "Stem")
	var ys: Array = [0.0, 0.10, 0.30, 0.50, BAR_Y - HINGE_Y]
	var wid: Array = [0.056, 0.058, 0.056, 0.054, 0.050]
	var hei: Array = [0.064, 0.068, 0.065, 0.061, 0.056]
	var rad: Array = [0.010, 0.010, 0.010, 0.009, 0.009]
	_sweep(stem, "Blade", _m_black, _stem_points(), wid, hei, rad, Vector3.FORWARD)
	# чёрные боковые накладки
	for side in [-1.0, 1.0]:
		var sx := 0.0280 * float(side)
		var pts: Array = []
		for y in [0.045, 0.26, 0.60]:
			pts.append(Vector3(sx, y, tan(RAKE) * y))
		_sweep(stem, "SidePlate", _m_black_d, pts, [0.005, 0.005, 0.004],
			[0.056, 0.052, 0.046], [0.006, 0.006, 0.006], Vector3.FORWARD)
	# болты по борту
	for side in [-1.0, 1.0]:
		for i in 3:
			var y := 0.16 + i * 0.16
			_bolt(stem, "StemBolt", Vector3(0.029 * float(side), y, tan(RAKE) * y),
				Vector3(float(side), 0.0, 0.0), 0.0042, 0.008, _m_steel)
	# маркировка вдоль стойки
	var axis_dir := Vector3(0.0, cos(RAKE), sin(RAKE))
	for side in [-1.0, 1.0]:
		var n := Vector3(float(side), 0.0, 0.0)
		var x_axis := axis_dir
		var y_axis := n.cross(x_axis).normalized()
		var basis := Basis(x_axis, y_axis, n)
		var center := Vector3(0.030 * float(side), 0.36, tan(RAKE) * 0.36)
		_decal(stem, "StemBrand", "KUKIRIN G4", 0.026, C_ORANGE,
			Transform3D(basis, center + n * 0.002))
		_decal(stem, "StemCode", "B-09-1", 0.012, Color(0.80, 0.81, 0.82),
			Transform3D(basis, Vector3(0.030 * float(side), 0.13, tan(RAKE) * 0.13) + n * 0.002))
		_chevron(stem, "StemChevron", 0.024,
			Transform3D(Basis(Vector3.UP, PI * 0.5 * float(side)),
				Vector3(0.030 * float(side), 0.075, tan(RAKE) * 0.075 + 0.030)))
	# замок складывания у основания
	var clamp := _node(stem, "FoldClamp")
	for y0 in [0.008, 0.070]:
		var pts: Array = []
		var w: Array = [0.062, 0.062]
		var h: Array = [0.078, 0.078]
		var r: Array = [0.010, 0.010]
		pts.append(Vector3(0.0, y0, tan(RAKE) * y0))
		pts.append(Vector3(0.0, y0 + 0.036, tan(RAKE) * (y0 + 0.036)))
		_sweep(clamp, "Collar", _m_black, pts, w, h, r, Vector3.FORWARD)
	for side in [-1.0, 1.0]:
		_bolt(clamp, "ClampBolt", Vector3(0.035 * float(side), 0.042, tan(RAKE) * 0.042),
			Vector3(float(side), 0.0, 0.0), 0.0052, 0.010, _m_steel)
		_bolt(clamp, "ClampBoltB", Vector3(0.035 * float(side), 0.100, tan(RAKE) * 0.100),
			Vector3(float(side), 0.0, 0.0), 0.0052, 0.010, _m_steel)
	# шарнирная проушина спереди с осью и шплинтом
	for y0 in [0.014, 0.086]:
		_cyl(clamp, "HingeKnuckle", 0.0135, 0.058,
			Transform3D(Basis(Vector3.BACK, PI * 0.5),
				Vector3(0.0, y0, tan(RAKE) * y0 - 0.040)), _m_black_d, -1.0, 16)
	_cyl(clamp, "HingePin", 0.0075, 0.084,
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 0.050, tan(RAKE) * 0.050 - 0.040)),
		_m_steel, -1.0, 14)
	_bolt(clamp, "HingePinEnd", Vector3(0.043, 0.050, tan(RAKE) * 0.050 - 0.040),
		Vector3.RIGHT, 0.0090, 0.008, _m_steel)
	# стяжная шпилька с гайкой сбоку
	for side in [-1.0, 1.0]:
		_cyl(clamp, "TieRod", 0.0060, 0.020,
			Transform3D(Basis(Vector3.BACK, PI * 0.5),
				Vector3(0.040 * float(side), 0.072, tan(RAKE) * 0.072 - 0.014)), _m_steel, -1.0, 10)
	# быстросъёмный рычаг
	_box(clamp, "Lever", Vector3(0.014, 0.030, 0.070),
		Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0.040, 0.050, tan(RAKE) * 0.050 + 0.056)),
		_m_black_d)
	_cyl(clamp, "LeverPin", 0.008, 0.020,
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.024, 0.050, tan(RAKE) * 0.050 + 0.048)),
		_m_steel, -1.0, 12)
	_build_stem_top(stem)
	_build_cables(steer, clamp)
	_build_strap(steer)


## Верх стойки: площадка, разрезной хомут руля и стяжные болты.
func _build_stem_top(stem: Node3D) -> void:
	var c := _bar_local()
	var top := _node(stem, "BarClamp")
	_box(top, "TopPlate", Vector3(0.058, 0.012, 0.062),
		Transform3D(Basis(Vector3.RIGHT, RAKE), Vector3(0.0, c.y - 0.026, c.z - 0.014)), _m_black_d)
	_box(top, "ClampBase", Vector3(0.092, 0.022, 0.050),
		Transform3D(Basis(Vector3.RIGHT, RAKE), Vector3(0.0, c.y - 0.012, c.z - 0.001)), _m_black)
	_box(top, "ClampCap", Vector3(0.092, 0.015, 0.050),
		Transform3D(Basis(Vector3.RIGHT, RAKE), Vector3(0.0, c.y + 0.0125, c.z - 0.001)), _m_black)
	_box(top, "ClampSeam", Vector3(0.094, 0.0025, 0.046),
		Transform3D(Basis(Vector3.RIGHT, RAKE), Vector3(0.0, c.y + 0.0005, c.z - 0.001)), _m_black_d)
	for side in [-1.0, 1.0]:
		for zz in [-0.017, 0.015]:
			_bolt(top, "ClampBolt", Vector3(0.036 * float(side), c.y + 0.0205,
				c.z + zz), Vector3.UP, 0.0042, 0.016, _m_steel)
			_cyl(top, "ClampNut", 0.0062, 0.007,
				Transform3D(Basis.IDENTITY, Vector3(0.036 * float(side), c.y - 0.025,
					c.z + zz)), _m_steel, -1.0, 6)
	# прилив под стойкой
	_box(top, "Neck", Vector3(0.050, 0.020, 0.056),
		Transform3D(Basis(Vector3.RIGHT, RAKE), Vector3(0.0, c.y - 0.038, c.z - 0.020)), _m_black)


## Передняя кромка стойки в системе координат Steer для высоты y.
func _stem_front_z(y: float) -> float:
	var half := 0.029
	if y > 0.18:
		half = 0.031
	if y > 0.45:
		half = 0.032
	return tan(RAKE) * y - half


## Транспортировочный ремешок на руле (деталь с оригинальных фото).
func _build_strap(steer: Node3D) -> void:
	var strap := _node(steer, "Strap")
	var c := _bar_local()
	var pts: Array = [
		Vector3(0.104, c.y + 0.004, c.z + 0.014),
		Vector3(0.112, c.y - 0.062, c.z + 0.026),
		Vector3(0.118, c.y - 0.140, c.z + 0.030),
		Vector3(0.110, c.y - 0.196, c.z + 0.026),
	]
	_sweep(strap, "Belt", _m_black_d, pts,
		[0.026, 0.026, 0.026, 0.024], [0.005, 0.005, 0.005, 0.005],
		[0.002, 0.002, 0.002, 0.002], Vector3.FORWARD)
	_box(strap, "Slider", Vector3(0.028, 0.010, 0.008),
		Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0.117, c.y - 0.150, c.z + 0.030)), _m_steel)
	_box(strap, "Tag", Vector3(0.030, 0.016, 0.003),
		Transform3D(Basis(Vector3.RIGHT, 0.10) * Basis(Vector3.UP, PI * 0.5),
			Vector3(0.106, c.y - 0.206, c.z + 0.026)), _m_orange)


## Прокладка кабелей: два тормозных шланга и жгут по задней кромке стойки,
## с обходом стяжного хомута, клипсами и резиновым вводом в раму.
func _build_cables(steer: Node3D, _clamp: Node3D) -> void:
	var cables := _node(steer, "Cables")
	var c := _bar_local()
	# Передняя кромка стойки: z = tan(RAKE)*y - полуглубина профиля.
	var runs: Array = [
		{"x": -0.021, "r": 0.0105, "off": 0.008, "name": "Harness"},
		{"x": -0.040, "r": 0.0050, "off": 0.006, "name": "BrakeHoseL"},
		{"x": 0.021, "r": 0.0050, "off": 0.007, "name": "BrakeHoseR"},
	]
	for run in runs:
		var x := float(run["x"])
		var off := float(run["off"])
		var path: Array = [
			Vector3(x, c.y - 0.014, _stem_front_z(c.y - 0.014) + off + 0.004),
			Vector3(x, c.y - 0.060, _stem_front_z(c.y - 0.060) + off),
			Vector3(x, 0.470, _stem_front_z(0.470) + off),
			Vector3(x, 0.330, _stem_front_z(0.330) + off),
			Vector3(x, 0.210, _stem_front_z(0.210) + off),
			Vector3(x, 0.150, _stem_front_z(0.150) + off + 0.004),
			Vector3(x, 0.118, tan(RAKE) * 0.118 - 0.042),
		]
		_tube(cables, str(run["name"]), _m_black_d, path, float(run["r"]), 8)
		_cyl(cables, "CableBoot", float(run["r"]) + 0.005, 0.012,
			Transform3D(Basis(Vector3.RIGHT, RAKE + 0.35), Vector3(x, 0.114, tan(RAKE) * 0.114 - 0.036)),
			_m_plastic, -1.0, 12)
	# стяжки жгута
	for y0 in [0.520, 0.400, 0.290, 0.190]:
		var z0: float = _stem_front_z(y0)
		_box(cables, "CableTie", Vector3(0.030, 0.006, 0.006),
			Transform3D(Basis(Vector3.RIGHT, RAKE), Vector3(-0.021, y0, z0 + 0.004)), _m_black_d)
	pass
# ---- руль ---------------------------------------------------------------------
## Переднее крыло в оригинале есть, но пользователь просил его не показывать.
const HAS_FRONT_FENDER := false


func _build_bar(steer: Node3D) -> void:
	var bar := _node(steer, "Bar")
	var c := _bar_local()
	var path: Array = []
	for x in [-BAR_HALF, -0.200, -0.090, 0.0, 0.090, 0.200, BAR_HALF]:
		var lift := 0.006 * absf(float(x)) / BAR_HALF
		var bow := 0.006 * pow(absf(float(x)) / BAR_HALF, 2.0)
		path.append(Vector3(x, c.y + lift, c.z + bow))
	_tube(bar, "Tube", _m_black, path, 0.0115, 12)
	# центральный хомут
	_box(bar, "CenterClamp", Vector3(0.050, 0.026, 0.030),
		Transform3D(Basis.IDENTITY, Vector3(0.0, c.y - 0.004, c.z - 0.004)), _m_steel)
	# грипсы
	for side in [-1.0, 1.0]:
		var sx := float(side)
		var gx := (GRIP_IN + BAR_HALF) * 0.5 * sx
		var gb := Basis(Vector3.BACK, PI * 0.5)
		_cyl(bar, "Grip", 0.0170, BAR_HALF - GRIP_IN,
			Transform3D(gb, Vector3(gx, c.y + 0.006, c.z + 0.006)), _m_rubber, 0.0162, 20)
		_cyl(bar, "GripRing", 0.0192, 0.010,
			Transform3D(gb, Vector3(GRIP_IN * sx + 0.005 * sx, c.y + 0.005, c.z + 0.004)),
			_m_black_d, -1.0, 20)
		_cyl(bar, "GripCap", 0.0175, 0.008,
			Transform3D(gb, Vector3((BAR_HALF + 0.002) * sx, c.y + 0.006, c.z + 0.006)),
			_m_black_d, -1.0, 20)
		# насечки на резине
		for i in 5:
			var ox := (GRIP_IN + 0.012 + i * 0.019) * sx
			_cyl(bar, "GripGroove", 0.0173, 0.003,
				Transform3D(gb, Vector3(ox, c.y + 0.006, c.z + 0.006)), _m_black_d, -1.0, 18)
		# перчатка тормоза: хомут, рычаг, ось, регулировка
		var px := 0.188 * sx
		_box(bar, "Perch", Vector3(0.030, 0.036, 0.044),
			Transform3D(Basis.IDENTITY, Vector3(px, c.y - 0.004, c.z - 0.006)), _m_steel)
		var lever: Array = [
			Vector3(px, c.y - 0.020, c.z - 0.030),
			Vector3(px - 0.004 * sx, c.y - 0.026, c.z - 0.078),
			Vector3(px - 0.012 * sx, c.y - 0.024, c.z - 0.116),
		]
		_sweep(bar, "LeverBlade", _m_alu, lever, [0.011, 0.010, 0.008],
			[0.014, 0.013, 0.011], [0.004, 0.004, 0.004], Vector3.UP)
		_bolt(bar, "LeverPivot", Vector3(px, c.y - 0.012, c.z + 0.002), Vector3.UP, 0.005, 0.012, _m_steel)
		_cyl(bar, "LeverBarrel", 0.007, 0.020,
			Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(px, c.y + 0.002, c.z - 0.048)), _m_steel, -1.0, 12)
	# акселератор справа
	var tx := 0.170
	_box(bar, "ThrottleBody", Vector3(0.034, 0.030, 0.056),
		Transform3D(Basis.IDENTITY, Vector3(tx, c.y + 0.002, c.z - 0.012)), _m_black)
	_box(bar, "ThrottlePaddle", Vector3(0.018, 0.010, 0.038),
		Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(tx, c.y + 0.020, c.z - 0.030)), _m_black_d)
	_cyl(bar, "ThrottlePin", 0.005, 0.014,
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(tx, c.y + 0.010, c.z + 0.002)), _m_steel, -1.0, 10)
	# звонок слева
	_sphere(bar, "BellDome", 0.014, Transform3D(Basis.IDENTITY, Vector3(-0.150, c.y + 0.020, c.z - 0.004)), _m_steel, 16)
	_box(bar, "BellLever", Vector3(0.006, 0.006, 0.026),
		Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(-0.150, c.y + 0.020, c.z + 0.014)), _m_steel)
	# кнопка и разъём на перекладине
	_box(bar, "BarSwitch", Vector3(0.036, 0.020, 0.026),
		Transform3D(Basis.IDENTITY, Vector3(0.060, c.y + 0.012, c.z + 0.014)), _m_black)
	if HAS_FRONT_FENDER:
		_build_front_fender(steer)


func _build_front_fender(steer: Node3D) -> void:
	var fender := _node(steer, "FrontFender")
	var center := Vector3(0.0, -HINGE_Y, AXLE_F - HEAD_Z)
	var pts: Array = []
	var wid: Array = []
	var hei: Array = []
	var rad: Array = []
	for i in 7:
		var t := float(i) / 6.0
		var ang := lerpf(-1.30, 0.10, t)
		pts.append(center + Vector3(0.0, cos(ang) * (R + 0.018), sin(ang) * (R + 0.018)))
		wid.append(0.011)
		hei.append(0.086 - 0.018 * t)
		rad.append(0.004)
	_sweep(fender, "Arch", _m_black, pts, wid, hei, rad, Vector3.RIGHT)


# ---- приборная панель и фара ---------------------------------------------------
func _build_dash(steer: Node3D) -> void:
	# Приборка G4: гранёный корпус-«шлем» 156×92×108 мм, отдельные дисплей,
	# стекло и рамка, козырёк, три кнопки, кронштейн и фара-планка внизу.
	var dash := _node(steer, "Dash")
	var c := _bar_local()
	var cz := c.z + 0.006
	var base := c.y - 0.020

	var ys: Array = [0.598, 0.614, 0.640, 0.664, 0.680, 0.690]
	var wid: Array = [0.140, 0.156, 0.157, 0.147, 0.121, 0.086]
	var dep: Array = [0.100, 0.108, 0.109, 0.101, 0.079, 0.050]
	var zoff: Array = [0.004, 0.004, 0.002, -0.002, -0.008, -0.014]
	var rad: Array = [0.007, 0.007, 0.006, 0.006, 0.005, 0.004]
	var pts: Array = []
	for i in ys.size():
		pts.append(Vector3(0.0, ys[i], cz + zoff[i]))
	_sweep(dash, "Housing", _m_black, pts, wid, dep, rad, Vector3.FORWARD)
	# линия разъёма корпуса и боковые «крылья»
	_sweep(dash, "SplitLine", _m_black_d, [Vector3(0.0, 0.628, cz + 0.003), Vector3(0.0, 0.632, cz + 0.003)],
		[0.158, 0.158], [0.111, 0.111], [0.007, 0.007], Vector3.FORWARD)
	for side in [-1.0, 1.0]:
		_box(dash, "SideWing", Vector3(0.010, 0.036, 0.070),
			Transform3D(Basis(Vector3.RIGHT, -0.16), Vector3(0.079 * float(side), 0.642, cz)), _m_black_d)

	# ---- экран: рамка, прокладка, стекло, дисплей ----------------------------
	var screen := _node(dash, "Screen")
	var tilt := -0.62
	var sb := Basis(Vector3.RIGHT, tilt)
	var center := Vector3(0.0, 0.652, cz + 0.058)
	_box(screen, "Gasket", Vector3(0.136, 0.062, 0.004), Transform3D(sb, center + sb.z * 0.001), _m_plastic)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.124, 0.050)
	var panel := MeshInstance3D.new()
	panel.name = "Display"
	panel.mesh = quad
	panel.material_override = _m_screen
	panel.transform = Transform3D(sb, center)
	screen.add_child(panel)
	# рамка из четырёх митрованных планок
	_box(screen, "FrameTop", Vector3(0.140, 0.009, 0.006),
		Transform3D(sb, center + Vector3(0.0, 0.0305, 0.004)), _m_black_d)
	_box(screen, "FrameBottom", Vector3(0.140, 0.009, 0.006),
		Transform3D(sb, center + Vector3(0.0, -0.0305, 0.004)), _m_black_d)
	for side in [-1.0, 1.0]:
		_box(screen, "FrameSide", Vector3(0.008, 0.071, 0.006),
			Transform3D(sb, center + Vector3(0.066 * float(side), 0.0, 0.004)), _m_black_d)
	var glass := QuadMesh.new()
	glass.size = Vector2(0.126, 0.052)
	var ginst := MeshInstance3D.new()
	ginst.name = "Glass"
	ginst.mesh = glass
	ginst.material_override = _m_glass
	ginst.transform = Transform3D(sb, center + sb.z * 0.0065)
	screen.add_child(ginst)

	# ---- козырёк над экраном ------------------------------------------------
	var visor := _node(dash, "Visor")
	_box(visor, "Hood", Vector3(0.146, 0.007, 0.030),
		Transform3D(Basis(Vector3.RIGHT, -0.42), Vector3(0.0, 0.694, cz + 0.036)), _m_black)
	for side in [-1.0, 1.0]:
		_box(visor, "Cheek", Vector3(0.006, 0.020, 0.026),
			Transform3D(Basis(Vector3.RIGHT, -0.42) * Basis(Vector3.UP, 0.10 * float(side)),
				Vector3(0.070 * float(side), 0.686, cz + 0.038)), _m_black)
	var lb := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -0.408, 0.913), Vector3(0.0, 0.913, 0.408))
	_decal(visor, "Logo", "KUKIRIN", 0.0075, Color(0.82, 0.84, 0.86),
		Transform3D(lb, Vector3(0.0, 0.6975, cz + 0.0375)), 6, true)

	# ---- кнопки --------------------------------------------------------------
	var buttons := _node(dash, "Buttons")
	for i in 3:
		var bx := -0.026 + i * 0.026
		_cyl(buttons, "ButtonRing", 0.0082, 0.0035,
			Transform3D(Basis(Vector3.RIGHT, -0.42), Vector3(bx, 0.6845, cz + 0.020)), _m_black_d, -1.0, 12)
		_cyl(buttons, "Button", 0.0060, 0.0045,
			Transform3D(Basis(Vector3.RIGHT, -0.42), Vector3(bx, 0.6855, cz + 0.020)), _m_plastic, -1.0, 12)
	_cyl(buttons, "PowerButton", 0.0068, 0.0040,
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0785, 0.622, cz + 0.030)), _m_plastic, -1.0, 12)

	# ---- кронштейн крепления к стойке ---------------------------------------
	var mount := _node(dash, "Mount")
	_box(mount, "Bracket", Vector3(0.054, 0.026, 0.044),
		Transform3D(Basis.IDENTITY, Vector3(0.0, base + 0.006, cz - 0.004)), _m_steel)
	_box(mount, "RubberPad", Vector3(0.060, 0.006, 0.050),
		Transform3D(Basis.IDENTITY, Vector3(0.0, base + 0.020, cz - 0.004)), _m_plastic)
	for side in [-1.0, 1.0]:
		_bolt(mount, "MountBolt", Vector3(0.022 * float(side), base + 0.002, cz + 0.006),
			Vector3.UP, 0.0045, 0.014, _m_steel)

	_build_headlight_assembly(dash, Vector3(0.0, base + 0.020, cz - 0.062))
	# логотип на передней грани корпуса
	_decal(dash, "DashBrand", "KUKIRIN", 0.009, Color(0.66, 0.68, 0.70),
		Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, base + 0.064, cz - 0.052)))
func _build_headlight(steer: Node3D) -> void:
	# фара уже встроена в корпус приборки; узел оставлен для иерархии GLB.
	var lamp := _node(steer, "Headlight")
	var c := _bar_local()
	lamp.position = Vector3(0.0, c.y - 0.014, c.z - 0.028)


func _build_headlight_assembly(parent: Node3D, pos: Vector3) -> void:
	# Фара-планка G4: посадочное гнездо, хромированный отражатель, шесть диодов,
	# прозрачная линза и ободок.
	var lamp := _node(parent, "Headlight")
	_box(lamp, "Recess", Vector3(0.126, 0.034, 0.014),
		Transform3D(Basis.IDENTITY, pos + Vector3(0.0, 0.0, 0.004)), _m_black_d)
	_box(lamp, "Reflector", Vector3(0.114, 0.024, 0.004),
		Transform3D(Basis.IDENTITY, pos + Vector3(0.0, 0.0, -0.002)), _m_steel)
	for i in 6:
		var x := -0.045 + i * 0.018
		_box(lamp, "Led", Vector3(0.013, 0.014, 0.004),
			Transform3D(Basis.IDENTITY, pos + Vector3(x, 0.0, -0.004)), _m_lamp)
	var lens := QuadMesh.new()
	lens.size = Vector2(0.118, 0.028)
	var lin := MeshInstance3D.new()
	lin.name = "Lens"
	lin.mesh = lens
	lin.material_override = _m_lamp
	lin.transform = Transform3D(Basis(Vector3.RIGHT, PI), pos + Vector3(0.0, 0.0, -0.007))
	lamp.add_child(lin)
	_box(lamp, "BezelTop", Vector3(0.124, 0.005, 0.010),
		Transform3D(Basis.IDENTITY, pos + Vector3(0.0, 0.016, -0.008)), _m_steel)
	_box(lamp, "BezelBottom", Vector3(0.124, 0.005, 0.010),
		Transform3D(Basis.IDENTITY, pos + Vector3(0.0, -0.016, -0.008)), _m_steel)
	for side in [-1.0, 1.0]:
		_box(lamp, "BezelSide", Vector3(0.005, 0.037, 0.010),
			Transform3D(Basis.IDENTITY, pos + Vector3(0.061 * float(side), 0.0, -0.008)), _m_steel)
