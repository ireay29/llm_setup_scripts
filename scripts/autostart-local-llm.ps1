param(
    [int]$Port = 8080,
    [string]$ApiKey = $env:LLAMA_API_KEY
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Logs = Join-Path $Root "logs"
$StartScript = Join-Path $PSScriptRoot "start-local-ai.ps1"
$AutostartLog = Join-Path $Logs "autostart-local-llm.log"

New-Item -ItemType Directory -Force -Path $Logs | Out-Null

function Write-AutostartLog {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $AutostartLog -Encoding utf8 -Value "[$stamp] $Message"
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = "local-qwen"
}

$connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($connection) {
    try {
        $health = Invoke-WebRequest `
            -UseBasicParsing `
            -Uri "http://127.0.0.1:$Port/health" `
            -Headers @{ Authorization = "Bearer $ApiKey" } `
            -TimeoutSec 5

        Write-AutostartLog "Port $Port already has a healthy server: $($health.StatusCode) $($health.Content)"
        exit 0
    }
    catch {
        $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
        Write-AutostartLog "Port $Port is occupied by pid=$($connection.OwningProcess) process=$($process.ProcessName); not starting another server. Error: $($_.Exception.Message)"
        exit 1
    }
}

$stdout = Join-Path $Logs "autostart-local-ai.out.log"
$stderr = Join-Path $Logs "autostart-local-ai.err.log"
$pidFile = Join-Path $Logs "autostart-local-ai.pid"

Write-AutostartLog "Starting local AI server on port $Port."

$proc = Start-Process `
    -FilePath "powershell.exe" `
    -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $StartScript,
        "-Port", $Port
    ) `
    -WorkingDirectory $Root `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -PassThru

$proc.Id | Set-Content -Path $pidFile -Encoding ascii
Write-AutostartLog "Started wrapper pid=$($proc.Id)."
