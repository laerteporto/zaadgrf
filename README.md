# ZAADGRF
> Monitoramento do Active Directory utilizando **Zabbix**, **Grafana** e **PowerShell**.

# Sobre

O **ZAADGRF** é um conjunto de artefatos desenvolvido para monitorar ambientes Microsoft Active Directory utilizando o Zabbix como plataforma de coleta e o Grafana para visualização dos indicadores.

O projeto fornece:

- Dashboard para Grafana
- Template XML para Zabbix
- Scripts PowerShell
- Arquivos de configuração do Zabbix Agent
- Guia de implantação

# Arquitetura<img width="1024" height="1536" alt="zaadgra" src="https://github.com/user-attachments/assets/2e56c46e-899b-48df-93b5-ef42a080d8b6" />

``text
                Active Directory
                        │
                        │
            PowerShell Scripts
                        │
                        │
               Zabbix Agent
                        │
                        │
               Zabbix Server
                        │
                        │
                  Grafana
                        │
                        ▼
                 Dashboard AD
```

# Funcionalidades

## Active Directory

- Usuários
- Computadores
- Controladores de Domínio
- FSMO
- DNS
- Replicação
- Serviços
- Eventos
- SYSVOL
- GPO
- Tempo de Resposta

## Dashboard Grafana

- Status geral do AD
- Indicadores em tempo real
- Histórico
- Disponibilidade
- Alertas
- Performance

## Zabbix

- Template pronto
- Descoberta automática
- Itens
- Triggers
- Gráficos

# Estrutura do Projeto

```text
.
├── ad_monitor_diag.ps1
├── ad_monitor.ps1
├── ad_monitor_write.ps1
├── grafana_ad_dashboard.json
├── grafana_dashboard_guia.md
├── Passo a passo pra aplicar.txt
├── Vou montar os 3 artefatos.txt
├── zabbix_agentd_ad_monitor.conf
└── zbx_ad_template.xml
```
---

# Arquivos

## ad_monitor.ps1

Script principal responsável pela coleta das informações do Active Directory.

---

## ad_monitor_diag.ps1

Ferramenta para diagnóstico e validação da coleta.

---

## ad_monitor_write.ps1

Responsável pela escrita das métricas utilizadas pelo Zabbix.

---

## zabbix_agentd_ad_monitor.conf

Arquivo de configuração do Zabbix Agent contendo os UserParameters necessários.

---

## zbx_ad_template.xml

Template completo para importação no Zabbix.

---

## grafana_ad_dashboard.json

Dashboard pronto para importação no Grafana.

---

## grafana_dashboard_guia.md

Guia de utilização do dashboard.

---

# Pré-requisitos

- Windows Server 2019 ou superior
- Active Directory
- PowerShell 5.1+
- Zabbix Server 7.x
- Zabbix Agent
- Grafana 12.x

---

# Instalação

## 1. Copiar os scripts

```
C:\Scripts\AD\
```

---

## 2. Configurar o Zabbix Agent

Copiar:

```
zabbix_agentd_ad_monitor.conf
```

para

```
conf.d
```
---

## 3. Reiniciar o serviço

```
Restart-Service "Zabbix Agent"
```

---

## 4. Importar Template

```
zbx_ad_template.xml
```
---

## 5. Importar Dashboard

```
grafana_ad_dashboard.json
```

---

# Fluxo de Funcionamento

```text
PowerShell
      │
      ▼
Zabbix Agent
      │
      ▼
Zabbix Server
      │
      ▼
Grafana
```
---

# Dashboard

O dashboard apresenta indicadores do Active Directory organizados em painéis contendo:

- Saúde geral
- Controladores de domínio
- Replicação
- DNS
- FSMO
- SYSVOL
- Usuários
- Computadores
- Serviços
- Performance

---

# Roadmap

- [x] Scripts PowerShell
- [x] Template Zabbix
- [x] Dashboard Grafana


Desenvolvido por **Laerte Porto**
