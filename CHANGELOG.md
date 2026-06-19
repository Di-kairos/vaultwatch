# Changelog

Все заметные изменения vaultwatch. Формат — [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
версионирование — [SemVer](https://semver.org/lang/ru/).

## [Unreleased]

## [0.1.0] — 2026-06-19

Первый функциональный срез: честный сторож открытого vault для macOS.

### Added
- **Интеграция с securetrash:** `install-hooks` / `uninstall-hooks` ставят managed
  `post-open`/`post-close` в `${ST_HOOK_DIR:-~/.securetrash/hooks}`, не трогая чужие хуки.
- **Сторожевое ядро `start <mount>`:** запоминает прежнее состояние Spotlight и
  выключает индексацию (`mdutil -i off`); исключает том из Time Machine
  (`tmutil addexclusion`) **только если он ещё не исключён**; эвристический
  cloud-детект (Dropbox/OneDrive/iCloud/Google Drive — процесс + расположение
  синк-папки относительно vault); пишет per-mount session-state.
- **`stop <mount>`:** восстанавливает **ровно то, что менял** `start` (не «чинит»
  чужое состояние) и печатает session report (длительность, Spotlight, Time Machine,
  cloud-демоны, локальные снапшоты, честная строка про swap).
- **Авто-выход `--ttl D`** (`30m`/`2h`/`45s`/`1d`/секунды) через **launchd LaunchAgent**:
  managed one-shot job (`RunAtLoad` → sleep → `_ttl_fire`), виден в `launchctl list`,
  снимается через `bootout`. По истечении: `lsof`-проверка → `hdiutil detach` свободного
  тома, иначе честное предупреждение; `--force` → `detach -force` с подтверждением.
  `stop` отменяет таймер (bootout + удаление plist).
- Вендоринг общего ядра `lib/common.sh` из securetrash inline-маркерами + CI-чек дрейфа.
- Дистрибуция: checksum-verified `install.sh` (бинарь + `SHA256SUMS` с релизного тега),
  `release.yml` собирает ассеты на push тега `v*`.

### Honest limitations
- Не закрывает swap; не удаляет уже снятые локальные снапшоты Time Machine (только
  сообщает о них); cloud-детект эвристичен; `--ttl` не размонтирует том с открытыми
  файлами без `--force`. Подробности — `README.md` «Scope & limitations».

### Tests
- bats 46/46 (12 интеграция/хуки + 22 start/stop + 12 ttl/launchd), shellcheck clean.
- Тесты идут на Linux-CI через PATH-стабы (`uname/mdutil/tmutil/pgrep/lsof/hdiutil/launchctl`).
- Real-device smoke на macOS: start/stop/`--ttl` на живом sparsebundle, launchd
  bootstrap/bootout-цикл, plist валиден (`plutil -lint`).

[Unreleased]: https://github.com/Di-kairos/vaultwatch/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Di-kairos/vaultwatch/releases/tag/v0.1.0
