<#
.SYNOPSIS
    Coleta métricas operacionais do Active Directory e retorna em JSON
    para consumo pelo Zabbix (item tipo "Zabbix agent", UserParameter).

.DESCRIPTION
    Consolida: saúde geral (health score), status de serviços críticos,
    dados de domínio/floresta/FSMO, DCs, SYSVOL/NETLOGON, usuários,
    computadores, eventos de segurança/DNS/Directory Service e replicação.

.NOTES
    Executar em um Domain Controller (ou host com RSAT-AD-PowerShell)
    com permissão de leitura no Security Event Log.
#>

param(
    [string]$Server = $env:COMPUTERNAME,
    [int]$InactiveDays = 30,
    [int]$EventHours = 24
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory -ErrorAction Stop

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$now = Get-Date
$since = $now.AddHours(-$EventHours)
$inactiveThreshold = $now.AddDays(-$InactiveDays)

function Get-SvcStatus {
    param([string]$Name)
    try {
        $s = Get-Service -Name $Name -ErrorAction Stop
        return $s.Status.ToString()
    } catch {
        return "NotFound"
    }
}

function Get-EventCount {
    param([string]$LogName, [int[]]$EventId, [datetime]$After)
    try {
        $filter = @{ LogName = $LogName; StartTime = $After }
        if ($EventId) { $filter['Id'] = $EventId }
        (Get-WinEvent -FilterHashtable $filter -ErrorAction Stop |
            Measure-Object).Count
    } catch {
        0
    }
}

#region Domínio / Floresta / FSMO
$domain = Get-ADDomain -Server $Server
$forest = Get-ADForest -Server $Server

$fsmo = [ordered]@{
    schema_master          = $forest.SchemaMaster
    domain_naming_master    = $forest.DomainNamingMaster
    pdc_emulator            = $domain.PDCEmulator
    rid_master              = $domain.RIDMaster
    infrastructure_master   = $domain.InfrastructureMaster
}
#endregion

#region Domain Controllers
$dcs = @(Get-ADDomainController -Filter * -Server $Server)
$dcList = @()
foreach ($dc in $dcs) {
    $dcList += [ordered]@{
        name        = $dc.Name
        hostname    = $dc.HostName
        site        = $dc.Site
        ip_address  = $dc.IPv4Address
        is_gc       = [bool]$dc.IsGlobalCatalog
        os_version  = $dc.OperatingSystem
        reachable   = [bool](Test-Connection -ComputerName $dc.HostName -Count 1 -Quiet -ErrorAction SilentlyContinue)
    }
}
#endregion

#region Serviços críticos (no DC alvo)
$services = [ordered]@{
    ntds     = Get-SvcStatus -Name 'NTDS'
    dns      = Get-SvcStatus -Name 'DNS'
    netlogon = Get-SvcStatus -Name 'Netlogon'
    kdc      = Get-SvcStatus -Name 'Kdc'
    dfsr     = Get-SvcStatus -Name 'DFSR'
    w32time  = Get-SvcStatus -Name 'W32Time'
    adws     = Get-SvcStatus -Name 'ADWS'
    certsvc  = Get-SvcStatus -Name 'CertSvc'
}
$servicesDown = ($services.Values | Where-Object { $_ -ne 'Running' -and $_ -ne 'NotFound' }).Count
#endregion

#region SYSVOL / NETLOGON (compartilhamentos)
function Test-Share {
    param([string]$ComputerName, [string]$ShareName)
    Test-Path "\\$ComputerName\$ShareName" -ErrorAction SilentlyContinue
}
$sysvolOk   = Test-Share -ComputerName $Server -ShareName 'SYSVOL'
$netlogonOk = Test-Share -ComputerName $Server -ShareName 'NETLOGON'
#endregion

#region Usuários
$users = Get-ADUser -Filter * -Server $Server -Properties LockedOut, Enabled, PasswordExpired, PasswordNeverExpires, LastLogonTimestamp

$usersTotal          = @($users).Count
$usersLockedOut      = @($users | Where-Object { $_.LockedOut }).Count
$usersDisabled       = @($users | Where-Object { -not $_.Enabled }).Count
$usersPasswordExpired = @($users | Where-Object { $_.PasswordExpired }).Count
$usersInactive       = @($users | Where-Object {
    $_.Enabled -and $_.LastLogonTimestamp -and
    ([datetime]::FromFileTime($_.LastLogonTimestamp)) -lt $inactiveThreshold
}).Count
#endregion

#region Computadores
$computers = Get-ADComputer -Filter * -Server $Server -Properties Enabled, LastLogonTimestamp

$computersTotal    = @($computers).Count
$computersEnabled  = @($computers | Where-Object { $_.Enabled }).Count
$computersDisabled = @($computers | Where-Object { -not $_.Enabled }).Count
$computersInactive = @($computers | Where-Object {
    $_.Enabled -and $_.LastLogonTimestamp -and
    ([datetime]::FromFileTime($_.LastLogonTimestamp)) -lt $inactiveThreshold
}).Count
#endregion

#region Eventos de Segurança (últimas N horas)
$secEvents = [ordered]@{
    logon_success       = Get-EventCount -LogName 'Security' -EventId 4624 -After $since
    logon_failure       = Get-EventCount -LogName 'Security' -EventId 4625 -After $since
    account_lockout     = Get-EventCount -LogName 'Security' -EventId 4740 -After $since
    user_created         = Get-EventCount -LogName 'Security' -EventId 4720 -After $since
    user_deleted         = Get-EventCount -LogName 'Security' -EventId 4726 -After $since
    password_reset       = Get-EventCount -LogName 'Security' -EventId @(4724,4723) -After $since
    group_membership_chg = Get-EventCount -LogName 'Security' -EventId @(4728,4729,4732,4733,4756,4757) -After $since
}
$secEventsOther = 0  # removido calculo caro (full-scan sem filtro de EventID no Security log,
                      # que chegava a 60-70s sozinho); as categorias relevantes ja sao
                      # cobertas pelos IDs especificos acima.
#endregion

#region Eventos de DNS e Directory Service (erros/avisos)
function Get-ErrorWarningCount {
    param([string]$LogName, [datetime]$After)
    try {
        (Get-WinEvent -FilterHashtable @{ LogName = $LogName; StartTime = $After; Level = 2,3 } `
            -ErrorAction Stop | Measure-Object).Count
    } catch { 0 }
}

$dsEvents = [ordered]@{
    dns_errors_warnings              = Get-ErrorWarningCount -LogName 'DNS Server'       -After $since
    directory_service_errors_warnings = Get-ErrorWarningCount -LogName 'Directory Service' -After $since
}
#endregion

#region Replicação (repadmin)
$replPartners = Get-ADReplicationPartnerMetadata -Target $Server -Scope Server -ErrorAction SilentlyContinue
$replFailures = @(Get-ADReplicationFailure -Target $Server -Scope Server -ErrorAction SilentlyContinue)

$replFailureCount = $replFailures.Count
$replLastSuccess  = if ($replPartners) {
    ($replPartners | Sort-Object LastReplicationSuccess | Select-Object -First 1).LastReplicationSuccess
} else { $null }

$replStatus = if ($replFailureCount -eq 0) { 'OK' }
              elseif ($replFailureCount -le 2) { 'Warning' }
              else { 'Critical' }
#endregion

#region Health Score (0-100, ponderado)
# Pesos: serviços 40 | replicação 25 | usuários bloqueados 15 | falhas logon 10 | DCs offline 10
$svcScore   = [math]::Max(0, 40 - ($servicesDown * 10))
$replScore  = if ($replFailureCount -eq 0) { 25 } elseif ($replFailureCount -le 2) { 15 } else { 0 }
$lockScore  = [math]::Max(0, 15 - ($usersLockedOut))
$logonScore = [math]::Max(0, 10 - [math]::Floor($secEvents.logon_failure / 50))
$dcOffline  = ($dcList | Where-Object { -not $_.reachable }).Count
$dcScore    = [math]::Max(0, 10 - ($dcOffline * 10))

$healthScore = [math]::Min(100, $svcScore + $replScore + $lockScore + $logonScore + $dcScore)
#endregion

$result = [ordered]@{
    hostname                = $Server
    timestamp                = $now.ToString('o')
    collection_time_ms       = 0   # preenchido no fim

    domain_name              = $domain.DNSRoot
    forest_name               = $forest.Name
    domain_mode               = $domain.DomainMode.ToString()
    forest_mode                = $forest.ForestMode.ToString()
    fsmo_roles                 = $fsmo

    domain_controllers_total  = $dcs.Count
    domain_controllers         = $dcList

    sysvol_status              = if ($sysvolOk) { 'OK' } else { 'FAIL' }
    netlogon_share_status       = if ($netlogonOk) { 'OK' } else { 'FAIL' }

    services                   = $services
    services_down               = $servicesDown

    users_total                = $usersTotal
    users_locked_out            = $usersLockedOut
    users_disabled               = $usersDisabled
    users_password_expired       = $usersPasswordExpired
    users_inactive                = $usersInactive

    computers_total              = $computersTotal
    computers_enabled             = $computersEnabled
    computers_disabled             = $computersDisabled
    computers_inactive             = $computersInactive

    security_events_24h            = $secEvents
    security_events_other_24h       = $secEventsOther
    dns_ds_events_24h                = $dsEvents

    replication_status               = $replStatus
    replication_failures              = $replFailureCount
    replication_last_success          = if ($replLastSuccess) { $replLastSuccess.ToString('o') } else { $null }

    ad_health_score                   = $healthScore
}

$sw.Stop()
$result.collection_time_ms = $sw.ElapsedMilliseconds

$result | ConvertTo-Json -Depth 6 -Compress
