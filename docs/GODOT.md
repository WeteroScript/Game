# Godot-порт: технические заметки

Проект `godot/` — самостоятельная игра на Godot 4.3 (GDScript). Unity-проект в `Assets/` оставлен
как справочник по логике и ТТХ, но в сборке не участвует.

## 1. Почему Godot

Unity требует лицензию (`.ulf`) даже для CI-сборки: GameCI без `UNITY_LICENSE` не активируется,
Unity Build Automation требует аккаунт и настройку облачного билда. Godot 4 собирает Android-APK
на обычном GitHub-runner'е без единого секрета: движок и шаблоны экспорта лежат в открытом доступе,
Android SDK ставится за минуту.

## 2. Соответствие классов

| Unity (C#) | Godot (GDScript) |
|---|---|
| `GameConfig` / `VehicleTuning` | `scripts/game_config.gd` (`GameConfig`) |
| `ScooterSpec` | `scripts/scooter_spec.gd` |
| `ScooterController` (Rigidbody + WheelCollider) | `scripts/scooter.gd` (`VehicleBody3D` + `VehicleWheel3D`) |
| `WheelieController` | `scripts/wheelie.gd` |
| `ScooterFactory` / `MeshUtil` | `scripts/scooter_model.gd` (+ `rider_model.gd` — райдер) |
| `TrackMap` / `CityMap` / `WorldBuilder` | `scripts/world_builder.gd` |
| `CameraRig` | `scripts/camera_rig.gd` |
| `TrickSystem` | `scripts/trick_system.gd` |
| `Hud` / `TouchControls` / `HoldButton` | `scripts/hud.gd` |
| `MenuScreen` / `UiFactory` | `scripts/menu_screen.gd` / `scripts/ui_factory.gd` |
| `InputController` | `scripts/input_state.gd` |
| `GameRoot` / `GameBootstrap` | `scripts/game.gd` + `scenes/main.tscn` |
| `ScooterAudio` | `scripts/scooter_audio.gd` (синтез, без файлов) |

## 3. Физика самоката

`Scooter extends VehicleBody3D`:

* два `VehicleWheel3D` дают подвеску, точки контакта и рулевое;
* тяга, тормоза, рекуперация и аэродинамика считаются вручную через `apply_force` /
  `apply_torque` — встроенный двигатель Godot (`use_as_traction`) не позволяет раздельно
  управлять передним и задним тормозом и рекуперацией;
* баланс крена/тангажа — ПД-регуляторы моментами (`apply_torque`), как в Unity-версии;
* наклон трассы учитывается через нормаль под колёсами (луч вниз из позиции колеса);
* падения: loop out при угле > 74°, падение на бок при крене > 62°, жёсткое приземление > 7.5 м/с
  по вертикали → падение и авто-респаун через 2.4 с.

Важные числа (полный список — в `game_config.gd`):

| Параметр | Значение |
|---|---|
| Гравитация | 14 м/с² (`physics/3d/default_gravity`) |
| Частота физики | 60 Гц |
| Подвеска | travel 0.09 м, stiffness 160, max force 22000, relax 3.4, compress 2.6 |
| Аэродинамика | 0.160 (сила ∝ v²) |
| Качение | 0.5 |
| Руление | 2 → 22 км/ч интерполяция, 0.42 с, макс 26° (зависит от скорости) |
| Крен | момент 260, жёсткость 46, демпфирование 520 |
| Тангаж | 120 / 26 / 380, рыскание 6 |
| Тормоза | передний/задний 0.85 доли, 30/55 Н·м лимит, −26 Н·м рекуперация |
| Мотор | КПД 0.80, 260 Вт «на градус газа», батарея 0.6 Вт·ч/с на нагрузку |

## 4. Что проверяет CI

1. `godot --import` — импорт ресурсов.
2. `godot --check-only --script res://scripts/<file>.gd` для **каждого** скрипта — синтаксис и
   разрешение классов.
3. `godot --headless --fixed-fps 60 -- --smoke` — автотест `Game._tick_smoke()`:
   * фаза 1: G4 на прямой трассе — разгон, удержание вилли, принудительное падение;
   * фаза 2: F3 Pro Max в городе, AWD ⇄ RWD, езда до конца таймера Freestyle;
   * фаза 3: экран результатов, затем `SMOKE OK` с числами (скорость, дистанция, очки, батарея).
   Падение сборки — если в логе есть `SCRIPT ERROR` / `Parse Error` / `Invalid call` или нет `SMOKE OK`.
4. Экспорт APK, загрузка артефакта, а на `main` — публикация релиза с APK.

По логам автотеста уже поймано и исправлено: конфликт сигнала и переменной `crashed`,
знак демпфирования крена, жёсткость подвески (Bullet умножает её на массу шасси),
коллизия корпуса, цеплявшая асфальт, endo в воздухе, падение за край карты.

Первые прогоны могут потребовать подстройки — например, если версия шаблонов экспорта не совпадёт
с версией движка (`GODOT_VERSION` в workflow) или Android SDK попросит другую build-tools.

## 5. Скриншоты и как они снимаются

В workflow есть отдельная задача `screenshots` (не блокирует APK):

1. `godot --headless --import` — импорт.
2. `xvfb-run godot --rendering-driver opengl3 --rendering-method gl_compatibility -- --shot`
   — игра сама расставляет камеру и сохраняет PNG в `SHOT_DIR`.
3. Кадры: `g4_*` и `f3_*` — пять ракурсов каждого самоката (спереди, сбоку, сзади, руль,
   колесо), `menu.png`, `hud_drive.png`, `hud_wheelie.png`.
4. Задача коммитит картинки в ветку `ci-screenshots` (force-push), чтобы их можно было
   открыть с телефона.

## 6. Что осталось за кадром

* Ворота-чекпоинты Time Attack: в Godot-версии режим считает очки за дистанцию и время.
* Модели процедурные; для замены на готовый меш достаточно положить `.glb` в `godot/models/`
  и вернуть его из `ScooterModel.build()`.
* Звук синтетический: замена на записи — положить `.ogg` в `godot/audio/` и отдать его
  `AudioStreamPlayer3D` вместо сгенерированных `AudioStreamWAV`.
