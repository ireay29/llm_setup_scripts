param(
    [switch]$WithHermes,
    [int]$LlmDelaySeconds = 30,
    [int]$HermesDelaySeconds = 60
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$User = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

function Register-LogonAutostartTask {
    param(
        [string]$TaskName,
        [string]$ScriptPath,
        [string]$Description,
        [int]$DelaySeconds
    )

    if (-not (Test-Path $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`"" `
        -WorkingDirectory $Root

    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $User
    $trigger.Delay = "PT$($DelaySeconds)S"

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

    $principal = New-ScheduledTaskPrincipal `
        -UserId $User `
        -LogonType Interactive `
        -RunLevel Limited

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description $Description `
        -Force | Out-Null

    Write-Host "Registered task: $TaskName"
}

Register-LogonAutostartTask `
    -TaskName "Local AI Server Autostart" `
    -ScriptPath (Join-Path $PSScriptRoot "autostart-local-llm.ps1") `
    -Description "Starts the configured local llama.cpp server after user logon if port 8080 is not already healthy." `
    -DelaySeconds $LlmDelaySeconds

if ($WithHermes) {
    Register-LogonAutostartTask `
        -TaskName "Hermes Autostart" `
        -ScriptPath (Join-Path $PSScriptRoot "autostart-hermes.ps1") `
        -Description "Starts Hermes desktop, gateway, and SearXNG after user logon if they are not already running." `
        -DelaySeconds $HermesDelaySeconds
}
else {
    Write-Host "Hermes autostart was not requested. Use -WithHermes to register it."
}

$names = @("Local AI Server Autostart")
if ($WithHermes) {
    $names += "Hermes Autostart"
}

Get-ScheduledTask -TaskName $names | Select-Object TaskName,TaskPath,State
