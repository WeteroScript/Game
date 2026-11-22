#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Рабочий стол в Google Cloud Shell — бесплатная альтернатива Codespaces,
# когда квота GitHub закончилась. Нужен только браузер телефона и Google-аккаунт.
#
# Запуск (вставить одной строкой в терминал Cloud Shell):
#   curl -fsSL https://raw.githubusercontent.com/WeteroScript/Game/arena/c7d56f15-game/tools/license/cloudshell.sh -o /tmp/u.sh && bash /tmp/u.sh < /dev/null
#
# Скрипт поднимает Xvfb + Fluxbox + x11vnc + noVNC на порту 8080 и запускает Unity Hub.
# Дальше: кнопка "Web Preview" -> порт 8080 -> рабочий стол -> Unity Hub.
# Лицензия появится в ~/.local/share/unity3d/Unity/Unity_lic.ulf (домашняя папка Cloud Shell
# переживает перезапуск сессии).
# ---------------------------------------------------------------------------
set -uo pipefail

# Скрипт часто запускают как `curl … | bash`. Тогда stdin занят самим скриптом, и apt/sudo
# могут «съесть» его кусок — симптом: `bash: line N: M: command not found`.
# Поэтому при запуске из pipe переисполняем себя из временного файла со stdin из /dev/null.
if [ ! -r "$0" ]; then
  tmp="$(mktemp /tmp/unityhub-cloudshell.XXXXXX.sh)"
  cat > "$tmp"
  exec bash "$tmp" "$@" < /dev/null
fi

DISP=":1"
PORT="8080"
APPIMAGE_URL="https://public-cdn.cloud.unity3d.com/hub/prod/UnityHub-x86_64.AppImage"
APP_DIR="$HOME/.unityhub-app"
HUB_BIN=""

say() { printf '%s\n' "$*"; }
die() { say ""; say "[fail] $*"; exit 1; }

say "=== Unity Hub в Google Cloud Shell ==="

# --- 1. Пакеты --------------------------------------------------------------
say "[1/5] Ставлю рабочий стол (2-4 минуты)..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq || say "[warn] apt-get update не удался"

pkgs="xvfb fluxbox x11vnc novnc websockify dbus-x11 xterm x11-utils gnupg ca-certificates \
fonts-dejavu-core libgtk-3-0 libnss3 libgbm1 libxss1 libsecret-1-0 libnotify4 \
libxshmfence1 libxdamage1 libdrm2 libgl1-mesa-dri libglx-mesa0 xdg-utils libfuse2 xz-utils"
for pkg in $pkgs libasound2 libasound2t64; do
  dpkg -s "$pkg" >/dev/null 2>&1 && continue
  sudo apt-get install -y --no-install-recommends "$pkg" >/dev/null 2>&1 || true
done

for bin in Xvfb x11vnc websockify; do
  command -v "$bin" >/dev/null 2>&1 || die "Не установился $bin (нет прав на apt?)"
done
[ -d /usr/share/novnc ] || die "Нет /usr/share/novnc (пакет novnc не установился)"

# gh — чтобы потом записать секреты в GitHub одной командой (необязательно).
if ! command -v gh >/dev/null 2>&1; then
  sudo apt-get install -y --no-install-recommends gh >/dev/null 2>&1 || true
fi
if ! command -v gh >/dev/null 2>&1; then
  tag=$(curl -fsSL --connect-timeout 15 https://api.github.com/repos/cli/cli/releases/latest \
        | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n1)
  if [ -n "${tag:-}" ]; then
    curl -fsSL -o /tmp/gh.tgz \
      "https://github.com/cli/cli/releases/download/v${tag}/gh_${tag}_linux_amd64.tar.gz" 2>/dev/null \
      && sudo tar -xzf /tmp/gh.tgz -C /usr/local --strip-components=1 --wildcards '*/bin/gh' >/dev/null 2>&1 || true
  fi
fi

# --- 2. Unity Hub ----------------------------------------------------------
# Порядок: уже установленный Hub -> официальный apt-репозиторий Unity -> AppImage.
say "[2/5] Ставлю Unity Hub..."
if command -v unityhub >/dev/null 2>&1; then
  HUB_BIN="$(command -v unityhub)"
  say "  -> Hub уже установлен: $HUB_BIN"
elif [ -x "$APP_DIR/unityhub" ]; then
  HUB_BIN="$APP_DIR/unityhub"
  say "  -> используется ранее распакованный AppImage: $HUB_BIN"
fi

if [ -z "$HUB_BIN" ]; then
  say "  -> добавляю официальный apt-репозиторий Unity Hub..."
  sudo install -d /etc/apt/keyrings
  if curl -fsSL https://hub.unity3d.com/linux/keys/public \
       | sudo gpg --dearmor -o /etc/apt/keyrings/unityhub.gpg 2>/dev/null; then
    sudo tee /etc/apt/sources.list.d/unityhub.sources >/dev/null <<'EOF'
Types: deb
URIs: https://hub.unity3d.com/linux/repos/deb
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/unityhub.gpg
EOF
    sudo apt-get update -qq || true
    sudo apt-get install -y unityhub || true
  fi
  command -v unityhub >/dev/null 2>&1 && HUB_BIN="$(command -v unityhub)"
fi

if [ -z "$HUB_BIN" ] || [ ! -x "$HUB_BIN" ]; then
  say "  -> apt не сработал, беру AppImage (~150 МБ)..."
  img="/tmp/UnityHub-x86_64.AppImage"
  if [ ! -f "$img" ] || [ "$(stat -c%s "$img" 2>/dev/null || echo 0)" -lt 50000000 ]; then
    curl -fL --retry 2 --connect-timeout 20 -o "$img" "$APPIMAGE_URL" \
      || die "Не скачался AppImage ($APPIMAGE_URL). Скачайте на телефоне с https://unity.com/download, загрузите сюда через меню Cloud Shell (⋮ -> Upload) и повторите."
  fi
  [ "$(head -c 4 "$img")" = "$(printf '\x7fELF')" ] || die "Скачался не бинарник"
  chmod +x "$img"
  rm -rf /tmp/squashfs-root
  ( cd /tmp && "$img" --appimage-extract >/dev/null 2>&1 )
  if [ -x /tmp/squashfs-root/unityhub ]; then
    rm -rf "$APP_DIR"; mv /tmp/squashfs-root "$APP_DIR"; HUB_BIN="$APP_DIR/unityhub"
  fi
fi

[ -n "$HUB_BIN" ] && [ -x "$HUB_BIN" ] || die "Unity Hub установить не удалось. Логи: apt / /tmp/unityhub.log"

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
pgrep -f websockify >/dev/null 2>&1 || nohup websockify --web=/usr/share/novnc "$PORT" localhost:5900 >/tmp/websockify.log 2>&1 &
sleep 2
pgrep -f websockify >/dev/null 2>&1 || { say "[warn] websockify не запустился:"; tail -n 10 /tmp/websockify.log 2>/dev/null; }

# --- 5. Unity Hub ----------------------------------------------------------
say "[5/5] Запускаю Unity Hub ($HUB_BIN)..."
if ! pgrep -f "unityhub" >/dev/null 2>&1; then
  ( DISPLAY="$DISP" LIBGL_ALWAYS_SOFTWARE=1 nohup "$HUB_BIN" --no-sandbox >/tmp/unityhub.log 2>&1 & )
  sleep 4
fi
if pgrep -f "unityhub" >/dev/null 2>&1; then
  say "[ok] Hub запущен."
else
  say "[warn] Hub не стартовал, хвост лога:"; tail -n 15 /tmp/unityhub.log 2>/dev/null
fi

cat <<'TXT'

------------------------------------------------------------------
КАК ОТКРЫТЬ РАБОЧИЙ СТОЛ (телефон):
 1. В Cloud Shell нажмите "Web Preview" (иконка глаза в панели
    инструментов) -> "Change port" -> 8080 -> Preview.
    Если вёрстка ломается, включите в браузере "Версия для ПК".
 2. Откроется рабочий стол с окном Unity Hub, пароль не нужен.

В HUB:
 3. Войдите в Unity ID -> шестерёнка Preferences -> Licenses -> Add
    -> "Get a free personal license" -> Agree.
    (Add нажимать даже если лицензия уже в списке!)

ЛИЦЕНЗИЯ: ~/.local/share/unity3d/Unity/Unity_lic.ulf

ПОТОМ (секреты в GitHub) — вернитесь в терминал Cloud Shell:
    git clone -b arena/c7d56f15-game https://github.com/WeteroScript/Game Game
    bash Game/tools/license/set-secrets.sh
  (если gh попросит вход: gh auth login --web, код ввести на github.com/login/device)

 ВРУЧНУЮ, если gh не заработал:
    cat ~/.local/share/unity3d/Unity/Unity_lic.ulf
    (в noVNC есть панель Clipboard: выделить -> скопировать), затем вставить
    в https://github.com/WeteroScript/Game/settings/secrets/actions как UNITY_LICENSE.

 4. В Hub нажмите на аватар -> Sign out (это возврат Personal-лицензии).
------------------------------------------------------------------
TXT
