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
$form.Size = New-Object System.Drawing.Size(760, 620)
$form.MinimumSize = New-Object System.Drawing.Size(760, 620)
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

$ocrLabel = New-Object System.Windows.Forms.Label
$ocrLabel.Text = "Chandra OCR output"
$ocrLabel.Location = New-Object System.Drawing.Point(26, 378)
$ocrLabel.AutoSize = $true
$form.Controls.Add($ocrLabel)

$ocrOutputPicker = New-Object System.Windows.Forms.ComboBox
$ocrOutputPicker.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$ocrOutputPicker.Location = New-Object System.Drawing.Point(26, 402)
$ocrOutputPicker.Size = New-Object System.Drawing.Size(200, 32)
[void]$ocrOutputPicker.Items.AddRange(@("Markdown", "JSON", "HTML", "Plain text"))
$ocrOutputPicker.SelectedIndex = 0
$form.Controls.Add($ocrOutputPicker)

$copyPromptButton = New-Object System.Windows.Forms.Button
$copyPromptButton.Text = "Copy OCR prompt"
$copyPromptButton.Location = New-Object System.Drawing.Point(238, 399)
$copyPromptButton.Size = New-Object System.Drawing.Size(190, 36)
$form.Controls.Add($copyPromptButton)

$ocrHint = New-Object System.Windows.Forms.Label
$ocrHint.Text = "Paste the copied prompt into chat together with an image."
$ocrHint.Location = New-Object System.Drawing.Point(26, 443)
$ocrHint.Size = New-Object System.Drawing.Size(680, 24)
$form.Controls.Add($ocrHint)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = "Activity"
$logLabel.Location = New-Object System.Drawing.Point(26, 482)
$logLabel.AutoSize = $true
$form.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(26, 505)
$logBox.Size = New-Object System.Drawing.Size(680, 66)
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

function Write-LauncherLog {
    param([string]$Message)

    $stamp = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("[$stamp] $Message$([Environment]::NewLine)")
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
        [scriptblock]$After
    )

    $argumentText = ($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join " "
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $argumentText"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $script:operationProcess = New-Object System.Diagnostics.Process
    $script:operationProcess.StartInfo = $psi
    [void]$script:operationProcess.Start()
    $script:operationName = $Name
    $script:operationAfter = $After
    Set-OperationUi -Running $true
    Write-LauncherLog "Started: $Name"
    Refresh-ServerStatus
}

function Start-SelectedServer {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$StartScript`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $script:serverProcess = New-Object System.Diagnostics.Process
    $script:serverProcess.StartInfo = $psi
    [void]$script:serverProcess.Start()
    $script:serverStarting = $true
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
        Start-ScriptOperation -ScriptPath $InstallScript -Arguments @("-Model", $script:pendingModelName) -Name "Prepare $script:pendingModelName" -After {
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
    if ($script:operationProcess -and $script:operationProcess.HasExited) {
        $exitCode = $script:operationProcess.ExitCode
        $after = $script:operationAfter
        $completedName = $script:operationName
        $script:operationProcess = $null
        $script:operationName = $null
        $script:operationAfter = $null
        Set-OperationUi -Running $false

        if ($exitCode -ne 0) {
            Write-LauncherLog "$completedName failed (exit code $exitCode)."
            [System.Windows.Forms.MessageBox]::Show("$completedName failed. Check the PowerShell error and activity log.", "Local AI Launcher")
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
