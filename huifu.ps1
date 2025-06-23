<#
.SYNOPSIS
  Unhide Administrator, disable auto-logon, enable the Administrator account.
#>

# 1. elevate check
$pr = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: run as Administrator" -ForegroundColor Red
    exit 1
}

# 2. unhide Administrator in UserList
$ulist = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'
if (Test-Path $ulist) {
    if (Get-ItemProperty -Path $ulist -Name 'Administrator' -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $ulist -Name 'Administrator' -Force
        Write-Host "Administrator unhidden." -ForegroundColor Green
    } else {
        Write-Host "Administrator was not hidden." -ForegroundColor Yellow
    }
} else {
    Write-Host "UserList key not found; no hiding was configured." -ForegroundColor Yellow
}

# 3. disable auto-logon
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $winlogon -Name 'AutoAdminLogon'   -Value '0' -Type String -Force
Remove-ItemProperty -Path $winlogon -Name 'DefaultPassword' -ErrorAction SilentlyContinue
# (optional) remove DefaultUserName/DefaultDomainName if needed:
# Remove-ItemProperty -Path $winlogon -Name 'DefaultUserName' -ErrorAction SilentlyContinue
# Remove-ItemProperty -Path $winlogon -Name 'DefaultDomainName' -ErrorAction SilentlyContinue
Write-Host "AutoAdminLogon disabled and saved password removed." -ForegroundColor Green

# 4. ensure Administrator is enabled
try {
    Enable-LocalUser -Name 'Administrator'
    Write-Host "Administrator account enabled." -ForegroundColor Green
} catch {
    Write-Host "ERROR enabling Administrator: $_" -ForegroundColor Red
}

Write-Host "All done. Please reboot to see Administrator on the logon screen." -ForegroundColor Cyan
