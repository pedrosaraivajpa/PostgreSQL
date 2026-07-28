# ⚙️ 11 — Instalação e Configuração do PostgreSQL

Procedimentos completos para instalação do PostgreSQL, ferramentas de análise de logs e auditoria.

---

## Scripts

| # | Script | O que faz | Ambiente |
|---|--------|-----------|----------|
| 1 | `01_install_so_postgresql.sql` | Instalação completa do PostgreSQL 16: partição `/pgdata`, firewall, SELinux, cluster, tuning, logging e roles iniciais | CentOS/RHEL 7/8/9 |
| 2 | `02_install_pgbadger.sql` | Instalação do pgBadger 12.4 com httpd, script de refresh incremental e cron | CentOS/RHEL 7/8/9 |
| 3 | `03_install_pgaudit_onpremise.sql` | Instalação e configuração do pgAudit em servidor on-premises ou EC2 | CentOS/RHEL/Rocky |
| 4 | `04_install_pgaudit_rds.sql` | Instalação e configuração do pgAudit no RDS/Aurora PostgreSQL | AWS RDS/Aurora |

---

## Ordem de execução recomendada

```
1. 01_install_so_postgresql.sql   → instala e configura o PostgreSQL
2. 02_install_pgbadger.sql        → instala pgBadger (depende do logging configurado no passo 1)
3. 03 ou 04 (pgAudit)            → habilita auditoria (complementa os logs do passo 1)
```

---

## `01_install_so_postgresql.sql` — Instalação do PostgreSQL 16

Cobre do zero ao PostgreSQL rodando e otimizado:

```
1.  Pré-validação (rede, hostname)
2.  Firewall (manter ativo, abrir portas 5432/80/10050)
3.  SELinux (permissive)
4.  Partição /pgdata (fdisk, ext4, fstab)
5.  Instalação do PostgreSQL 16 via repo oficial
6.  Configuração do cluster em /pgdata/16/data/
7.  pg_hba.conf com scram-sha-256
8.  postgresql.conf com tuning + logging para pgBadger
9.  Roles iniciais (admin, app, leitura)
10. Validação final
```

### Tuning incluído

| Parâmetro | Valor (16GB RAM) | Finalidade |
|-----------|-------------------|------------|
| `shared_buffers` | 4GB | Cache de dados em memória |
| `effective_cache_size` | 12GB | Estimativa do cache do SO |
| `work_mem` | 64MB | Memória por operação de sort/hash |
| `maintenance_work_mem` | 1GB | VACUUM, CREATE INDEX |
| `max_wal_size` | 2GB | Limite antes de checkpoint |
| `checkpoint_completion_target` | 0.9 | Suavizar I/O de checkpoint |

---

## `02_install_pgbadger.sql` — Instalação do pgBadger 12.4

Instala o pgBadger com geração incremental de relatórios via browser.

```
1.  Verificar pré-requisitos do postgresql.conf
2.  Instalar httpd + abrir porta 80
3.  Desabilitar cron existente (se atualizando)
4.  Remover versão antiga
5.  Backup dos relatórios existentes
6.  Instalar dependências
7.  Download e compilação do pgBadger 12.4
8.  Criar script de refresh incremental
9.  Primeira execução manual (validação)
10. Configurar cron (a cada hora)
11. Limpeza + troubleshooting
```

### Logging necessário no postgresql.conf

| Parâmetro | Valor |
|-----------|-------|
| `log_line_prefix` | `'%m:%r:%u@%d:[%c]:[%a]:[%p] '` |
| `log_min_duration_statement` | `1000` (1 segundo) |
| `log_checkpoints` | `on` |
| `log_connections` / `log_disconnections` | `on` |
| `log_lock_waits` | `on` |
| `lc_messages` | `'C'` (logs em inglês) |

---

## `03_install_pgaudit_onpremise.sql` — pgAudit On-Premises

Instalação e configuração do pgAudit em servidores físicos, VMs ou EC2.

```
1. Instalar pacote via yum (pgaudit_16)
2. Adicionar ao shared_preload_libraries
3. Reiniciar PostgreSQL (ou Patroni)
4. Criar extensão no banco
5. Configurar níveis de auditoria
6. Auditoria por database ou por role (opcional)
7. Validação com comandos de teste
```

### Níveis de auditoria disponíveis

| Valor | O que audita |
|-------|--------------|
| `read` | SELECT, COPY TO |
| `write` | INSERT, UPDATE, DELETE, TRUNCATE, COPY FROM |
| `function` | Chamadas de funções e DO blocks |
| `role` | GRANT, REVOKE, CREATE/ALTER/DROP ROLE |
| `ddl` | CREATE, ALTER, DROP (exceto role) |
| `misc` | DISCARD, FETCH, CHECKPOINT, VACUUM, SET |
| `all` | Tudo acima |
| `none` | Desabilitado |

**Recomendado para produção:** `'write, function, role, ddl'`

---

## `04_install_pgaudit_rds.sql` — pgAudit no RDS/Aurora

Instalação via Parameter Group (sem acesso ao SO).

```
1. Editar Parameter Group (shared_preload_libraries + pgaudit.role)
2. Reboot da instância RDS
3. Criar role rds_pgaudit
4. Criar extensão
5. Configurar níveis de auditoria (Parameter Group ou ALTER DATABASE)
6. Auditoria granular por role
7. Validação
```

### Diferenças: On-Premises vs RDS

| Aspecto | On-Premises | RDS/Aurora |
|---------|-------------|------------|
| Instalação do pacote | `yum install pgaudit` | Já disponível |
| shared_preload_libraries | postgresql.conf | Parameter Group |
| pgaudit.role | Opcional | Obrigatório (`rds_pgaudit`) |
| ALTER SYSTEM | Funciona | Não permitido |
| Acesso aos logs | `tail -f pg_log/` | Console/CLI/CloudWatch |
| Restart | `systemctl restart` | Reboot via console |

---

## Placeholders para substituir

| Placeholder | Substitua por |
|-------------|---------------|
| `nome_servidor` | Hostname do servidor |
| `IP_REDE_LOCAL` | Subnet permitida (ex: `10.0.0.0/8`) |
| `VERSAO_PG` | Versão do PostgreSQL (15, 16) |
| `nome_database` | Nome do banco alvo |
| `TROCAR_SENHA` | Senhas dos roles criados |
| `SEU_UUID_AQUI` | UUID real da partição (`blkid`) |
| `NOME_DA_INSTANCIA` | Identifier da instância RDS |

---

## Observações gerais

- Testado em CentOS 7/8 e RHEL 7/8/9
- Para Ubuntu/Debian, substituir `yum` por `apt` e ajustar caminhos
- O tuning do postgresql.conf assume 16GB de RAM — ajuste proporcionalmente
- Em produção, **nunca** usar `trust` no pg_hba.conf
- O firewall é mantido **ativo** — apenas portas necessárias abertas
- pgBadger acessível via browser: `http://IP_DO_SERVIDOR/`
- pgAudit + pgBadger = auditoria completa nos relatórios
