param(
    [string]$Server = "http://127.0.0.1:8080",
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $PSScriptRoot) ".local-ai-config.json"),
    [string]$Model,
    [string]$ApiKey = $env:LLAMA_API_KEY,
    [string]$Prompt = "Reply in one concise sentence: what are you?"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = "local-qwen"
}

if ([string]::IsNullOrWhiteSpace($Model)) {
    if (-not (Test-Path $ConfigPath)) {
        throw "Config was not found: $ConfigPath"
    }
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $Model = $config.alias
}

$headers = @{ Authorization = "Bearer $ApiKey" }
$body = @{
    model = $Model
    messages = @(
        @{ role = "user"; content = $Prompt }
    )
    max_tokens = 128
    temperature = 0.2
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "$Server/v1/chat/completions" `
    -Headers $headers `
    -ContentType "application/json; charset=utf-8" `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
    -TimeoutSec 180

$message = $response.choices[0].message
Write-Host "Model: $($response.model)"
Write-Host "Content: $($message.content)"

if ($message.PSObject.Properties.Name -contains "reasoning_content") {
    Write-Host "Reasoning content: $($message.reasoning_content)"
}

if ($response.timings) {
    Write-Host "Prompt tok/s: $([math]::Round($response.timings.prompt_per_second, 2))"
    Write-Host "Generation tok/s: $([math]::Round($response.timings.predicted_per_second, 2))"
}
