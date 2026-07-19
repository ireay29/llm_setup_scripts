param(
    [string]$Model,
    [string]$ModelUrl,
    [string]$ModelPath,
    [string]$Alias,
    [int]$CtxSize = 0,
    [int]$Port = 8080,
    [string]$HostName = "0.0.0.0",
    [string]$ApiKey = $env:LLAMA_API_KEY,
    [switch]$ListModels,
    [switch]$Autostart,
    [switch]$WithHermes,
    [switch]$OpenFirewall,
    [switch]$Start,
    [string]$ManifestPath = (Join-Path $PSScriptRoot "models.manifest.json")
)

$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$ModelsDir = Join-Path $Root "models"
$ToolsDir = Join-Path $Root "tools"
$CacheDir = Join-Path $Root ".cache"
$ConfigPath = Join-Path $Root ".local-ai-config.json"

function Read-Manifest {
    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }
    Get-Content $ManifestPath -Raw | ConvertFrom-Json
}

function Get-ModelEntries {
    param($Manifest)

    $Manifest.models.PSObject.Properties | ForEach-Object {
        $value = $_.Value
        [pscustomobject]@{
            Name = $_.Name
            Alias = $value.alias
            CtxSize = $value.ctxSize
            File = $value.file
            Description = $value.description
        }
    }
}

function Download-File {
    param(
        [Parameter(Mandatory)] [string]$Url,
        [Parameter(Mandatory)] [string]$OutFile
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Write-Host "Downloading:"
    Write-Host "  $Url"
    Write-Host "  -> $OutFile"

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & $curl.Source -L -C - --retry 8 --retry-delay 5 --connect-timeout 30 -o $OutFile $Url
        if ($LASTEXITCODE -ne 0) {
            throw "curl failed with exit code $LASTEXITCODE"
        }
        return
    }

    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Assert-Sha256 {
    param(
        [string]$Path,
        [string]$Expected
    )

    if ([string]::IsNullOrWhiteSpace($Expected)) {
        return
    }

    $actual = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToUpperInvariant()
    $expectedUpper = $Expected.ToUpperInvariant()
    if ($actual -ne $expectedUpper) {
        throw "SHA256 mismatch for $Path. Expected $expectedUpper, got $actual"
    }
    Write-Host "SHA256 verified: $Path"
}

function Install-LlamaCpp {
    param($Manifest)

    $releaseTag = [string]$Manifest.llamaCpp.release
    if ([string]::IsNullOrWhiteSpace($releaseTag) -or $releaseTag -eq "latest") {
        throw "llamaCpp.release must be pinned to an exact llama.cpp release tag."
    }

    $assetName = [string]$Manifest.llamaCpp.assetName
    if ([string]::IsNullOrWhiteSpace($assetName)) {
        throw "llamaCpp.assetName must identify the exact Windows Vulkan release asset."
    }

    $expectedSha256 = [string]$Manifest.llamaCpp.sha256
    if ($expectedSha256 -notmatch "^[0-9A-Fa-f]{64}$") {
        throw "llamaCpp.sha256 must contain the release asset's 64-character SHA256 hash."
    }

    $llamaDir = Join-Path $ToolsDir "llama.cpp"
    $server = Join-Path $ToolsDir "llama.cpp\llama-server.exe"
    $installedReleasePath = Join-Path $llamaDir ".release-tag"
    if ((Test-Path $server) -and (Test-Path $installedReleasePath)) {
        $installedRelease = (Get-Content $installedReleasePath -Raw).Trim()
        if ($installedRelease -eq $releaseTag) {
            Write-Host "llama.cpp $releaseTag already installed: $server"
            return
        }
    }

    New-Item -ItemType Directory -Force -Path $ToolsDir,$CacheDir | Out-Null

    $releaseUrl = "https://api.github.com/repos/ggml-org/llama.cpp/releases/tags/$releaseTag"
    $release = Invoke-RestMethod -Uri $releaseUrl -TimeoutSec 30

    $asset = $release.assets |
        Where-Object { $_.name -eq $assetName } |
        Select-Object -First 1

    if (-not $asset) {
        throw "Could not find llama.cpp release asset '$assetName' in release $releaseTag"
    }

    $zip = Join-Path $CacheDir $asset.name
    Download-File -Url $asset.browser_download_url -OutFile $zip
    Assert-Sha256 -Path $zip -Expected $expectedSha256

    New-Item -ItemType Directory -Force -Path $llamaDir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $llamaDir -Force

    $found = Get-ChildItem -Path $llamaDir -Recurse -Filter "llama-server.exe" | Select-Object -First 1
    if (-not $found) {
        throw "llama-server.exe was not found after extracting $zip"
    }

    if ($found.FullName -ne $server) {
        Copy-Item -Path (Join-Path (Split-Path -Parent $found.FullName) "*") -Destination $llamaDir -Recurse -Force
    }

    if (-not (Test-Path $server)) {
        throw "llama-server.exe was not installed to expected path: $server"
    }

    Set-Content -Path $installedReleasePath -Value $releaseTag -Encoding ascii
    Write-Host "Installed llama.cpp $releaseTag`: $server"
}

function Get-FileNameFromUrl {
    param([string]$Url)
    $withoutQuery = ($Url -split "\?")[0]
    [System.Uri]::UnescapeDataString((Split-Path -Leaf $withoutQuery))
}

function New-CustomAlias {
    param([string]$PathOrUrl)
    $name = if ($PathOrUrl -match "^https?://") { Get-FileNameFromUrl $PathOrUrl } else { Split-Path -Leaf $PathOrUrl }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
    ($base -replace "[^A-Za-z0-9_.-]", "-").ToLowerInvariant()
}

function Resolve-ModelConfig {
    param($Manifest)

    if ($ModelUrl -and $ModelPath) {
        throw "Use either -ModelUrl or -ModelPath, not both."
    }

    if ($ModelUrl) {
        $file = Get-FileNameFromUrl $ModelUrl
        if ([string]::IsNullOrWhiteSpace($file)) {
            throw "Could not infer file name from -ModelUrl. Use a direct GGUF URL."
        }
        if ([string]::IsNullOrWhiteSpace($Alias)) {
            $Alias = New-CustomAlias $ModelUrl
        }
        if ($CtxSize -le 0) {
            $CtxSize = 4096
        }

        $target = Join-Path $ModelsDir $file
        if (-not (Test-Path $target)) {
            Download-File -Url $ModelUrl -OutFile $target
        }

        return [pscustomobject]@{
            name = "custom-url"
            model = "models\$file"
            alias = $Alias
            ctxSize = $CtxSize
            batch = 512
            ubatch = 256
            reasoning = "off"
            flashAttn = "auto"
            hostName = $HostName
            port = $Port
        }
    }

    if ($ModelPath) {
        $resolved = (Resolve-Path $ModelPath).Path
        if ([string]::IsNullOrWhiteSpace($Alias)) {
            $Alias = New-CustomAlias $resolved
        }
        if ($CtxSize -le 0) {
            $CtxSize = 4096
        }

        return [pscustomobject]@{
            name = "custom-path"
            model = $resolved
            alias = $Alias
            ctxSize = $CtxSize
            batch = 512
            ubatch = 256
            reasoning = "off"
            flashAttn = "auto"
            hostName = $HostName
            port = $Port
        }
    }

    if ([string]::IsNullOrWhiteSpace($Model)) {
        $Model = $Manifest.defaultModel
    }

    $prop = $Manifest.models.PSObject.Properties[$Model]
    if (-not $prop) {
        $known = (Get-ModelEntries $Manifest | Select-Object -ExpandProperty Name) -join ", "
        throw "Unknown model '$Model'. Known models: $known"
    }

    $spec = $prop.Value
    $file = $spec.file
    $target = Join-Path $ModelsDir $file

    if (-not (Test-Path $target)) {
        Download-File -Url $spec.url -OutFile $target
    }
    Assert-Sha256 -Path $target -Expected $spec.sha256

    if ($CtxSize -le 0) {
        $CtxSize = [int]$spec.ctxSize
    }

    return [pscustomobject]@{
        name = $Model
        model = "models\$file"
        alias = $spec.alias
        ctxSize = $CtxSize
        batch = $spec.batch
        ubatch = $spec.ubatch
        reasoning = $spec.reasoning
        flashAttn = $spec.flashAttn
        cacheTypeK = $spec.cacheTypeK
        cacheTypeV = $spec.cacheTypeV
        mmproj = $spec.mmproj
        imageMaxTokens = $spec.imageMaxTokens
        mtmdBatchMaxTokens = $spec.mtmdBatchMaxTokens
        hostName = $HostName
        port = $Port
    }
}

function Save-Config {
    param($Config)
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding utf8
    Write-Host "Wrote config: $ConfigPath"
}

function Open-FirewallPort {
    param([int]$Port)
    $ruleName = "Local AI llama.cpp API $Port"
    $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Firewall rule already exists: $ruleName"
        return
    }

    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort $Port | Out-Null

    Write-Host "Firewall rule added: $ruleName"
}

$manifest = Read-Manifest

if ($ListModels) {
    Get-ModelEntries $manifest | Format-Table -AutoSize
    exit 0
}

New-Item -ItemType Directory -Force -Path $ModelsDir,$ToolsDir,$CacheDir,(Join-Path $Root "logs") | Out-Null
Install-LlamaCpp -Manifest $manifest
$config = Resolve-ModelConfig -Manifest $manifest
Save-Config -Config $config

if ($Autostart) {
    $register = Join-Path $Root "scripts\register-autostart-tasks.ps1"
    if ($WithHermes) {
        & $register -WithHermes
    }
    else {
        & $register
    }
}
elseif ($WithHermes) {
    Write-Warning "-WithHermes only has an effect together with -Autostart."
}

if ($OpenFirewall) {
    try {
        Open-FirewallPort -Port $Port
    }
    catch {
        Write-Warning "Could not add firewall rule. Run PowerShell as Administrator and retry -OpenFirewall. Error: $($_.Exception.Message)"
    }
}

if ($Start) {
    & (Join-Path $Root "scripts\start-local-ai.ps1")
}
else {
    Write-Host ""
    Write-Host "Install complete. Start the server with:"
    Write-Host "  .\scripts\start-local-ai.cmd"
}
