
Procedimento: Configuração de Replicação Lógica no PostgreSQL
==============================================================

Autor: Pedro Marques
Data: 07/10/2025

Objetivo:
----------
Configurar replicação lógica entre dois bancos PostgreSQL.
Banco origem: IP_ORIGEM
Banco destino: IP_DESTINO

--------------------------------------------------------------
1. Criar a tabela de exemplo no banco de origem
--------------------------------------------------------------
-- Banco: IP_ORIGEM
CREATE SCHEMA IF NOT EXISTS teste;

CREATE TABLE teste.tabela01 (
    id INT,
    nome TEXT,
    data_criacao TIMESTAMP
);

alter table teste.tabela01 add PRIMARY key(id);
--------------------------------------------------------------
2. Inserir registros de teste
--------------------------------------------------------------
INSERT INTO teste.tabela01 (id, nome, data_criacao)
SELECT g, 'Nome_' || g, now()
FROM generate_series(1, 50) g;

--------------------------------------------------------------
3. Criar a publicação no banco origem
--------------------------------------------------------------
CREATE PUBLICATION pub_teste01 FOR TABLE teste.tabela01;

ou 
--criar a publicação para todas as tabelas
CREATE PUBLICATION pub_teste01 FOR ALL TABLES;

-- Validar a publicação
\dRp+


--------------------------------------------------------------
4. Configurar a replicação no banco destino
--------------------------------------------------------------
-- Banco: IP_DESTINO
CREATE DATABASE teste02;

\c teste02

-- Criar a mesma estrutura de tabela
CREATE SCHEMA IF NOT EXISTS teste;

CREATE TABLE teste.tabela01 (
    id INT,
    nome TEXT,
    data_criacao TIMESTAMP
);

ALTER TABLE teste.tabela01 ADD PRIMARY KEY (id);
-- ou para tabelas que não tem pk
ALTER TABLE teste.tabela02 REPLICA IDENTITY FULL;
--------------------------------------------------------------
5. Criar a subscription no banco destino
--------------------------------------------------------------
CREATE SUBSCRIPTION sub_teste01
CONNECTION 'host=IP_ORIGEM port=5432 dbname=teste01 user=replicador password=sua_senha_fdw'
PUBLICATION pub_teste01;


--valida a SUBSCRIPTION
\dRs+

--------------------------------------------------------------
6. Possíveis erros e soluções
--------------------------------------------------------------
--Na origem
Erro:  permission denied for schema teste
Solução:  conceder permissão ao usuário replicador
GRANT USAGE ON SCHEMA teste TO replicador;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA teste TO replicador;

Erro:  cannot delete from table because it does not have a replica identity
Solução:
ALTER TABLE teste.tabela01 ADD PRIMARY KEY (id);
ou
ALTER TABLE teste.tabela01 REPLICA IDENTITY FULL;

--------------------------------------------------------------
7. Consultas de verificação
--------------------------------------------------------------
-- No destino
SELECT * FROM pg_subscription;
SELECT * FROM pg_subscription_rel;
SELECT * FROM teste.tabela01;


-- No origem
SELECT * FROM pg_publication;
SELECT * FROM pg_stat_replication;

--------------------------------------------------------------
8. Exclusão da subscription (se necessário)
--------------------------------------------------------------
DROP SUBSCRIPTION sub_teste01;

--------------------------------------------------------------
9. Exclusão da publicação (se necessário)
--------------------------------------------------------------
DROP PUBLICATION pub_teste01;

--------------------------------------------------------------
10. Logs úteis para diagnóstico
--------------------------------------------------------------
Verificar erros comuns no log do PostgreSQL:
- Falta de permissão no schema
- Falta de chave primária
- Erro de conexão entre origem e destino
- Tabela não encontrada

--------------------------------------------------------------
Fim do procedimento
==============================================================

--retirar um tabela da publicação
ALTER PUBLICATION pub_teste01 DROP TABLE teste.tabela02;
--adicionar um tabela da publição
ALTER PUBLICATION pub_teste01 ADD TABLE teste.tabela02;



--refresh na subscription
ALTER SUBSCRIPTION sub_teste01 REFRESH PUBLICATION;

--retoma ou pausa a subscription
ALTER SUBSCRIPTION sub_teste01 DISABLE;  -- pausa a replicação
ALTER SUBSCRIPTION sub_teste01 ENABLE;   -- retoma a replicação

--consulta no destino para acompanhamento da subscription
SELECT
S.subname
,srrelid::regclass
,CASE srsubstate
WHEN 'i' THEN 'i = initialize'
WHEN 'd' THEN 'd = data is being copied'
WHEN 's' THEN 's = synchronized'
WHEN 'r' THEN 'r = ready (normal replication)'
END as tab_status
,srsublsn
,CASE WHEN NOT pg_is_in_recovery() THEN pg_current_wal_lsn() ELSE pg_last_wal_receive_lsn() END as current_lsn
, COALESCE( pg_size_pretty( pg_wal_lsn_diff( (CASE WHEN NOT pg_is_in_recovery() THEN pg_current_wal_lsn() ELSE pg_last_wal_receive_lsn() END) , SR.srsublsn ) ), '0') as lag_diff
FROM pg_subscription_rel SR
INNER JOIN  pg_subscription S ON SR.srsubid=S.oid 
order by tab_status desc;
