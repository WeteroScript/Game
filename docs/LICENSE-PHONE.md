# Лицензия Unity и APK с одного телефона (GitHub Codespaces)

Полный путь «нет ни ПК, ни ноутбука»: облачный Linux с рабочим столом прямо в браузере телефона.
В нём один раз запускается Unity Hub, выпускается файл лицензии `.ulf`, и дальше всё делает GitHub Actions.

- **Время:** 40–60 минут, из них 15 минут — ожидание установки.
- **Деньги:** 0. Codespaces на личном аккаунте даёт 120 core-часов в месяц (машина 2 ядра = 60 часов)
  и 15 ГБ хранилища. Вся процедура съедает ~1 час и ~5 ГБ.
- **Что нужно:** телефон с браузером, аккаунт GitHub, бесплатный аккаунт Unity ID.
- **Что НЕ нужно:** Unity Editor, Docker, Android SDK, компьютер.

> Секрет `UNITY_LICENSE` — это ключ к вашему аккаунту Unity. Не присылайте его в чаты,
> не вставляйте в issues и не коммитьте: репозиторий публичный.

---

## Шаг 1. Аккаунт Unity ID

1. Откройте <https://id.unity.com> → **Create a Unity ID**.
2. Подтвердите e-mail.
3. **Сразу сделайте пароль только из букв и цифр.** GameCI ломается на спецсимволах
   (`!`, `#`, `@`, кавычки) — это известное ограничение их активатора, а не проекта.

Ничего скачивать и покупать не нужно: Personal — бесплатная лицензия.

## Шаг 2. Создать Codespace

**Самый короткий путь — прямая ссылка (кнопку искать не нужно):**

```text
https://codespaces.new/WeteroScript/Game/tree/arena/c7d56f15-game
```

Открывайте её **в браузере** (Chrome/Safari), а не в приложении GitHub: в мобильном приложении
Codespaces нет вообще. На странице останется нажать **Create codespace** (или «New with options» →
машина 2 ядра). Формат ссылки официальный: `codespaces.new/OWNER/REPO/tree/BRANCH`.

Через интерфейс это выглядит так:

1. Откройте <https://github.com/WeteroScript/Game> и войдите в аккаунт.
2. Переключите ветку на **`arena/c7d56f15-game`** (кнопка с названием ветки над списком файлов) —
   в `main` файлов для этого пути ещё нет.
3. Зелёная кнопка **Code** → вкладка **Codespaces** → **Create codespace on arena/c7d56f15-game**.
   Если вкладки нет: <https://github.com/codespaces> → кнопка **New codespace** → выберите
   репозиторий `WeteroScript/Game` и ветку `arena/c7d56f15-game`.
4. Подождите 3–6 минут. В логе установки видно шаги `[1/4] … [4/4]`:
   поднимается VNC-десктоп, скачивается Unity Hub.

Итог: в браузере открывается веб-VS Code. Он неудобен на телефоне, но нужен только для двух команд.

## Шаг 3. Открыть рабочий стол

1. В веб-VS Code откройте панель **Ports** (внизу рядом с Terminal; на телефоне — меню `≡` → Ports).
2. У строки порта **6080** нажмите ссылку «Open in Browser» (или значок глобуса).
   Альтернатива: прямой URL `https://<имя-codespace>-6080.app.github.dev/vnc.html?autoconnect=1&resize=scale`
   (его печатает в терминале `bash tools/license/start-unityhub.sh`).
3. Пароль VNC: **`unity`**.
4. Настройте noVNC под телефон (иконка со стрелками / шестерёнка в панели слева):
   *Scaling mode* → **Remote scaling**; иконка мыши → **Touch mode**.

В десктопе **Unity Hub уже запущен** (это делает `postStartCommand`).
Если окна нет — долгое нажатие на пустом месте фона → **Application Menu → Terminal** → введите `~/unityhub`.

## Шаг 4. Выпустить лицензию

В окне Unity Hub:

1. Войдите тем Unity ID, для которого делаете сборку.
2. Шестерёнка **Preferences** → вкладка **Licenses** → **Add**.
3. **Get a free personal license** → **Agree and get personal edition license**.
4. Ждите 10–60 секунд. Если попросит выбрать редакцию — Personal.

> **Важно:** нажать **Add нужно даже если лицензия уже показана в списке.** Без этого шага файл
> `.ulf` может не появиться — это официальная рекомендация GameCI, люди на ней и спотыкаются.
> Редактор Unity при этом устанавливать **не** требуется.

Файл появляется по пути `~/.local/share/unity3d/Unity/Unity_lic.ulf` (≈4–6 КБ).

## Шаг 5. Записать секреты

Вернитесь из десктопа в **терминал веб-VS Code** (панель Terminal, не в VNC).

**Самый простой способ — без набора путей:** меню `≡` → **Terminal → Run Task** →
**«1. Записать секреты Unity в GitHub»**.
Ручной вариант той же команды:

```bash
bash tools/license/set-secrets.sh
```

Скрипт сам найдёт `.ulf`, проверит его, спросит e-mail и пароль Unity (пароль — ввод скрыт) и запишет три
секрета: `UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD`.

Если появится `403` / «нет прав на secrets» — токен Codespaces ограничен. Тогда:

```bash
gh auth login --web     # введите код на github.com/login/device (это удобно с телефона)
bash tools/license/set-secrets.sh
```

Совсем запасной путь (ручная вставка): `bash tools/license/set-secrets.sh --print`, затем скопировать
текст и вставить на странице
`https://github.com/WeteroScript/Game/settings/secrets/actions` → **New repository secret** → `UNITY_LICENSE`.
Копировать нужно **целиком**: от `<?xml …` до `</root>`; обрезанный файл даёт ошибку активации.

Проверить: `gh secret list` — должны быть видны три имени.

## Шаг 6. Освободить лицензию и погасить Codespace

1. В Unity Hub (десктоп) нажмите на аватар → **Sign out**. В Hub 3.7+ выход из аккаунта
   и есть возврат Personal-лицензии: иначе место останется занятым и CI не активируется.
   Сам файл `.ulf` при этом остаётся рабочим — его уже забрали в секрет.
2. Закройте Codespace и **удалите** его: <https://github.com/codespaces> → `...` → **Delete**.
   Иначе он съедает квоту хранилища (15 ГБ/мес).

## Шаг 7. Собрать APK и поставить на телефон

1. Откройте пулл-реквест из ветки `arena/c7d56f15-game` в `main`
   (или влейте её) — это запускает сборку. Кнопка **Run workflow** появится только после того,
   как workflow окажется в `main`.
2. **Actions → Build Android APK** → зелёная галочка (10–25 минут, первый раз дольше).
3. Внизу страницы запуска: **Artifacts → `AndroidBuild`** → скачать ZIP (около 30–60 МБ).
4. Распаковать ZIP на телефоне (встроенный «Файлы» умеет, либо ZArchiver) → внутри `KugooFreeride.apk`.
5. Установить: при запросе разрешить «Установка из неизвестных источников» для браузера/файлового менеджера.

## Шаг 8. Если что-то пошло не так

| Симптом | Что делать |
|---|---|
| Порт 6080 отдаёт ошибку авторизации/404 | Открывайте ссылку именно из панели **Ports** (в ней есть токен доступа) или выставьте порту Visibility → **Private** и оставайтесь в своём аккаунте |
| Чёрный экран в noVNC | Нажать **Connect**, ввести пароль `unity`; обновить страницу; Scaling → Remote |
| Нет курсора/сложно попасть по кнопкам | Иконка мыши в панели noVNC → **Touch mode**, затем Scaling → Remote |
| Окно Hub не появилось | В терминале VS Code: `bash tools/license/start-unityhub.sh`, лог — `/tmp/unityhub.log` |
| Hub не устанавливается (`[fail]`) | Скрипт сначала ставит Hub из официального apt-репозитория Unity, потом качает `UnityHub-x86_64.AppImage`. Если не вышло — скачайте Linux-версию с <https://unity.com/download> и загрузите файл в Cloud Shell (меню `⋮` → **Upload**) |
| «There was a problem activating a new personal license» | В терминале десктопа: `pkill -9 -f Unity.Licensing.Client`, удалить старый `~/.local/share/unity3d/Unity/Unity_lic.ulf`, перезапустить Hub и повторить **Add**. Лог: `~/.config/unity3d/Unity/Unity.Licensing.Client.log` |
| Лицензия есть в Hub, а `.ulf` нет | Нажать **Add** ещё раз (см. предупреждение в шаге 4) |
| `set-secrets.sh`: `.ulf` не найден | Та же причина: лицензия без нажатия **Add**. Либо искать вручную: `find ~ -name '*.ulf'` |
| `set-secrets.sh`: 403 | `gh auth login --web`, затем повторить; либо `--print` и вставка руками |
| CI: «No valid Unity license» | Секрет `UNITY_LICENSE` обрезан или записан не целиком |
| CI: «A license is already in use» | Остался вход в Hub (шаг 6) либо параллельно идёт другая сборка — workflow уже ограничен `concurrency` |
| Codespace «stopped» после паузы | Он засыпает после 30 минут простоя. Откройте его снова — Hub поднимется автоматически |
| Закончилась квота Codespaces («You are out of monthly free usage…») | Смотрите раздел ниже — тот же рабочий стол поднимается в Google Cloud Shell, без квоты GitHub |

## Если квота Codespaces закончилась (или Codespaces недоступны)

Сообщение «You are out of monthly free usage or have exceeded your budget for Codespaces» значит, что
израсходованы 120 core-часов (60 часов на машине с 2 ядрами) или 15 ГБ·мес хранилища. Обнулится в новый
расчётный период. Что можно сделать бесплатно:

1. **Удалить старые Codespaces** — они продолжают занимать хранилище:
   <https://github.com/codespaces> → `...` → **Delete**. Иногда этого хватает, чтобы доступ вернулся.
2. Поставить короткий таймаут простоя: <https://github.com/settings/codespaces> → **Default idle timeout** → 10 минут.
3. Дождаться нового месяца — либо идти путём ниже, он не использует квоту GitHub вообще.

### Путь без Codespaces: Google Cloud Shell

Бесплатно, без банковской карты, только Google-аккаунт. Даёт root-терминал в браузере и «Web Preview»,
который открывает порт прямо на телефоне — то же самое, что даёт Codespaces.

1. Откройте <https://shell.cloud.google.com> и разрешите доступ (первый запуск ~1 минута).
2. Вставьте одну строку и нажмите Enter:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/WeteroScript/Game/arena/c7d56f15-game/tools/license/cloudshell.sh -o /tmp/u.sh && bash /tmp/u.sh < /dev/null
   ```

   (Скачивать в файл и запускать с `< /dev/null` важно: при `curl … | bash` команды `sudo`/`apt`
   вычитывают stdin и «съедают» остаток скрипта — типичная ошибка вида `line 37: M: command not found`.)

   Скрипт поставит рабочий стол (2–4 минуты), скачает Unity Hub и запустит его.
3. Кнопка **Web Preview** (иконка глаза в панели инструментов) → **Change port** → **8080** → **Preview**.
   Откроется рабочий стол с уже запущенным Unity Hub, пароль не нужен.
4. В Hub: вход → `Preferences → Licenses → Add → Get a free personal license → Agree`.
5. Вернитесь в терминал Cloud Shell и запишите секреты:

   ```bash
   git clone -b arena/c7d56f15-game https://github.com/WeteroScript/Game Game
   bash Game/tools/license/set-secrets.sh
   ```

   Если `gh` попросит вход — `gh auth login --web` и введите код на <https://github.com/login/device>.
6. В Hub: аватар → **Sign out** (возврат лицензии).

Ограничения Cloud Shell: сессия завершается после ~20 минут бездействия (лицензия в домашней папке
сохраняется, скрипт можно запустить снова), лимит ~50 часов в неделю. Домашняя папка — 5 ГБ, этого хватает.

## Чего я не смог проверить

Честно: в моей среде нет графики и доступа к `unity.com`/`download.unity3d.com`, поэтому
десктоп, установка Hub и выпуск лицензии **не прогонялись вживую**. Проверено другое:

- официальная документация GameCI (путь `.ulf`, кнопка **Add**, выход из Hub вместо «Return license») — <https://game.ci/docs/github/activation>;
- исходники фичи `desktop-lite` (какие пакеты, порт 6080, пароль, запуск noVNC) — <https://github.com/devcontainers/features/tree/main/src/desktop-lite>;
- Unity Manual: Personal-лицензия активируется только входом в Hub, а возвращается выходом из него;
- синтаксис всех скриптов и JSON конфигурации.

Если на каком-то шаге стена — пришлите текст ошибки (без содержимого `.ulf` и без пароля), и я подгоню скрипты.
