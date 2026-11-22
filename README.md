# OpenWispr Globe Edition

**Никита Одинцов · ATHEYA.org**

**Создано Atheya.Org · Created by Atheya.Org**

**Лицензия: [MIT](LICENSE). При распространении доработок сохраняйте уведомление об авторстве Atheya.Org (https://atheya.org) и human37 вместе с текстом лицензии. [Подробности / Attribution](NOTICE.md).**

Local dictation for macOS, developed by Nikita Odintsov / ATHEYA.org.

Based on [human37/open-wispr v0.48.0](https://github.com/human37/open-wispr/tree/v0.48.0), with the original MIT license retained.

Release: **0.48.0-globe.2**. The app reports version 0.48.0.

## Globe behaviour

- A short Globe/Fn tap does not start recording. macOS can keep using it to switch input languages.
- Holding Globe for **350 ms** starts dictation. Begin speaking after the recording indicator appears.
- Releasing Globe stops recording.
- Duplicate Fn state events are ignored. Fn plus another key during the delay cancels pending recording.
- Toggle mode and other hotkeys retain their upstream behaviour.

Language switching is controlled by macOS: Keyboard → “Press Globe key to” → Change Input Source. Keyboard layouts and macOS versions may behave differently.

Place a text cursor in the destination field, including Electron/Chromium editors, before recording.

## Downloads

[Hugging Face download page](https://huggingface.co/spaces/ATHEYA/open-wispr-globe)

**Apple Silicon and Intel Mac:** [Download the universal DMG](https://github.com/nodintsov-rgb/open-wispr-globe/releases/download/v0.48.0-globe.2/OpenWispr-Globe-0.48.0-globe.2-universal-licensed.dmg). Open the included installer on macOS 15+; it prepares Homebrew and `whisper-cpp`. [SHA-256](https://github.com/nodintsov-rgb/open-wispr-globe/releases/download/v0.48.0-globe.2/OpenWispr-Globe-0.48.0-globe.2-universal-licensed.dmg.sha256). The Intel build has not been tested on a physical Intel Mac.

### Install with one command

The recommended DMG bundles the full MIT license with human37 and Nikita Odintsov / Atheya.Org attribution (`LICENSE.txt` / `LICENSE-Atheya.Org.txt`), `NOTICE.txt`, and `Создано Atheya.Org.txt` alongside the app. The 22 November 2026 packaging update leaves the app and installer unchanged.

On an **Apple Silicon Mac with macOS 15 or newer**, paste this into Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/nodintsov-rgb/open-wispr-globe/main/install.sh | /bin/bash
```

Homebrew is installed automatically if missing, using its official installer. It may ask for your Mac password and Enter confirmation. The script installs whisper.cpp if needed, checks the pinned app ZIP checksum, installs into your user Applications folder, stops only an older Homebrew OpenWispr service if present, and opens the app. Existing app copies, configuration and models are preserved. If the install path already contains a different copy, a new timestamped path is used. Re-running is supported.

Prefer a double-click? Download [Install-OpenWispr-Globe.command.zip](https://github.com/nodintsov-rgb/open-wispr-globe/releases/download/v0.48.0-globe.2/Install-OpenWispr-Globe.command.zip), extract it and open the `.command` file. It contains the same installer. macOS may require your approval to open a downloaded script. You can also [read install.sh](install.sh) before running it or run `bash install.sh --check` for a compatibility-only check.

The installer displays Russian progress messages. **Microphone, Accessibility and any macOS launch approval must be confirmed by you**. The script does not disable Gatekeeper, remove quarantine attributes, or grant permissions automatically. It opens the app once; it does not create an additional login service. A first model download can take time. The automatic installation route follows Homebrew's macOS 15+ support; the app itself still targets macOS 13+.

### Manual installation

Download `OpenWispr-0.48.0-Globe.2-arm64.zip`. Extract it and place `OpenWispr 0.48.0 Globe.app` in your Applications folder. This ZIP is **Apple Silicon / arm64 only**, built for macOS 13 or newer. For Intel Macs, use the universal DMG above.

The app has an **ad-hoc local signature**, no Developer ID signature and **no Apple notarization**. macOS may block opening it; review the source and checksum before deciding whether to permit it in Privacy & Security. This repository does not provide commands to disable Gatekeeper.

Install the external transcription dependency if needed:

```sh
brew install whisper-cpp
```

If you already run another OpenWispr through Homebrew, stop that service before launching this copy:

```sh
brew services stop open-wispr
```

Open the app from Finder, then grant **Microphone** and **Accessibility** in macOS Privacy & Security. After replacing a build, you may need to re-add the exact new app bundle in Accessibility. The first run downloads the configured Whisper model; model weights are **not included** in the ZIP. Downloads require internet access. Audio transcription runs locally through whisper.cpp.

Existing OpenWispr configuration and models in `~/.config/open-wispr` are reused. This release does not bundle the publisher's settings, recordings or models. Do not run the Homebrew and downloaded copies simultaneously. A Homebrew upgrade does not install this edition.

## Build from source

Requires Apple command line developer tools with Swift 5.9 or newer:

```sh
swift build -c release --disable-sandbox
bash scripts/bundle-app.sh .build/release/open-wispr 'OpenWispr Globe.app' 0.48.0
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

Неофициальная сборка OpenWispr 0.48.0 с доработкой Globe. Короткое нажатие оставлено macOS для переключения языка; удержание 350 мс начинает запись, отпускание завершает её. Говорите после появления индикатора записи. После распаковки установите whisper-cpp и разрешите приложению микрофон и «Универсальный доступ». Сборка для Apple Silicon, с локальной подписью, без notarization Apple. Модели скачиваются отдельно; личных настроек и записей в архиве нет.
