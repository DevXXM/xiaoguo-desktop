<#
.SYNOPSIS
    Create local user 'xiaoguo' with no password, hide Administrator, and enable auto-logon to xiaoguo.
#>

# 1. require elevation
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: must run as Administrator" -ForegroundColor Red
    exit 1
}

# 2. create user xiaoguo with no password
if (-not (Get-LocalUser -Name 'xiaoguo' -ErrorAction SilentlyContinue)) {
    try {
        New-LocalUser -Name 'xiaoguo' -NoPassword `
          -FullName 'xiaoguo' -Description 'Standard user xiaoguo' -ErrorAction Stop
        Add-LocalGroupMember -Group 'Users' -Member 'xiaoguo' -ErrorAction Stop
        Write-Host "User 'xiaoguo' created." -ForegroundColor Green
    } catch {
        Write-Host "ERROR creating user 'xiaoguo': $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "User 'xiaoguo' already exists." -ForegroundColor Yellow
}

# 3. hide built-in Administrator on sign-in screen
try {
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    New-ItemProperty -Path $regPath -Name 'Administrator' -PropertyType DWord -Value 0 -Force
    Write-Host "Administrator hidden from sign-in screen." -ForegroundColor Green
} catch {
    Write-Host "ERROR hiding Administrator: $_" -ForegroundColor Red
    exit 1
}

# 4. configure auto-logon to xiaoguo
try {
    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty -Path $wl -Name 'AutoAdminLogon'    -Value '1'             -Type String -Force
    Set-ItemProperty -Path $wl -Name 'DefaultUserName'   -Value 'xiaoguo'       -Type String -Force
    Set-ItemProperty -Path $wl -Name 'DefaultPassword'   -Value ''              -Type String -Force
    Set-ItemProperty -Path $wl -Name 'DefaultDomainName' -Value $env:COMPUTERNAME -Type String -Force
    Write-Host "Auto-logon configured for 'xiaoguo' (empty password)." -ForegroundColor Green
} catch {
    Write-Host "ERROR configuring auto-logon: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Setup complete. Please reboot to apply changes." -ForegroundColor Cyan
