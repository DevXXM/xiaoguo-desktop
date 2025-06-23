<#
.SYNOPSIS
  AppLocker lockdown script: allow only Explorer, PowerShell, and your app folder.

.PARAMETER Action
  Enable  – apply lockdown policy + enforce
  Disable – reset to default policy

.PARAMETER AppPath
  Path to folder containing your application's executables.
  Defaults to script’s parent directory.
#>
param(
  [Parameter(Mandatory)]
  [ValidateSet("Enable","Disable")]
  [string]$Action,

  [string]$AppPath = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

function Write-Log {
  param($msg, $color='White')
  Write-Host $msg -ForegroundColor $color
}

# require admin
$me = New-Object Security.Principal.WindowsPrincipal(
  [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Log "ERROR: must run as Administrator." 'Red'; exit 1
}

# ensure AppLocker module
if (-not (Get-Module -ListAvailable -Name AppLocker)) {
  Write-Log "ERROR: AppLocker module not available." 'Red'; exit 1
}
Import-Module AppLocker -ErrorAction Stop

if ($Action -eq 'Disable') {
  Write-Log "Resetting AppLocker to default…" 'Cyan'
  Set-AppLockerPolicy -Reset -ErrorAction Stop
  Get-AppLockerPolicy -Effective | Set-AppLockerPolicy -Merge -ErrorAction Stop
  # turn off enforcement
  if (Test-Path HKLM:\Software\Policies\Microsoft\Windows\SrpV2\Exe) {
    Remove-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\SrpV2\Exe -Name EnforcementMode -ErrorAction SilentlyContinue
  }
  Write-Log "Policy reset. Enforcement disabled." 'Green'
  return
}

# Enable path rules
if (-not (Test-Path $AppPath)) {
  Write-Log "ERROR: AppPath '$AppPath' does not exist." 'Red'; exit 1
}

# build allow-list
$allow = @(
  "$env:WinDir\explorer.exe",
  "$env:WinDir\System32\WindowsPowerShell\v1.0\powershell.exe"
)
try { $apps = Get-ChildItem -Path $AppPath -Filter '*.exe' -Recurse -ErrorAction Stop } catch {
  Write-Log "WARNING: error scanning AppPath: $_" 'Yellow'
}
if ($apps) { $allow += $apps.FullName }

# backdoor=this script
$allow += $MyInvocation.MyCommand.Path

# collect file info
$fileInfo = @()
try {
  $fileInfo += Get-AppLockerFileInformation -Path $allow -ErrorAction Stop
} catch { Write-Log "WARNING: some Path infos failed." 'Yellow' }
try {
  $fileInfo += Get-AppLockerFileInformation -Directory $AppPath -Recurse -FileType Exe -ErrorAction Stop
} catch { Write-Log "WARNING: directory file info failed." 'Yellow' }

if (-not $fileInfo) {
  Write-Log "ERROR: no file info, aborting." 'Red'; exit 1
}

# generate policy object
try {
  $policy = New-AppLockerPolicy -FileInformation $fileInfo -RuleType Path
} catch {
  Write-Log "ERROR: generating policy object: $_" 'Red'; exit 1
}

# apply + merge
try {
  Write-Log "Applying AppLocker policy…" 'Cyan'
  Set-AppLockerPolicy -PolicyObject $policy -Merge -ErrorAction Stop
} catch {
  Write-Log "ERROR: applying policy: $_" 'Red'; exit 1
}

# enforce executable rules
$base = 'HKLM:\Software\Policies\Microsoft\Windows\SrpV2'
if (-not (Test-Path $base)) { New-Item -Path $base -Force | Out-Null }
$exeKey = Join-Path $base 'Exe'
if (-not (Test-Path $exeKey)) { New-Item -Path $exeKey -Force | Out-Null }
New-ItemProperty -Path $exeKey -Name EnforcementMode -PropertyType DWord -Value 1 -Force | Out-Null

Write-Log "Policy applied and enforcement enabled. Allowed paths:" 'Green'
foreach ($p in $allow) { Write-Log "  $p" 'White' }
Write-Log "To disable, run this script with -Action Disable" 'Yellow'
