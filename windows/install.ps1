# install.ps1 — установщик vaultwatch для Windows (BETA) с проверкой целостности.
#
# Тянет vaultwatch.ps1 и SHA256SUMS из РЕЛИЗНОГО тега (не из ветки main) и сверяет SHA256
# ДО установки. Закрывает supply-chain риск «irm|iex из main без проверки»: содержимое
# релизного тега неизменно (в отличие от подвижной main), хеш ловит повреждение, частичную/
# кэш-подмену и рассинхрон с публикацией. ЧЕСТНО: сумма и скрипт приходят по одному каналу —
# от подмены САМОГО релиза это не защищает; для подлинности нужна подпись (SHA256SUMS.sig).
#
# Использование (рекомендуется verify-then-run, см. windows/README.md):
#   irm https://github.com/Di-kairos/vaultwatch/releases/latest/download/install.ps1 -OutFile install.ps1
#   irm https://github.com/Di-kairos/vaultwatch/releases/latest/download/SHA256SUMS  -OutFile SHA256SUMS
#   # сверить хеш install.ps1 вручную, прочитать скрипт, затем:
#   pwsh -File install.ps1
#
# Переменные окружения:
#   VAULTWATCH_VERSION     — конкретный тег (напр. 0.1.3). По умолчанию latest.
#   VAULTWATCH_BASE_URL    — источник целиком: http(s) URL ИЛИ локальный каталог (тесты/форки).
#   VAULTWATCH_INSTALL_DIR — каталог установки. По умолчанию %LOCALAPPDATA%\Programs\vaultwatch.
#   VAULTWATCH_SKIP_PATH   — '1' пропускает правку PATH (для тестов).
#
# ВНИМАНИЕ: BETA-порт. Логика проверена через Pester (системные эффекты мокаются);
# поведение на широком парке Windows-конфигов (Search/VSS/Task Scheduler) не обкатано.

$ErrorActionPreference = 'Stop'

$Repo = 'Di-kairos/vaultwatch'

if ($env:VAULTWATCH_BASE_URL) {
    $BaseUrl = $env:VAULTWATCH_BASE_URL
} elseif ($env:VAULTWATCH_VERSION) {
    $BaseUrl = "https://github.com/$Repo/releases/download/v$($env:VAULTWATCH_VERSION)"
} else {
    $BaseUrl = "https://github.com/$Repo/releases/latest/download"
}

$InstallDir = if ($env:VAULTWATCH_INSTALL_DIR) { $env:VAULTWATCH_INSTALL_DIR } else {
    Join-Path $env:LOCALAPPDATA 'Programs\vaultwatch'
}
$ScriptPath = Join-Path $InstallDir 'vaultwatch.ps1'
$ShimPath   = Join-Path $InstallDir 'vaultwatch.cmd'

Write-Host 'vaultwatch (Windows, BETA) installer'
Write-Host '------------------------------------'

function Get-ReleaseFile {
    param([string]$Name, [string]$OutFile)
    if ($BaseUrl -match '^https?://') {
        Invoke-RestMethod -Uri "$BaseUrl/$Name" -OutFile $OutFile
    } else {
        Copy-Item -Path (Join-Path $BaseUrl $Name) -Destination $OutFile -Force
    }
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("vaultwatch-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Tmp -Force | Out-Null
try {
    $tmpScript = Join-Path $Tmp 'vaultwatch.ps1'
    $tmpSums   = Join-Path $Tmp 'SHA256SUMS'

    Write-Host 'Downloading vaultwatch.ps1 + SHA256SUMS from release...'
    Get-ReleaseFile -Name 'vaultwatch.ps1' -OutFile $tmpScript
    Get-ReleaseFile -Name 'SHA256SUMS'     -OutFile $tmpSums

    $expected = $null
    foreach ($line in Get-Content -Path $tmpSums) {
        $parts = $line -split '\s+', 2
        if ($parts.Count -eq 2) {
            $fname = $parts[1].Trim().TrimStart('*')
            if ($fname -eq 'vaultwatch.ps1') { $expected = $parts[0].Trim().ToLower() }
        }
    }
    if (-not $expected) {
        Write-Error 'SHA256SUMS не содержит записи для vaultwatch.ps1 — установка прервана.'
        exit 1
    }

    $actual = (Get-FileHash -Path $tmpScript -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected) {
        Write-Error "Контрольная сумма НЕ совпала (возможна подмена) — установка прервана.`nexpected: $expected`nactual:   $actual"
        exit 1
    }
    Write-Host 'Checksum OK.'

    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    Copy-Item -Path $tmpScript -Destination $ScriptPath -Force
    Write-Host "Installed: $ScriptPath"
}
finally {
    Remove-Item -Path $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}

$shim = @"
@echo off
pwsh -NoProfile -File "%~dp0vaultwatch.ps1" %*
if errorlevel 1 exit /b %errorlevel%
"@
Set-Content -Path $ShimPath -Value $shim -Encoding ASCII
Write-Host "Shim created: $ShimPath"

if ($env:VAULTWATCH_SKIP_PATH -ne '1') {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    $paths = $userPath.Split(';') | Where-Object { $_ -ne '' }
    if ($paths -notcontains $InstallDir) {
        $newPath = (($paths + $InstallDir) -join ';')
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "Added to user PATH: $InstallDir"
    } else {
        Write-Host 'Already on user PATH.'
    }
}

Write-Host ''
Write-Host 'Done. NEXT STEPS:'
Write-Host '  1) Open a NEW terminal (so PATH refreshes).'
Write-Host '  2) Run:  vaultwatch version'
Write-Host '  3) Guard a mounted vault:  vaultwatch start --ttl 30m V:\'
Write-Host ''
Write-Host 'NOTE: BETA port. Search exclusion + TTL auto-dismount work; backup snapshots (VSS) are'
Write-Host 'reported but NOT removed, and the pagefile is not addressed. See windows/README.md.'
