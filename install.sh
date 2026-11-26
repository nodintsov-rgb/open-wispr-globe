#!/bin/bash
# OpenWispr Globe Edition — Создано Atheya.Org
# Copyright (c) 2026 Atheya.Org (https://atheya.org), installer; MIT license.
# Original OpenWispr: copyright (c) 2026 human37, MIT license.
# Preserve both copyright notices and the MIT license when redistributing copies.
# Full license: https://github.com/nodintsov-rgb/open-wispr-globe/blob/main/LICENSE
set -euo pipefail

RELEASE='0.49.0-globe.10'
ASSET='OpenWispr-Globe-Universal.dmg'
SHA256='7c3ca3031fa10f2e778dd94e1aacb1b93f5c409fd8f843c1dc2ddd5d928ec987'
GITHUB_BASE="https://github.com/nodintsov-rgb/open-wispr-globe/releases/download/v$RELEASE"
HF_BASE="https://huggingface.co/spaces/ATHEYA/open-wispr-globe/resolve/main/downloads/v$RELEASE"

fail() { printf '%s\n' "$*" >&2; exit 1; }

case "${1:-}" in
    --help|-h)
        printf '%s\n' 'OpenWispr Globe Universal · Создано Atheya.Org' \
            'Запуск установщика: bash install.sh' \
            'Проверка совместимости: bash install.sh --check' \
            'Скачать и проверить DMG без запуска: bash install.sh --download-only'
        exit 0 ;;
    ''|--check|--download-only) ;;
    *) fail "Неизвестный параметр: $1. Используйте --help." ;;
esac

[[ "$(uname -s)" == Darwin ]] || fail 'Установщик работает на macOS.'
version="$(sw_vers -productVersion)"
[[ "${version%%.*}" -ge 15 ]] || fail 'Для установщика требуется macOS 15 или новее.'
[[ "$(id -u)" -ne 0 ]] || fail 'Запустите установщик без sudo.'
if [[ "${1:-}" == --check ]]; then
    printf 'Совместимость: OK. Версия: %s. Ничего не скачано и не установлено.\n' "$RELEASE"
    exit 0
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/openwispr-globe.XXXXXX")"
dmg="$work/OpenWispr Globe Universal.dmg"
if ! curl -fL --retry 2 -o "$dmg" "$GITHUB_BASE/$ASSET"; then
    curl -fL --retry 2 -o "$dmg" "$HF_BASE/$ASSET"
fi
printf '%s  %s\n' "$SHA256" "$dmg" | shasum -a 256 -c - || fail 'Контрольная сумма DMG не совпала.'
xattr -w com.apple.quarantine "0081;$(printf '%x' "$(date +%s)");OpenWispr Globe;" "$dmg"
if [[ "${1:-}" == --download-only ]]; then
    printf 'DMG проверен и сохранён: %s\n' "$dmg"
    exit 0
fi
mkdir "$work/volume"
hdiutil attach -readonly -mountpoint "$work/volume" "$dmg"
open "$work/volume/Установить OpenWispr Globe.app"
