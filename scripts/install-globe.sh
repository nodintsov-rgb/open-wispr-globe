#!/bin/bash
set -euo pipefail

APP_NAME='OpenWispr Globe Universal.app'
RELEASE='0.49.0-globe.10'
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SOURCE_DIR/$APP_NAME"

fail() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || fail 'Нужен Mac.'
ARCH="$(uname -m)"
[[ "$ARCH" == arm64 || "$ARCH" == x86_64 ]] || fail 'Поддерживаются Apple Silicon и Intel Mac.'
if [[ "$ARCH" == x86_64 && "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]]; then
    fail 'На Apple Silicon отключите «Открывать с помощью Rosetta» в свойствах установщика и запустите его снова.'
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
    exit 20
fi
eval "$("$BREW" shellenv)"
if [[ ! -x "$("$BREW" --prefix)/bin/whisper-cli" ]]; then
    HOMEBREW_NO_AUTO_UPDATE=1 "$BREW" install whisper-cpp
fi
[[ -x "$("$BREW" --prefix)/bin/whisper-cli" ]] || fail 'whisper-cli не найден после установки.'

printf '\n[2/3] Копируем приложение\n'
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
