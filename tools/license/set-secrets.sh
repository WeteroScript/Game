#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Находит лицензию Unity Personal (.ulf), созданную в Codespace, и записывает
# три секрета GameCI в репозиторий GitHub — без копирования XML руками.
#
#   bash tools/license/set-secrets.sh you@example.com
#   bash tools/license/set-secrets.sh you@example.com --repo owner/repo
#   bash tools/license/set-secrets.sh --print      # только показать файл (ручная вставка)
#
# Секреты, которые пишутся: UNITY_LICENSE, UNITY_EMAIL, UNITY_PASSWORD.
# ---------------------------------------------------------------------------
set -uo pipefail

EMAIL=""
REPO=""
PRINT_ONLY=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --print) PRINT_ONLY=1; shift ;;
    --repo)  REPO="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) EMAIL="$1"; shift ;;
  esac
done

say()  { printf '%s\n' "$*"; }
fail() { say ""; say "[fail] $*"; exit 1; }

# --- 1. Ищем файл лицензии -------------------------------------------------
ULF=""
for p in "$HOME/.local/share/unity3d/Unity/Unity_lic.ulf" \
         "/root/.local/share/unity3d/Unity/Unity_lic.ulf"; do
  if [ -f "$p" ]; then ULF="$p"; break; fi
done
if [ -z "$ULF" ]; then
  ULF=$(find "$HOME" /root -maxdepth 7 -type f -name 'Unity_lic*.ulf' 2>/dev/null | head -n1)
fi

if [ -z "$ULF" ]; then
  say "[fail] Файл .ulf не найден."
  say ""
  say "Так бывает, если в Unity Hub была уже активная лицензия, но кнопку Add не нажимали."
  say "Откройте десктоп (порт 6080) -> Unity Hub -> Preferences -> Licenses -> Add"
  say "-> 'Get a free personal license' -> Agree. После этого повторите скрипт."
  say ""
  say "Поискать вручную:  find ~ -name '*.ulf' 2>/dev/null"
  exit 1
fi

say "[ok] Лицензия: $ULF ($(stat -c%s "$ULF") байт)"

if ! grep -q '</root>' "$ULF" 2>/dev/null; then
  say "[warn] В файле нет закрывающего </root> — возможно, файл неполный."
fi
if [ "$(stat -c%s "$ULF")" -gt 48000 ]; then
  say "[warn] Файл больше лимита GitHub на секрет (48 КБ) — секрет не запишется."
fi

# --- 2. Режим ручной вставки ----------------------------------------------
if [ "$PRINT_ONLY" -eq 1 ]; then
  say ""
  say "Ниже — содержимое файла. Скопируйте ЦЕЛИКОМ (от <?xml до </root>)"
  say "в секрет UNITY_LICENSE: Settings -> Secrets and variables -> Actions."
  say "ВНИМАНИЕ: это секрет, не вставляйте его в чаты, issues и коммиты."
  say "------------------------------------------------------------------"
  cat "$ULF"
  say "------------------------------------------------------------------"
  exit 0
fi

# --- 3. Определяем репозиторий --------------------------------------------
if [ -z "$REPO" ]; then
  origin=$(git -C "$(dirname "$0")/../.." remote get-url origin 2>/dev/null || true)
  REPO=$(printf '%s' "$origin" | sed -E 's#.*github\.com[:/]##; s#\.git$##')
fi
[ -n "$REPO" ] || fail "Не понял, в какой репозиторий писать. Укажите: --repo owner/repo"

if [ -z "$EMAIL" ]; then
  read -r -p "E-mail аккаунта Unity ID: " EMAIL
fi
[ -n "$EMAIL" ] || fail "Нужен e-mail Unity ID."

# Пароль не печатается и нигде не сохраняется.
if [ -z "${UNITY_PASSWORD_INPUT:-}" ]; then
  read -r -s -p "Пароль Unity ID (ввод скрыт): " UNITY_PASSWORD_INPUT; say ""
fi
[ -n "$UNITY_PASSWORD_INPUT" ] || fail "Пустой пароль."

# --- 4. Пробуем gh ---------------------------------------------------------
export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
ok=1
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  say "[1/3] UNITY_LICENSE ..."
  cat "$ULF" | gh secret set UNITY_LICENSE --repo "$REPO" || ok=0
  if [ "$ok" -eq 1 ]; then
    say "[2/3] UNITY_EMAIL ..."
    printf '%s' "$EMAIL" | gh secret set UNITY_EMAIL --repo "$REPO" || ok=0
    say "[3/3] UNITY_PASSWORD ..."
    printf '%s' "$UNITY_PASSWORD_INPUT" | gh secret set UNITY_PASSWORD --repo "$REPO" || ok=0
  fi
else
  ok=0
  say "[warn] gh CLI не авторизован в этой среде."
fi

if [ "$ok" -eq 1 ]; then
  say ""
  say "[ok] Секреты записаны в $REPO:"
  gh secret list --repo "$REPO" || true
  say ""
  say "Дальше: docs/LICENSE-PHONE.md, шаг 7 — сборка APK."
  exit 0
fi

# --- 5. Запасной путь: вставить руками ------------------------------------
say ""
say "Автоматически записать секреты не удалось (у токена Codespaces нет прав на secrets)."
say "Вариант 1 — дать права:  gh auth login --web   (код покажется в терминале),"
say "            затем повторить этот скрипт."
say "Вариант 2 — вставить вручную:"
say ""
say "  a) Секрет UNITY_LICENSE: откройте файл и скопируйте всё содержимое"
say "     cat $ULF"
say "     (в терминале Codespaces: долгое нажатие -> Select All -> Copy)"
say "  b) Страница Settings -> Secrets and variables -> Actions:"
say "     https://github.com/$REPO/settings/secrets/actions"
say "  c) Добавьте UNITY_EMAIL и UNITY_PASSWORD вручную (это короткие строки)."
say ""
say "Ничего не удаляйте и не обрезайте: незакрытый XML = ошибка активации в CI."
exit 1
