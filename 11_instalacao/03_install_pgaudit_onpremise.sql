-- ============================================================================
-- PostgreSQL — Instalação e Configuração do pgAudit (On-Premises / EC2)
-- ============================================================================
--
-- O pgAudit gera logs detalhados de auditoria (DDL, DML, funções, roles),
-- complementando os logs nativos do PostgreSQL e enriquecendo relatórios
-- do pgBadger.
--
-- Compatível com: PostgreSQL 13, 14, 15, 16
-- Distro: CentOS/RHEL/Rocky Linux
--
-- Substitua os placeholders:
--   VERSAO_PG       → versão do PostgreSQL (13, 14, 15, 16)
--   nome_database   → nome do banco onde habilitar auditoria
--
-- ============================================================================


-- ============================================================================
-- 1. INSTALAÇÃO DO PACOTE NO SISTEMA OPERACIONAL
-- ============================================================================

-- Executar como root:

-- 1.1 Instalar dependências
-- # dnf --enablerepo=crb install perl-IPC-Run
-- # yum install -y postgresql16-devel

-- 1.2 Instalar o pgAudit (ajustar versão conforme PG instalado)
-- PG 13: yum install -y pgaudit_13
-- PG 14: yum install -y pgaudit_14
-- PG 15: yum install -y pgaudit_15
-- PG 16: yum install -y pgaudit_16


-- ============================================================================
-- 2. CONFIGURAÇÃO DO POSTGRESQL.CONF
-- ============================================================================

-- 2.1 Adicionar pgaudit ao shared_preload_libraries
-- Editar postgresql.conf (ou via Patroni):
--
-- Single instance:
--   vi /pgdata/16/data/postgresql.conf
--   shared_preload_libraries = 'pgaudit'
--
-- Com Patroni:
--   patronictl -c /etc/patroni/postgres.yml edit-config
--   Adicionar pgaudit à lista de shared_preload_libraries

-- 2.2 Reiniciar para aplicar (shared_preload_libraries exige restart)
--
-- Single instance:
--   systemctl restart postgresql-16
--
-- Com Patroni:
--   systemctl restart patroni


-- ============================================================================
-- 3. CRIAÇÃO DA EXTENSÃO E CONFIGURAÇÃO
-- ============================================================================

-- 3.1 Conectar no banco desejado como superuser
-- psql -h localhost -U postgres -d nome_database

-- 3.2 Verificar que shared_preload_libraries carregou o pgaudit
SHOW shared_preload_libraries;
-- Saída esperada: pgaudit (ou pgaudit,pg_cron,... se houver outras)

-- 3.3 Criar a extensão
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- 3.4 Verificar instalação
SELECT extname, extversion FROM pg_extension WHERE extname = 'pgaudit';


-- ============================================================================
-- 4. CONFIGURAÇÃO DOS NÍVEIS DE AUDITORIA
-- ============================================================================

-- 4.1 Configuração global (todas as bases da instância)
-- Opções: read, write, function, role, ddl, misc, all
ALTER SYSTEM SET pgaudit.log = 'write, function, role, ddl';

-- 4.2 Logar nome da tabela/relação afetada
ALTER SYSTEM SET pgaudit.log_relation = 'on';

-- 4.3 Logar parâmetros dos comandos (valores de INSERT/UPDATE)
ALTER SYSTEM SET pgaudit.log_parameter = 'on';

-- 4.4 Não logar comandos que não afetaram linhas (reduz ruído)
ALTER SYSTEM SET pgaudit.log_statement_once = 'on';

-- 4.5 Aplicar sem restart
SELECT pg_reload_conf();

-- 4.6 Verificar configuração aplicada
SHOW pgaudit.log;
SHOW pgaudit.log_relation;
SHOW pgaudit.log_parameter;


-- ============================================================================
-- 5. CONFIGURAÇÃO POR DATABASE (opcional — mais granular)
-- ============================================================================

-- Auditar TUDO em um banco específico:
-- ALTER DATABASE nome_database SET pgaudit.log = 'all';

-- Auditar apenas DDL em outro banco:
-- ALTER DATABASE outro_banco SET pgaudit.log = 'ddl';


-- ============================================================================
-- 6. AUDITORIA POR ROLE (opcional — mais granular ainda)
-- ============================================================================

-- Criar uma role de auditoria
-- CREATE ROLE role_auditoria NOLOGIN;

-- Configurar pgaudit para auditar ações dessa role
-- ALTER SYSTEM SET pgaudit.role = 'role_auditoria';
-- SELECT pg_reload_conf();

-- Conceder permissões à role (tudo que essa role tiver GRANT será auditado)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO role_auditoria;


-- ============================================================================
-- 7. VALIDAÇÃO
-- ============================================================================

-- Executar um comando de teste
CREATE TABLE IF NOT EXISTS teste_audit (id int);
INSERT INTO teste_audit VALUES (1);
DROP TABLE IF EXISTS teste_audit;

-- Verificar nos logs que os comandos apareceram:
-- tail -50 /pgdata/16/data/pg_log/postgresql-$(date +%a).log | grep AUDIT

-- Formato esperado:
-- AUDIT: SESSION,1,1,DDL,CREATE TABLE,TABLE,public.teste_audit,"CREATE TABLE..."
-- AUDIT: SESSION,2,1,WRITE,INSERT,,,"INSERT INTO teste_audit VALUES (1)"


-- ============================================================================
-- 8. OPÇÕES DE pgaudit.log DISPONÍVEIS
-- ============================================================================
--
-- | Valor    | O que audita                                    |
-- |----------|-------------------------------------------------|
-- | read     | SELECT, COPY TO                                 |
-- | write    | INSERT, UPDATE, DELETE, TRUNCATE, COPY FROM      |
-- | function | Chamadas de funções e DO blocks                  |
-- | role     | GRANT, REVOKE, CREATE/ALTER/DROP ROLE             |
-- | ddl      | CREATE, ALTER, DROP (exceto role)                |
-- | misc     | DISCARD, FETCH, CHECKPOINT, VACUUM, SET          |
-- | all      | Tudo acima                                      |
-- | none     | Desabilitado                                    |
--
-- Recomendado para produção: 'write, function, role, ddl'
-- (evita logar SELECT que gera muito volume)
-- ============================================================================
