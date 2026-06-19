# vaultwatch

Честный сторож открытого vault — часть экосистемы [Paranoid Tools](https://github.com/Di-kairos/paranoid-tools).

`vaultwatch` активен **только пока vault примонтирован**. Он сужает каналы, по которым
открытый plaintext может утечь (Spotlight, Time Machine), и **восстанавливает всё при
закрытии**. Запускается автоматически из хуков `securetrash vault open/close`.

> **Статус: ранний (v0.1.0, work in progress).** Готовы интеграция (хуки + вендоринг)
> и **сторожевое ядро `start`/`stop`** (Spotlight off, Time Machine exclude, cloud-detect,
> session report). Фоновый режим через `launchd` и авто-выход `--ttl` — в следующем паке.

## Использование

```bash
vaultwatch start <mount>      # сторожить открытый vault (обычно из хука post-open)
vaultwatch stop  <mount>      # восстановить всё + session report (из хука post-close)
vaultwatch install-hooks      # подключить к securetrash vault open/close
vaultwatch uninstall-hooks    # убрать (только свои managed-хуки)
```

`start` запоминает прежнее состояние и сужает каналы утечки; `stop` восстанавливает
**ровно то, что менял** `start` (если Spotlight был уже выключен или vault уже исключён
из Time Machine до сессии — `stop` это не трогает), и печатает отчёт сессии.

Хуки кладутся в `${ST_HOOK_DIR:-~/.securetrash/hooks}` — тот же каталог, который читает
`securetrash`. Чужие (не-managed) хуки `vaultwatch` не трогает.

### Session report (пример)

```
vaultwatch — session report
  duration:        24m 18s
  Spotlight:       indexing re-enabled for /Volumes/SecretVault
  Time Machine:    exclusion removed (added by this session)
  cloud daemons:   Dropbox active — vault was OUTSIDE its sync folder
  local snapshots: none observed (tmutil listlocalsnapshots /)
  swap:            NOT addressed (see limitations)
```

## Архитектура

- Single-file Bash, ноль зависимостей. Нативные примитивы macOS.
- Общее ядро (`lib/common.sh`) **вендорится** из securetrash inline, пиннуто к git-ref;
  `tools/vendor-common.sh --check` ловит дрейф в CI. См. `paranoid-tools/README.md`.

## Scope & limitations

Базовый принцип экосистемы: честно про пределы. vaultwatch делает **обратимые**
исключения на время сессии и **не**:

- **не закрывает swap** — если во время сессии была memory pressure, фрагменты plaintext
  могли уйти в swap и остаться там до перезаписи. session report говорит это прямо.
- **не удаляет уже снятые локальные снапшоты** Time Machine: `addexclusion` исключает
  vault на будущее, но снапшоты, снятые до старта, остаются. vaultwatch их обнаруживает
  (`tmutil listlocalsnapshots /`) и сообщает в отчёте — не удаляет молча.
- **не редактирует настройки облаков и не удаляет чужие бэкапы.** cloud-детект эвристичен:
  смотрит запущенные процессы (Dropbox/OneDrive/iCloud/Google Drive) и лежит ли mount
  внутри их синк-папок — сообщает «демон X активен, vault внутри/вне его папки», не телепатия.
- **восстанавливает только своё:** если Spotlight был выключен или vault уже был исключён
  из Time Machine до сессии — `stop` оставляет это как есть, не «чинит» чужое состояние.

## Windows-эквивалент

Планируется: эквивалент через VSS (shadow copies), Windows Search indexer и контроль
pagefile/OneDrive. Порт — во вторую очередь, как у securetrash.
