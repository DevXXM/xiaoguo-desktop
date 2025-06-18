<#
.SYNOPSIS
  Configure AppLocker Path rules for Explorer, PowerShell, xiaoguo-desktop, with backdoor.

.PARAMETER Action
  Enable | Disable
#>

param(
  [Parameter(Mandatory)]
  [ValidateSet("Enable","Disable")]
  [string]$Action
)

# require elevation
if (-not (
    [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Script must be run as Administrator"
    exit 1
}

# path to AppLocker module
$modulePath = "$env:WinDir\System32\WindowsPowerShell\v1.0\Modules\AppLocker\AppLocker.psd1"

if ($Action -eq "Enable") {
    if (-not (Test-Path $modulePath)) {
        Write-Error "AppLocker module not found at $modulePath"
        exit 1
    }
    Import-Module $modulePath -ErrorAction Stop

    # generate a path-based policy and clear existing executable rules
    $policy = New-AppLockerPolicy -RuleType Path -Xml
    $policy.RuleCollections.ExecutableRules.Clear()

    # list of allowed executables
    $allowed = @(
        "$env:WinDir\explorer.exe",
        "$env:WinDir\System32\WindowsPowerShell\v1.0\powershell.exe",
        "C:\Program Files\xiaoguo-desktop\*.exe",
        $MyInvocation.MyCommand.Path
    )

    # add each as a path rule
    foreach ($path in $allowed) {
        $ruleName = "Allow " + (Split-Path $path -Leaf)
        $rule = New-AppLockerFileRule -Name $ruleName `
            -User Everyone -Action Allow `
            -Path $path
        $policy.RuleCollections.ExecutableRules.Add($rule)
    }

    # apply and enforce
    Set-AppLockerPolicy -PolicyObject $policy -Merge
    Write-Host "AppLocker path rules applied."
    Write-Host "To disable, re-run script with: -Action Disable"
}
else {
    # reset to default and remove enforcement
    if (Test-Path $modulePath) { Import-Module $modulePath -ErrorAction SilentlyContinue }
    Set-AppLockerPolicy -Reset
    Get-AppLockerPolicy -Effective | Set-AppLockerPolicy -Merge
    Write-Host "AppLocker policy reset to default."
}
