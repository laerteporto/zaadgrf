<#
.SYNOPSIS
    Executa ad_monitor.ps1 e grava o JSON resultante em disco de forma atomica
    (escreve em .tmp e so entao renomeia), para ser lido instantaneamente
    pelo Zabbix Agent via UserParameter (comando "type"), eliminando o risco
    de timeout na coleta sincrona.

.NOTES
    Agendar via Task Scheduler para rodar a cada 5 minutos, na mesma
    frequencia do item ad.monitor.data no Zabbix.
#>

param(
    [string]$OutputPath = "C:\Scripts\ad_monitor_output.json"
)

$ErrorActionPreference = 'Stop'
$tmpPath = "$OutputPath.tmp"

# IMPORTANTE: Out-File -Encoding utf8 no Windows PowerShell 5.1 grava BOM
# (Byte Order Mark) no inicio do arquivo, o que quebra o parsing JSON do
# Zabbix ("Preprocessing failed... expected opening character '{'").
# Por isso gravamos manualmente em UTF-8 SEM BOM.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

try {
    $json = & "$PSScriptRoot\ad_monitor.ps1"
    [System.IO.File]::WriteAllText($tmpPath, $json, $utf8NoBom)
    Move-Item -Path $tmpPath -Destination $OutputPath -Force
}
catch {
    $errJson = @{
        error     = $_.Exception.Message
        timestamp = (Get-Date).ToString('o')
        ad_health_score = 0
    } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($tmpPath, $errJson, $utf8NoBom)
    Move-Item -Path $tmpPath -Destination $OutputPath -Force
    throw
}
