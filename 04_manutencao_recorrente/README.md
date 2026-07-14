# 🔧 04 — Manutenção Recorrente

Scripts e rotinas para manutenção recorrente do PostgreSQL.

---

## Scripts

| Script | O que faz | Tipo |
|--------|-----------|------|
| `01_apaga_wals_antigos.sh` | Remove arquivos WAL com mais de 3 dias do diretório de archive, com log de execução | Shell |
| `02_vacuum_geral.sh` | Executa `VACUUM VERBOSE ANALYZE` em todas as tabelas de um banco, ignorando tabelas particionadas pai | Shell |
| `03_vacuum_aggressive.sh` | Executa vacuum agressivo (`DISABLE_PAGE_SKIPPING`) nas tabelas próximas do limite de wraparound | Shell |
| `04_vacuum_analyze.sql` | Query para identificar tabelas que precisam de ANALYZE — mostra modificações pendentes vs escala configurada | SQL |
| `05_pg_repack.sh` | Executa `pg_repack` em uma tabela específica para desfragmentação sem lock | Shell |

---

## Como usar os shell scripts

```bash
# Vacuum geral em um banco
chmod +x 02_vacuum_geral.sh
./02_vacuum_geral.sh nome_database nome_usuario

# Vacuum agressivo (tabelas próximas do wraparound)
chmod +x 03_vacuum_aggressive.sh
./03_vacuum_aggressive.sh nome_database nome_usuario

# pg_repack em uma tabela
chmod +x 05_pg_repack.sh
./05_pg_repack.sh nome_tabela nome_database
```

---

## Agendamento via cron (exemplos)

```bash
# Apagar WALs antigos todo dia às 2h
0 2 * * * /caminho/01_apaga_wals_antigos.sh

# Vacuum geral toda segunda às 3h
0 3 * * 1 /caminho/02_vacuum_geral.sh nome_database postgres
```

---

## Quando usar

| Situação | Script recomendado |
|----------|--------------------|
| Disco de archive cheio | `01` |
| Tabelas com muito bloat | `02` ou `05` (pg_repack) |
| Alerta de transaction ID wraparound | `03` |
| Identificar tabelas sem ANALYZE recente | `04` |

---

## Observações

- `01_apaga_wals_antigos.sh` — ajuste o caminho `/pgarch` e o tempo `-mtime +3` conforme sua política de retenção
- `05_pg_repack.sh` requer a extensão `pg_repack` instalada — `yum install pg_repack_XX` ou `apt install postgresql-XX-repack`
- Os shell scripts usam sintaxe GNU (`find -printf`, `stat --printf`) — **Linux only**, não funcionam no macOS sem adaptação
