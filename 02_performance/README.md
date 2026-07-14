# ⚡ 02 — Performance: Análise e Configuração

Scripts para monitorar, diagnosticar e ajustar a performance do PostgreSQL.

---

## Scripts

| Script | O que faz | PG mínimo |
|--------|-----------|-----------|
| `01_checkpoint_timeout.sql` | Analisa saúde dos checkpoints e taxa de escrita de buffers (checkpoint, backend, bgwriter) | PG 8.3 |
| `02_fill_factor.sql` | Tabelas com baixa taxa de HOT updates — candidatas a ajuste de `fillfactor` | PG 8.4 |
| `03_tabelas_sem_uso.sql` | Tabelas com menos de 10 acessos totais (seq + idx scan) — candidatas a remoção | PG 8.1 |
| `04_analyze_stats.sql` | Estatísticas detalhadas por tabela: INSERTs/DELETEs/UPDATEs por dia, HOT updates, autovacuum | PG 10 |
| `05_table_bloat.sql` | Bloat de tabelas acima de 100MB com taxa de HOT update | PG 8.4 |
| `06_bloat_index.sql` | Bloat de índices acima de 50MB — versão simplificada | PG 9.5 |
| `07_monitore_cpu.sql` | Função PL/Python para monitorar uso de CPU por processo PostgreSQL + script shell de coleta | PG 13+ (plpython3u) |
| `08_identifica_vacuum_aggressive.sql` | Identifica tabelas próximas do limite de vacuum agressivo (transaction ID wraparound) | PG 9.4 |

---

## Quando usar

| Situação | Script recomendado |
|----------|--------------------|
| I/O alto no disco | `01` (checkpoints forçados) |
| UPDATEs lentos / table bloat crescendo | `02` (fill_factor inadequado) |
| Banco crescendo sem motivo | `05` (bloat de tabela) |
| Índices ocupando muito espaço | `06` (bloat de índice) |
| CPU alta no servidor de banco | `07` |
| Alerta de transaction ID wraparound | `08` |
| Limpeza de schema | `03` (tabelas sem uso) |
| Tuning de autovacuum por tabela | `04` |

---

## Observações

- `07_monitore_cpu.sql` requer a extensão `plpython3u` e o pacote Python `psutil` instalados no servidor
- `08_identifica_vacuum_aggressive.sql` tem um filtro de schema — ajuste conforme necessário
- Os scripts de bloat (`05`, `06`) têm filtros de tamanho mínimo comentados — ajuste conforme o ambiente
