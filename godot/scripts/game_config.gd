## Глобальные константы геймплея и общая настройка физики.
## Значения перенесены из Unity-версии (Assets/Scripts/Core/GameConfig.cs),
## пояснения — в docs/TECHNICAL.md.
class_name GameConfig
extends RefCounted

enum GameMode { FREE_RIDE, TIME_ATTACK, FREESTYLE }
enum MapId { STRAIGHT_TRACK, CITY }
enum DriveMode { RWD, AWD }

const PRODUCT_NAME := "Kugoo Freeride"
const BUNDLE_ID := "com.weteroscript.kugoowheelie"
const VERSION := "1.0.0"

## Гравитация в Godot задаётся в project.godot (3d/default_gravity = 14).
const GRAVITY := 14.0
const TARGET_FPS := 60
const FREESTYLE_DURATION := 90.0
const TIME_ATTACK_LIMIT := 300.0
const RESPAWN_DELAY := 2.4

## Расход батареи сжат для геймплея: 1 = реализм (полный заряд ~45 минут),
## 6 = заезд сажает батарею примерно за 6–7 минут.
const BATTERY_DRAIN_MULTIPLIER := 6.0

const COUNTDOWN_SECONDS := 3.0

# ---- Подвеска ---------------------------------------------------------------
const SUSPENSION_TRAVEL := 0.09
## Bullet умножает жёсткость пружины на массу шасси, поэтому для 37-килограммового
## самоката 38 — это «мягкий диван»: подвеска пробивалась и тело ложилось на асфальт.
## 160 даёт ~50 % хода под весом самоката.
const SUSPENSION_STIFFNESS := 160.0
const SUSPENSION_MAX_FORCE := 22000.0
const DAMPING_COMPRESSION := 2.6
const DAMPING_RELAXATION := 3.4

# ---- Сопротивление движению ------------------------------------------------
const ROLLING_RESISTANCE_TORQUE := 0.5
const AIR_DRAG_COEFFICIENT := 0.160

# ---- Руль -------------------------------------------------------------------
const STEER_FALLOFF_START := 2.0
const STEER_FALLOFF_END := 22.0
const STEER_MIN_FACTOR := 0.42
const REAR_STEER_FACTOR := 0.3

# ---- Баланс (искусственная устойчивость) ------------------------------------
const ROLL_STABILITY_GAIN := 260.0
const ROLL_STABILITY_DAMPING := 46.0
const ROLL_MAX_TORQUE := 520.0
const LEAN_INTO_TURN_MAX_ANGLE := 21.0
const LEAN_INTO_TURN_FULL_SPEED := 14.0

const PITCH_STABILITY_GAIN := 120.0
const PITCH_STABILITY_DAMPING := 26.0
const PITCH_MAX_TORQUE := 380.0
const YAW_DAMPING := 6.0

# ---- Тормоза ----------------------------------------------------------------
const REAR_BRAKE_SHARE := 0.85
const FULL_FRONT_BRAKE_THRESHOLD := 0.85
const ENDO_RISK_SPEED_KMH := 30.0
const ENDO_RISK_TORQUE := 55.0
const ENDO_CRASH_ANGLE := -26.0

# ---- Аварии -----------------------------------------------------------------
const LOOP_OUT_ANGLE := 74.0
const FALL_ROLL_ANGLE := 62.0
const HARD_IMPACT_SPEED := 7.5

# ---- Батарея ----------------------------------------------------------------
const MOTOR_EFFICIENCY := 0.80
const MOTOR_SPINUP_LOSS_WATTS := 260.0
const IDLE_DRAIN_WATTS := 0.6
const LOW_BATTERY_PERCENT := 8.0
const LOW_BATTERY_POWER_SCALE := 0.4

# ---- Камера -----------------------------------------------------------------
const CAMERA_DISTANCE := 3.9
const CAMERA_HEIGHT := 1.55
const CAMERA_LOOK_AHEAD := 2.4
const CAMERA_FOV_BASE := 62.0
const CAMERA_FOV_MAX := 74.0
