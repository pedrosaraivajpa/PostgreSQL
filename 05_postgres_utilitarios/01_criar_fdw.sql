--base origem
create database teste01         
with                                                       
owner = postgres                                           
encoding = 'UTF8'                                          
lc_collate = 'pt_BR.utf8'                                  
lc_ctype = 'pt_BR.utf8'                                    
connection limit = -1                                      
template = template0;

--base destino
create database teste02
with                                                       
owner = postgres                                           
encoding = 'UTF8'                                          
lc_collate = 'pt_BR.utf8'                                  
lc_ctype = 'pt_BR.utf8'                                    
connection limit = -1                                      
template = template0;

-- Criar usuário base origem
CREATE USER fdw_origem WITH PASSWORD 'sua_senha_fdw';

-- Conceder permissões de leitura na tabela base origem
GRANT CONNECT ON DATABASE teste01 TO fdw_origem;
GRANT USAGE ON SCHEMA public TO fdw_origem;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
GRANT SELECT ON tabela_exemplo TO fdw_origem;

--base destino
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE USER fdw_destino WITH PASSWORD 'sua_senha_fdw';


--base origem
create table teste.tabela01 (
id INT,
    nome TEXT,
    data_criacao TIMESTAMP);

--base destino
-- Criar servidor remoto com user postgres
DROP FOREIGN TABLE IF EXISTS tabela_exemplo_remota;
CREATE SERVER servidor_origem
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (
    host 'IP_ORIGEM',
    port '5432',
    dbname 'teste01'
);

--base destino
-- Criar mapeamento de usuário para o FDW
CREATE USER MAPPING FOR fdw_destino
SERVER servidor_origem
OPTIONS (
    user 'fdw_origem',
    password 'sua_senha_fdw'
);

--select para validar na destino quais wrapper foram criados
select 
    srvname as name, 
    srvowner::regrole as owner, 
    fdwname as wrapper, 
    srvoptions as options
from pg_foreign_server
join pg_foreign_data_wrapper w on w.oid = srvfdw;

GRANT SELECT ON tabela_exemplo_remota TO fdw_destino;
grant usage on schema teste to fdw_destino;                      


---Veja as permissões atuais da foreign table:
\z tabela_exemplo_remota

--Verifique o servidor e o mapeamento criados:
\des+
\deu+
