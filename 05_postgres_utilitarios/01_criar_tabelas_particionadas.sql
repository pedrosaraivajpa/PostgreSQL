--------------------------------------------------------------------------------
-- PostgreSQL — Procedimento para converter tabelas em tabelas particionadas
-- Compatível com PostgreSQL 10+
--
-- Substitua os placeholders antes de executar:
--   schema_name      → nome do seu schema
--   nome_database    → nome do seu banco
--   sua_senha        → senha do usuário
--   tabela_hash      → tabela que será particionada por HASH
--   tabela_range     → tabela que será particionada por RANGE
--   tabela_audit     → tabela de auditoria (range por ID sequencial)
--   tabela_audit_chave / tabela_audit_descr → filhas da auditoria
--   role_escrita     → role com permissão de escrita
--   role_leitura     → role com permissão de leitura
--------------------------------------------------------------------------------



-- PASSO 1
-- DUMP DA ESTRUTURA ANTIGA — USE PARA ATUALIZAR OS CREATE TABLE
-- Remova o "ALTER TABLE ONLY" gerado pelo pg_dump, trocando por "ALTER TABLE"
pg_dump -h localhost -p 5432 -d nome_database -U schema_name -W \
  -x -n schema_name -s \
  -t tabela_hash \
  -t tabela_range \
  -t tabela_audit \
  -t tabela_audit_chave \
  -t tabela_audit_descr \
  -f particionar_tabelas_nome_database.sql



-- PASSO 2
-- DUMP FULL DA BASE POR SEGURANÇA
set PGPASSWORD=sua_senha
nohup pg_dump -h localhost -p 5432 -d nome_database -U schema_name \
  -x -n schema_name \
  -f YYYYMMDD_nome_database.bak -Fc > nohup_out_pg_dump.out &



-- PASSO 3
-- SALVAR O RETORNO DOS COMANDOS DROP E CREATE DAS FKs
-- Execute com o usuário schema_name e guarde o resultado
SELECT
  'ALTER TABLE schema_name.' || conrelid::pg_catalog.regclass
    || ' DROP CONSTRAINT ' || conname || ';' AS comando_drop,
  'ALTER TABLE schema_name.' || conrelid::pg_catalog.regclass
    || ' ADD CONSTRAINT ' || conname || ' '
    || pg_catalog.pg_get_constraintdef(r.oid, true) || ';' AS comando_create
FROM pg_catalog.pg_constraint r
WHERE r.contype = 'f'
  AND conparentid = 0
  AND confrelid::pg_catalog.regclass IN (
    'tabela_hash',
    'tabela_range',
    'tabela_audit',
    'tabela_audit_chave',
    'tabela_audit_descr'
  );



-- PASSO 4
-- RENOMEAR AS TABELAS ANTIGAS (mantém FKs e índices existentes)
ALTER TABLE schema_name.tabela_hash        RENAME TO tabela_hash_bkp;
ALTER TABLE schema_name.tabela_range       RENAME TO tabela_range_bkp;
ALTER TABLE schema_name.tabela_audit       RENAME TO tabela_audit_bkp;
ALTER TABLE schema_name.tabela_audit_chave RENAME TO tabela_audit_chave_bkp;
ALTER TABLE schema_name.tabela_audit_descr RENAME TO tabela_audit_descr_bkp;



-- PASSO 5
-- CREATE DAS TABELAS PARTICIONADAS
-- ATENÇÃO: Atualize as colunas conforme o DDL real da sua tabela (use o dump do PASSO 1)

-- Exemplo: tabela particionada por HASH (ideal para blobs, imagens, binários)
CREATE TABLE schema_name.tabela_hash (
    id_registro  numeric(16,0) NOT NULL,
    dado_binario bytea
) PARTITION BY HASH (id_registro);

-- Partições HASH — ajuste o modulus conforme o volume de dados
-- Regra geral: modulus = número de partições desejadas
CREATE TABLE schema_name.tabela_hash_000 PARTITION OF schema_name.tabela_hash FOR VALUES WITH (modulus 8, remainder 0);
CREATE TABLE schema_name.tabela_hash_001 PARTITION OF schema_name.tabela_hash FOR VALUES WITH (modulus 8, remainder 1);
CREATE TABLE schema_name.tabela_hash_002 PARTITION OF schema_name.tabela_hash FOR VALUES WITH (modulus 8, remainder 2);
CREATE TABLE schema_name.tabela_hash_003 PARTITION OF schema_name.tabela_hash FOR VALUES WITH (modulus 8, remainder 3);
CREATE TABLE schema_name.tabela_hash_004 PARTITION OF schema_name.tabela_hash FOR VALUES WITH (modulus 8, remainder 4);
CREATE TABLE schema_name.tabela_hash_005 PARTITION OF schema_name.tabela_hash FOR VALUES WITH (modulus 8, remainder 5);
CREATE TABLE schema_name.tabela_hash_006 PARTITION OF schema_name.tabela_hash FOR VALUES WITH (modulus 8, remainder 6);
CREATE TABLE schema_name.tabela_hash_007 PARTITION OF schema_name.tabela_hash FOR VALUES WITH (modulus 8, remainder 7);


-- Exemplo: tabela particionada por RANGE (ideal para IDs sequenciais ou datas)
CREATE TABLE schema_name.tabela_range (
    id_registro    numeric(16,0) NOT NULL,
    id_referencia  numeric(16,0) NOT NULL,
    ds_campo1      character varying(200),
    ds_campo2      character varying(500),
    dt_criacao     timestamp(0) without time zone,
    dt_alteracao   timestamp(0) without time zone,
    fl_status      character(1) DEFAULT 'A'::bpchar NOT NULL
) PARTITION BY RANGE (id_registro);

-- Partições RANGE — ajuste os intervalos conforme o volume atual e crescimento esperado
CREATE TABLE schema_name.tabela_range_001 PARTITION OF schema_name.tabela_range FOR VALUES FROM ('0')          TO ('30000000');
CREATE TABLE schema_name.tabela_range_002 PARTITION OF schema_name.tabela_range FOR VALUES FROM ('30000000')   TO ('60000000');
CREATE TABLE schema_name.tabela_range_003 PARTITION OF schema_name.tabela_range FOR VALUES FROM ('60000000')   TO ('90000000');
CREATE TABLE schema_name.tabela_range_004 PARTITION OF schema_name.tabela_range FOR VALUES FROM ('90000000')   TO ('120000000');
CREATE TABLE schema_name.tabela_range_005 PARTITION OF schema_name.tabela_range FOR VALUES FROM ('120000000')  TO ('150000000');
CREATE TABLE schema_name.tabela_range_006 PARTITION OF schema_name.tabela_range FOR VALUES FROM ('150000000')  TO ('180000000');
CREATE TABLE schema_name.tabela_range_007 PARTITION OF schema_name.tabela_range FOR VALUES FROM ('180000000')  TO ('210000000');
CREATE TABLE schema_name.tabela_range_008 PARTITION OF schema_name.tabela_range FOR VALUES FROM ('210000000')  TO ('240000000');


-- Exemplo: tabela de auditoria particionada por RANGE (ID sequencial)
CREATE TABLE schema_name.tabela_audit (
    id_auditoria numeric(10,0) NOT NULL,
    cd_usuario   character(15),
    cd_sistema   numeric(3,0)  NOT NULL,
    cd_tela      numeric(3,0),
    cd_nivel     numeric(2,0)  NOT NULL,
    dt_auditoria timestamp(0) without time zone,
    ds_ip        character varying(20)
) PARTITION BY RANGE (id_auditoria);

CREATE TABLE schema_name.tabela_audit_000 PARTITION OF schema_name.tabela_audit FOR VALUES FROM ('0')          TO ('15000000');
CREATE TABLE schema_name.tabela_audit_001 PARTITION OF schema_name.tabela_audit FOR VALUES FROM ('15000000')   TO ('30000000');
CREATE TABLE schema_name.tabela_audit_002 PARTITION OF schema_name.tabela_audit FOR VALUES FROM ('30000000')   TO ('45000000');
CREATE TABLE schema_name.tabela_audit_003 PARTITION OF schema_name.tabela_audit FOR VALUES FROM ('45000000')   TO ('60000000');
CREATE TABLE schema_name.tabela_audit_004 PARTITION OF schema_name.tabela_audit FOR VALUES FROM ('60000000')   TO ('75000000');
CREATE TABLE schema_name.tabela_audit_005 PARTITION OF schema_name.tabela_audit FOR VALUES FROM ('75000000')   TO ('90000000');


-- Tabela filha da auditoria — chaves
CREATE TABLE schema_name.tabela_audit_chave (
    id_auditoria numeric(10,0)       NOT NULL,
    cd_chave     numeric(10,0)       NOT NULL,
    ds_conteudo  character varying(250)
) PARTITION BY RANGE (id_auditoria);

CREATE TABLE schema_name.tabela_audit_chave_000 PARTITION OF schema_name.tabela_audit_chave FOR VALUES FROM ('0')        TO ('15000000');
CREATE TABLE schema_name.tabela_audit_chave_001 PARTITION OF schema_name.tabela_audit_chave FOR VALUES FROM ('15000000') TO ('30000000');
CREATE TABLE schema_name.tabela_audit_chave_002 PARTITION OF schema_name.tabela_audit_chave FOR VALUES FROM ('30000000') TO ('45000000');
CREATE TABLE schema_name.tabela_audit_chave_003 PARTITION OF schema_name.tabela_audit_chave FOR VALUES FROM ('45000000') TO ('60000000');
CREATE TABLE schema_name.tabela_audit_chave_004 PARTITION OF schema_name.tabela_audit_chave FOR VALUES FROM ('60000000') TO ('75000000');
CREATE TABLE schema_name.tabela_audit_chave_005 PARTITION OF schema_name.tabela_audit_chave FOR VALUES FROM ('75000000') TO ('90000000');


-- Tabela filha da auditoria — descrições
CREATE TABLE schema_name.tabela_audit_descr (
    id_auditoria numeric(10,0)       NOT NULL,
    nu_linha     numeric(10,0)       NOT NULL,
    ds_linha     character varying(250)
) PARTITION BY RANGE (id_auditoria);

CREATE TABLE schema_name.tabela_audit_descr_000 PARTITION OF schema_name.tabela_audit_descr FOR VALUES FROM ('0')        TO ('15000000');
CREATE TABLE schema_name.tabela_audit_descr_001 PARTITION OF schema_name.tabela_audit_descr FOR VALUES FROM ('15000000') TO ('30000000');
CREATE TABLE schema_name.tabela_audit_descr_002 PARTITION OF schema_name.tabela_audit_descr FOR VALUES FROM ('30000000') TO ('45000000');
CREATE TABLE schema_name.tabela_audit_descr_003 PARTITION OF schema_name.tabela_audit_descr FOR VALUES FROM ('45000000') TO ('60000000');
CREATE TABLE schema_name.tabela_audit_descr_004 PARTITION OF schema_name.tabela_audit_descr FOR VALUES FROM ('60000000') TO ('75000000');
CREATE TABLE schema_name.tabela_audit_descr_005 PARTITION OF schema_name.tabela_audit_descr FOR VALUES FROM ('75000000') TO ('90000000');



-- PASSO 6
-- POPULAR AS TABELAS PARTICIONADAS A PARTIR DAS TABELAS DE BACKUP
INSERT INTO schema_name.tabela_hash        SELECT * FROM schema_name.tabela_hash_bkp;
INSERT INTO schema_name.tabela_range       SELECT * FROM schema_name.tabela_range_bkp;
INSERT INTO schema_name.tabela_audit       SELECT * FROM schema_name.tabela_audit_bkp;
INSERT INTO schema_name.tabela_audit_chave SELECT * FROM schema_name.tabela_audit_chave_bkp;
INSERT INTO schema_name.tabela_audit_descr SELECT * FROM schema_name.tabela_audit_descr_bkp;



-- PASSO 7
-- VERIFICAR DIVERGÊNCIA NA QUANTIDADE DE REGISTROS
SELECT count(1), 'novo'   AS origem FROM schema_name.tabela_hash
UNION ALL
SELECT count(1), 'antigo' AS origem FROM schema_name.tabela_hash_bkp;

SELECT count(1), 'novo'   AS origem FROM schema_name.tabela_range
UNION ALL
SELECT count(1), 'antigo' AS origem FROM schema_name.tabela_range_bkp;

SELECT count(1), 'novo'   AS origem FROM schema_name.tabela_audit
UNION ALL
SELECT count(1), 'antigo' AS origem FROM schema_name.tabela_audit_bkp;

SELECT count(1), 'novo'   AS origem FROM schema_name.tabela_audit_chave
UNION ALL
SELECT count(1), 'antigo' AS origem FROM schema_name.tabela_audit_chave_bkp;

SELECT count(1), 'novo'   AS origem FROM schema_name.tabela_audit_descr
UNION ALL
SELECT count(1), 'antigo' AS origem FROM schema_name.tabela_audit_descr_bkp;



-- PASSO 8.1
-- EXECUTAR O ARQUIVO DE COMANDO_DROP GERADO NO PASSO 3

-- PASSO 8.2
-- DROPAR AS TABELAS ANTIGAS (remove índices e FKs associados)
DROP TABLE schema_name.tabela_hash_bkp;
DROP TABLE schema_name.tabela_range_bkp;
DROP TABLE schema_name.tabela_audit_bkp;
DROP TABLE schema_name.tabela_audit_chave_bkp;
DROP TABLE schema_name.tabela_audit_descr_bkp;



-- PASSO 9.1
-- RECRIAR PRIMARY KEYS NAS TABELAS PARTICIONADAS
ALTER TABLE schema_name.tabela_hash
    ADD CONSTRAINT pk_tabela_hash PRIMARY KEY (id_registro);

ALTER TABLE schema_name.tabela_range
    ADD CONSTRAINT pk_tabela_range PRIMARY KEY (id_registro, id_referencia);

ALTER TABLE schema_name.tabela_audit
    ADD CONSTRAINT pk_tabela_audit PRIMARY KEY (id_auditoria);

ALTER TABLE schema_name.tabela_audit_chave
    ADD CONSTRAINT pk_tabela_audit_chave PRIMARY KEY (id_auditoria, cd_chave);

ALTER TABLE schema_name.tabela_audit_descr
    ADD CONSTRAINT pk_tabela_audit_descr PRIMARY KEY (id_auditoria, nu_linha);


-- PASSO 9.2
-- RECRIAR ÍNDICES NAS TABELAS PARTICIONADAS
-- Adapte conforme os índices originais da sua tabela

CREATE INDEX idx_tabela_range_dt_criacao   ON schema_name.tabela_range   USING btree (dt_criacao);
CREATE INDEX idx_tabela_range_fl_status    ON schema_name.tabela_range   USING btree (fl_status, id_referencia);
CREATE INDEX idx_tabela_audit_dt           ON schema_name.tabela_audit   USING btree (dt_auditoria);
CREATE INDEX idx_tabela_audit_cd_sistema   ON schema_name.tabela_audit   USING btree (cd_sistema, cd_tela);
CREATE INDEX idx_tabela_audit_cd_usuario   ON schema_name.tabela_audit   USING btree (cd_usuario);
CREATE INDEX idx_tabela_audit_chave_ds     ON schema_name.tabela_audit_chave USING btree (ds_conteudo);


-- PASSO 9.3
-- RECRIAR FOREIGN KEYS (usar o arquivo COMANDO_CREATE gerado no PASSO 3)
-- Exemplo de FKs entre as tabelas:

ALTER TABLE schema_name.tabela_range
    ADD CONSTRAINT fk_range_hash FOREIGN KEY (id_registro)
    REFERENCES schema_name.tabela_hash (id_registro);

ALTER TABLE schema_name.tabela_audit_chave
    ADD CONSTRAINT fk_audit_chave_audit FOREIGN KEY (id_auditoria)
    REFERENCES schema_name.tabela_audit (id_auditoria);

ALTER TABLE schema_name.tabela_audit_descr
    ADD CONSTRAINT fk_audit_descr_audit FOREIGN KEY (id_auditoria)
    REFERENCES schema_name.tabela_audit (id_auditoria);



-- PASSO 10
-- VACUUM FULL NAS TABELAS PARTICIONADAS (recupera espaço em disco)
VACUUM FULL schema_name.tabela_hash;
VACUUM FULL schema_name.tabela_range;
VACUUM FULL schema_name.tabela_audit;
VACUUM FULL schema_name.tabela_audit_chave;
VACUUM FULL schema_name.tabela_audit_descr;



-- PASSO 11
-- RECRIAR GRANTS
GRANT INSERT, DELETE, UPDATE, SELECT ON schema_name.tabela_hash        TO role_escrita;
GRANT INSERT, DELETE, UPDATE, SELECT ON schema_name.tabela_range       TO role_escrita;
GRANT INSERT, DELETE, UPDATE, SELECT ON schema_name.tabela_audit       TO role_escrita;
GRANT INSERT, DELETE, UPDATE, SELECT ON schema_name.tabela_audit_chave TO role_escrita;
GRANT INSERT, DELETE, UPDATE, SELECT ON schema_name.tabela_audit_descr TO role_escrita;

GRANT SELECT ON schema_name.tabela_hash        TO role_leitura;
GRANT SELECT ON schema_name.tabela_range       TO role_leitura;
GRANT SELECT ON schema_name.tabela_audit       TO role_leitura;
GRANT SELECT ON schema_name.tabela_audit_chave TO role_leitura;
GRANT SELECT ON schema_name.tabela_audit_descr TO role_leitura;
