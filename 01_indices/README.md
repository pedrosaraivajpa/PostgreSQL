# 📊 01 — Índices: Saúde e Performance

Scripts para identificar e corrigir problemas com índices no PostgreSQL.

---

## Scripts

| Script | O que faz | PG mínimo |
|--------|-----------|-----------|
| `01_index_bloat.sql` | Identifica índices fragmentados (bloat) acima de 50MB, mostrando tamanho real vs tamanho estimado | PG 9.5 |
| `02_tabelas_poucos_indices.sql` | Tabelas com muitos seq_scans e poucos índices — candidatas a novos índices | PG 8.4 |
| `03_indices_invalidos.sql` | Lista índices com status inválido e gera os comandos DROP/CREATE para recriá-los | PG 8.0 |
| `04_fk_sem_indices.sql` | Foreign keys em tabelas acima de 10MB sem índice correspondente — causa lentidão em JOINs e DELETEs | PG 9.4 |

---

## Quando usar

| Situação | Script recomendado |
|----------|--------------------|
| Queries lentas sem motivo aparente | `02` e `01` |
| Após `REINDEX` ou `CREATE INDEX CONCURRENTLY` com falha | `03` |
| JOINs ou DELETEs lentos em tabelas relacionadas | `04` |
| Banco crescendo muito em disco | `01` (bloat de índice) |

---

## Observações

- `01_index_bloat.sql` requer permissão de leitura nas tabelas analisadas
- `03_indices_invalidos.sql` tem um filtro por schema — substitua `schema_name` pelo seu schema ou remova o filtro para buscar em todos
- `04_fk_sem_indices.sql` usa `WITH ORDINALITY` e `cardinality()` — requer PG 9.4+
