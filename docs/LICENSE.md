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

### Путь B (полностью с телефона) — облачный рабочий стол в браузере

Если совсем нет доступа к чужому компьютеру, Unity Hub можно запустить в облаке и управлять им из браузера
телефона. Дольше и капризнее, но реально:

1. Откройте репозиторий на github.com → кнопка **Code** → вкладка **Codespaces** → **Create codespace**.
   Бесплатный лимит GitHub даёт несколько десятков часов в месяц.
2. В терминале Codespace поднимите простой рабочий стол с VNC:

   ```bash
   sudo apt-get update
   sudo apt-get install -y xfce4 x11vnc novnc websockify unzip libfuse2 wget
   x11vnc -display :1 -nopw -listen localhost -xkb -forever &
   websockify --web=/usr/share/novnc 6080 localhost:5900 &
   # второй терминал:
   Xvfb :1 -screen 0 1600x900x24 &
   DISPLAY=:1 startxfce4 &
   ```
3. В портах Codespace сделайте порт `6080` публичным и откройте `https://<codespace>-6080.app.github.dev/vnc.html`.
   Это рабочий стол в браузере телефона.
4. Скачайте и запустите Unity Hub (Linux AppImage с <https://unity.com/download>):

   ```bash
   wget -O ~/UnityHub.AppImage "https://public-cdn.cloud.unity3d.com/hub/prod/UnityHub.AppImage"
   chmod +x ~/UnityHub.AppImage
   DISPLAY=:1 ~/UnityHub.AppImage --no-sandbox
   ```
5. Дальше — как в пути A: вход, `Preferences → Licenses → Add → Get a free personal license`,
   затем файл `~/.local/share/unity3d/Unity/Unity_lic.ulf` (в терминале: `cat ~/.local/share/unity3d/Unity/Unity_lic.ulf`).

> Честно: путь B занимает 20–40 минут и требует аккуратности. Если есть возможность взять чужой
> ноутбук на 10 минут — путь A проще.

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
