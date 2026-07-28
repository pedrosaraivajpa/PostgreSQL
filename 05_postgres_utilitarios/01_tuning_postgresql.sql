-- ============================================================================
-- PostgreSQL — Tuning de Parâmetros (On-Premises / EC2)
-- ============================================================================
--
-- Ajustes no postgresql.conf para melhorar performance e observabilidade.
-- Executar via psql conectado como superuser (postgres).
--
-- Referência de memória (ajustar conforme RAM do servidor):
--   8GB RAM  → shared_buffers=2GB,  effective_cache_size=6GB,  work_mem=32MB
--   16GB RAM → shared_buffers=4GB,  effective_cache_size=12GB, work_mem=64MB
--   32GB RAM → shared_buffers=8GB,  effective_cache_size=24GB, work_mem=128MB
--   64GB RAM → shared_buffers=16GB, effective_cache_size=48GB, work_mem=256MB
--
-- Após alterar: SELECT pg_reload_conf(); (ou systemctl reload postgresql-XX)
-- Parâmetros marcados com (*) exigem restart.
-- ============================================================================


-- ============================================================================
-- 1. MONITORAMENTO E ESTATÍSTICAS
-- ============================================================================

-- Habilitar medição de I/O em operações (custo mínimo, grande ganho em EXPLAIN ANALYZE)
ALTER SYSTEM SET track_io_timing = 'on';

-- Rastrear execução de funções (pl/pgsql, C, etc.)
ALTER SYSTEM SET track_functions = 'all';

-- Habilitar estatísticas de I/O em pg_stat_io (PG 16+)
-- ALTER SYSTEM SET track_io_timing = 'on';  -- já coberto acima

-- Aumentar tamanho do histórico de statements (padrão 1000)
ALTER SYSTEM SET pg_stat_statements.max = 5000;          -- (*) requer restart
ALTER SYSTEM SET pg_stat_statements.track = 'all';


-- ============================================================================
-- 2. MEMÓRIA
-- ============================================================================

-- Cache principal do PostgreSQL (25% da RAM)
ALTER SYSTEM SET shared_buffers = '4GB';                  -- (*) requer restart

-- Estimativa do cache total disponível (SO + PG) — 75% da RAM
ALTER SYSTEM SET effective_cache_size = '12GB';

-- Memória por operação de sort/hash (por sessão!)
ALTER SYSTEM SET work_mem = '64MB';

-- Memória para VACUUM, CREATE INDEX, ALTER TABLE
ALTER SYSTEM SET maintenance_work_mem = '1GB';

-- Memória do autovacuum (limitar para não competir com queries)
ALTER SYSTEM SET autovacuum_work_mem = '512MB';


-- ============================================================================
-- 3. WAL E CHECKPOINTS
-- ============================================================================

-- Nível do WAL (replica permite pg_basebackup e streaming replication)
ALTER SYSTEM SET wal_level = 'replica';                   -- (*) requer restart

-- Tamanho máximo de WAL antes de forçar checkpoint
ALTER SYSTEM SET max_wal_size = '2GB';
ALTER SYSTEM SET min_wal_size = '512MB';

-- Suavizar I/O durante checkpoints (0.9 = espalha a escrita ao longo de 90% do intervalo)
ALTER SYSTEM SET checkpoint_completion_target = 0.9;

-- Intervalo entre checkpoints automáticos
ALTER SYSTEM SET checkpoint_timeout = '10min';

-- Compressão de WAL (reduz I/O em disco)
ALTER SYSTEM SET wal_compression = 'on';


-- ============================================================================
-- 4. CONEXÕES
-- ============================================================================

-- Máximo de conexões simultâneas
ALTER SYSTEM SET max_connections = 200;                   -- (*) requer restart

-- Timeout de conexões idle em transação (evita locks pendurados)
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';

-- Timeout de statements longos (0 = sem limite — ajustar conforme aplicação)
-- ALTER SYSTEM SET statement_timeout = '30min';


-- ============================================================================
-- 5. AUTOVACUUM
-- ============================================================================

-- Workers paralelos de autovacuum
ALTER SYSTEM SET autovacuum_max_workers = 4;

-- Frequência de verificação
ALTER SYSTEM SET autovacuum_naptime = '30s';

-- Thresholds mais agressivos para tabelas com muitas atualizações
ALTER SYSTEM SET autovacuum_vacuum_threshold = 50;
ALTER SYSTEM SET autovacuum_analyze_threshold = 50;
ALTER SYSTEM SET autovacuum_vacuum_scale_factor = 0.05;
ALTER SYSTEM SET autovacuum_analyze_scale_factor = 0.02;

-- Cost limits do autovacuum (mais agressivo — padrão é 200)
ALTER SYSTEM SET autovacuum_vacuum_cost_limit = 1000;


-- ============================================================================
-- 6. LOGGING (compatível com pgBadger)
-- ============================================================================

ALTER SYSTEM SET logging_collector = 'on';               -- (*) requer restart
ALTER SYSTEM SET log_directory = 'pg_log';
ALTER SYSTEM SET log_filename = 'postgresql-%a.log';
ALTER SYSTEM SET log_rotation_age = '1d';
ALTER SYSTEM SET log_rotation_size = '0';
ALTER SYSTEM SET log_truncate_on_rotation = 'on';
ALTER SYSTEM SET log_min_duration_statement = 1000;      -- log queries > 1 segundo
ALTER SYSTEM SET log_checkpoints = 'on';
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_lock_waits = 'on';
ALTER SYSTEM SET log_temp_files = 0;                     -- log qualquer uso de temp
ALTER SYSTEM SET log_autovacuum_min_duration = 0;        -- log todo autovacuum
ALTER SYSTEM SET log_line_prefix = '%m:%r:%u@%d:[%c]:[%a]:[%p] ';
ALTER SYSTEM SET lc_messages = 'C';                      -- logs em inglês


-- ============================================================================
-- 7. APLICAR ALTERAÇÕES
-- ============================================================================

-- Recarregar parâmetros que não exigem restart
SELECT pg_reload_conf();

-- Para parâmetros marcados com (*), reiniciar:
-- systemctl restart postgresql-16

-- Verificar parâmetros pendentes de restart
SELECT name, setting, pending_restart
FROM pg_settings
WHERE pending_restart = true;
