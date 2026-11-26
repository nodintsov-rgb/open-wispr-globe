# OpenWispr Globe Edition

**Никита Одинцов · ATHEYA.org**

**Создано Atheya.Org · Created by Atheya.Org**

**Лицензия: [MIT](LICENSE). При распространении доработок сохраняйте уведомление об авторстве Atheya.Org (https://atheya.org) и human37 вместе с текстом лицензии. [Подробности / Attribution](NOTICE.md).**

Local dictation for macOS, developed by Nikita Odintsov / ATHEYA.org.

Based on [human37/open-wispr v0.49.0](https://github.com/human37/open-wispr/tree/v0.49.0), with the original MIT license retained.

Release: **0.49.0-globe.2**. The app reports version 0.49.0. This release includes upstream fixes for automatic pasting in Firefox and for applying custom vocabulary and prompt hints.

## Globe behaviour

- A short Globe/Fn tap does not start recording. macOS can keep using it to switch input languages.
- Holding Globe for **350 ms** starts dictation. Begin speaking after the recording indicator appears.
- Releasing Globe stops recording.
- Duplicate Fn state events are ignored. Fn plus another key during the delay cancels pending recording.
- Toggle mode and other hotkeys retain their upstream behaviour.

Language switching is controlled by macOS: Keyboard → “Press Globe key to” → Change Input Source. Keyboard layouts and macOS versions may behave differently.

Place a text cursor in the destination field, including Electron/Chromium editors, before recording.

## Install

[Download the installer DMG](https://github.com/nodintsov-rgb/open-wispr-globe/releases/download/v0.49.0-globe.2/OpenWispr-Globe-0.49.0-globe.2-installer.dmg) · [SHA-256](https://github.com/nodintsov-rgb/open-wispr-globe/releases/download/v0.49.0-globe.2/OpenWispr-Globe-0.49.0-globe.2-installer.dmg.sha256) · [Hugging Face mirror](https://huggingface.co/spaces/ATHEYA/open-wispr-globe)

1. Open the DMG on an Apple Silicon or Intel Mac running macOS 15 or newer.
2. Double-click **Установить OpenWispr Globe**. The installer opens Terminal and prepares Homebrew and whisper.cpp if needed.
3. Open the installed copy from your Applications folder if another copy was running. Choose whether to start at login, then grant Microphone and Accessibility when macOS asks.

The login option is also available under **Запускать при входе** in the menu bar. The installer and app have local ad-hoc signatures. macOS may ask for launch approval. The installer contains the MIT license and Atheya.Org attribution. The first model download requires internet access.

## Build from source

Requires Apple command line developer tools with Swift 5.9 or newer:

```sh
swift build -c release --disable-sandbox
bash scripts/bundle-app.sh .build/release/open-wispr 'OpenWispr Globe.app' 0.49.0
```

Run the standalone hotkey checks:

```sh
swiftc Sources/OpenWisprLib/HotkeyManager.swift GlobeHotkeyCheck.swift -o /tmp/openwispr-globe-check
/tmp/openwispr-globe-check
```

## Validation and limits

Release compilation, ad-hoc signature verification and six deterministic Globe scenarios passed on the publisher's Apple Silicon Mac. The app reached Ready and captured microphone audio there. This is not a claim of testing every Mac, keyboard, macOS release or destination editor. Full XCTest was not run because the local command line toolchain did not provide XCTest.

The delay distinguishes a tap from a hold; it does not detect silence. Check the physical microphone mute button if transcription is empty or produces a hallucinated phrase.

## Attribution and license

Original OpenWispr: **human37**, copyright © 2026 human37. Globe edition modifications and installer: copyright © 2026 **Nikita Odintsov / Atheya.Org (https://atheya.org)**. Both are distributed under the included [MIT license](LICENSE).

When redistributing modified copies containing these contributions, preserve both copyright notices (human37 and Atheya.Org) and the full MIT permission notice with copies or substantial portions. See [NOTICE.md](NOTICE.md). This is MIT attribution, not an additional interface-branding requirement.

The edition is developed and distributed in accordance with upstream MIT permissions. There is no separately confirmed agreement or endorsement by the original author. This is an independent community derivative, not an official release or endorsement by human37, OpenAI, Apple or Hugging Face. Whisper model weights and whisper.cpp have their own upstream distribution and licenses.

Globe edition and installer: **Создано Atheya.Org / Created by Atheya.Org**. This credit identifies the community edition and installer; original upstream copyright and MIT license are retained.

## По-русски

**Автор: Никита Одинцов · ATHEYA.org.** Для Apple Silicon и Intel Mac доступен универсальный DMG выше. Пароль Mac, разрешения микрофона и «Универсального доступа» подтверждаются только в системных окнах.

Неофициальная сборка OpenWispr 0.49.0 с доработкой Globe. Короткое нажатие оставлено macOS для переключения языка; удержание 350 мс начинает запись, отпускание завершает её. Говорите после появления индикатора записи. После распаковки установите whisper-cpp и разрешите приложению микрофон и «Универсальный доступ». Универсальный DMG для Apple Silicon и Intel, с локальной подписью, без notarization Apple. Модели скачиваются отдельно; личных настроек и записей в архиве нет.
