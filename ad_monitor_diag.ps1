<#
.SYNOPSIS
    Versao de DIAGNOSTICO do ad_monitor.ps1 - mede o tempo de cada bloco
    separadamente e grava em C:\Scripts\ad_monitor_diag.log.
    Rodar via Task Scheduler (mesmo contexto do problema) para identificar
    exatamente qual chamada esta demorando.
#>

param(
    [string]$Server = $env:COMPUTERNAME,
    [int]$EventHours = 24
)

$logPath = "C:\Scripts\ad_monitor_diag.log"
"" | Out-File $logPath -Force

function Log-Step {
    param([string]$StepName, [scriptblock]$Action)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $err = $null
    try {
        & $Action | Out-Null
    } catch {
        $err = $_.Exception.Message
    }
    $sw.Stop()
    $line = "{0,-45} {1,8} ms   {2}" -f $StepName, $sw.ElapsedMilliseconds, $err
    $line | Out-File $logPath -Append
    Write-Host $line
}

$ErrorActionPreference = 'Stop'
$since = (Get-Date).AddHours(-$EventHours)

Log-Step "Import-Module ActiveDirectory" { Import-Module ActiveDirectory -ErrorAction Stop }
Log-Step "Get-ADDomain" { Get-ADDomain -Server $Server }
Log-Step "Get-ADForest" { Get-ADForest -Server $Server }
Log-Step "Get-ADDomainController -Filter *" { Get-ADDomainController -Filter * -Server $Server }
Log-Step "Test-Connection ao proprio DC" { Test-Connection -ComputerName $Server -Count 1 -Quiet -ErrorAction SilentlyContinue }
Log-Step "Get-Service NTDS" { Get-Service -Name 'NTDS' -ErrorAction Stop }
Log-Step "Test-Path SYSVOL" { Test-Path "\\$Server\SYSVOL" -ErrorAction SilentlyContinue }
Log-Step "Get-ADUser -Filter *" { Get-ADUser -Filter * -Server $Server -Properties LockedOut, Enabled, PasswordExpired, LastLogonTimestamp }
Log-Step "Get-ADComputer -Filter *" { Get-ADComputer -Filter * -Server $Server -Properties Enabled, LastLogonTimestamp }
Log-Step "Get-WinEvent Security (4625)" { Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625; StartTime=$since} -ErrorAction Stop }
Log-Step "Get-WinEvent Security (todos)" { Get-WinEvent -FilterHashtable @{LogName='Security'; StartTime=$since} -ErrorAction Stop }
Log-Step "Get-WinEvent DNS Server" { Get-WinEvent -FilterHashtable @{LogName='DNS Server'; StartTime=$since; Level=2,3} -ErrorAction Stop }
Log-Step "Get-WinEvent Directory Service" { Get-WinEvent -FilterHashtable @{LogName='Directory Service'; StartTime=$since; Level=2,3} -ErrorAction Stop }
Log-Step "Get-ADReplicationPartnerMetadata" { Get-ADReplicationPartnerMetadata -Target $Server -Scope Server -ErrorAction SilentlyContinue }
Log-Step "Get-ADReplicationFailure" { Get-ADReplicationFailure -Target $Server -Scope Server -ErrorAction SilentlyContinue }

"Diagnostico concluido." | Out-File $logPath -Append
