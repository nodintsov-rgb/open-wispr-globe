#!/bin/bash
# OpenWispr Globe Edition — Создано Atheya.Org
# Original OpenWispr: copyright (c) 2026 human37, MIT license.
set -euo pipefail

RELEASE='0.48.0-globe.2'
ARCHIVE='OpenWispr-0.48.0-Globe.2-arm64.zip'
ARCHIVE_SHA256='5ecbde6100e43fce2faaf19881bb8231268806cc2c6d113ca3348c89a872ab43'
GITHUB_BASE="https://github.com/nodintsov-rgb/open-wispr-globe/releases/download/v${RELEASE}"
HF_BASE='https://huggingface.co/spaces/ATHEYA/open-wispr-globe/resolve/main/downloads'
INSTALL_WORK=''

finish() {
    local result=$?
    if [[ "$result" -ne 0 ]]; then
        printf '\nУстановка остановлена. Повторный запуск безопасен.\n'
        if [[ -n "$INSTALL_WORK" ]]; then
            printf 'Файлы и журнал сохранены: %s\n' "$INSTALL_WORK"
        fi
    fi
    if [[ "$0" == *.command && -t 0 ]]; then
        printf '\nНажмите Enter, чтобы закрыть окно.'
        read -r _ </dev/tty || true
    fi
    exit "$result"
}
trap finish EXIT

fail() { printf '\n%s\n' "$*" >&2; exit 1; }
step() { printf '\n[%s/5] %s\n' "$1" "$2"; }
fetch() {
    curl --fail --location --silent --show-error --retry 2 \
        --connect-timeout 15 --max-time 300 "$1" -o "$2"
}

case "${1:-}" in
    --help|-h)
        printf '%s\n' 'OpenWispr Globe Edition — Создано Atheya.Org' \
            'Запуск: bash install.sh' \
            'Проверка совместимости без установки: bash install.sh --check' \
            'Скачать и проверить приложение без установки: bash install.sh --download-only' \
            'Нужны Mac с Apple Silicon и macOS 15 или новее.'
        exit 0 ;;
    ''|--check|--download-only) ;;
    *) fail "Неизвестный параметр: $1. Используйте --help." ;;
esac

printf '\nOpenWispr Globe Edition\nСоздано Atheya.Org\n'
printf 'Установка приложения и необходимых компонентов.\n'
[[ "$(uname -s)" == Darwin ]] || fail 'Этот установщик работает только на macOS.'
[[ "$(uname -m)" == arm64 ]] || fail 'Нужен Mac с Apple Silicon. Если включена Rosetta, запустите обычный Терминал.'
MACOS_VERSION="$(sw_vers -productVersion)"
[[ "${MACOS_VERSION%%.*}" -ge 15 ]] || fail 'Для автоматической установки нужен macOS 15 или новее. Само приложение можно собрать для macOS 13+.'
[[ "$(id -u)" -ne 0 ]] || fail 'Запустите установщик обычным пользователем, без sudo.'
if [[ "${1:-}" == --check ]]; then
    printf 'Совместимость: OK. Версия: %s. Программа будет установлена в ~/Applications.\n' "$RELEASE"
    printf 'Сейчас ничего не установлено и не загружено.\n'
    exit 0
fi

INSTALL_WORK="$(mktemp -d "${TMPDIR:-/tmp}/openwispr-globe.XXXXXX")"
step 1 'Скачиваем приложение'
if ! fetch "$GITHUB_BASE/$ARCHIVE" "$INSTALL_WORK/$ARCHIVE"; then
    printf 'Пробуем зеркало Hugging Face…\n'
    fetch "$HF_BASE/$ARCHIVE?download=true" "$INSTALL_WORK/$ARCHIVE"
fi
printf '%s  %s\n' "$ARCHIVE_SHA256" "$INSTALL_WORK/$ARCHIVE" | shasum -a 256 -c - >"$INSTALL_WORK/checksum.log" 2>&1 \
    || fail 'Контрольная сумма не совпала. Приложение не установлено.'
ditto -x -k "$INSTALL_WORK/$ARCHIVE" "$INSTALL_WORK/unpacked"
STAGED_APP="$INSTALL_WORK/unpacked/OpenWispr 0.48.0 Globe.app"
codesign --verify --deep --strict "$STAGED_APP" || fail 'Проверка целостности приложения не прошла.'
if [[ "${1:-}" == --download-only ]]; then
    printf '\nАрхив и подпись проверены. Приложение не установлено и не запущено.\nФайлы: %s\n' "$INSTALL_WORK"
    exit 0
fi

step 2 'Проверяем Homebrew'
if [[ ! -x /opt/homebrew/bin/brew ]]; then
    printf 'Homebrew пока нет. Откроется его официальный установщик.\nОн может запросить пароль Mac и подтверждение Enter. Пароль при вводе не отображается.\n'
    [[ -r /dev/tty && -w /dev/tty ]] || fail 'Для установки Homebrew запустите эту команду в обычном Терминале.'
    fetch 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' "$INSTALL_WORK/homebrew-install.sh"
    /bin/bash "$INSTALL_WORK/homebrew-install.sh" </dev/tty
fi
[[ -x /opt/homebrew/bin/brew ]] || fail 'Homebrew не установлен. Проверьте сообщения выше и повторите запуск.'
eval "$(/opt/homebrew/bin/brew shellenv)"

step 3 'Готовим распознавание речи'
if [[ ! -x /opt/homebrew/bin/whisper-cli ]]; then
    printf 'Первая установка может занять несколько минут…\n'
    if ! HOMEBREW_NO_AUTO_UPDATE=1 brew install whisper-cpp >"$INSTALL_WORK/whisper-install.log" 2>&1; then
        tail -n 15 "$INSTALL_WORK/whisper-install.log" >&2
        fail 'Не удалось установить whisper-cpp. Подробности сохранены в журнале.'
    fi
fi
[[ -x /opt/homebrew/bin/whisper-cli ]] || fail 'Не найден whisper-cli после установки.'

step 4 'Устанавливаем OpenWispr'
mkdir -p "$HOME/Applications"
APP_TARGET="$HOME/Applications/OpenWispr Globe ${RELEASE}.app"
if [[ -e "$APP_TARGET" || -L "$APP_TARGET" ]]; then
    if ! diff -qr "$STAGED_APP" "$APP_TARGET" >/dev/null 2>&1; then
        APP_TARGET="$HOME/Applications/OpenWispr Globe ${RELEASE}-$(date +%Y%m%d-%H%M%S).app"
        [[ ! -e "$APP_TARGET" && ! -L "$APP_TARGET" ]] || fail 'Папка установки уже существует. Повторите запуск через минуту.'
    fi
fi
if [[ ! -e "$APP_TARGET" ]]; then
    ditto "$STAGED_APP" "$APP_TARGET"
fi
codesign --verify --deep --strict "$APP_TARGET"
if HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_FROM_API=1 brew list --versions open-wispr >/dev/null 2>&1; then
    # Stop only the older OpenWispr service, after the new bundle is verified.
    brew services stop open-wispr >"$INSTALL_WORK/stop-service.log" 2>&1 \
        || fail 'Не удалось остановить прежнюю службу OpenWispr. Закройте её и повторите установку.'
fi

step 5 'Открываем приложение'
printf 'Приложение: %s\n' "$APP_TARGET"
printf '\nЕсли macOS попросит: разрешите микрофон и «Универсальный доступ».\n'
printf 'Сборка без notarization Apple. Если запуск заблокирован, проверьте\n«Системные настройки → Конфиденциальность и безопасность → Всё равно открыть».\n'
printf 'Первый запуск скачает выбранную модель. Дождитесь Ready.\n'
printf 'Globe: короткое нажатие — системное переключение языка; удержание — диктовка.\n'
printf 'Говорите после появления индикатора записи.\n'
if ! open "$APP_TARGET"; then
    printf '\nПриложение установлено. Завершите разрешение запуска в настройках macOS\nи откройте его из папки Applications вашего пользователя.\n'
fi
printf '\nСоздано Atheya.Org. Основа: human37/open-wispr, лицензия MIT.\n'
