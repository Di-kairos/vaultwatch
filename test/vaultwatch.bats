# Тесты vaultwatch (pack 3a: вендоринг + hook-installer).
setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../vaultwatch"
}

@test "version prints semver" {
  run bash "$SCRIPT" version
  [ "$status" -eq 0 ]
  [[ "$output" == *"vaultwatch"* ]]
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "no args prints usage and exits non-zero" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown command exits non-zero" {
  run bash "$SCRIPT" bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown command"* ]]
}

@test "vendored common is present and provides primitives" {
  run bash -c "source '$SCRIPT' 2>/dev/null; type info >/dev/null && type confirm >/dev/null && type require_macos >/dev/null && echo OK"
  [[ "$output" == *"OK"* ]]
}

@test "sourcing the script does not run the dispatcher" {
  run bash -c "source '$SCRIPT'; echo SOURCED_OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SOURCED_OK"* ]]
  [[ "$output" != *"Usage:"* ]]
}

@test "vendor --check passes (no drift)" {
  run bash "${BATS_TEST_DIRNAME}/../tools/vendor-common.sh" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"синхронен"* ]] || [[ "$output" == *"sync"* ]]
}

@test "install-hooks writes managed, executable post-open/post-close" {
  tmp="$(mktemp -d)"; hooks="$tmp/hooks"
  run env ST_HOOK_DIR="$hooks" bash "$SCRIPT" install-hooks
  [ "$status" -eq 0 ]
  [ -x "$hooks/post-open" ]
  [ -x "$hooks/post-close" ]
  grep -q "managed-by: vaultwatch" "$hooks/post-open"
  grep -q "managed-by: vaultwatch" "$hooks/post-close"
  grep -q "start" "$hooks/post-open"
  grep -q "stop" "$hooks/post-close"
  rm -rf "$tmp"
}

@test "install-hooks does NOT clobber a foreign hook" {
  tmp="$(mktemp -d)"; hooks="$tmp/hooks"; mkdir -p "$hooks"
  printf '#!/usr/bin/env bash\necho custom\n' > "$hooks/post-open"
  chmod +x "$hooks/post-open"
  run env ST_HOOK_DIR="$hooks" bash "$SCRIPT" install-hooks
  [ "$status" -eq 0 ]
  grep -q "custom" "$hooks/post-open"          # чужой хук цел
  ! grep -q "managed-by: vaultwatch" "$hooks/post-open"
  grep -q "managed-by: vaultwatch" "$hooks/post-close"   # свой поставлен
  rm -rf "$tmp"
}

@test "uninstall-hooks removes managed but keeps foreign" {
  tmp="$(mktemp -d)"; hooks="$tmp/hooks"; mkdir -p "$hooks"
  env ST_HOOK_DIR="$hooks" bash "$SCRIPT" install-hooks
  printf '#!/usr/bin/env bash\n# managed-by: vaultwatch\n' > "$hooks/post-open"  # managed
  printf '#!/usr/bin/env bash\necho custom\n' > "$hooks/post-close"              # foreign
  run env ST_HOOK_DIR="$hooks" bash "$SCRIPT" uninstall-hooks
  [ "$status" -eq 0 ]
  [ ! -e "$hooks/post-open" ]                   # managed удалён
  grep -q "custom" "$hooks/post-close"          # чужой цел
  rm -rf "$tmp"
}

@test "installed post-open hook execs vaultwatch start with mountpoint" {
  tmp="$(mktemp -d)"; hooks="$tmp/hooks"
  env ST_HOOK_DIR="$hooks" bash "$SCRIPT" install-hooks
  # хук вызывает start с аргументом; start ещё не реализован (pack 3b) → код 2,
  # но это доказывает корректную диспетчеризацию аргумента в vaultwatch.
  run bash "$hooks/post-open" /Volumes/SecretVault
  [ "$status" -eq 2 ]
  [[ "$output" == *"start"* ]]
  rm -rf "$tmp"
}

@test "start/stop are deferred (exit 2) — pack 3a/3b boundary" {
  run bash "$SCRIPT" start /Volumes/SecretVault
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" stop /Volumes/SecretVault
  [ "$status" -eq 2 ]
}

@test "installed post-open hook preserves a mountpoint with spaces" {
  tmp="$(mktemp -d)"; hooks="$tmp/hooks"
  env ST_HOOK_DIR="$hooks" bash "$SCRIPT" install-hooks
  run bash "$hooks/post-open" "/Volumes/Secret Vault"
  [ "$status" -eq 2 ]
  [[ "$output" == *"start"* ]]
  rm -rf "$tmp"
}

@test "uninstall-hooks on a clean dir is a quiet success" {
  tmp="$(mktemp -d)"; hooks="$tmp/hooks"; mkdir -p "$hooks"
  run env ST_HOOK_DIR="$hooks" bash "$SCRIPT" uninstall-hooks
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "vendor --check detects drift in the vendored block" {
  work="$(mktemp -d)"; mkdir -p "$work/tools"
  cp "${BATS_TEST_DIRNAME}/../vaultwatch" "$work/vaultwatch"
  cp "${BATS_TEST_DIRNAME}/../tools/vendor-common.sh" "$work/tools/"
  # Мутируем строку ВНУТРИ вшитого блока → --check должен поймать дрейф (exit 1).
  # Portable (без sed -i: BSD/GNU расходятся): sed в файл → mv.
  sed 's/_ST_COMMON_LOADED=1/_ST_COMMON_LOADED=999/' "$work/vaultwatch" > "$work/vaultwatch.mut"
  mv "$work/vaultwatch.mut" "$work/vaultwatch"
  run bash "$work/tools/vendor-common.sh" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"ДРЕЙФ"* ]] || [[ "$output" == *"drift"* ]]
  rm -rf "$work"
}
