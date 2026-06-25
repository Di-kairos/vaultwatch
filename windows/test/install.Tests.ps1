# Pester 5 — install.ps1 (Windows-порт vaultwatch). Integrity-gate без сети:
# VAULTWATCH_BASE_URL → локальный каталог-«релиз», установка во временный каталог,
# правка PATH отключена. Покрытие: happy-path, провал на расхождении хеша, провал
# при отсутствии записи в SHA256SUMS (fail-closed).

BeforeAll {
    $script:InstallScript = Join-Path $PSScriptRoot '..\install.ps1'
}

Describe 'install.ps1 integrity gate' {
    BeforeEach {
        $script:Work = Join-Path ([System.IO.Path]::GetTempPath()) ("vw_inst_" + [Guid]::NewGuid().ToString('N'))
        $script:Release = Join-Path $script:Work 'release'
        $script:Target  = Join-Path $script:Work 'target'
        New-Item -ItemType Directory -Path $script:Release -Force | Out-Null

        $payload = "Write-Output 'payload-ok'`n"
        $script:ScriptFile = Join-Path $script:Release 'vaultwatch.ps1'
        Set-Content -LiteralPath $script:ScriptFile -Value $payload -NoNewline
        $hash = (Get-FileHash -Path $script:ScriptFile -Algorithm SHA256).Hash.ToLower()
        Set-Content -LiteralPath (Join-Path $script:Release 'SHA256SUMS') -Value "$hash  vaultwatch.ps1"
    }

    AfterEach {
        Remove-Item -LiteralPath $script:Work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'installs the script when the checksum matches' {
        & pwsh -NoProfile -Command "`$env:VAULTWATCH_BASE_URL='$($script:Release)'; `$env:VAULTWATCH_INSTALL_DIR='$($script:Target)'; `$env:VAULTWATCH_SKIP_PATH='1'; & '$($script:InstallScript)'" *> $null
        (Test-Path (Join-Path $script:Target 'vaultwatch.ps1')) | Should -BeTrue
        (Test-Path (Join-Path $script:Target 'vaultwatch.cmd')) | Should -BeTrue
    }

    It 'fails closed when the checksum does not match' {
        Set-Content -LiteralPath (Join-Path $script:Release 'SHA256SUMS') -Value ("0"*64 + "  vaultwatch.ps1")
        & pwsh -NoProfile -Command "`$env:VAULTWATCH_BASE_URL='$($script:Release)'; `$env:VAULTWATCH_INSTALL_DIR='$($script:Target)'; `$env:VAULTWATCH_SKIP_PATH='1'; & '$($script:InstallScript)'" *> $null
        $LASTEXITCODE | Should -Not -Be 0
        (Test-Path (Join-Path $script:Target 'vaultwatch.ps1')) | Should -BeFalse
    }

    It 'fails closed when SHA256SUMS lacks the vaultwatch.ps1 entry' {
        Set-Content -LiteralPath (Join-Path $script:Release 'SHA256SUMS') -Value ("deadbeef  somethingelse.txt")
        & pwsh -NoProfile -Command "`$env:VAULTWATCH_BASE_URL='$($script:Release)'; `$env:VAULTWATCH_INSTALL_DIR='$($script:Target)'; `$env:VAULTWATCH_SKIP_PATH='1'; & '$($script:InstallScript)'" *> $null
        $LASTEXITCODE | Should -Not -Be 0
        (Test-Path (Join-Path $script:Target 'vaultwatch.ps1')) | Should -BeFalse
    }
}
