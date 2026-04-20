#!/usr/bin/env bash
# Интерактивная установка: клон репозитория (если нужно), .env, venv, опционально systemd.
#
# Запуск из уже склонированного репозитория:
#   chmod +x install.sh && ./install.sh
#
# Одна команда с GitHub (логин или org; репозиторий по умолчанию telegram-join-gif-bot; ниже — lyakich):
#   curl -fsSL https://raw.githubusercontent.com/lyakich/telegram-join-gif-bot/main/install.sh | bash -s -- lyakich
#
# Полная форма owner/repo и каталог установки:
#   curl -fsSL https://raw.githubusercontent.com/lyakich/telegram-join-gif-bot/main/install.sh | bash -s -- lyakich/telegram-join-gif-bot /opt/telegram-join-gif-bot
#
# Репозиторий по умолчанию из окружения (если не передан аргумент):
#   curl ... | env GITHUB_REPO=lyakich/telegram-join-gif-bot bash
#
# На минимальной Ubuntu без python3-venv:
#   TG_JOIN_GIF_APT_INSTALL=1 curl ... | bash -s -- lyakich
#
# Без запросов (CI):
#   TG_JOIN_GIF_NONINTERACTIVE=1 BOT_TOKEN=... WELCOME_GIF_FILE_ID=... bash install.sh

set -euo pipefail

REPO_SLUG="telegram-join-gif-bot"

# При «curl … | bash» stdin = скрипт; read съедает строки кода → обрыв парсера и ошибки у «fi».
# Все интерактивные вопросы читаем с терминала.
read_tty() {
  if [[ -r /dev/tty ]] && [[ -w /dev/tty ]]; then
    read "$@" </dev/tty
  else
    read "$@"
  fi
}

is_truthy() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|y|yes|true|on) return 0 ;;
    *) return 1 ;;
  esac
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Не найдена команда «$1». Установите её и повторите запуск." >&2
    exit 1
  }
}

ensure_python() {
  need_cmd python3
  python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' || {
    echo "Нужен Python 3.10 или новее. Сейчас: $(python3 -V 2>&1)" >&2
    exit 1
  }
}

normalize_owner_repo() {
  local in="${1:-}"
  in="${in//[[:space:]]/}"
  [[ -n "$in" ]] || {
    echo ""
    return
  }
  if [[ "$in" == */* ]]; then
    echo "$in"
  else
    echo "${in}/${REPO_SLUG}"
  fi
}

maybe_install_apt_deps() {
  is_truthy "${TG_JOIN_GIF_APT_INSTALL:-}" || return 0
  [[ "$(uname -s)" == Linux ]] || return 0
  command -v apt-get >/dev/null 2>&1 || return 0
  echo "TG_JOIN_GIF_APT_INSTALL=1 — ставлю пакеты через apt-get…"
  if [[ "$(id -u)" -eq 0 ]]; then
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      python3 python3-venv python3-pip git curl ca-certificates
  else
    need_cmd sudo
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
      python3 python3-venv python3-pip git curl ca-certificates
  fi
}

probe_venv() {
  local t
  t="$(mktemp -d)"
  trap 'rm -rf "$t"' RETURN
  if python3 -m venv "$t/v" >/dev/null 2>&1; then
    return 0
  fi
  echo "Не удалось создать venv (python3 -m venv)." >&2
  if [[ "$(uname -s)" == Linux ]] && command -v apt-get >/dev/null 2>&1; then
    echo "На Debian/Ubuntu выполните: sudo apt install -y python3-venv" >&2
    echo "Или перезапустите скрипт с: TG_JOIN_GIF_APT_INSTALL=1" >&2
  fi
  return 1
}

repo_root_from_script() {
  local src="${BASH_SOURCE[0]:-}"
  case "$src" in
    "" | - | bash | */bash) return 1 ;;
  esac
  local d
  d="$(cd "$(dirname "$src")" && pwd)" || return 1
  if [[ -f "$d/bot.py" ]]; then
    echo "$d"
    return 0
  fi
  return 1
}

suggest_github_repo() {
  if [[ -n "${GITHUB_REPO:-}" ]]; then
    echo "$GITHUB_REPO"
    return
  fi
  local u
  u="$(git config --global github.user 2>/dev/null || true)"
  if [[ -n "$u" ]]; then
    echo "${u}/${REPO_SLUG}"
  else
    echo ""
  fi
}

clone_or_update_repo() {
  local target="$1" owner_repo="$2"
  local url="https://github.com/${owner_repo}.git"

  if [[ -d "$target/.git" ]]; then
    echo "Каталог уже есть: $target — выполняю git pull…"
    git -C "$target" pull --ff-only
    return
  fi
  if [[ -e "$target" ]]; then
    echo "Каталог «$target» существует и это не git-репозиторий. Удалите его или укажите другой путь." >&2
    exit 1
  fi
  echo "Клонирую $url → $target …"
  git clone "$url" "$target"
}

write_env_file() {
  local root="$1" out="$1/.env"
  umask 077
  {
    printf 'BOT_TOKEN=%s\n\n' "$BOT_TOKEN"
    printf 'WELCOME_GIF_FILE_ID=%s\n' "${WELCOME_GIF_FILE_ID:-}"
    printf 'WELCOME_GIF_URL=%s\n\n' "${WELCOME_GIF_URL:-}"
    printf 'ECHO_FILE_ID_MODE=%s\n' "${ECHO_FILE_ID_MODE:-0}"
    printf 'ECHO_ALLOWED_USER_IDS=%s\n' "${ECHO_ALLOWED_USER_IDS:-}"
  } >"$out"
  chmod 600 "$out"
  echo "Записан файл $out (права 600)."
}

install_venv() {
  local root="$1"
  need_cmd python3
  echo "Создаю виртуальное окружение…"
  python3 -m venv "$root/.venv"
  "$root/.venv/bin/pip" install -q --upgrade pip
  "$root/.venv/bin/pip" install -q -r "$root/requirements.txt"
  echo "Зависимости установлены в $root/.venv"
}

install_systemd() {
  local root="$1"
  local user="${SUDO_USER:-$USER}"
  local svc="/etc/systemd/system/${REPO_SLUG}.service"
  local py="$root/.venv/bin/python"
  local bot="$root/bot.py"

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemctl не найден — пропускаю unit systemd." >&2
    return 1
  fi
  if [[ ! -d /run/systemd/system && ! -d /usr/lib/systemd/system ]]; then
    echo "Похоже, это не система с systemd — пропускаю unit." >&2
    return 1
  fi

  echo "Создаю systemd-сервис (нужен sudo)…"
  sudo tee "$svc" >/dev/null <<EOF
[Unit]
Description=Telegram join GIF bot (${REPO_SLUG})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${user}
Group=${user}
WorkingDirectory=${root}
ExecStart=${py} ${bot}
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable --now "${REPO_SLUG}.service"
  echo "Сервис запущен: systemctl status ${REPO_SLUG}.service"
  echo "Логи: journalctl -u ${REPO_SLUG}.service -f"
}

interactive_wizard() {
  local root="$1"

  if [[ -n "${TG_JOIN_GIF_NONINTERACTIVE:-}" ]]; then
    : "${BOT_TOKEN:?Задайте BOT_TOKEN для режима без запросов}"
    if [[ -z "${WELCOME_GIF_FILE_ID:-}" && -z "${WELCOME_GIF_URL:-}" ]]; then
      if ! is_truthy "${ECHO_FILE_ID_MODE:-}"; then
        echo "Нужен WELCOME_GIF_FILE_ID или WELCOME_GIF_URL, либо ECHO_FILE_ID_MODE=1." >&2
        exit 1
      fi
    fi
    write_env_file "$root"
    return
  fi

  local token gif_id gif_url echo_mode echo_ids yn

  if [[ -z "${BOT_TOKEN:-}" ]]; then
    read_tty -rsp "Введите BOT_TOKEN от @BotFather (ввод скрыт): " token
    echo ""
    BOT_TOKEN="$token"
  fi
  [[ -n "${BOT_TOKEN:-}" ]] || {
    echo "BOT_TOKEN не может быть пустым." >&2
    exit 1
  }

  echo ""
  echo "Приветственная гифка для группы:"
  read_tty -rp "Уже есть WELCOME_GIF_FILE_ID? Вставьте или Enter, чтобы пропустить: " gif_id
  WELCOME_GIF_FILE_ID="${gif_id:-}"
  if [[ -z "$WELCOME_GIF_FILE_ID" ]]; then
    read_tty -rp "Или WELCOME_GIF_URL (HTTPS)? Enter — пропустить: " gif_url
    WELCOME_GIF_URL="${gif_url:-}"
  else
    WELCOME_GIF_URL=""
  fi

  if [[ -z "$WELCOME_GIF_FILE_ID" && -z "${WELCOME_GIF_URL:-}" ]]; then
    read_tty -rp "Гифка пока не задана. Включить ECHO_FILE_ID_MODE для получения file_id в личке? [y/N]: " yn
    if is_truthy "$yn"; then
      ECHO_FILE_ID_MODE=1
      read_tty -rp "Ограничить эхо списком user id (через запятую)? Enter — без ограничения: " echo_ids
      ECHO_ALLOWED_USER_IDS="${echo_ids:-}"
    else
      ECHO_FILE_ID_MODE=0
      ECHO_ALLOWED_USER_IDS=""
      echo "Без гифки и без эхо бот не сможет стартовать. Завершите настройку .env вручную." >&2
    fi
  else
    read_tty -rp "Включить ECHO_FILE_ID_MODE (получение file_id в личке)? [y/N]: " yn
    if is_truthy "$yn"; then
      ECHO_FILE_ID_MODE=1
      read_tty -rp "ECHO_ALLOWED_USER_IDS (через запятую)? Enter — без ограничения: " echo_ids
      ECHO_ALLOWED_USER_IDS="${echo_ids:-}"
    else
      ECHO_FILE_ID_MODE=0
      ECHO_ALLOWED_USER_IDS=""
    fi
  fi

  if [[ -z "${WELCOME_GIF_FILE_ID:-}" && -z "${WELCOME_GIF_URL:-}" ]]; then
    if ! is_truthy "${ECHO_FILE_ID_MODE:-0}"; then
      echo "Нужны WELCOME_GIF_FILE_ID или WELCOME_GIF_URL, либо включите ECHO_FILE_ID_MODE." >&2
      exit 1
    fi
  fi

  write_env_file "$root"
}

# --- main flow ---
need_cmd git
ensure_python
maybe_install_apt_deps

ROOT=""
if ROOT="$(repo_root_from_script 2>/dev/null)"; then
  :
elif [[ -f ./bot.py ]]; then
  ROOT="$(pwd)"
else
  OWNER_REPO="$(normalize_owner_repo "${1:-${GITHUB_REPO:-}}")"
  INSTALL_DIR="${2:-$HOME/$REPO_SLUG}"

  if [[ -z "$OWNER_REPO" ]]; then
    sug="$(suggest_github_repo)"
    if [[ -n "$sug" ]]; then
      read_tty -rp "GitHub: логин/org [${sug%%/*}] или полностью owner/repo [${sug}]: " ans
      ans="${ans:-$sug}"
      OWNER_REPO="$(normalize_owner_repo "$ans")"
    else
      read_tty -rp "GitHub логин/org (будет клон ${REPO_SLUG}) или owner/repo: " ans
      OWNER_REPO="$(normalize_owner_repo "$ans")"
    fi
  fi
  [[ -n "$OWNER_REPO" ]] || {
    echo "Укажите репозиторий: аргумент (логин GitHub или owner/repo), либо переменную GITHUB_REPO." >&2
    exit 1
  }
  [[ "$OWNER_REPO" == */* ]] || {
    echo "Внутренняя ошибка: ожидался owner/repo, получено: $OWNER_REPO" >&2
    exit 1
  }

  if [[ -z "${2:-}" ]]; then
    read_tty -rp "Каталог установки [${INSTALL_DIR}]: " ans
    INSTALL_DIR="${ans:-$INSTALL_DIR}"
  fi

  clone_or_update_repo "$INSTALL_DIR" "$OWNER_REPO"
  ROOT="$(cd "$INSTALL_DIR" && pwd)"
fi

cd "$ROOT"
echo "Корень проекта: $ROOT"
probe_venv || exit 1

interactive_wizard "$ROOT"
install_venv "$ROOT"

if [[ -n "${TG_JOIN_GIF_NONINTERACTIVE:-}" ]]; then
  if is_truthy "${TG_JOIN_GIF_SYSTEMD:-}"; then
    install_systemd "$ROOT" || true
  fi
  echo "Готово. Запуск: cd \"$ROOT\" && .venv/bin/python bot.py"
  exit 0
fi

read_tty -rp "Установить и запустить systemd-сервис (Linux с systemd)? [y/N]: " yn
if is_truthy "$yn"; then
  if install_systemd "$ROOT"; then
    echo "Готово. Бот работает как systemd-сервис."
  else
    read_tty -rp "Запустить бота сейчас в foreground (Ctrl+C — остановить)? [y/N]: " yn2
    if is_truthy "$yn2"; then
      exec "$ROOT/.venv/bin/python" "$ROOT/bot.py"
    else
      echo "Запуск вручную: cd \"$ROOT\" && .venv/bin/python bot.py"
    fi
  fi
else
  read_tty -rp "Запустить бота сейчас в foreground (Ctrl+C — остановить)? [y/N]: " yn2
  if is_truthy "$yn2"; then
    exec "$ROOT/.venv/bin/python" "$ROOT/bot.py"
  else
    echo "Запуск вручную: cd \"$ROOT\" && .venv/bin/python bot.py"
  fi
fi
