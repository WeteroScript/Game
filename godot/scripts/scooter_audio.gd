## Процедурный звук самоката: вой мотора, шум шин, ветер, удар при падении
## и «дзынь» за трюк. Никаких внешних файлов — сэмплы синтезируются на старте
## (аналог Assets/Scripts/Audio/ScooterAudio.cs из Unity-версии).
class_name ScooterAudio
extends Node3D

const MIX_RATE := 22050
const MOTOR_HZ := 110.0
const MOTOR_FRAMES := 11025 # ровно 55 периодов — петля без щелчка

var motor_player: AudioStreamPlayer3D
var wind_player: AudioStreamPlayer3D
var tire_player: AudioStreamPlayer3D
var impact_player: AudioStreamPlayer3D
var chime_player: AudioStreamPlayer3D

var max_speed := 70.0
var enabled := true

var _level := 0.0

# Сэмплы синтезируются один раз на весь запуск: у каждого самоката свой
# AudioStreamPlayer, но данные общие (иначе старт заезда тормозит на 100+ мс).
static var _stream_cache := {}


static func create(max_speed_kmh: float) -> ScooterAudio:
	var audio := ScooterAudio.new()
	audio.name = "Audio"
	audio.max_speed = maxf(10.0, max_speed_kmh)
	return audio


func _ready() -> void:
	motor_player = _player(_cached("motor", _motor_stream), -22.0)
	wind_player = _player(_cached("wind", _wind_stream), -45.0)
	tire_player = _player(_cached("tire", _tire_stream), -45.0)
	impact_player = _player(_cached("impact", _impact_stream), -12.0)
	chime_player = _player(_cached("chime", _chime_stream), -10.0)

	motor_player.play()
	wind_player.play()
	tire_player.play()


func _cached(key: String, builder: Callable) -> AudioStream:
	if not _stream_cache.has(key):
		_stream_cache[key] = builder.call()
	return _stream_cache[key]


func _wind_stream() -> AudioStreamWAV:
	return _noise_stream(0.5, 0.22, 0.05)


func _tire_stream() -> AudioStreamWAV:
	return _noise_stream(0.5, 0.06, 0.55)


func _player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 8.0
	player.max_db = 3.0
	player.max_distance = 70.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(player)
	return player


# ---- управление звуком -------------------------------------------------------
func update_state(speed_kmh: float, throttle: float, grounded: bool, crashed: bool) -> void:
	if not enabled or motor_player == null:
		return

	var speed_ratio := clampf(speed_kmh / max_speed, 0.0, 1.0)
	var load := clampf(throttle * 0.75 + speed_ratio * 0.55, 0.0, 1.0)

	if crashed:
		motor_player.volume_db = lerpf(motor_player.volume_db, -40.0, 0.12)
		wind_player.volume_db = lerpf(wind_player.volume_db, -45.0, 0.12)
		tire_player.volume_db = lerpf(tire_player.volume_db, -45.0, 0.12)
		return

	# Мотор: чем быстрее и чем больше газа — тем выше и громче.
	motor_player.pitch_scale = clampf(0.55 + speed_ratio * 1.85 + throttle * 0.14, 0.4, 3.2)
	motor_player.volume_db = lerpf(-32.0, -8.0, load)

	wind_player.pitch_scale = 0.9 + speed_ratio * 0.35
	wind_player.volume_db = lerpf(-45.0, -14.0, pow(speed_ratio, 1.6))

	var tire_db := lerpf(-40.0, -17.0, pow(speed_ratio, 1.2))
	tire_player.volume_db = (tire_db if grounded else -45.0)
	tire_player.pitch_scale = 0.8 + speed_ratio * 0.6

	_level = load


func play_impact() -> void:
	if impact_player != null:
		impact_player.volume_db = -6.0
		impact_player.play()


func play_chime() -> void:
	if chime_player != null:
		chime_player.play()


# ---- синтез сэмплов ----------------------------------------------------------
func _make_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var frames := samples.size()
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var value := clampf(samples[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(round(value * 32000.0)))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frames
	return stream


## Пилообразный вой мотора с гармониками — узнаваемый звук электросамоката.
func _motor_stream() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(MOTOR_FRAMES)
	for i in MOTOR_FRAMES:
		var t := float(i) / float(MIX_RATE)
		var phase := fmod(t * MOTOR_HZ, 1.0)
		var saw := phase * 2.0 - 1.0
		var value := saw * 0.42
		value += sin(t * TAU * MOTOR_HZ * 2.0) * 0.22
		value += sin(t * TAU * MOTOR_HZ * 3.0) * 0.10
		value += sin(t * TAU * MOTOR_HZ * 7.0) * 0.05
		value += randf_range(-0.02, 0.02)
		samples[i] = value * 0.7
	return _make_wav(samples, true)


## Шум с однополюсным фильтром: ветер (низкая частота среза) или шины (высокая).
func _noise_stream(duration: float, smooth: float, brightness: float) -> AudioStreamWAV:
	var frames := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var lp := 0.0
	var lp2 := 0.0
	for i in frames:
		var white := randf_range(-1.0, 1.0)
		lp = lerpf(lp, white, smooth)
		# Яркость — это доля «сухого» шума поверх сглаженного.
		lp2 = lerpf(lp2, white, clampf(brightness, 0.01, 1.0))
		var value := lerpf(lp, lp2, brightness)
		# Плавные края, чтобы петля не щёлкала.
		var edge := minf(1.0, minf(float(i), float(frames - i)) / 400.0)
		samples[i] = value * 0.55 * edge
	return _make_wav(samples, true)


func _impact_stream() -> AudioStreamWAV:
	var frames := int(0.45 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	for i in frames:
		var t := float(i) / float(MIX_RATE)
		var envelope := exp(-t * 11.0)
		var thump := sin(t * TAU * 58.0) * exp(-t * 7.0) * 0.85
		var crunch := randf_range(-1.0, 1.0) * envelope * 0.5
		samples[i] = clampf(thump + crunch, -1.0, 1.0) * 0.9
	return _make_wav(samples, false)


func _chime_stream() -> AudioStreamWAV:
	var frames := int(0.35 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	for i in frames:
		var t := float(i) / float(MIX_RATE)
		var glide := 1.0 + t * 0.25
		var a := sin(t * TAU * 880.0 * glide) * exp(-t * 8.0)
		var b := sin(t * TAU * 1320.0 * glide) * exp(-t * 11.0) * 0.55
		samples[i] = (a + b) * 0.5
	return _make_wav(samples, false)
