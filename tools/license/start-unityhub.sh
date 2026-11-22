#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Поднимает Unity Hub в VNC-десктопе Codespaces (порт 6080).
# Вызывается автоматически на старте контейнера (postStartCommand) — можно и вручную:
#     bash tools/license/start-unityhub.sh
# ---------------------------------------------------------------------------
set -uo pipefail

export DISPLAY="${DISPLAY:-:1}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-autolaunch:}"

say() { printf '%s\n' "$*"; }

if [ ! -x "$HOME/unityhub" ]; then
  say "[warn] Hub ещё не установлен. Запустите: bash tools/license/install-unityhub.sh"
  exit 1
fi

# VNC-сервер поднимается entrypoint'ом контейнера — ждём, пока X ответит (до 60 с).
ready=0
for _ in $(seq 1 60); do
  if xdpyinfo >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  say "[warn] X-сервер на $DISPLAY не отвечает — десктоп ещё не готов."
  say "       Обновите страницу десктопа и выполните скрипт ещё раз."
  exit 1
fi

if pgrep -f "$HOME/.unityhub-app/unityhub" >/dev/null 2>&1; then
  say "[ok] Unity Hub уже запущен в десктопе."
else
  nohup "$HOME/unityhub" >/tmp/unityhub.log 2>&1 &
  sleep 2
  if pgrep -f "$HOME/.unityhub-app/unityhub" >/dev/null 2>&1; then
    say "[ok] Unity Hub запущен (лог: /tmp/unityhub.log)."
  else
    say "[warn] Hub не стартовал. Смотрите /tmp/unityhub.log"
    tail -n 15 /tmp/unityhub.log 2>/dev/null
    exit 1
  fi
fi

# Подсказка со ссылкой на десктоп (Codespaces подставляет переменные сам).
if [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
  say ""
  say "Десктоп в браузере:"
  say "  https://${CODESPACE_NAME}-6080.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/vnc.html?autoconnect=1&resize=scale"
  say "  пароль VNC: unity"
fi
