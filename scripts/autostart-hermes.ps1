$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Logs = Join-Path $Root "logs"
$AutostartLog = Join-Path $Logs "autostart-hermes.log"

$HermesRoot = Join-Path $env:LOCALAPPDATA "hermes"
$HermesExe = Join-Path $HermesRoot "hermes-agent\apps\desktop\release\win-unpacked\Hermes.exe"
$HermesWorkDir = Split-Path -Parent $HermesExe
$GatewayVbs = Join-Path $HermesRoot "gateway-service\Hermes_Gateway.vbs"
$SearxngVbs = Join-Path $HermesRoot "searxng\start-searxng-hidden.vbs"

New-Item -ItemType Directory -Force -Path $Logs | Out-Null

function Write-AutostartLog {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $AutostartLog -Encoding utf8 -Value "[$stamp] $Message"
}

function Get-ProcessByCommandLine {
    param([string]$Pattern)
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match $Pattern }
}

if (-not (Test-Path $HermesRoot)) {
    Write-AutostartLog "Hermes root was not found. Skipping Hermes autostart: $HermesRoot"
    exit 0
}

if (Test-Path $HermesExe) {
    $escapedHermes = [regex]::Escape($HermesExe)
    $hermesMain = Get-ProcessByCommandLine $escapedHermes |
        Where-Object { $_.Name -ieq "Hermes.exe" -and $_.CommandLine -notmatch "--type=" } |
        Select-Object -First 1

    if ($hermesMain) {
        Write-AutostartLog "Hermes desktop already running, pid=$($hermesMain.ProcessId)."
    }
    else {
        Start-Process -FilePath $HermesExe -WorkingDirectory $HermesWorkDir
        Write-AutostartLog "Started Hermes desktop."
    }
}
else {
    Write-AutostartLog "Hermes executable was not found: $HermesExe"
}

$gateway = Get-ProcessByCommandLine "hermes_cli\.main gateway run" | Select-Object -First 1
if ($gateway) {
    Write-AutostartLog "Hermes gateway already running, pid=$($gateway.ProcessId)."
}
elseif (Test-Path $GatewayVbs) {
    Start-Process -FilePath "wscript.exe" -ArgumentList @($GatewayVbs) -WindowStyle Hidden
    Write-AutostartLog "Started Hermes gateway."
}
else {
    Write-AutostartLog "Hermes gateway script was not found: $GatewayVbs"
}

$searxng = Get-NetTCPConnection -LocalPort 8888 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($searxng) {
    Write-AutostartLog "Hermes SearXNG already listening on port 8888, pid=$($searxng.OwningProcess)."
}
elseif (Test-Path $SearxngVbs) {
    Start-Process -FilePath "wscript.exe" -ArgumentList @($SearxngVbs) -WindowStyle Hidden
    Write-AutostartLog "Started Hermes SearXNG."
}
else {
    Write-AutostartLog "Hermes SearXNG script was not found: $SearxngVbs"
}
