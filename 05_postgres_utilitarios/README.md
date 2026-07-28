# 🗄️ Utilitários PostgreSQL — Tuning, Particionamento, FDW e Replicação Lógica

Scripts para funcionalidades avançadas do PostgreSQL: tuning de banco e SO, particionamento de tabelas, Foreign Data Wrapper (FDW) e replicação lógica.

---

## Scripts

| # | Script | Tema | PG mínimo |
|---|--------|------|-----------|
| 1 | `01_tuning_postgresql.sql` | Tuning de parâmetros do PostgreSQL (memória, WAL, autovacuum, logging) | PG 13 |
| 2 | `02_tuning_linux_kernel.sh` | Tuning do Linux (THP, sysctl, limits, I/O scheduler) para servidores PostgreSQL | N/A (SO) |
| 3 | `01_criar_tabelas_particionadas.sql` | Converter tabelas normais em particionadas (HASH e RANGE) | PG 10 |
| 4 | `01_criar_fdw.sql` | Criar FDW entre dois bancos PostgreSQL | PG 9.3 |
| 5 | `01_replicacao_logica.sql` | Configurar replicação lógica (publication/subscription) | PG 10 |

---

## 1. Tuning do PostgreSQL

### `01_tuning_postgresql.sql` — Parâmetros do postgresql.conf

Ajustes via `ALTER SYSTEM` para melhorar performance e observabilidade. Executar como superuser.

### Categorias cobertas

| Seção | O que ajusta |
|-------|-------------|
| Monitoramento | `track_io_timing`, `track_functions`, `pg_stat_statements` |
| Memória | `shared_buffers`, `effective_cache_size`, `work_mem`, `maintenance_work_mem` |
| WAL e Checkpoints | `wal_level`, `max_wal_size`, `checkpoint_completion_target`, `wal_compression` |
| Conexões | `max_connections`, `idle_in_transaction_session_timeout` |
| Autovacuum | `autovacuum_max_workers`, `autovacuum_naptime`, scale factors agressivos |
| Logging | Configuração completa compatível com pgBadger |

### Referência de memória

| RAM do servidor | shared_buffers | effective_cache_size | work_mem |
|-----------------|---------------|---------------------|----------|
| 8GB | 2GB | 6GB | 32MB |
| 16GB | 4GB | 12GB | 64MB |
| 32GB | 8GB | 24GB | 128MB |
| 64GB | 16GB | 48GB | 256MB |

### Observações

- Parâmetros marcados com `(*)` exigem restart do PostgreSQL
- Os demais podem ser aplicados com `SELECT pg_reload_conf();`
- Use `SELECT name, setting, pending_restart FROM pg_settings WHERE pending_restart = true;` para verificar pendências

---

## 2. Tuning do Linux

### `02_tuning_linux_kernel.sh` — Otimização do SO para PostgreSQL

Script bash para executar como root. Ajusta o sistema operacional para workloads de banco de dados.

### O que configura

| Seção | Ajuste | Por que |
|-------|--------|---------|
| THP | Desabilita Transparent Huge Pages | Evita latência imprevisível por compactação de memória |
| sysctl | `vm.swappiness=1`, `vm.dirty_ratio=10`, `vm.overcommit_memory=2` | Reduz swap, suaviza flush de I/O, evita OOM killer |
| Rede | `somaxconn=4096`, `tcp_tw_reuse=1` | Suporta muitas conexões simultâneas |
| Shared Memory | `kernel.shmmax`, `kernel.shmall` | Compatível com shared_buffers grandes |
| Limites | `nofile=65536`, `nproc=65536` para postgres | Evita erros de "too many open files" |
| I/O Scheduler | `none` para SSD/NVMe | Elimina overhead desnecessário de scheduling |

### Observações

- Executar como **root**
- O THP é desabilitado via serviço systemd (persiste após reboot)
- Ajustar `kernel.shmmax` conforme o valor de `shared_buffers`
- Reiniciar PostgreSQL após aplicar para que shared memory seja realocada

---

## 3. Particionamento de Tabelas

### `01_criar_tabelas_particionadas.sql`

Procedimento completo de 11 passos para converter tabelas normais em tabelas particionadas.

### Tipos de particionamento cobertos

| Tipo | Quando usar | Exemplo |
|------|-------------|---------|
| **HASH** | Distribuição uniforme por chave (blobs, binários, IDs sem ordem) | 8 partições |
| **RANGE** | Dados com crescimento sequencial (IDs, datas) | 8 partições |
| **RANGE (auditoria)** | Tabelas de auditoria com ID sequencial e filhas relacionadas | tabela principal + chave + descrição |

### Fluxo resumido

```
1.  Dump da estrutura antiga
2.  Dump full de segurança
3.  Salvar DROP/CREATE das FKs
4.  Renomear tabelas antigas (_bkp)
5.  Criar tabelas particionadas (HASH ou RANGE)
6.  Popular as novas tabelas
7.  Validar contagem de registros
8.  Dropar FKs e tabelas antigas
9.  Recriar índices, PKs e FKs
10. VACUUM FULL
11. Recriar GRANTs
```

### Observações

- Requer PostgreSQL 10+ (particionamento declarativo)
- Planeje espaço em disco suficiente para duplicar os dados durante a migração
- Execute o PASSO 3 antes de qualquer DROP para não perder as FKs
- O VACUUM FULL no PASSO 10 pode demorar em tabelas grandes — considere executar fora do horário de pico
- Ajuste o número de partições e os intervalos de RANGE conforme o volume atual e crescimento esperado

---

## 4. Foreign Data Wrapper (FDW)

### `01_criar_fdw.sql` — FDW entre dois bancos PostgreSQL

Cria uma conexão entre dois bancos PostgreSQL:

```
banco_origem (IP_ORIGEM:5432) →→ banco_destino (IP_DESTINO:5432)
```

Passos cobertos:
1. Criar usuários `fdw_origem` e `fdw_destino`
2. Criar a extensão `postgres_fdw` em ambos os bancos
3. Criar o servidor remoto (`CREATE SERVER`)
4. Criar o mapeamento de usuário (`CREATE USER MAPPING`)
5. Criar a foreign table
6. Conceder permissões

### Observações FDW

- A extensão `postgres_fdw` já vem com o PostgreSQL — não precisa instalar separadamente
- O usuário FDW precisa ter permissão de `SELECT` na tabela remota
- Para verificar os servidores criados: `SELECT * FROM pg_foreign_server;`
- Para verificar os mapeamentos: `SELECT * FROM pg_user_mappings;`

---

## 5. Replicação Lógica

### `01_replicacao_logica.sql`

### Conceitos

| Conceito | Descrição |
|----------|-----------|
| **Publication** | Criada no banco **origem** — define quais tabelas serão replicadas |
| **Subscription** | Criada no banco **destino** — conecta na publication e recebe as mudanças |

### Fluxo coberto no script

```
1. Criar tabela no banco origem
2. Inserir dados de teste
3. Criar a PUBLICATION (FOR TABLE ou FOR ALL TABLES)
4. Criar a mesma estrutura no banco destino
5. Criar a SUBSCRIPTION no banco destino
6. Erros comuns e soluções
7. Queries de verificação (pg_subscription, pg_publication, pg_stat_replication)
8. Gerenciamento (DROP, REFRESH, ENABLE/DISABLE)
9. Query de monitoramento de lag da subscription
```

### Erros comuns cobertos

| Erro | Solução |
|------|---------|
| `permission denied for schema` | `GRANT USAGE ON SCHEMA ... TO replicador` |
| `cannot delete from table because it does not have a replica identity` | `ALTER TABLE ... ADD PRIMARY KEY` ou `REPLICA IDENTITY FULL` |
| `ERROR: local node not attached to primary node` | Aguardar a replicação sincronizar |

### Observações Replicação

- Requer `wal_level = logical` no banco origem
- Todas as tabelas replicadas precisam ter PRIMARY KEY (ou `REPLICA IDENTITY FULL`)
- A subscription faz a cópia inicial dos dados automaticamente (`copy_data = true` por padrão)
- Para replicar apenas mudanças futuras sem copiar dados existentes: `WITH (copy_data = false)`

---

## Placeholders para substituir

| Placeholder | Substitua por |
|-------------|--------------|
| `IP_ORIGEM` | IP do banco de origem |
| `IP_DESTINO` | IP do banco de destino |
| `IP_SERVIDOR` | IP do servidor remoto |
| `sua_senha_fdw` / `sua_senha` | Senha do usuário |
| `schema_name` | Nome do seu schema |
| `nome_database` | Nome do seu banco |
| `tabela_hash` | Tabela particionada por HASH |
| `tabela_range` | Tabela particionada por RANGE |
| `tabela_audit` | Tabela de auditoria |
| `tabela_exemplo` | Tabela a ser acessada remotamente |
| `role_escrita` | Role com permissão de escrita |
| `role_leitura` | Role com permissão de leitura |
| `replicador` | Usuário com permissão de replicação |
