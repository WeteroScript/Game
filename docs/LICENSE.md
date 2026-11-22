# Лицензия Unity и GitHub-секреты (в том числе без своего ПК)

Сборка APK идёт в **GitHub Actions** — свой компьютер для сборки не нужен.
Но Unity как редактор требует лицензию, поэтому один раз нужно получить файл лицензии `.ulf`
и положить его в секреты репозитория.

## 1. Что это за три секрета

| Секрет | Что это | Где взять |
|---|---|---|
| `UNITY_EMAIL` | e-mail вашего **бесплатного** Unity ID | регистрация на <https://id.unity.com> (работает с телефона) |
| `UNITY_PASSWORD` | пароль Unity ID | там же. **Только буквы и цифры**, без спецсимволов — GameCI с ними ломается |
| `UNITY_LICENSE` | содержимое файла `Unity_lic.ulf` | создаётся Unity Hub (см. ниже) |

Unity Personal бесплатна. Платить ничего не нужно.

## 2. Получить `.ulf` — три пути

### Путь A (официальный, самый надёжный) — любой компьютер на 10 минут

Unity Editor ставить **не нужно**, нужен только Unity Hub (~150 МБ).
Подойдёт ноутбук друга/родственника, школьный компьютер, интернет-кафе.

1. Поставить **Unity Hub**: <https://unity.com/download>.
2. Войти в тот же Unity ID, что будет в секретах.
3. `Unity Hub → Preferences (⚙) → Licenses → Add → Get a free personal license`.
4. Забрать файл лицензии:

   | ОС | Путь |
   |---|---|
   | Windows | `C:\ProgramData\Unity\Unity_lic.ulf` |
   | macOS | `/Library/Application Support/Unity/Unity_lic.ulf` |
   | Linux | `~/.local/share/unity3d/Unity/Unity_lic.ulf` |

   Папки скрытые — включите показ скрытых файлов. Лицензия не привязана к ОС: активировали на Windows —
   собираете на Ubuntu.
5. Скопировать `.ulf` на телефон (Telegram «Избранное», почта, облако) **или** сразу открыть и скопировать текст.
6. **Выйти из аккаунта в Unity Hub** (Sign out). В Hub 3.7+ для Personal это и есть «вернуть лицензию»:
   иначе локальная машина держит место, и CI не сможет активироваться.

### Путь B (совсем нет ПК) — облачный рабочий стол в браузере телефона

**Готовая, автоматизированная инструкция: [`LICENSE-PHONE.md`](LICENSE-PHONE.md).**
Коротко, что сделано в репозитории, чтобы не набирать команды на телефоне:

| Файл | Зачем |
|---|---|
| `.devcontainer/devcontainer.json` | Codespace сам поднимает VNC-десктоп (порт 6080) и запускает Unity Hub |
| `tools/license/install-unityhub.sh` | скачивает и распаковывает Unity Hub (AppImage) |
| `tools/license/start-unityhub.sh` | открывает Hub в десктопе (в т.ч. после «сна» Codespace) |
| `tools/license/set-secrets.sh` | находит `.ulf` и пишет три секрета через `gh` |

Порядок в двух словах: репозиторий → **Code → Codespaces → Create codespace** (ветка с этими файлами) →
порт **6080** в браузере (пароль VNC `unity`) → в Hub `Preferences → Licenses → Add → Get a free personal
license` → в терминале `bash tools/license/set-secrets.sh ваш@e-mail` → **Sign out** из Hub → удалить Codespace.

Ограничения: бесплатная квота Codespaces — 120 core-часов и 15 ГБ в месяц (машина на 2 ядра = 60 часов),
Codespace засыпает через 30 минут простоя. Лицензия Unity Personal привязана к аккаунту, а не к машине —
поэтому «облачный» `.ulf` для GameCI ничем не хуже локального.

### Путь C (вообще без лицензии) — Unity Build Automation

Unity умеет собирать проект в своём облаке, авторизуясь по аккаунту в браузере
(<https://cloud.unity.com> → Build Automation, подключить GitHub-репозиторий, цель Android).
Это отступление от требований ТЗ (там нужен GameCI), но это единственный сценарий, где `.ulf` не нужен вовсе.
GitHub Actions при этом не используется.

## 3. Что НЕ работает

Старый способ «сгенерировать `.alf` в CI → загрузить на license.unity3d.com/manual → получить `.ulf`»
**больше не поддерживается**: action `game-ci/unity-request-activation-file` теперь сразу завершается ошибкой
`This action is no longer supported…` (проверено по исходникам action, 2026).
Не тратьте на него время — нужен Unity Hub.

## 4. Куда вписать секреты

`GitHub → репозиторий → Settings → Secrets and variables → Actions → New repository secret`:

1. `UNITY_EMAIL` — почта Unity ID.
2. `UNITY_PASSWORD` — пароль (без спецсимволов).
3. `UNITY_LICENSE` — **всё содержимое** `.ulf` (это XML; начинается с `<?xml version="1.0"…`).
   Копируйте целиком, включая последнюю строку `</root>`.

Затем: влить ветку в `main` (или `Actions → Build Android APK → Run workflow`) → дождаться зелёного прогона →
`Artifacts → AndroidBuild → KugooFreeride.apk`.

## 5. Если сборка падает на активации

| Сообщение в логе | Причина | Что делать |
|---|---|---|
| `No valid Unity license` / `License is not activated` | секрет `UNITY_LICENSE` пустой или обрезан | перекопировать `.ulf` целиком |
| `Failed to activate with the specified license` + «seat» | место Personal-лицензии занято локальной машиной | выйти из Unity Hub (Sign out) и перезапустить сборку |
| `Invalid credentials` | неверный e-mail/пароль | проверить вход на id.unity.com |
| ошибка авторизации при спецсимволах в пароле | известное ограничение GameCI | сменить пароль на буквы+цифры |
| `A license is already in use` | параллельные сборки | не запускать два билда одновременно |

Лицензия Personal позволяет одну активную сборку за раз; наш workflow дополнительно отменяет
предыдущие прогоны (`concurrency`).

## 6. Безопасность

* Секреты вводите **только** в GitHub → Settings → Secrets. Они шифруются и не видны никому, включая меня.
* Не присылайте `.ulf`, пароль или e-mail в чат — в них нет необходимости.
* Файл `.ulf` привязан к вашему аккаунту; передавать его третьим лицам нельзя.
