# 💾 03 — Rotinas de Backup PostgreSQL

Rotinas completas de backup e restore para PostgreSQL usando pg_basebackup.

---

## Estrutura

```
03_rotinas_backup/
├── pgbasebackup/
│   ├── 01_backup_local.sh           — Backup full com rotação local (bak1/bak2)
│   ├── 02_backup_s3.sh              — Backup full + upload S3 com validação MD5
│   └── 03_restore_manual.sql        — Restore manual com tablespaces e PITR
└── README.md
```

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

## Placeholders para substituir

| Placeholder | Substitua por |
|-------------|---------------|
| `VERSAO_PG` | Versão do PostgreSQL (13, 14, 15, 16) |
| `IP_REPLICA` | IP do servidor de réplica |
| `nome_database` | Banco de dados |
| `usuario_backup` | Usuário com permissão de replicação |
| `sua_senha` | Senha |
| `schema_name` | Schema dos objetos de controle |
| `SEU_BUCKET` / `SEU_PREFIXO` | Bucket e prefixo S3 |
| `/pgbackup` | Diretório de backup |
| `/diretorio_scripts` | Diretório base dos scripts |
| `DATA_HORA_PITR` | Data/hora alvo do PITR |
