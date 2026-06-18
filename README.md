# vaultwatch

Честный сторож открытого vault — часть экосистемы [Paranoid Tools](https://github.com/Di-kairos/paranoid-tools).

`vaultwatch` активен **только пока vault примонтирован**. Он сужает каналы, по которым
открытый plaintext может утечь (Spotlight, Time Machine), и **восстанавливает всё при
закрытии**. Запускается автоматически из хуков `securetrash vault open/close`.

> **Статус: ранний (v0.1.0, work in progress).** Сейчас готов слой интеграции:
> установка хуков + вендоринг общего ядра. Сторожевая логика (`start`/`stop`,
> mdutil/tmutil, cloud-detect, `--ttl`, session report) — в следующих паках.

## Установка хуков

```bash
vaultwatch install-hooks      # подключить к securetrash vault open/close
vaultwatch uninstall-hooks    # убрать (только свои managed-хуки)
```

Хуки кладутся в `${ST_HOOK_DIR:-~/.securetrash/hooks}` — тот же каталог, который читает
`securetrash`. Чужие (не-managed) хуки `vaultwatch` не трогает.

## Архитектура

- Single-file Bash, ноль зависимостей. Нативные примитивы macOS.
- Общее ядро (`lib/common.sh`) **вендорится** из securetrash inline, пиннуто к git-ref;
  `tools/vendor-common.sh --check` ловит дрейф в CI. См. `paranoid-tools/README.md`.

## Scope & limitations

> Раздел будет дополнен по мере реализации ядра. Базовый принцип экосистемы: честно про
> пределы. vaultwatch делает **обратимые** исключения на время сессии и **не**:
> - не закрывает swap (фрагменты plaintext могли уйти в swap при memory pressure);
> - не удаляет уже снятые локальные снапшоты Time Machine;
> - не редактирует настройки облаков и не удаляет чужие бэкапы;
> - cloud-детект эвристичен (сообщает «обнаружены демоны X, Y», не телепатия).

## Windows-эквивалент

Планируется: эквивалент через VSS (shadow copies), Windows Search indexer и контроль
pagefile/OneDrive. Порт — во вторую очередь, как у securetrash.
