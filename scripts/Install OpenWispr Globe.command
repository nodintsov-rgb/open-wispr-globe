#!/bin/bash
set -euo pipefail

APP_NAME='OpenWispr Globe.app'
RELEASE='0.49.0-globe.2'
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SOURCE_DIR/$APP_NAME"

finish() {
    result=$?
    if [[ "$result" -ne 0 ]]; then
        printf '\nУстановка остановлена. Существующие приложения, настройки и модели не удалены.\n'
    fi
    if [[ -t 0 ]]; then
        printf '\nНажмите Enter, чтобы закрыть окно.'
        read -r _ </dev/tty || true
    fi
}
trap finish EXIT

fail() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || fail 'Нужен Mac.'
ARCH="$(uname -m)"
[[ "$ARCH" == arm64 || "$ARCH" == x86_64 ]] || fail 'Поддерживаются Apple Silicon и Intel Mac.'
if [[ "$ARCH" == x86_64 && "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]]; then
    fail 'На Apple Silicon откройте обычный Терминал без Rosetta и запустите установщик снова.'
fi
OS_VERSION="$(sw_vers -productVersion)"
[[ "${OS_VERSION%%.*}" -ge 15 ]] || fail 'Для автоматической установки нужен macOS 15 или новее.'
[[ "$(id -u)" -ne 0 ]] || fail 'Запустите установщик обычным пользователем, без sudo.'
[[ -d "$SOURCE_APP" ]] || fail 'Приложение не найдено рядом с установщиком.'
codesign --verify --deep --strict "$SOURCE_APP" || fail 'Проверка подписи приложения не прошла.'

if [[ "${1:-}" == --check ]]; then
    printf 'Совместимость: OK. Архитектура: %s. Версия: %s. Ничего не установлено.\n' "$ARCH" "$RELEASE"
    exit 0
fi
[[ "${1:-}" == '' ]] || fail 'Неизвестный параметр. Допустим только --check.'

if [[ "$ARCH" == arm64 ]]; then
    BREW=/opt/homebrew/bin/brew
else
    BREW=/usr/local/bin/brew
fi

printf '\n[1/3] Проверяем Homebrew и whisper.cpp\n'
if [[ ! -x "$BREW" ]]; then
    [[ -r /dev/tty && -w /dev/tty ]] || fail 'Для установки Homebrew нужен обычный Терминал.'
    printf 'Установится Homebrew с официального сайта. Он может запросить пароль Mac.\n'
    BREW_INSTALLER="$(mktemp "${TMPDIR:-/tmp}/openwispr-homebrew.XXXXXX")"
    curl --fail --location --silent --show-error --retry 2 \
        'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' -o "$BREW_INSTALLER"
    /bin/bash "$BREW_INSTALLER" </dev/tty
fi
[[ -x "$BREW" ]] || fail 'Homebrew не установлен. Проверьте сообщения выше.'
eval "$("$BREW" shellenv)"
if [[ ! -x "$("$BREW" --prefix)/bin/whisper-cli" ]]; then
    HOMEBREW_NO_AUTO_UPDATE=1 "$BREW" install whisper-cpp
fi
[[ -x "$("$BREW" --prefix)/bin/whisper-cli" ]] || fail 'whisper-cli не найден после установки.'

printf '\n[2/3] Копируем приложение\n'
mkdir -p "$HOME/Applications"
TARGET="$HOME/Applications/OpenWispr Globe ${RELEASE} Universal.app"
if [[ -e "$TARGET" || -L "$TARGET" ]]; then
    if ! diff -qr "$SOURCE_APP" "$TARGET" >/dev/null 2>&1; then
        TARGET="$HOME/Applications/OpenWispr Globe ${RELEASE}-$(date +%Y%m%d-%H%M%S).app"
        [[ ! -e "$TARGET" && ! -L "$TARGET" ]] || fail 'Папка установки уже существует. Повторите запуск через минуту.'
    fi
fi
if [[ ! -e "$TARGET" ]]; then
    ditto "$SOURCE_APP" "$TARGET"
fi
codesign --verify --deep --strict "$TARGET" || fail 'Проверка установленного приложения не прошла.'

printf '\n[3/3] Открываем приложение\n'
printf 'Приложение: %s\n' "$TARGET"
if pgrep -x open-wispr >/dev/null; then
    printf 'OpenWispr уже запущен. Закройте прежнюю копию, затем откройте:\n%s\n' "$TARGET"
    printf 'При первом запуске новой копии выберите «Включить автозапуск».\n'
    exit 0
fi
printf 'При первом открытии выберите «Включить автозапуск».\n'
printf 'Разрешите микрофон и «Универсальный доступ» в настройках macOS.\n'
printf 'Если macOS блокирует независимую сборку, проверьте источник и разрешите её в «Конфиденциальность и безопасность».\n'
printf 'При первом запуске программа загрузит модель. Дождитесь статуса Ready.\n'
if ! open -n "$TARGET"; then
    printf 'Приложение установлено. Завершите разрешение запуска и откройте его из папки Applications вашего пользователя.\n'
fi
