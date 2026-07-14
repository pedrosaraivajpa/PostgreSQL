yum install postgresql13-plpython3-13.5

yum deplist postgresql13-plpython3-13.5

psql -d nome_database 

CREATE EXTENSION plpython3u ;


CREATE OR REPLACE FUNCTION u.get_usage_cpu_per_db(pid BIGINT)
RETURNS numeric AS $
    import psutil
    try:
        p = psutil.Process(pid)
        perc_cpu = p.cpu_percent(interval=1) / psutil.cpu_count()
        return float(perc_cpu)
    except psutil.NoSuchProcess:
        return 0.0
    except Exception as e:
        # Loga o erro ou retorna um valor indicativo
        return -1.0  # Retorna -1 em caso de erro
$
 LANGUAGE plpython3u;
 
 
 
CREATE OR REPLACE FUNCTION get_all_cpu_usage_pid( pid BIGINT)
RETURNS numeric AS $
    import psutil
    import time
    try:
        p = psutil.Process(pid)
        perc_cpu = p.cpu_percent(interval=None)/psutil.cpu_count()
        time.sleep(0.5)
        perc_cpu = p.cpu_percent(interval=None)/psutil.cpu_count()
        return float(perc_cpu)
    except psutil.NoSuchProcess:
        return 0.0
$
LANGUAGE plpython3u;
 
 
SELECT pid,
backend_type AS backend,
datname AS Database,  
SUM(get_usage_cpu_per_db(pid)) AS "CPU%",
query  
FROM pg_stat_activity 
WHERE datname IS NOT NULL
AND state = 'active' 
GROUP BY pid, backend_type, datname, query 
ORDER BY 2;
-------------------------------------------------------------------ARQUIVO SSH-------------------------------------------------------------------------------------


#!/bin/bash -x
#################################################################
#                Rotina de Monitoria de cpu                     #
#                                                               #
# Desenvolvida por:  Pedro Saraiva                              #
# Tipo de Backup:    MONITORIA DE CPU                           #
# Arquivo config:    /tmp/exec_monitoria_cpu.flag               #
#################################################################

##variaveis
PATH=$PATH:$HOME/bin
export PATH
source /var/lib/pgsql/.bash_profile
DATA=`date '+%d_%m_%Y'`
DATA_MINUTO=`date '+%d_%m_%Y_%H_%M'`
FILECONTROL=/tmp/exec_monitoria_cpu.flag
export PGPASSWORD=sua_senha

LOG=/pgdata/rotinas/logs/monitoria_cpu/monitoria_cpu_CLIENTE_MASTER_$DATA.log

echo "Iniciando a rotina de monitoria de cpu do banco master - CLIENTE :    `date`" >> ${LOG}

if ! [ -f $FILECONTROL ]; then

echo "Iniciando a monitoria do cluster do servidor $HOSTNAME - $DATA" >> ${LOG}

touch $FILECONTROL

echo "gerando os dados para do uso de cpu  `date`" >> ${LOG}

psql -d nome_database -h IP_MASTER -p 5000 -U usuario_monitoramento -t -c "select * from (
SELECT
    'INSERT INTO u.monitoria_cpu_master (cpu, data_hora, pid, datid, datname, usesysid, usename, application_name, client_addr, client_hostname, client_port, backend_start, xact_start, query_start, state_change, wait_event_type, wait_event, state, backend_xid, backend_xmin, query, backend_type) VALUES (' ||
    CAST(get_usage_cpu_per_db(pid) AS TEXT) || ', ''' ||
    now() || ''', '||
    CAST(pid  as text) || ', '||
    CAST(datid as text)|| ', ''' ||
    CAST(datname AS TEXT) || ''', ' ||
    CAST(usesysid AS TEXT) || ', ''' ||
    CAST(usename AS TEXT) || ''', ''' ||
    CAST(application_name AS TEXT)|| ''', ''' ||
    CAST(client_addr AS TEXT)|| ''', ''' ||
    COALESCE(client_hostname, 'NULL') || ''', ' ||
    CAST(client_port AS TEXT) || ', ''' ||
    CAST(backend_start AS TEXT) || ''', ''' ||
    COALESCE(xact_start::text, 'NULL') || ''', ''' ||
    COALESCE(query_start::text, 'NULL') || ''', ''' ||
    CAST(state_change AS TEXT)|| ''', ''' ||
    COALESCE(wait_event_type, 'NULL') || ''', ''' ||
    COALESCE(wait_event, 'NULL') || ''', ''' ||
    CAST(state AS TEXT) || ''', ' ||
    COALESCE(backend_xid::text, 'NULL') || ', ' ||
    COALESCE(backend_xmin::text, 'NULL') || ', ''' ||
    REPLACE(query, '''', '''''') || ''', ''' ||
    CAST(backend_type AS TEXT) || ''');' as VALOR
FROM pg_stat_activity
WHERE state = 'active'
) as A where VALOR is not null;" > /pgdata/rotinas/logs/monitoria_cpu/monitoria_cpu_CLIENTE_MASTER_$DATA_MINUTO.txt

echo "inserindo dados do arquivo no minuto `date`" >> ${LOG} 2>&1
psql -d nome_database -h IP_MASTER -p 5000 -U usuario_monitoramento < /pgdata/rotinas/logs/monitoria_cpu/monitoria_cpu_CLIENTE_MASTER_$DATA_MINUTO.txt


echo "deletando registros com data mais de 15 dias  `date`" >> ${LOG}
psql -d nome_database -h IP_MASTER -p 5000 -U usuario_monitoramento -c "delete from u.monitoria_cpu_master  where data_hora <= current_date - interval '15 days';" >> ${LOG} 2>&1

echo "apagando os registros de logs do inserts gerados antigos `date`" >> ${LOG} 2>&1
find /pgdata/rotinas/logs/monitoria_cpu/ -maxdepth 1 -name 'monitoria_cpu_CLIENTE_MASTER_*.txt' -mmin +5 -delete -print >> ${LOG} 2>&1

rm /tmp/exec_monitoria_cpu.flag

fi

echo "Fim da rotina da monitoria de cpu do banco master - CLIENTE :    `date`" >> ${LOG}
echo "#############################"`date` >> ${LOG}
