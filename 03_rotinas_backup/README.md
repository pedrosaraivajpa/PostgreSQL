# 💾 03 — Rotinas de Backup PostgreSQL

Rotinas completas de backup e restore para PostgreSQL usando pg_basebackup e pgBackRest.

---

## Estrutura

```
03_rotinas_backup/
├── pgbasebackup/
│   ├── 01_backup_local.sh           — Backup full com rotação local (bak1/bak2)
│   ├── 02_backup_s3.sh              — Backup full + upload S3 com validação MD5
│   └── 03_restore_manual.sql        — Restore manual com tablespaces e PITR
├── pgbackrest/
│   ├── 01_install_pgbackrest.sql    — Instalação e configuração do zero
│   ├── 02_backup_pgbackrest.sh      — Rotina de backup parametrizável (full/diff/incr)
│   ├── 03_restore_pgbackrest.sql    — Restore full, PITR e delta
│   ├── 04_pgbackrest.conf           — Exemplos de configuração (primary/standby/NFS)
│   └── restore_automatico/          — Pipeline automatizado de restore
│       ├── restore_main.sh          — Orquestrador principal
│       ├── restore_command.sh       — Executa o pgbackrest restore
│       ├── stop_postgres.sh         — Para o serviço
│       ├── start_postgres.sh        — Inicia o serviço
│       ├── reinitialize_pgdata.sh   — Limpa /pgdata antes do restore
│       └── check_restore.sh         — Verifica resultado e registra status
├── 04_ddl_controle_backup.sql       — Tabela + function de log de backups
└── README.md
```

---

## Comparação: pg_basebackup vs pgBackRest

| Aspecto | pg_basebackup | pgBackRest |
|---------|---------------|------------|
| Paralelismo | ❌ 1 thread | ✅ Configurável (process-max) |
| Incremental | ❌ Sempre full | ✅ full, diff, incr |
| Compressão | gzip básico | gz, lz4, zstd |
| Retenção | Manual (rotação de pastas) | Automática (retention-full) |
| PITR | Manual (recovery.signal + WALs) | Nativo (--type=time --target=...) |
| Delta restore | ❌ | ✅ Restaura só o que mudou |
| Verificação | ❌ | ✅ Checksum automático |
| Upload S3 | Via script (aws s3 cp) | Nativo (repo1-type=s3) |
| Ideal para | Bases < 50GB, emergência, réplica | Produção, bases grandes, automação |

---

## pgbasebackup/

### `01_backup_local.sh` — Backup com rotação

- Rotação: bak1 (atual) → bak2 (anterior)
- Formato tar compactado
- Controle de execução concorrente (flag)
- Cron: 2x/semana

### `02_backup_s3.sh` — Backup com upload para S3

- pg_basebackup local + upload para bucket S3
- Validação de integridade (tamanho local vs remoto)
- Remove arquivo local após upload validado
- Retenção controlada por S3 Lifecycle Policy

### `03_restore_manual.sql` — Restore completo

- Restore com tablespaces (descompactar + symlinks)
- PITR opcional (recovery_target_time)
- Passo a passo de 12 etapas

---

## pgbackrest/

### `01_install_pgbackrest.sql` — Instalação do zero

- Instalação do pacote
- Configuração do pgbackrest.conf
- Configuração do archive_command no PostgreSQL
- Criação e verificação da stanza
- Cron sugerido (full/diff/incr)
- Seção para Patroni

### `02_backup_pgbackrest.sh` — Rotina de backup

- Parametrizável: `./02_backup_pgbackrest.sh full|diff|incr`
- Controle de concorrência
- Integração opcional com tabela de controle (flogbackup)
- Log detalhado + info da stanza após backup

### `03_restore_pgbackrest.sql` — Restore

- Restore full (último backup)
- Restore PITR (até data/hora específica)
- Delta restore (restaura apenas o que mudou)
- Restore de backup específico (por label)
- Pós-restore (stanza-create, ANALYZE)

### `04_pgbackrest.conf` — Configurações

- Exemplo: Primary (standalone)
- Exemplo: Standby (backup sem carga no primary)
- Exemplo: Repositório remoto (NFS)
- Tabela de parâmetros explicados

### `restore_automatico/` — Pipeline automatizado

Pipeline orquestrado para restore automático (ex: refresh de homologação):

```
restore_main.sh
  ├── stop_postgres.sh
  ├── reinitialize_pgdata.sh
  ├── restore_command.sh
  ├── [ajusta postgresql.conf]
  ├── start_postgres.sh
  └── check_restore.sh (registra resultado)
```

---

## `04_ddl_controle_backup.sql` — Objetos de controle

- `backuplist`: tabela que registra início/fim/status de cada backup
- `flogbackup()`: function chamada pelas rotinas para registrar eventos
- `restore`: tabela que registra resultados de restore automático
- Limpeza automática de registros > 90 dias

---

## Placeholders para substituir

| Placeholder | Substitua por |
|-------------|---------------|
| `VERSAO_PG` | Versão do PostgreSQL (13, 14, 15, 16) |
| `NOME_STANZA` | Nome da stanza pgBackRest |
| `IP_MASTER` / `IP_REPLICA` | IPs dos servidores |
| `IP_PRIMARY` / `IP_STANDBY` | IPs para config pgBackRest |
| `nome_database` | Banco de dados |
| `usuario_backup` / `usuario_monitoramento` | Usuários |
| `sua_senha` | Senha |
| `schema_name` | Schema dos objetos de controle |
| `SEU_BUCKET` / `SEU_PREFIXO` | Bucket e prefixo S3 |
| `/pgbackup` / `/backups` | Diretórios de backup |
| `/diretorio_scripts` | Diretório base dos scripts |
| `DATA_HORA_PITR` | Data/hora alvo do PITR |
