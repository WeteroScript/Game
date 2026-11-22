#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Ставит Unity Hub внутрь контейнера (GitHub Codespaces), чтобы выпустить
# лицензию Unity Personal (.ulf) без компьютера — только с телефона.
#
# Запускается автоматически из .devcontainer/devcontainer.json
# (postCreateCommand), но можно и вручную:  bash tools/license/install-unityhub.sh
#
# Редактор Unity здесь НЕ нужен и НЕ скачивается: для лицензии хватает Hub.
# ---------------------------------------------------------------------------
set -uo pipefail

HUB_URL="https://public-cdn.cloud.unity3d.com/hub/prod/UnityHub.AppImage"
APP_DIR="$HOME/.unityhub-app"
IMG="/tmp/UnityHub.AppImage"
LOG="/tmp/unityhub-install.log"

say() { printf '%s\n' "$*"; }
fail() { say ""; say "[fail] $*"; say "       Лог: $LOG"; exit 1; }

# Дублируем вывод в лог, чтобы после автоустановки можно было посмотреть, что было.
exec > >(tee -a "$LOG") 2>&1

say "=== Unity Hub для Codespaces: $(date -u +%H:%M:%SZ) ==="

if [ -x "$APP_DIR/unityhub" ]; then
  say "[ok] Unity Hub уже распакован в $APP_DIR — ничего не делаю."
  exit 0
fi

# --- 1. Библиотеки, без которых Electron-приложения не стартуют -------------
say "[1/4] Системные библиотеки для Unity Hub (может занять минуту)..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq || say "[warn] apt-get update не удался, пробую ставить как есть"

# libasound2 на Ubuntu 24.04+ переименован в libasound2t64 — ставим что найдётся,
# отсутствие необязательного пакета установку не ломает.
for pkg in libgtk-3-0 libnss3 libgbm1 libxss1 libsecret-1-0 libnotify4 \
           libxshmfence1 libxdamage1 libdrm2 libgl1-mesa-dri libglx-mesa0 \
           xdg-utils libasound2 libasound2t64; do
  dpkg -s "$pkg" >/dev/null 2>&1 && continue
  sudo apt-get install -y --no-install-recommends "$pkg" >/dev/null 2>&1 || true
done

# --- 2. Скачивание AppImage ------------------------------------------------
say "[2/4] Скачиваю Unity Hub (~150 МБ) с официального CDN Unity..."
if ! curl -fL --retry 3 --connect-timeout 20 --progress-bar -o "$IMG" "$HUB_URL"; then
  say ""
  say "[fail] Не удалось скачать $HUB_URL"
  say "       Что делать: откройте https://unity.com/download в браузере телефона/десктопа,"
  say "       скачайте Linux-версию и положите файл как $IMG, затем повторите скрипт."
  exit 1
fi

if [ "$(head -c 4 "$IMG")" != "$(printf '\x7fELF')" ]; then
  fail "Скачался не бинарник (вероятно, HTML-страница вместо файла). Повторите позже."
fi
if [ "$(stat -c%s "$IMG")" -lt 50000000 ]; then
  fail "Файл подозрительно маленький ($(stat -c%s "$IMG") байт). Скачивание прервалось?"
fi

# --- 3. Распаковка (FUSE в контейнере недоступен, поэтому --appimage-extract)
say "[3/4] Распаковываю AppImage..."
chmod +x "$IMG"
rm -rf /tmp/squashfs-root
( cd /tmp && "$IMG" --appimage-extract >/dev/null 2>&1 )
if [ ! -x /tmp/squashfs-root/unityhub ]; then
  fail "Не получилось распаковать AppImage (нет /tmp/squashfs-root/unityhub)."
fi
rm -rf "$APP_DIR"
mv /tmp/squashfs-root "$APP_DIR"

# --- 4. Обёртка запуска + иконка в меню десктопа ----------------------------
say "[4/4] Готовлю ярлык запуска..."
cat > "$HOME/unityhub" <<'WRAP'
#!/usr/bin/env bash
# Запуск Unity Hub внутри VNC-десктопа Codespaces.
export DISPLAY="${DISPLAY:-:1}"
export LIBGL_ALWAYS_SOFTWARE=1          # в контейнере нет GPU — рисуем программно
export ELECTRON_DISABLE_SECURITY_WARNINGS=1
exec "$HOME/.unityhub-app/unityhub" --no-sandbox "$@"
WRAP
chmod +x "$HOME/unityhub"

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/unityhub.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Unity Hub
Comment=Выпуск лицензии Unity Personal для CI
Exec=$HOME/unityhub
Terminal=false
Categories=Development;
DESK

say ""
say "[ok] Unity Hub установлен: $APP_DIR"
say "     Запуск в десктопе:  ~/unityhub"
say "     Дальше: docs/LICENSE-PHONE.md, шаг 4 (войти и нажать Add -> Get a free personal license)."
