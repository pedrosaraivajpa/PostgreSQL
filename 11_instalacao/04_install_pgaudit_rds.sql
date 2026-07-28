-- ============================================================================
-- PostgreSQL RDS/Aurora — Instalação e Configuração do pgAudit
-- ============================================================================
--
-- O pgAudit gera logs detalhados de auditoria no RDS/Aurora PostgreSQL.
-- No RDS, a instalação é via Parameter Group (não há acesso ao SO).
--
-- Compatível com: RDS PostgreSQL 13, 14, 15, 16 / Aurora PostgreSQL
--
-- Referência AWS:
--   https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.pgaudit.html
--
-- Substitua os placeholders:
--   nome_database   → nome do banco onde habilitar auditoria
--
-- ============================================================================


-- ============================================================================
-- 1. CONFIGURAÇÃO DO PARAMETER GROUP (Console AWS ou CLI)
-- ============================================================================

-- 1.1 Acessar o Parameter Group da instância RDS/Aurora no console AWS

-- 1.2 Editar o parâmetro shared_preload_libraries:
--     Adicionar 'pgaudit' à lista (separado por vírgula se já houver outros)
--     Valor: pgaudit
--     (no RDS geralmente já tem 'rdsutils' — ficará: rdsutils,pgaudit)

-- 1.3 Editar o parâmetro pgaudit.role:
--     Valor: rds_pgaudit

-- 1.4 Reiniciar a instância RDS para aplicar (shared_preload_libraries exige reboot)
--     Console → Instância → Actions → Reboot
--     Ou via CLI:
--     aws rds reboot-db-instance --db-instance-identifier NOME_DA_INSTANCIA


-- ============================================================================
-- 2. CRIAÇÃO DA ROLE E EXTENSÃO
-- ============================================================================

-- 2.1 Conectar no banco como master user
-- psql -h endpoint-rds.xxxxx.sa-east-1.rds.amazonaws.com -U master_user -d nome_database

-- 2.2 Criar a role rds_pgaudit (obrigatório no RDS)
CREATE ROLE rds_pgaudit;

-- 2.3 Verificar shared_preload_libraries
SHOW shared_preload_libraries;
-- Saída esperada: rdsutils,pgaudit

-- 2.4 Criar a extensão no banco desejado
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- 2.5 Confirmar que pgaudit.role está correto
SHOW pgaudit.role;
-- Saída esperada: rds_pgaudit


-- ============================================================================
-- 3. CONFIGURAÇÃO DOS NÍVEIS DE AUDITORIA
-- ============================================================================

-- OPÇÃO A: Via Parameter Group (aplica para todas as bases da instância)
-- No console AWS, editar o parâmetro:
--   pgaudit.log = 'write, function, role, ddl'

-- OPÇÃO B: Via ALTER DATABASE (aplica apenas para um banco)
ALTER DATABASE nome_database SET pgaudit.log = 'write, function, role, ddl';

-- OPÇÃO C: Auditar tudo (gera mais volume de log)
-- ALTER DATABASE nome_database SET pgaudit.log = 'all';


-- ============================================================================
-- 4. CONFIGURAÇÕES ADICIONAIS (via Parameter Group)
-- ============================================================================

-- Logar nome da relação (tabela) afetada:
--   pgaudit.log_relation = on

-- Logar parâmetros dos comandos:
--   pgaudit.log_parameter = on

-- Evitar duplicação de statements no log:
--   pgaudit.log_statement_once = on

-- Ou via SQL (por database):
ALTER DATABASE nome_database SET pgaudit.log_relation = 'on';
ALTER DATABASE nome_database SET pgaudit.log_parameter = 'on';
ALTER DATABASE nome_database SET pgaudit.log_statement_once = 'on';


-- ============================================================================
-- 5. AUDITORIA POR ROLE (granular)
-- ============================================================================

-- Conceder permissões à role rds_pgaudit nas tabelas que deseja auditar
-- Tudo que tiver GRANT para rds_pgaudit será auditado

-- Exemplo: auditar todas as operações no schema public
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO rds_pgaudit;

-- Exemplo: auditar apenas uma tabela específica
-- GRANT ALL ON TABLE schema_name.tabela_importante TO rds_pgaudit;


-- ============================================================================
-- 6. CONFIGURAÇÃO DE LOG RECOMENDADA NO PARAMETER GROUP
-- ============================================================================

-- Para que os logs do pgAudit sejam úteis, ajustar também:
--
-- | Parâmetro                    | Valor recomendado     |
-- |------------------------------|-----------------------|
-- | log_min_duration_statement   | 1000 (1 segundo)      |
-- | log_statement                | none (pgaudit cuida)  |
-- | log_connections              | 1                     |
-- | log_disconnections           | 1                     |
-- | log_lock_waits               | 1                     |
-- | log_temp_files               | 0                     |


-- ============================================================================
-- 7. VALIDAÇÃO
-- ============================================================================

-- 7.1 Executar comandos de teste
CREATE TABLE IF NOT EXISTS teste_audit (id int);
INSERT INTO teste_audit VALUES (1);
DROP TABLE IF EXISTS teste_audit;

-- 7.2 Verificar nos logs do RDS (Console → Logs & Events → ou via CLI)
-- aws rds download-db-log-file-portion \
--   --db-instance-identifier NOME_DA_INSTANCIA \
--   --log-file-name error/postgresql.log.2026-07-23-12 \
--   --output text

-- 7.3 Formato esperado nos logs:
-- AUDIT: SESSION,1,1,DDL,CREATE TABLE,TABLE,public.teste_audit,...
-- AUDIT: SESSION,2,1,WRITE,INSERT,,,INSERT INTO teste_audit VALUES (1)


-- ============================================================================
-- 8. DIFERENÇAS: ON-PREMISES vs RDS
-- ============================================================================
--
-- | Aspecto                      | On-Premises           | RDS/Aurora            |
-- |------------------------------|-----------------------|-----------------------|
-- | Instalação do pacote         | yum install pgaudit   | Já disponível         |
-- | shared_preload_libraries     | postgresql.conf       | Parameter Group       |
-- | pgaudit.role                 | Opcional              | Obrigatório (rds_pgaudit) |
-- | ALTER SYSTEM                 | Funciona              | Não permitido (usar PG) |
-- | Acesso aos logs              | tail -f pg_log/       | Console/CLI/CloudWatch |
-- | Restart                      | systemctl restart     | Reboot via console    |
--
-- ============================================================================
