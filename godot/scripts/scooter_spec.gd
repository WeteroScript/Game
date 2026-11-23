## Паспортные и игровые данные самоката. Оба самоката бесплатны и доступны сразу.
## Перенесено из Assets/Scripts/Vehicle/ScooterSpec.cs, реальные характеристики — docs/VEHICLES.md.
class_name ScooterSpec
extends RefCounted

var id := "g4"
var display_name := "KugooKirin G4"
var tagline := "2026 · задний привод"
var drive_description := "RWD — один задний хаб-мотор"

# ---- Реальные характеристики (для карточек в меню и HUD) --------------------
var mass_kg := 37.0
var max_load_kg := 120.0
var power_watts := 2000.0
var peak_power_watts := 2400.0
var motor_count := 1
var top_speed_kmh := 70.0
var range_km := 75.0
var battery_voltage := 60.0
var battery_amp_hours := 20.0
var wheel_inches := 11.0
var battery_text := "60V 20Ah"
var brakes_text := "Передний + задний дисковые"
var suspension_text := "Регулируемая двойная"
var features_text := "LCD · фара · стоп-сигнал · поворотники · ключ"

# ---- Симуляция --------------------------------------------------------------
var wheel_radius := 0.14
var wheel_base := 1.06
var deck_length := 0.51
## Высота настила над осями колёс (для модели).
var deck_height := 0.10
## Цвет рычагов подвески (на F3 они оранжевые, на G4 — в цвет рамы).
var suspension_color := Color(0.45, 0.47, 0.50)
## Надпись на стойке и деке.
var brand_text := "KUGOO"
## Приподнятая задняя площадка на кронштейне — она есть на обоих фото.
var has_rear_step := true
## Переднее крыло: у G4 его нет, у F3 — есть.
var front_fender := false
var deck_width := 0.22

var battery_wh := 1200.0
var gear_top_speeds_kmh: Array = [20.0, 40.0, 70.0]
var supports_awd_toggle := false

var power_per_motor_watts := 2000.0
var max_traction_force_per_motor := 700.0
var motor_ramp_rate := 4.0
var torque_ceiling := 120.0

var max_brake_torque := 60.0
var regen_brake_torque := 14.0
var regen_efficiency := 0.55

var grip_road := 1.8
var grip_off_road := 0.95
var steer_angle_max := 26.0

# ---- Вилли ------------------------------------------------------------------
var wheelie_lift_time := 0.8
var wheelie_balance_gain := 130.0
var wheelie_balance_damping := 8.0
var wheelie_max_torque := 460.0
var wheelie_equilibrium := 38.0

# ---- Внешний вид ------------------------------------------------------------
var frame_color := Color(0.09, 0.09, 0.10)
var accent_color := Color(0.85, 0.85, 0.87)
var off_road_tires := true
var orange_accents := false


func gear_count() -> int:
	return gear_top_speeds_kmh.size()


func gear_top_speed_kmh(gear: int) -> float:
	if gear_top_speeds_kmh.is_empty():
		return top_speed_kmh
	var index := clampi(gear, 0, gear_top_speeds_kmh.size() - 1)
	return float(gear_top_speeds_kmh[index])


static func create_g4() -> ScooterSpec:
	var s := ScooterSpec.new()
	s.id = "g4"
	s.display_name = "KugooKirin G4"
	s.tagline = "2026 · задний привод"
	s.drive_description = "RWD — один задний хаб-мотор"
	s.mass_kg = 37.0
	s.max_load_kg = 120.0
	s.power_watts = 2000.0
	s.peak_power_watts = 2400.0
	s.motor_count = 1
	s.top_speed_kmh = 70.0
	s.range_km = 75.0
	s.battery_voltage = 60.0
	s.battery_amp_hours = 20.0
	s.wheel_inches = 11.0
	s.battery_text = "60V 20Ah"
	s.brakes_text = "Передний + задний дисковые"
	s.suspension_text = "Регулируемая двойная"
	s.features_text = "LCD · фара · стоп-сигнал · поворотники · ключ"

	s.wheel_radius = 0.5 * 11.0 * 0.0254
	s.wheel_base = 1.06
	s.deck_length = 0.51
	s.deck_height = 0.10
	s.deck_width = 0.22
	s.battery_wh = s.battery_voltage * s.battery_amp_hours
	s.gear_top_speeds_kmh = [20.0, 40.0, 70.0]
	s.supports_awd_toggle = false

	s.power_per_motor_watts = 2000.0
	s.max_traction_force_per_motor = 320.0
	s.motor_ramp_rate = 4.2
	s.torque_ceiling = 45.0
	s.max_brake_torque = 62.0
	s.regen_brake_torque = 8.0
	s.grip_road = 1.85
	s.grip_off_road = 0.95
	s.steer_angle_max = 26.0

	# RWD: легче поднять, сложнее удержать баланс.
	s.wheelie_lift_time = 0.75
	s.wheelie_balance_gain = 700.0
	s.wheelie_balance_damping = 220.0
	s.wheelie_max_torque = 420.0
	s.wheelie_equilibrium = 37.0

	# По фото: серый gunmetal с оранжевыми шевронами и надписями.
	s.frame_color = Color(0.33, 0.35, 0.38)
	s.accent_color = Color(0.93, 0.45, 0.09)
	s.suspension_color = Color(0.36, 0.38, 0.41)
	s.brand_text = "KUKIRIN G4"
	s.front_fender = false
	s.off_road_tires = true
	s.orange_accents = false
	return s


static func create_f3_pro_max() -> ScooterSpec:
	var s := ScooterSpec.new()
	s.id = "f3"
	s.display_name = "Kugoo F3 Pro Max"
	s.tagline = "полный привод AWD"
	s.drive_description = "AWD — передний + задний моторы, переключение в RWD"
	s.mass_kg = 32.5
	s.max_load_kg = 130.0
	s.power_watts = 2200.0
	s.peak_power_watts = 2400.0
	s.motor_count = 2
	s.top_speed_kmh = 68.0
	s.range_km = 70.0
	s.battery_voltage = 52.0
	s.battery_amp_hours = 23.4
	s.wheel_inches = 10.0
	s.battery_text = "52V 23.4Ah"
	s.brakes_text = "Дисковые + электронный тормоз"
	s.suspension_text = "Передняя и задняя амортизация"
	s.features_text = "LCD · AWD/RWD · фара · стоп-сигнал · габариты"

	s.wheel_radius = 0.5 * 10.0 * 0.0254
	s.wheel_base = 1.0
	s.deck_length = 0.48
	s.deck_height = 0.095
	s.deck_width = 0.21
	s.battery_wh = s.battery_voltage * s.battery_amp_hours
	s.gear_top_speeds_kmh = [30.0, 51.0, 66.0]
	s.supports_awd_toggle = true

	s.power_per_motor_watts = 1100.0
	s.max_traction_force_per_motor = 150.0
	s.motor_ramp_rate = 5.0
	s.torque_ceiling = 40.0
	s.max_brake_torque = 58.0
	s.regen_brake_torque = 7.0
	s.grip_road = 1.9
	s.grip_off_road = 1.0
	s.steer_angle_max = 27.0

	# AWD: передний мотор тянет вниз — поднимать тяжелее, но баланс стабильнее.
	s.wheelie_lift_time = 0.8
	s.wheelie_balance_gain = 780.0
	s.wheelie_balance_damping = 240.0
	s.wheelie_max_torque = 400.0
	s.wheelie_equilibrium = 39.0

	# По фото: чёрный корпус, оранжевые рычаги подвески и кольца на дисках.
	s.frame_color = Color(0.075, 0.075, 0.085)
	s.accent_color = Color(0.96, 0.47, 0.10)
	s.suspension_color = Color(0.88, 0.44, 0.11)
	s.brand_text = "KUGOO"
	s.front_fender = true
	s.off_road_tires = false
	s.orange_accents = true
	return s


static func all() -> Array[ScooterSpec]:
	var result: Array[ScooterSpec] = []
	result.append(create_g4())
	result.append(create_f3_pro_max())
	return result


static func get_by_id(spec_id: String) -> ScooterSpec:
	for spec in all():
		if spec.id == spec_id:
			return spec
	return create_g4()
