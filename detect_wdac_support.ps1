<#
.SYNOPSIS
  Detects whether the system meets requirements for Windows Defender Application Control (WDAC).

  Checks:
    1. OS SKU
    2. Secure Boot
    3. Virtualization firmware support
    4. TPM status
    5. WDAC Windows features
    6. CIPolicy module
#>

Write-Host "=== WDAC Support Check Start ===" -ForegroundColor Cyan

# 1. Check OS SKU
Write-Host "`n[1] Checking OS SKU..."
try {
    $product = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop).ProductName
    if ($product -match "Enterprise|Education") {
        Write-Host "    OS SKU: $product (Supported)" -ForegroundColor Green
    } else {
        Write-Host "    OS SKU: $product (Not supported)" -ForegroundColor Red
    }
} catch {
    Write-Host "    Failed to read OS SKU: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Check Secure Boot
Write-Host "`n[2] Checking Secure Boot..."
if (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
    try {
        $sb = Confirm-SecureBootUEFI
        if ($sb) {
            Write-Host "    Secure Boot: Enabled" -ForegroundColor Green
        } else {
            Write-Host "    Secure Boot: Disabled" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    Error checking Secure Boot: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "    Secure Boot check not available (Legacy BIOS)" -ForegroundColor Yellow
}

# 3. Check virtualization firmware
Write-Host "`n[3] Checking virtualization firmware support..."
try {
    $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
    if ($cpu.VirtualizationFirmwareEnabled) {
        Write-Host "    Virtualization firmware: Enabled" -ForegroundColor Green
    } else {
        Write-Host "    Virtualization firmware: Disabled" -ForegroundColor Yellow
    }
} catch {
    Write-Host "    Error checking virtualization firmware: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Check TPM
Write-Host "`n[4] Checking TPM..."
if (Get-Command Get-Tpm -ErrorAction SilentlyContinue) {
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        if ($tpm.TpmPresent) {
            $presentColor = "Green"
        } else {
            $presentColor = "Yellow"
        }
        Write-Host "    TPM Present: $($tpm.TpmPresent)" -ForegroundColor $presentColor

        if ($tpm.TpmReady) {
            $readyColor = "Green"
        } else {
            $readyColor = "Yellow"
        }
        Write-Host "    TPM Ready:   $($tpm.TpmReady)" -ForegroundColor $readyColor
    } catch {
        Write-Host "    Error checking TPM: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "    Get-Tpm cmdlet not available" -ForegroundColor Yellow
}

# 5. Check WDAC Windows features
Write-Host "`n[5] Checking WDAC required Windows features..."
$features = @(
    "DeviceGuard-Client-Package",
    "DeviceGuard-Local-CSP",
    "DeviceGuard-Remote-CSP"
)
foreach ($f in $features) {
    try {
        $feat = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction Stop
        if ($feat.State -eq "Enabled") {
            Write-Host "    $f : Enabled" -ForegroundColor Green
        } else {
            Write-Host "    $f : $($feat.State)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    $f : Not found or error" -ForegroundColor Red
    }
}

# 6. Check CIPolicy module
Write-Host "`n[6] Checking CIPolicy PowerShell module..."
if (Get-Module -ListAvailable -Name CIPolicy) {
    Write-Host "    CIPolicy module: Available" -ForegroundColor Green
} else {
    Write-Host "    CIPolicy module: Not available" -ForegroundColor Red
}

Write-Host "`n=== WDAC Support Check End ===" -ForegroundColor Cyan
