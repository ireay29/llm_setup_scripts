param(
    [string]$Server = "http://127.0.0.1:8080",
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $PSScriptRoot) ".local-ai-config.json"),
    [string]$Model,
    [string]$ApiKey = $env:LLAMA_API_KEY,
    [string]$Prompt = "Reply in one concise sentence: what are you?",
    [string]$ImagePath,
    [string]$ImageUrl
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
$content = @(
    @{ type = "text"; text = $Prompt }
)

if ($ImagePath -and $ImageUrl) {
    throw "Use either -ImagePath or -ImageUrl, not both."
}

if ($ImagePath) {
    $resolvedImagePath = (Resolve-Path $ImagePath).Path
    $extension = [System.IO.Path]::GetExtension($resolvedImagePath).ToLowerInvariant()
    $mimeType = switch ($extension) {
        ".jpg" { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".png" { "image/png" }
        ".webp" { "image/webp" }
        default { throw "Unsupported image extension '$extension'. Use JPG, PNG, or WEBP." }
    }
    $encodedImage = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($resolvedImagePath))
    $ImageUrl = "data:$mimeType;base64,$encodedImage"
}

if ($ImageUrl) {
    if ($ImageUrl -notmatch "^(?i:https://|data:)") {
        throw "-ImageUrl must be an HTTPS or data: image URL."
    }
    $content += @{ type = "image_url"; image_url = @{ url = $ImageUrl } }
}

$body = @{
    model = $Model
    messages = @(
        @{ role = "user"; content = $content }
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
