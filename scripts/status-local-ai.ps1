param(
    [int]$Port = 8080,
    [string]$ApiKey = $env:LLAMA_API_KEY
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = "local-qwen"
}

$connection = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not $connection) {
    Write-Host "No server is listening on port $Port."
    exit 1
}

$process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue

try {
    $health = Invoke-WebRequest `
        -UseBasicParsing `
        -Uri "http://127.0.0.1:$Port/health" `
        -Headers @{ Authorization = "Bearer $ApiKey" } `
        -TimeoutSec 5

    Write-Host "Local AI status"
    Write-Host "  port    : $Port"
    Write-Host "  pid     : $($connection.OwningProcess)"
    Write-Host "  process : $($process.ProcessName)"
    Write-Host "  health  : $($health.StatusCode) $($health.Content)"
}
catch {
    Write-Host "Port $Port is listening, but health check failed."
    Write-Host "  pid     : $($connection.OwningProcess)"
    Write-Host "  process : $($process.ProcessName)"
    Write-Host "  error   : $($_.Exception.Message)"
    exit 1
}
