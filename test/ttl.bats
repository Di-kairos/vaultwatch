# Тесты --ttl авто-выхода (pack 3c): парсинг длительности, планирование в state,
# и _ttl_fire (lsof-чек → hdiutil detach / honest warn). Системные команды —
# стабы через PATH, поэтому тесты идут и на Linux-CI без macOS-тулзов.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../vaultwatch"
  STUBS="${BATS_TEST_DIRNAME}/stubs"
  TMP="$(mktemp -d)"
  mkdir -p "$TMP/Vault"
  MOUNT="$(cd "$TMP/Vault" && pwd -P)"
  export VW_STATE_DIR="$TMP/state"
  export VW_STUB_LOG="$TMP/calls.log"
  export PATH="$STUBS:$PATH"
  export ST_ASSUME_YES=1
  export VW_NO_SPAWN=1   # не плодить реальный sleep-таймер в тестах
  unset ST_LANG
}

teardown() { rm -rf "$TMP"; }

run_vw() { run env PATH="$STUBS:$PATH" bash "$SCRIPT" "$@"; }

# --- _parse_duration ---

@test "_parse_duration converts unit suffixes to seconds" {
  source "$SCRIPT"
  [ "$(_parse_duration 45s)" -eq 45 ]
  [ "$(_parse_duration 30m)" -eq 1800 ]
  [ "$(_parse_duration 2h)" -eq 7200 ]
  [ "$(_parse_duration 1d)" -eq 86400 ]
}

@test "_parse_duration treats a bare number as seconds" {
  source "$SCRIPT"
  [ "$(_parse_duration 90)" -eq 90 ]
}

@test "_parse_duration rejects garbage" {
  source "$SCRIPT"
  run _parse_duration abc
  [ "$status" -ne 0 ]
  run _parse_duration ""
  [ "$status" -ne 0 ]
}

# --- start --ttl ---

@test "start --ttl records ttl seconds in the session state" {
  run_vw start --ttl 30m "$MOUNT"
  [ "$status" -eq 0 ]
  run cat "$VW_STATE_DIR"/*
  [[ "$output" == *"ttl_secs=1800"* ]]
}

@test "start --ttl with bad duration errors" {
  run_vw start --ttl nope "$MOUNT"
  [ "$status" -ne 0 ]
}

@test "start without --ttl records no ttl timer" {
  run_vw start "$MOUNT"
  [ "$status" -eq 0 ]
  run cat "$VW_STATE_DIR"/*
  [[ "$output" != *"ttl_secs="* ]] || [[ "$output" == *"ttl_secs=0"* ]]
}

@test "start --force --ttl records force flag" {
  run_vw start --force --ttl 10m "$MOUNT"
  [ "$status" -eq 0 ]
  run cat "$VW_STATE_DIR"/*
  [[ "$output" == *"ttl_force=1"* ]]
}

# --- _ttl_fire ---

@test "ttl fire detaches an idle vault and clears the session" {
  bash "$SCRIPT" start --ttl 30m "$MOUNT" >/dev/null
  STUB_LSOF_BUSY=0 run_vw _ttl_fire "$MOUNT"
  [ "$status" -eq 0 ]
  grep -qF -- "detach $MOUNT" "$VW_STUB_LOG"
  [ -z "$(ls -A "$VW_STATE_DIR" 2>/dev/null)" ]   # сессия закрыта
}

@test "ttl fire does NOT detach a busy vault without force" {
  bash "$SCRIPT" start --ttl 30m "$MOUNT" >/dev/null
  STUB_LSOF_BUSY=1 run_vw _ttl_fire "$MOUNT"
  [ "$status" -eq 0 ]
  ! grep -q "detach" "$VW_STUB_LOG"
  [ -n "$(ls -A "$VW_STATE_DIR" 2>/dev/null)" ]   # сессия цела (честно: не смогли закрыть)
  [[ "$output" == *"open files"* ]] || [[ "$output" == *"открыты файлы"* ]]
}

@test "ttl fire force-detaches a busy vault when force was set" {
  bash "$SCRIPT" start --force --ttl 30m "$MOUNT" >/dev/null
  STUB_LSOF_BUSY=1 run_vw _ttl_fire "$MOUNT"
  [ "$status" -eq 0 ]
  grep -qF -- "detach -force $MOUNT" "$VW_STUB_LOG"
  [ -z "$(ls -A "$VW_STATE_DIR" 2>/dev/null)" ]
}

@test "ttl fire on a vault with no session is a quiet success" {
  STUB_LSOF_BUSY=0 run_vw _ttl_fire "$MOUNT"
  [ "$status" -eq 0 ]
  ! grep -q "detach" "$VW_STUB_LOG"
}

# --- stop cancels the timer ---

@test "stop kills a live ttl timer process" {
  bash "$SCRIPT" start "$MOUNT" >/dev/null
  sleep 60 &                       # фейковый таймер
  pid=$!
  sf="$(ls "$VW_STATE_DIR"/*)"
  printf 'ttl_pid=%s\n' "$pid" >> "$sf"
  run_vw stop "$MOUNT"
  [ "$status" -eq 0 ]
  ! kill -0 "$pid" 2>/dev/null     # таймер убит
}
