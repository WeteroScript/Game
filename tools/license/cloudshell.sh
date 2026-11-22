#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Рабочий стол в Google Cloud Shell — бесплатная альтернатива Codespaces,
# когда квота GitHub закончилась. Нужен только браузер телефона и Google-аккаунт.
#
# Запуск (Cloud Shell, вставить одной строкой):
#   curl -fsSL https://raw.githubusercontent.com/WeteroScript/Game/arena/c7d56f15-game/tools/license/cloudshell.sh | bash
#
# Скрипт поднимает Xvfb + Fluxbox + x11vnc + noVNC на порту 8080 и запускает Unity Hub.
# Дальше: кнопка "Web Preview" в Cloud Shell -> порт 8080 -> рабочий стол -> Unity Hub.
# Лицензия появится в ~/.local/share/unity3d/Unity/Unity_lic.ulf (домашняя папка Cloud Shell
# переживает перезапуск сессии).
# ---------------------------------------------------------------------------
set -uo pipefail

DISP=":1"
PORT="8080"
HUB_URL="https://public-cdn.cloud.unity3d.com/hub/prod/UnityHub.AppImage"
APP_DIR="$HOME/.unityhub-app"

say() { printf '%s\n' "$*"; }
die() { say ""; say "[fail] $*"; exit 1; }

say "=== Unity Hub в Google Cloud Shell ==="

# --- 1. Пакеты --------------------------------------------------------------
say "[1/5] Ставлю рабочий стол (2-4 минуты)..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq || say "[warn] apt-get update не удался"

pkgs="xvfb fluxbox x11vnc novnc websockify dbus-x11 xterm x11-utils \
fonts-dejavu-core libgtk-3-0 libnss3 libgbm1 libxss1 libsecret-1-0 libnotify4 \
libxshmfence1 libxdamage1 libdrm2 libgl1-mesa-dri libglx-mesa0 xdg-utils libfuse2 xz-utils file"
for pkg in $pkgs libasound2 libasound2t64; do
  dpkg -s "$pkg" >/dev/null 2>&1 && continue
  sudo apt-get install -y --no-install-recommends "$pkg" >/dev/null 2>&1 || true
done

# gh — чтобы потом записать секреты в GitHub одной командой.
if ! command -v gh >/dev/null 2>&1; then
  sudo apt-get install -y --no-install-recommends gh >/dev/null 2>&1 || true
fi
if ! command -v gh >/dev/null 2>&1; then
  tag=$(curl -fsSL --connect-timeout 15 https://api.github.com/repos/cli/cli/releases/latest \
        | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n1)
  if [ -n "$tag" ]; then
    curl -fsSL -o /tmp/gh.tgz "https://github.com/cli/cli/releases/download/v${tag}/gh_${tag}_linux_amd64.tar.gz" \
      && sudo tar -xzf /tmp/gh.tgz -C /usr/local --strip-components=1 --wildcards '*/bin/gh' >/dev/null 2>&1 || true
  fi
fi

for bin in Xvfb x11vnc websockify; do
  command -v "$bin" >/dev/null 2>&1 || die "Не установился $bin — нет прав на apt?"
done
[ -d /usr/share/novnc ] || die "Нет /usr/share/novnc (пакет novnc не установился)."

# --- 2. Unity Hub ----------------------------------------------------------
if [ -x "$APP_DIR/unityhub" ]; then
  say "[2/5] Unity Hub уже распакован — пропускаю."
else
  say "[2/5] Скачиваю Unity Hub (~150 МБ)..."
  curl -fL --retry 2 --connect-timeout 20 -o /tmp/UnityHub.AppImage "$HUB_URL" \
    || die "Не скачался Hub. Скачайте вручную с https://unity.com/download и положите в /tmp/UnityHub.AppImage"
  [ "$(head -c 4 /tmp/UnityHub.AppImage)" = "$(printf '\x7fELF')" ] || die "Скачался не бинарник"
  chmod +x /tmp/UnityHub.AppImage
  rm -rf /tmp/squashfs-root
  ( cd /tmp && ./UnityHub.AppImage --appimage-extract >/dev/null 2>&1 )
  [ -x /tmp/squashfs-root/unityhub ] || die "AppImage не распаковался"
  rm -rf "$APP_DIR"
  mv /tmp/squashfs-root "$APP_DIR"
fi

# --- 3. X-сервер + оконный менеджер ---------------------------------------
say "[3/5] Поднимаю Xvfb и Fluxbox на $DISP..."
pgrep -f "Xvfb $DISP" >/dev/null 2>&1 || nohup Xvfb "$DISP" -screen 0 1440x900x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
sleep 2
pgrep -x fluxbox >/dev/null 2>&1 || ( DISPLAY="$DISP" nohup fluxbox >/tmp/fluxbox.log 2>&1 & )
sleep 1

# --- 4. VNC + noVNC на 8080 -----------------------------------------------
say "[4/5] Запускаю VNC и веб-клиент на порту $PORT..."
pgrep -x x11vnc >/dev/null 2>&1 || nohup x11vnc -display "$DISP" -localhost -nopw -forever -shared \
  -xkb -rfbport 5900 >/tmp/x11vnc.log 2>&1 &
sleep 2
if ! pgrep -f "websockify" >/dev/null 2>&1; then
  nohup websockify --web=/usr/share/novnc "$PORT" localhost:5900 >/tmp/websockify.log 2>&1 &
  sleep 2
fi
if ! pgrep -f websockify >/dev/null 2>&1; then
  say "[warn] websockify не запустился, лог:"; tail -n 10 /tmp/websockify.log 2>/dev/null
fi

# --- 5. Unity Hub ----------------------------------------------------------
say "[5/5] Запускаю Unity Hub в десктопе..."
if ! pgrep -f "$APP_DIR/unityhub" >/dev/null 2>&1; then
  ( DISPLAY="$DISP" LIBGL_ALWAYS_SOFTWARE=1 nohup "$APP_DIR/unityhub" --no-sandbox >/tmp/unityhub.log 2>&1 & )
  sleep 3
fi
pgrep -f "$APP_DIR/unityhub" >/dev/null 2>&1 \
  && say "[ok] Hub запущен." \
  || { say "[warn] Hub не стартовал, хвост лога:"; tail -n 15 /tmp/unityhub.log 2>/dev/null; }

cat <<'TXT'

------------------------------------------------------------------
КАК ОТКРЫТЬ РАБОЧИЙ СТОЛ (телефон):
 1. В Cloud Shell нажмите кнопку "Web Preview" (иконка глаза
    в правой части панели инструментов).
 2. В выпадающем списке выберите "Change port" -> 8080 -> Preview.
 3. Откроется noVNC с окном Unity Hub. Пароль не нужен.

В HUB:
 4. Войдите в Unity ID -> шестерёнка Preferences -> Licenses -> Add
    -> "Get a free personal license" -> Agree.
    (Add нажимать даже если лицензия уже в списке!)

ЛИЦЕНЗИЯ: ~/.local/share/unity3d/Unity/Unity_lic.ulf

ПОТОМ (секреты в GitHub) — вернитесь в терминал Cloud Shell:
    git clone -b arena/c7d56f15-game https://github.com/WeteroScript/Game Game
    cd Game && bash tools/license/set-secrets.sh
  (если gh попросит вход: gh auth login --web, код ввести на github.com/login/device)

 ВРУЧНУЮ, если gh не заработал:
    cat ~/.local/share/unity3d/Unity/Unity_lic.ulf
    (в noVNC есть панель Clipboard — выделить и скопировать), затем вставить
    в https://github.com/WeteroScript/Game/settings/secrets/actions как UNITY_LICENSE.

 5. В Hub нажмите на аватар -> Sign out (это возврат Personal-лицензии).
------------------------------------------------------------------
TXT
