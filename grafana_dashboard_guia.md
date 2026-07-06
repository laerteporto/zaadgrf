# Dashboard Grafana — Active Directory Overview
Datasource: **Zabbix** (plugin `alexanderzobnin-zabbix-datasource`), 100% via itens do template `AD Health Monitoring`.

## Pré-requisitos
1. Plugin Zabbix instalado no Grafana e datasource apontando para a API do Zabbix.
2. Host com o template `AD Health Monitoring` (importar `zbx_ad_template.xml`) aplicado e coletando.
3. Grupo de host recomendado: `Active Directory`.

## Linha 1 — Painéis de valor único (Stat)
| Painel | Item Zabbix (key) | Tipo de painel | Observações |
|---|---|---|---|
| Health Score | `ad.health_score` | Stat (gauge) | Thresholds: verde ≥85, amarelo 70–84, vermelho <70 |
| Replication Status | `ad.repl.status` | Stat (texto) | Mapear "OK"→verde, "Warning"→amarelo, "Critical"→vermelho |
| Failed Logons 24h | `ad.sec.logon_failure` | Stat | Threshold amarelo >20, vermelho >50 |
| Users Disabled | `ad.users.disabled` | Stat | — |
| Domain Controllers | `ad.dc.total` | Stat | Subtítulo "Total" |

## Linha 2 — Série temporal
| Painel | Item(s) | Tipo |
|---|---|---|
| Health Score (24h) | `ad.health_score` (histórico) | Time series / area |

## Linha 3 — Status operacional
| Painel | Fonte | Tipo |
|---|---|---|
| Core Services Status | itens descobertos via LLD `ad.service.status[{#SERVICE}]` (NTDS, DNS, Netlogon, KDC, DFSR, W32Time, ADWS, CertSvc) | Painel "Service list" — usar Text panel com Value mappings (Running=🟢, senão 🔴) repetido por variável `$service` |
| Domain / Forest / FSMO | `ad.domain.name`, `ad.forest.name`, `ad.fsmo.pdc_emulator`, `ad.fsmo.rid_master`, `ad.fsmo.infrastructure_master`, `ad.fsmo.schema_master`, `ad.fsmo.domain_naming_master` | Table |
| Users & Computers | `ad.users.total`, `ad.users.locked_out`, `ad.users.password_expired`, `ad.users.inactive`, `ad.computers.total`, `ad.computers.enabled`, `ad.computers.disabled`, `ad.computers.inactive` | Stat / Bar gauge lado a lado |

## Linha 4 — Eventos de segurança (24h)
| Painel | Itens | Tipo |
|---|---|---|
| Security Events 24h | `ad.sec.logon_success`, `ad.sec.logon_failure`, `ad.sec.account_lockout`, `ad.sec.other` | Bar chart horizontal (cores: verde/vermelho/laranja/cinza, igual ao print de referência) |
| User Lifecycle Events | `ad.sec.user_created`, `ad.sec.user_deleted`, `ad.sec.password_reset`, `ad.sec.group_membership_chg` | Bar chart |
| DNS & Directory Service Events | `ad.dns.errors_warnings`, `ad.ds.errors_warnings` | Stat / Bar gauge |

## Variáveis do dashboard
- `$dc` → Zabbix template variable a partir da LLD de Domain Controllers (`{#DC_NAME}`), usada para filtrar painéis de reachability (`ad.dc.reachable[{#DC_HOST}]`).
- `$service` → a partir da LLD de serviços (`{#SERVICE}`), usada no painel "Core Services Status".

## Refresh e range
- Auto-refresh: 1–5 min (alinhado ao `delay` do item mestre `ad.monitor.data` = 5m).
- Time range padrão: Last 24 hours (compatível com todas as métricas `_24h`).

## Alertas (opcional, no próprio Grafana ou via triggers do Zabbix)
Os triggers já vêm prontos no template (`zbx_ad_template.xml`):
- Health Score crítico / alerta
- Falhas de replicação (>0 e >2)
- SYSVOL / NETLOGON indisponível
- Pico de falhas de logon e de account lockout
- Serviço crítico parado (por DC, via LLD)
- Domain Controller inacessível (via LLD)

Recomendação: usar os triggers do Zabbix como fonte da verdade para alertas (SLA, escalonamento, integração com NOC), e o Grafana apenas para visualização — evita duplicidade de regras.
