param(
  [Parameter(Mandatory)]
  [string]$StandardUserName,

  [Parameter(Mandatory)]
  [string]$StandardUserPassword
)

function Write-Log {
  param($msg, $color='White')
  Write-Host $msg -ForegroundColor $color
}

# require elevation
$pr = New-Object Security.Principal.WindowsPrincipal(
  [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $pr.IsInRole(
      [Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Log "Script must be run as Administrator." 'Red'
  exit 1
}

# set Administrator password to dzwydev
try {
  $secureAdminPwd = ConvertTo-SecureString 'dzwydev' -AsPlainText -Force
  Set-LocalUser -Name 'Administrator' -Password $secureAdminPwd -ErrorAction Stop
  Write-Log "Administrator password set to 'dzwydev'." 'Green'
} catch {
  Write-Log "Error setting Administrator password: $_" 'Red'
  exit 1
}

# create standard user if missing
if (-not (Get-LocalUser -Name $StandardUserName -ErrorAction SilentlyContinue)) {
  try {
    $secureStdPwd = ConvertTo-SecureString $StandardUserPassword -AsPlainText -Force
    New-LocalUser -Name $StandardUserName `
                  -Password $secureStdPwd `
                  -FullName $StandardUserName `
                  -Description "Auto-login standard user" -ErrorAction Stop
    Add-LocalGroupMember -Group 'Users' -Member $StandardUserName -ErrorAction Stop
    Write-Log "Standard user '$StandardUserName' created." 'Green'
  } catch {
    Write-Log "Error creating standard user: $_" 'Red'
    exit 1
  }
} else {
  Write-Log "Standard user '$StandardUserName' already exists." 'Yellow'
}

# hide Administrator from sign-in screen
try {
  $ulist = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
  if (-not (Test-Path $ulist)) { New-Item -Path $ulist -Force | Out-Null }
  New-ItemProperty -Path $ulist -Name 'Administrator' -PropertyType DWord -Value 0 -Force
  Write-Log "Administrator account hidden from sign-in screen." 'Green'
} catch {
  Write-Log "Error hiding Administrator: $_" 'Red'
}

# configure auto-logon
try {
  $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
  Set-ItemProperty -Path $wl -Name 'AutoAdminLogon'    -Value '1'                   -Type String -Force
  Set-ItemProperty -Path $wl -Name 'DefaultUserName'   -Value $StandardUserName     -Type String -Force
  Set-ItemProperty -Path $wl -Name 'DefaultPassword'   -Value $StandardUserPassword -Type String -Force
  Set-ItemProperty -Path $wl -Name 'DefaultDomainName' -Value $env:COMPUTERNAME      -Type String -Force
  Write-Log "Auto-logon configured for '$StandardUserName'." 'Green'
} catch {
  Write-Log "Error configuring auto-logon: $_" 'Red'
}

Write-Log "Setup complete. Please reboot to apply changes." 'Cyan'
