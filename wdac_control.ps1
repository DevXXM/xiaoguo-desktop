<#
.SYNOPSIS
  һ������ WDAC��ֻ���� Explorer��PowerShell��xiaoguo-desktop ���С�

.PARAMETER Action
  Audit   # ���� XML ����ļ�
  Enforce # ת�����ơ�ǩ�������������ǿ��ִ��
  Disable # �������Բ��ر� WDAC
#>
param(
  [Parameter(Mandatory)]
  [ValidateSet("Audit","Enforce","Disable")]
  [string]$Action
)

# 1. �����Թ���Ա����
$prin = New-Object Security.Principal.WindowsPrincipal(
  [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $prin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "���Թ���Ա������д˽ű�"
    exit 1
}

# 2. ���û�� CIPolicy ģ�飬��ͨ�� DISM ���� WDAC ���
if (-not (Get-Module -ListAvailable -Name CIPolicy)) {
    Write-Host "��⵽ CIPolicy ģ��ȱʧ���������� WDAC ���� Windows ����..."
    dism.exe /Online /Enable-Feature /FeatureName:DeviceGuard-Client-Package /All /NoRestart | Out-Null
    dism.exe /Online /Enable-Feature /FeatureName:DeviceGuard-Local-CSP /All /NoRestart        | Out-Null
    dism.exe /Online /Enable-Feature /FeatureName:DeviceGuard-Remote-CSP /All /NoRestart       | Out-Null
    Write-Host "����������ɣ����������������б��ű��Լ�����" -ForegroundColor Yellow
    exit 0
}

# 3. ���� CIPolicy ģ��
Import-Module CIPolicy -ErrorAction Stop

# 4. ̽�����Ӧ��Ŀ¼���ű�����Ŀ¼��
$AppFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExeRule   = Join-Path $AppFolder "*.exe"

# 5. ׼����ǩ��֤�飨����һ�����ɣ�
$Subject = "CN=WDACPolicySelfCert"
$Cert    = Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -EQ $Subject
if (-not $Cert) {
    Write-Host "���ɲ�������ǩ������ǩ��֤��..."
    $Cert = New-SelfSignedCertificate `
      -Subject $Subject `
      -CertStoreLocation "Cert:\LocalMachine\My" `
      -Type CodeSigningCert `
      -KeyAlgorithm RSA -KeyLength 2048 `
      -NotAfter (Get-Date).AddYears(5)
    # ���뵽�������θ����͡���������Ա��
    $r=New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
    $r.Open("ReadWrite"); $r.Add($Cert); $r.Close()
    $t=New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople","LocalMachine")
    $t.Open("ReadWrite"); $t.Add($Cert); $t.Close()
}

# 6. ��ʱ�ļ�Ŀ¼
$TempDir   = Join-Path $env:TEMP "WDAC_Policy"
Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path $TempDir -ItemType Directory | Out-Null

$PubXml    = Join-Path $TempDir "publisher.xml"
$PathXml   = Join-Path $TempDir "path.xml"
$MergedXml = Join-Path $TempDir "policy.xml"
$BinPolicy = Join-Path $TempDir "policy.p7b"
$Dest      = "C:\Windows\System32\CodeIntegrity\CiPolicies\Active\xiaoguo_policy.p7b"

# 7. ����ģʽ�߼�
switch ($Action) {
  "Audit" {
    Write-Host "[Audit] ���� Publisher ��Ʋ���..."
    New-CIPolicy -Level Publisher -UserPEsIncluded -Audit -FilePath $PubXml

    Write-Host "[Audit] ���� Path ��Ʋ���..."
    New-CIPolicy -Level FilePath `
      -FilePathRules @("$env:WinDir\explorer.exe",
                       "$env:WinDir\System32\WindowsPowerShell\v1.0\powershell.exe",
                       $ExeRule) `
      -Audit -FilePath $PathXml

    Write-Host "[Audit] �ϲ��� XML..."
    Merge-CIPolicy -PolicyPaths @($PubXml,$PathXml) -OutputFile $MergedXml

    Write-Host "`n[Audit] ��ɣ�XML �ļ��� $MergedXml" -ForegroundColor Yellow
  }

  "Enforce" {
    # ��ִ�� Audit ����
    & $MyInvocation.MyCommand.Path -Action Audit

    # �л�Ϊǿ��ģʽ
    [xml]$doc = Get-Content $MergedXml
    $doc.Policy.Config.EnforcementMode = "Enabled"
    $doc.Save($MergedXml)

    Write-Host "[Enforce] ת��Ϊ�����Ʋ���..."
    ConvertFrom-CIPolicy -XmlFilePath $MergedXml -BinaryFilePath $BinPolicy

    Write-Host "[Enforce] ʹ����ǩ��֤��ǩ��..."
    Set-AuthenticodeSignature -FilePath $BinPolicy -Certificate $Cert | Out-Null

    Write-Host "[Enforce] ������Ե�ϵͳ..."
    Copy-Item $BinPolicy -Destination $Dest -Force

    Write-Host "[Enforce] ���� WDAC ǿ��ִ��..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" `
      -Name "EnableVirtualizationBasedSecurity" -Value 1 -Type DWord -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
      -Name "LsaCfgFlags" -Value 1 -Type DWord -Force | Out-Null

    Write-Host "`n[Enforce] ��ɣ�����������Ч��" -ForegroundColor Green
  }

  "Disable" {
    Write-Host "[Disable] ɾ������Ĳ����ļ�..."
    if (Test-Path $Dest) { Remove-Item $Dest -Force }

    Write-Host "[Disable] �ر� WDAC ǿ��ִ��..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" `
      -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
      -Name "LsaCfgFlags" -Value 0 -Type DWord -Force | Out-Null

    Write-Host "`n[Disable] ��ɣ��������Իָ�������" -ForegroundColor Green
  }
}
