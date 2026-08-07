-- ============================================================================
-- PostgreSQL — Restore Manual via pg_basebackup (com tablespaces e PITR)
-- ============================================================================
--
-- Procedimento para restaurar um backup gerado por pg_basebackup.
-- Suporta: tablespaces customizados, PITR (Point-In-Time Recovery)
--
-- Substitua os placeholders:
--   VERSAO_PG         → versão do PostgreSQL (14, 15, 16)
--   /bkp/YYYY-MM-DD  → diretório do backup a restaurar
--   /pgdata           → raiz do diretório de dados
--   schema_name       → nome do schema (para tablespaces)
--
-- ============================================================================


-- ============================================================================
-- 1. INSTALAR POSTGRESQL NA MESMA VERSÃO DE ORIGEM
-- ============================================================================

-- Seguir procedimento: 11_instalacao/01_install_so_postgresql.sql
-- IMPORTANTE: a versão MAJOR deve ser idêntica à do backup


-- ============================================================================
-- 2. PREPARAR DIRETÓRIOS DE DATA E TABLESPACES
-- ============================================================================

-- # mkdir -p /pgdata/VERSAO_PG/data
-- # mkdir -p /pgdata/schema_name/ts/ts_main_default
-- # mkdir -p /pgdata/schema_name/ts/ts_main_tmp_default
-- # mkdir -p /pgdata/schema_name/ts/ts_extra_default
-- # mkdir -p /pgdata/schema_name/ts/ts_extra_tmp_default
--
-- Ajustar conforme as tablespaces do seu ambiente.
-- Para descobrir quais existem, consultar no backup:
-- cat /bkp/YYYY-MM-DD/tablespace_map


-- ============================================================================
-- 3. AJUSTAR PERMISSÕES
-- ============================================================================

-- # chown -R postgres:postgres /pgdata
-- # chmod 700 /pgdata/VERSAO_PG/data


-- ============================================================================
-- 4. CONFIGURAR SYSTEMD PARA USAR /pgdata
-- ============================================================================

-- # vi /usr/lib/systemd/system/postgresql-VERSAO_PG.service
-- Alterar: Environment=PGDATA=/pgdata/VERSAO_PG/data/


-- ============================================================================
-- 5. INICIALIZAR CLUSTER (apenas para validar que funciona)
-- ============================================================================

-- # su - postgres
-- # /usr/pgsql-VERSAO_PG/bin/initdb -D /pgdata/VERSAO_PG/data/
-- # exit

-- # systemctl daemon-reload
-- # systemctl start postgresql-VERSAO_PG
-- # systemctl status postgresql-VERSAO_PG
-- # systemctl stop postgresql-VERSAO_PG


-- ============================================================================
-- 6. DESCOMPACTAR BACKUP (base + pg_wal)
-- ============================================================================

-- # rm -rf /pgdata/VERSAO_PG/data/*

-- Descompactar base:
-- # tar xvf /bkp/YYYY-MM-DD/base.tar.gz -C /pgdata/VERSAO_PG/data

-- Descompactar WAL:
-- # tar xvf /bkp/YYYY-MM-DD/pg_wal.tar.gz -C /pgdata/VERSAO_PG/data/pg_wal


-- ============================================================================
-- 7. DESCOMPACTAR TABLESPACES (se houver)
-- ============================================================================

-- Consultar mapeamento de OIDs → tablespaces:
-- SELECT oid, spcname, pg_tablespace_location(oid) FROM pg_tablespace ORDER BY oid;
--
-- Ou verificar o arquivo:
-- # cat /pgdata/VERSAO_PG/data/tablespace_map
--
-- Exemplo:
-- # tar -C /pgdata/schema_name/ts/ts_main_default/ -xvf /bkp/YYYY-MM-DD/16392.tar.gz
-- # tar -C /pgdata/schema_name/ts/ts_extra_default/ -xvf /bkp/YYYY-MM-DD/94258.tar.gz

-- Criar links simbólicos (com usuário postgres):
-- # ln -f -s /pgdata/schema_name/ts/ts_main_default /pgdata/VERSAO_PG/data/pg_tblspc/16392
-- # ln -f -s /pgdata/schema_name/ts/ts_extra_default /pgdata/VERSAO_PG/data/pg_tblspc/94258


-- ============================================================================
-- 8. AJUSTAR postgresql.conf PARA RESTORE
-- ============================================================================

-- # vi /pgdata/VERSAO_PG/data/postgresql.conf

-- Parâmetros obrigatórios:
-- shared_buffers = '1GB'
-- archive_mode = 'off'
-- archive_command = ''
-- listen_addresses = '127.0.0.1'


-- ============================================================================
-- 9. CONFIGURAR PITR (opcional — restaurar até data/hora específica)
-- ============================================================================

-- Adicionar ao postgresql.conf:
-- restore_command = 'cp /bkp/pgarch/%f %p'
-- recovery_target_time = '2026-07-23 07:00:00 UTC'
--
-- Se não quiser PITR (restaurar tudo), pular este passo.


-- ============================================================================
-- 10. SINALIZAR MODO RECOVERY E INICIAR
-- ============================================================================

-- # touch /pgdata/VERSAO_PG/data/recovery.signal

-- Instalar extensões necessárias antes de subir:
-- # yum install -y pgaudit_VERSAO_PG pg_cron_VERSAO_PG

-- # systemctl start postgresql-VERSAO_PG


-- ============================================================================
-- 11. VERIFICAR RESTORE
-- ============================================================================

-- Verificar se está em recovery:
SELECT pg_is_in_recovery();
-- Se true e já restaurou os WALs desejados:

-- Promover para primary (encerrar recovery):
SELECT pg_wal_replay_resume();

-- Verificar dados:
SELECT pg_is_in_recovery();  -- deve ser false
SELECT count(*) FROM pg_stat_activity;


-- ============================================================================
-- 12. PÓS-RESTORE
-- ============================================================================

-- Reconfigurar listen_addresses se necessário
-- Reabilitar archive_mode se for manter backups
-- Executar ANALYZE para atualizar estatísticas:
-- ANALYZE VERBOSE;
