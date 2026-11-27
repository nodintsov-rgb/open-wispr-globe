#!/bin/bash
set -euo pipefail

APP_NAME='OpenWispr Globe Universal.app'
RELEASE='0.49.0-globe.12'
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SOURCE_DIR/$APP_NAME"

fail() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || fail 'Нужен Mac.'
ARCH="$(uname -m)"
[[ "$ARCH" == arm64 || "$ARCH" == x86_64 ]] || fail 'Поддерживаются Apple Silicon и Intel Mac.'
OS_VERSION="$(sw_vers -productVersion)"
[[ "${OS_VERSION%%.*}" -ge 15 ]] || fail 'Для автоматической установки нужен macOS 15 или новее.'
[[ "$(id -u)" -ne 0 ]] || fail 'Запустите установщик обычным пользователем, без sudo.'
[[ -d "$SOURCE_APP" ]] || fail 'Приложение не найдено рядом с установщиком.'
[[ -x "$SOURCE_APP/Contents/Helpers/whisper-cli" ]] || fail 'В комплекте отсутствует движок распознавания.'
codesign --verify --deep --strict "$SOURCE_APP" || fail 'Проверка подписи приложения не прошла.'

if [[ "${1:-}" == --check ]]; then
    printf 'Совместимость: OK. Архитектура: %s. Версия: %s. Ничего не установлено.\n' "$ARCH" "$RELEASE"
    exit 0
fi
[[ "${1:-}" == '' ]] || fail 'Неизвестный параметр. Допустим только --check.'

printf '\nКопируем OpenWispr Globe Universal\n'
mkdir -p "$HOME/Applications"
TARGET="$HOME/Applications/$APP_NAME"
if [[ -e "/Applications/$APP_NAME" || -L "/Applications/$APP_NAME" ]]; then
    TARGET="/Applications/$APP_NAME"
fi
if [[ -L "$TARGET" ]]; then
    fail "На месте приложения находится ссылка. Уберите её через Finder и повторите установку."
elif [[ -e "$TARGET" ]] && ! diff -qr "$SOURCE_APP" "$TARGET" >/dev/null 2>&1; then
    printf '\0%s\0' "$TARGET"
    exit 22
elif [[ ! -e "$TARGET" ]]; then
    ditto "$SOURCE_APP" "$TARGET"
fi
codesign --verify --deep --strict "$TARGET" || fail 'Проверка установленного приложения не прошла.'

# Mark the installed path separately from the diagnostic output.
printf '\0%s\0' "$TARGET"
