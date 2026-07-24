param(
    [switch]$SmokeTest
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $Root "models.manifest.json"
$InstallScript = Join-Path $Root "install-local-ai.ps1"
$StartScript = Join-Path $PSScriptRoot "start-local-ai.ps1"
$StopScript = Join-Path $PSScriptRoot "stop-local-ai.ps1"
$TaskRunner = Join-Path $PSScriptRoot "run-local-ai-task.cmd"
$ConfigPath = Join-Path $Root ".local-ai-config.json"
$ApiKey = if ([string]::IsNullOrWhiteSpace($env:LLAMA_API_KEY)) { "local-qwen" } else { $env:LLAMA_API_KEY }

function Read-Manifest {
    Get-Content $ManifestPath -Raw | ConvertFrom-Json
}

function Test-ModelInstalled {
    param($Model)

    $modelPath = Join-Path $Root (Join-Path "models" $Model.File)
    if (-not (Test-Path $modelPath)) {
        return $false
    }

    if ($Model.mmprojFile) {
        $projectorPath = Join-Path $Root (Join-Path "models" $Model.mmprojFile)
        return (Test-Path $projectorPath)
    }

    return $true
}

function Get-ServerModel {
    try {
        $response = Invoke-RestMethod `
            -Method Get `
            -Uri "http://127.0.0.1:8080/v1/models" `
            -Headers @{ Authorization = "Bearer $ApiKey" } `
            -TimeoutSec 2

        if ($response.data -and $response.data.Count -gt 0) {
            return [string]$response.data[0].id
        }
        return "Running"
    }
    catch {
        return $null
    }
}

function Get-SelectedModel {
    return $modelPicker.SelectedItem
}

function Get-OcrPrompt {
    switch ($ocrOutputPicker.SelectedItem) {
        "JSON" {
            return "Extract all visible text. Return only valid JSON, with no code fences or explanation. Preserve headings, body text, and tables."
        }
        "HTML" {
            return "Extract all visible text. Return only HTML that preserves the layout, headings, paragraphs, and tables. Do not add an explanation."
        }
        "Plain text" {
            return "Extract all visible text. Return only plain text while preserving line breaks and reading order. Do not add an explanation."
        }
        default {
            return "Extract all visible text. Return only Markdown that preserves headings, paragraphs, and tables. Do not add an explanation."
        }
    }
}

$manifest = Read-Manifest
$modelItems = @(
    $manifest.models.PSObject.Properties | ForEach-Object {
        $model = $_.Value
        [pscustomobject]@{
            Name = $_.Name
            Alias = $model.alias
            Description = $model.description
            Installed = Test-ModelInstalled -Model $model
            IsVision = [bool]($model.mmprojFile)
        }
    }
)

$form = New-Object System.Windows.Forms.Form
$form.Text = "Local AI Launcher"
$form.Size = New-Object System.Drawing.Size(760, 670)
$form.MinimumSize = New-Object System.Drawing.Size(760, 670)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Yu Gothic UI", 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Local AI Launcher"
$title.Font = New-Object System.Drawing.Font("Yu Gothic UI Semibold", 18)
$title.Location = New-Object System.Drawing.Point(24, 18)
$title.AutoSize = $true
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Choose a model and start it. Switching safely stops the current server first."
$subtitle.Location = New-Object System.Drawing.Point(26, 53)
$subtitle.Size = New-Object System.Drawing.Size(680, 24)
$form.Controls.Add($subtitle)

$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Text = "Model"
$modelLabel.Location = New-Object System.Drawing.Point(26, 96)
$modelLabel.AutoSize = $true
$form.Controls.Add($modelLabel)

$modelPicker = New-Object System.Windows.Forms.ComboBox
$modelPicker.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$modelPicker.Location = New-Object System.Drawing.Point(26, 120)
$modelPicker.Size = New-Object System.Drawing.Size(680, 32)
$modelPicker.DisplayMember = "Name"
[void]$modelPicker.Items.AddRange($modelItems)
$form.Controls.Add($modelPicker)

$details = New-Object System.Windows.Forms.Label
$details.Location = New-Object System.Drawing.Point(26, 164)
$details.Size = New-Object System.Drawing.Size(680, 62)
$details.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$details.Padding = New-Object System.Windows.Forms.Padding(8, 7, 8, 7)
$form.Controls.Add($details)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Start selected model"
$startButton.Location = New-Object System.Drawing.Point(26, 244)
$startButton.Size = New-Object System.Drawing.Size(210, 42)
$startButton.Font = New-Object System.Drawing.Font("Yu Gothic UI Semibold", 10)
$form.Controls.Add($startButton)

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = "Stop"
$stopButton.Location = New-Object System.Drawing.Point(248, 244)
$stopButton.Size = New-Object System.Drawing.Size(110, 42)
$form.Controls.Add($stopButton)

$chatButton = New-Object System.Windows.Forms.Button
$chatButton.Text = "Open chat"
$chatButton.Location = New-Object System.Drawing.Point(370, 244)
$chatButton.Size = New-Object System.Drawing.Size(150, 42)
$form.Controls.Add($chatButton)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "Refresh status"
$refreshButton.Location = New-Object System.Drawing.Point(532, 244)
$refreshButton.Size = New-Object System.Drawing.Size(174, 42)
$form.Controls.Add($refreshButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Checking status..."
$statusLabel.Location = New-Object System.Drawing.Point(26, 306)
$statusLabel.Size = New-Object System.Drawing.Size(680, 25)
$statusLabel.Font = New-Object System.Drawing.Font("Yu Gothic UI Semibold", 10)
$form.Controls.Add($statusLabel)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(26, 336)
$progress.Size = New-Object System.Drawing.Size(680, 14)
$progress.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
$form.Controls.Add($progress)

$downloadDetail = New-Object System.Windows.Forms.Label
$downloadDetail.Text = ""
$downloadDetail.Location = New-Object System.Drawing.Point(26, 356)
$downloadDetail.Size = New-Object System.Drawing.Size(680, 22)
$form.Controls.Add($downloadDetail)

$ocrLabel = New-Object System.Windows.Forms.Label
$ocrLabel.Text = "Chandra OCR output"
$ocrLabel.Location = New-Object System.Drawing.Point(26, 394)
$ocrLabel.AutoSize = $true
$form.Controls.Add($ocrLabel)

$ocrOutputPicker = New-Object System.Windows.Forms.ComboBox
$ocrOutputPicker.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$ocrOutputPicker.Location = New-Object System.Drawing.Point(26, 418)
$ocrOutputPicker.Size = New-Object System.Drawing.Size(200, 32)
[void]$ocrOutputPicker.Items.AddRange(@("Markdown", "JSON", "HTML", "Plain text"))
$ocrOutputPicker.SelectedIndex = 0
$form.Controls.Add($ocrOutputPicker)

$copyPromptButton = New-Object System.Windows.Forms.Button
$copyPromptButton.Text = "Copy OCR prompt"
$copyPromptButton.Location = New-Object System.Drawing.Point(238, 415)
$copyPromptButton.Size = New-Object System.Drawing.Size(190, 36)
$form.Controls.Add($copyPromptButton)

$ocrHint = New-Object System.Windows.Forms.Label
$ocrHint.Text = "Paste the copied prompt into chat together with an image."
$ocrHint.Location = New-Object System.Drawing.Point(26, 459)
$ocrHint.Size = New-Object System.Drawing.Size(680, 24)
$form.Controls.Add($ocrHint)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = "Activity"
$logLabel.Location = New-Object System.Drawing.Point(26, 492)
$logLabel.AutoSize = $true
$form.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(26, 515)
$logBox.Size = New-Object System.Drawing.Size(680, 100)
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$form.Controls.Add($logBox)

$script:operationProcess = $null
$script:operationName = $null
$script:operationAfter = $null
$script:serverProcess = $null
$script:serverStarting = $false
$script:pendingModelName = $null
$script:nextStatusRefresh = [DateTime]::MinValue
$script:operationDownloadPath = $null
$script:operationStage = $null
$script:operationLogPath = $null
$script:serverLogPath = $null
$script:serverFailureReported = $false

function Write-LauncherLog {
    param([string]$Message)

    $stamp = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("[$stamp] $Message$([Environment]::NewLine)")
}

function Format-ByteCount {
    param([Int64]$Bytes)

    if ($Bytes -ge 1GB) {
        return ("{0:N2} GB" -f ($Bytes / 1GB))
    }
    if ($Bytes -ge 1MB) {
        return ("{0:N1} MB" -f ($Bytes / 1MB))
    }
    return ("{0:N0} KB" -f ($Bytes / 1KB))
}

function Update-OperationProgress {
    if ($script:operationProcess -and $script:operationLogPath -and (Test-Path $script:operationLogPath)) {
        $logLines = @(Get-Content $script:operationLogPath -Tail 40 -ErrorAction SilentlyContinue)
        $logBox.Lines = $logLines
        if ($logLines -match "^Downloading:") {
            $script:operationStage = "Downloading model"
        }
        elseif ($logLines -match "^SHA256 verified:") {
            $script:operationStage = "Verifying model files"
        }
        elseif ($logLines -match "^Wrote config:") {
            $script:operationStage = "Saving selected-model settings"
        }
    }

    if ($script:serverStarting -and $script:serverLogPath -and (Test-Path $script:serverLogPath)) {
        $logBox.Lines = @(Get-Content $script:serverLogPath -Tail 40 -ErrorAction SilentlyContinue)
        $downloadDetail.Text = "Loading selected model..."
        return
    }

    if (-not $script:operationDownloadPath) {
        $downloadDetail.Text = ""
        return
    }

    if ($script:operationStage -eq "Downloading model" -and (Test-Path $script:operationDownloadPath)) {
        $size = (Get-Item $script:operationDownloadPath).Length
        $downloadDetail.Text = "Downloading: $(Format-ByteCount $size) received. Keep the launcher open."
        return
    }

    if ($script:operationStage) {
        $downloadDetail.Text = $script:operationStage
    }
    else {
        $downloadDetail.Text = "Checking the selected model..."
    }
}

function Update-SelectedModelDetails {
    $selected = Get-SelectedModel
    if (-not $selected) {
        return
    }

    $availability = if ($selected.Installed) { "Installed" } else { "Not installed (downloaded and verified when starting)" }
    $type = if ($selected.IsVision) { "Vision" } else { "Text" }
    $details.Text = "$availability / $type`r`n$($selected.Description)"
}

function Refresh-ServerStatus {
    $runningModel = Get-ServerModel
    if ($runningModel) {
        if ($script:serverStarting) {
            $script:serverStarting = $false
            Write-LauncherLog "Server is ready."
        }
        $statusLabel.Text = "Running: $runningModel  (http://127.0.0.1:8080)"
        $chatButton.Enabled = $true
    }
    elseif ($script:serverStarting -and $script:serverProcess -and $script:serverProcess.HasExited) {
        $script:serverStarting = $false
        Write-LauncherLog "Server process exited before it became ready."
        $statusLabel.Text = "Server stopped unexpectedly."
        $chatButton.Enabled = $false
        if (-not $script:serverFailureReported) {
            $script:serverFailureReported = $true
            $details = if ($script:serverLogPath -and (Test-Path $script:serverLogPath)) { (Get-Content $script:serverLogPath -Tail 12) -join [Environment]::NewLine } else { "No server output was captured." }
            $logBox.Lines = $details -split "`r?`n"
            [System.Windows.Forms.MessageBox]::Show("The server did not start.`r`n`r`n$details", "Local AI Launcher")
        }
    }
    elseif ($script:serverStarting) {
        $statusLabel.Text = "Loading model..."
        $chatButton.Enabled = $false
    }
    elseif ($script:operationProcess) {
        $statusLabel.Text = "$script:operationName in progress..."
        $chatButton.Enabled = $false
    }
    else {
        $statusLabel.Text = "Stopped"
        $chatButton.Enabled = $false
    }
}

function Set-OperationUi {
    param([bool]$Running)

    $modelPicker.Enabled = -not $Running
    $startButton.Enabled = -not $Running
    $stopButton.Enabled = -not $Running
    $refreshButton.Enabled = -not $Running
    if ($Running) {
        $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
        $progress.MarqueeAnimationSpeed = 30
    }
    else {
        $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
        $progress.MarqueeAnimationSpeed = 0
    }
}

function Start-ScriptOperation {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments,
        [string]$Name,
        [string]$DownloadPath,
        [scriptblock]$After
    )

    $logDirectory = Join-Path $Root "logs"
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $logStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $safeName = ($Name -replace "[^A-Za-z0-9_.-]", "-")
    $script:operationLogPath = Join-Path $logDirectory "launcher-$logStamp-$safeName.log"
    $taskArguments = @($script:operationLogPath, $ScriptPath) + $Arguments
    $argumentText = ($taskArguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join " "
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    $psi.Arguments = "/d /c `"`"$TaskRunner`" $argumentText`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $script:operationProcess = New-Object System.Diagnostics.Process
    $script:operationProcess.StartInfo = $psi
    $script:operationDownloadPath = $DownloadPath
    $script:operationStage = "Starting"
    [void]$script:operationProcess.Start()
    $script:operationName = $Name
    $script:operationAfter = $After
    Set-OperationUi -Running $true
    Write-LauncherLog "Started: $Name"
    Refresh-ServerStatus
}

function Start-SelectedServer {
    $logDirectory = Join-Path $Root "logs"
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $logStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:serverLogPath = Join-Path $logDirectory "launcher-$logStamp-start-server.log"
    $taskArguments = @($script:serverLogPath, $StartScript)
    $argumentText = ($taskArguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join " "
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    $psi.Arguments = "/d /c `"`"$TaskRunner`" $argumentText`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $script:serverProcess = New-Object System.Diagnostics.Process
    $script:serverProcess.StartInfo = $psi
    [void]$script:serverProcess.Start()
    $script:serverStarting = $true
    $script:serverFailureReported = $false
    Write-LauncherLog "Starting server. Loading a model can take a moment."
    $statusLabel.Text = "Loading model..."
}

function Stop-ThenStartSelectedModel {
    $selected = Get-SelectedModel
    if (-not $selected) {
        return
    }
    $script:pendingModelName = $selected.Name

    Start-ScriptOperation -ScriptPath $StopScript -Arguments @() -Name "Stop current server" -After {
        $script:serverProcess = $null
        $script:serverStarting = $false
        $modelSpec = $manifest.models.PSObject.Properties[$script:pendingModelName].Value
        $modelPath = Join-Path $Root (Join-Path "models" $modelSpec.file)
        Start-ScriptOperation -ScriptPath $InstallScript -Arguments @("-Model", $script:pendingModelName) -Name "Prepare $script:pendingModelName" -DownloadPath $modelPath -After {
            $selectedItem = Get-SelectedModel
            if ($selectedItem -and $selectedItem.Name -eq $script:pendingModelName) {
                $selectedItem.Installed = $true
            }
            Update-SelectedModelDetails
            Write-LauncherLog "Prepared: $script:pendingModelName"
            Start-SelectedServer
        }
    }
}

$modelPicker.add_SelectedIndexChanged({ Update-SelectedModelDetails })

$startButton.add_Click({
    Stop-ThenStartSelectedModel
})

$stopButton.add_Click({
    Start-ScriptOperation -ScriptPath $StopScript -Arguments @() -Name "Stop server" -After {
        $script:serverProcess = $null
        $script:serverStarting = $false
        Write-LauncherLog "Server stopped."
        Refresh-ServerStatus
    }
})

$chatButton.add_Click({
    if (Get-ServerModel) {
        Start-Process "http://127.0.0.1:8080"
    }
    else {
        [System.Windows.Forms.MessageBox]::Show("Start the server before opening chat.", "Local AI Launcher")
    }
})

$refreshButton.add_Click({ Refresh-ServerStatus })

$copyPromptButton.add_Click({
    [System.Windows.Forms.Clipboard]::SetText((Get-OcrPrompt))
    Write-LauncherLog "Copied $($ocrOutputPicker.SelectedItem) OCR prompt."
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 750
$timer.add_Tick({
    Update-OperationProgress

    if ($script:operationProcess -and $script:operationProcess.HasExited) {
        $exitCode = $script:operationProcess.ExitCode
        $after = $script:operationAfter
        $completedName = $script:operationName
        $completedLogPath = $script:operationLogPath
        $script:operationProcess = $null
        $script:operationName = $null
        $script:operationAfter = $null
        $script:operationDownloadPath = $null
        $script:operationStage = $null
        $script:operationLogPath = $null
        Set-OperationUi -Running $false

        if ($exitCode -ne 0) {
            Write-LauncherLog "$completedName failed (exit code $exitCode)."
            $details = if ($completedLogPath -and (Test-Path $completedLogPath)) { (Get-Content $completedLogPath -Tail 12) -join [Environment]::NewLine } else { "No process output was captured." }
            [System.Windows.Forms.MessageBox]::Show("$completedName failed (exit code $exitCode).`r`n`r`n$details", "Local AI Launcher")
        }
        else {
            Write-LauncherLog "Completed: $completedName"
            if ($after) {
                & $after
            }
        }
    }

    if ([DateTime]::Now -ge $script:nextStatusRefresh) {
        Refresh-ServerStatus
        $script:nextStatusRefresh = [DateTime]::Now.AddSeconds(3)
    }
})

$currentConfigModel = $null
if (Test-Path $ConfigPath) {
    try {
        $currentConfigModel = (Get-Content $ConfigPath -Raw | ConvertFrom-Json).name
    }
    catch {
        # A malformed local config should not prevent the launcher from opening.
    }
}

$initialIndex = 0
if ($currentConfigModel) {
    for ($i = 0; $i -lt $modelPicker.Items.Count; $i++) {
        if ($modelPicker.Items[$i].Name -eq $currentConfigModel) {
            $initialIndex = $i
            break
        }
    }
}
$modelPicker.SelectedIndex = $initialIndex
Update-SelectedModelDetails
Write-LauncherLog "Launcher started."
Refresh-ServerStatus
$form.add_Shown({
    if ($SmokeTest) {
        $form.Close()
    }
})
$timer.Start()
[void]$form.ShowDialog()
