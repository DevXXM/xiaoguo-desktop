<#
.SYNOPSIS
  一键管理 WDAC，只允许 Explorer、PowerShell、xiaoguo-desktop 运行。

.PARAMETER Action
  Audit   # 生成 XML 审计文件
  Enforce # 转二进制→签名→部署→启用强制执行
  Disable # 撤销策略并关闭 WDAC
#>
param(
  [Parameter(Mandatory)]
  [ValidateSet("Audit","Enforce","Disable")]
  [string]$Action
)

# 1. 必须以管理员运行
$prin = New-Object Security.Principal.WindowsPrincipal(
  [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $prin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "请以管理员身份运行此脚本"
    exit 1
}

# 2. 如果没有 CIPolicy 模块，先通过 DISM 启用 WDAC 组件
if (-not (Get-Module -ListAvailable -Name CIPolicy)) {
    Write-Host "检测到 CIPolicy 模块缺失，正在启用 WDAC 所需 Windows 功能..."
    dism.exe /Online /Enable-Feature /FeatureName:DeviceGuard-Client-Package /All /NoRestart | Out-Null
    dism.exe /Online /Enable-Feature /FeatureName:DeviceGuard-Local-CSP /All /NoRestart        | Out-Null
    dism.exe /Online /Enable-Feature /FeatureName:DeviceGuard-Remote-CSP /All /NoRestart       | Out-Null
    Write-Host "功能启用完成，请重启后重新运行本脚本以继续。" -ForegroundColor Yellow
    exit 0
}

# 3. 导入 CIPolicy 模块
Import-Module CIPolicy -ErrorAction Stop

# 4. 探测你的应用目录（脚本所在目录）
$AppFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExeRule   = Join-Path $AppFolder "*.exe"

# 5. 准备自签名证书（仅第一次生成）
$Subject = "CN=WDACPolicySelfCert"
$Cert    = Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -EQ $Subject
if (-not $Cert) {
    Write-Host "生成并信任自签名代码签名证书..."
    $Cert = New-SelfSignedCertificate `
      -Subject $Subject `
      -CertStoreLocation "Cert:\LocalMachine\My" `
      -Type CodeSigningCert `
      -KeyAlgorithm RSA -KeyLength 2048 `
      -NotAfter (Get-Date).AddYears(5)
    # 导入到“受信任根”和“受信任人员”
    $r=New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
    $r.Open("ReadWrite"); $r.Add($Cert); $r.Close()
    $t=New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople","LocalMachine")
    $t.Open("ReadWrite"); $t.Add($Cert); $t.Close()
}

# 6. 临时文件目录
$TempDir   = Join-Path $env:TEMP "WDAC_Policy"
Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path $TempDir -ItemType Directory | Out-Null

$PubXml    = Join-Path $TempDir "publisher.xml"
$PathXml   = Join-Path $TempDir "path.xml"
$MergedXml = Join-Path $TempDir "policy.xml"
$BinPolicy = Join-Path $TempDir "policy.p7b"
$Dest      = "C:\Windows\System32\CodeIntegrity\CiPolicies\Active\xiaoguo_policy.p7b"

# 7. 三种模式逻辑
switch ($Action) {
  "Audit" {
    Write-Host "[Audit] 生成 Publisher 审计策略..."
    New-CIPolicy -Level Publisher -UserPEsIncluded -Audit -FilePath $PubXml

    Write-Host "[Audit] 生成 Path 审计策略..."
    New-CIPolicy -Level FilePath `
      -FilePathRules @("$env:WinDir\explorer.exe",
                       "$env:WinDir\System32\WindowsPowerShell\v1.0\powershell.exe",
                       $ExeRule) `
      -Audit -FilePath $PathXml

    Write-Host "[Audit] 合并到 XML..."
    Merge-CIPolicy -PolicyPaths @($PubXml,$PathXml) -OutputFile $MergedXml

    Write-Host "`n[Audit] 完成，XML 文件： $MergedXml" -ForegroundColor Yellow
  }

  "Enforce" {
    # 先执行 Audit 步骤
    & $MyInvocation.MyCommand.Path -Action Audit

    # 切换为强制模式
    [xml]$doc = Get-Content $MergedXml
    $doc.Policy.Config.EnforcementMode = "Enabled"
    $doc.Save($MergedXml)

    Write-Host "[Enforce] 转换为二进制策略..."
    ConvertFrom-CIPolicy -XmlFilePath $MergedXml -BinaryFilePath $BinPolicy

    Write-Host "[Enforce] 使用自签名证书签名..."
    Set-AuthenticodeSignature -FilePath $BinPolicy -Certificate $Cert | Out-Null

    Write-Host "[Enforce] 部署策略到系统..."
    Copy-Item $BinPolicy -Destination $Dest -Force

    Write-Host "[Enforce] 启用 WDAC 强制执行..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" `
      -Name "EnableVirtualizationBasedSecurity" -Value 1 -Type DWord -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
      -Name "LsaCfgFlags" -Value 1 -Type DWord -Force | Out-Null

    Write-Host "`n[Enforce] 完成，请重启以生效。" -ForegroundColor Green
  }

  "Disable" {
    Write-Host "[Disable] 删除部署的策略文件..."
    if (Test-Path $Dest) { Remove-Item $Dest -Force }

    Write-Host "[Disable] 关闭 WDAC 强制执行..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" `
      -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
      -Name "LsaCfgFlags" -Value 0 -Type DWord -Force | Out-Null

    Write-Host "`n[Disable] 完成，请重启以恢复正常。" -ForegroundColor Green
  }
}
