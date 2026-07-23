param(
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $PSScriptRoot) ".local-ai-config.json"),
    [string]$ModelPath,
    [string]$Alias,
    [int]$CtxSize = 0,
    [string]$HostName,
    [int]$Port = 0,
    [string]$ApiKey = $env:LLAMA_API_KEY,
    [int]$Threads = 8,
    [int]$Parallel = 1
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Server = Join-Path $Root "tools\llama.cpp\llama-server.exe"

if (-not (Test-Path $Server)) {
    throw "llama-server.exe was not found. Run install-local-ai.ps1 first."
}

if (-not (Test-Path $ConfigPath)) {
    throw "Config was not found: $ConfigPath. Run install-local-ai.ps1 first."
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($ModelPath)) {
    $ModelPath = $config.model
}
if ([string]::IsNullOrWhiteSpace($Alias)) {
    $Alias = $config.alias
}
if ($CtxSize -le 0) {
    $CtxSize = [int]$config.ctxSize
}
if ([string]::IsNullOrWhiteSpace($HostName)) {
    $HostName = if ($config.hostName) { $config.hostName } else { "0.0.0.0" }
}
if ($Port -le 0) {
    $Port = if ($config.port) { [int]$config.port } else { 8080 }
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = "local-qwen"
    Write-Warning "LLAMA_API_KEY is not set. Using the default API key: local-qwen"
}

$model = if ([System.IO.Path]::IsPathRooted($ModelPath)) { $ModelPath } else { Join-Path $Root $ModelPath }
if (-not (Test-Path $model)) {
    throw "Model file was not found: $model"
}

$batch = if ($config.batch) { [int]$config.batch } else { 512 }
$ubatch = if ($config.ubatch) { [int]$config.ubatch } else { 256 }
$gpuLayers = if ($null -ne $config.gpuLayers) { [string]$config.gpuLayers } else { "all" }

Write-Host "Starting llama.cpp server"
Write-Host "  config  : $ConfigPath"
Write-Host "  model   : $model"
Write-Host "  alias   : $Alias"
Write-Host "  bind    : http://$HostName`:$Port"
Write-Host "  ctx     : $CtxSize"
if ($config.mmproj) {
    Write-Host "  vision  : $config.mmproj"
}
Write-Host ""

$args = @(
    "-m", $model,
    "-a", $Alias,
    "--host", $HostName,
    "--port", $Port,
    "--api-key", $ApiKey,
    "-c", $CtxSize,
    "-ngl", $gpuLayers,
    "-t", $Threads,
    "-np", $Parallel,
    "-b", $batch,
    "-ub", $ubatch,
    "--jinja",
    "--metrics"
)

if ($config.reasoning) {
    $args += @("--reasoning", $config.reasoning)
}
if ($config.flashAttn) {
    $args += @("-fa", $config.flashAttn)
}
if ($config.cacheTypeK) {
    $args += @("-ctk", $config.cacheTypeK)
}
if ($config.cacheTypeV) {
    $args += @("-ctv", $config.cacheTypeV)
}
if ($config.mmproj) {
    $mmproj = if ([System.IO.Path]::IsPathRooted($config.mmproj)) { $config.mmproj } else { Join-Path $Root $config.mmproj }
    if (-not (Test-Path $mmproj)) {
        throw "MM projector file was not found: $mmproj"
    }
    $args += @("-mm", $mmproj)
    $mmprojOffload = if ($null -ne $config.mmprojOffload) { [bool]$config.mmprojOffload } else { $true }
    $args += if ($mmprojOffload) { "--mmproj-offload" } else { "--no-mmproj-offload" }
}
if ($config.imageMaxTokens) {
    $args += @("--image-max-tokens", [int]$config.imageMaxTokens)
}
if ($config.mtmdBatchMaxTokens) {
    $args += @("--mtmd-batch-max-tokens", [int]$config.mtmdBatchMaxTokens)
}

& $Server @args
