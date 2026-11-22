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
| `ScooterFactory` / `MeshUtil` | `scripts/scooter_model.gd` |
| `TrackMap` / `CityMap` / `WorldBuilder` | `scripts/world_builder.gd` |
| `CameraRig` | `scripts/camera_rig.gd` |
| `TrickSystem` | `scripts/trick_system.gd` |
| `Hud` / `TouchControls` / `HoldButton` | `scripts/hud.gd` |
| `MenuScreen` / `UiFactory` | `scripts/menu_screen.gd` / `scripts/ui_factory.gd` |
| `InputController` | `scripts/input_state.gd` |
| `GameRoot` / `GameBootstrap` | `scripts/game.gd` + `scenes/main.tscn` |
| `ScooterAudio` | пока не портирован |

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
| Подвеска | travel 0.09 м, stiffness 38, damping 22000, relax 2.6, compress 3.4 |
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
3. `godot --headless --quit-after 180` — 3 секунды игры; в логе не должно быть
   `SCRIPT ERROR` / `Parse Error` / `Invalid call`. Это ловит ошибки, которые не видны парсеру
   (несуществующие свойства, неверные типы аргументов).
4. Экспорт APK и загрузка артефакта.

Первые прогоны могут потребовать подстройки — например, если версия шаблонов экспорта не совпадёт
с версией движка (`GODOT_VERSION` в workflow) или Android SDK попросит другую build-tools.

## 5. Что осталось за кадром

* Звук мотора/ветра (`ScooterAudio.cs` в Unity) не портирован.
* Ворота-чекпоинты Time Attack: в Godot-версии режим считает очки за дистанцию и время.
* Модели процедурные; для замены на готовый меш достаточно положить `.glb` в `godot/models/`
  и вернуть его из `ScooterModel.build()`.
