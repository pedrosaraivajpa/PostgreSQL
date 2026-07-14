#!/bin/bash

DATABASENAME=$1
DATABASEUSER=$2

if [ -z $DATABASENAME ] || [ -z $DATABASEUSER ]; then
  echo "USAGE: ./$(basename $0) db_name db_user"
  exit 1
fi

for tablename in $(psql -h localhost -U $DATABASEUSER -d $DATABASENAME -t -c "WITH per_table_stats AS (    SELECT        c.oid::regclass AS relation,        age(c.relfrozenxid) AS oldest_current_xid_table,
       current_setting('vacuum_freeze_table_age')::float AS vacuum_freeze_table_age,        pg_size_pretty(pg_total_relation_size(c.oid)) AS size    FROM        pg_class c        JOIN pg_namespace n on c.re
lnamespace = n.oid        LEFT JOIN pg_class t ON t.oid = c.reltoastrelid    WHERE        c.relkind IN ('r', 't', 'm')        AND n.nspname NOT IN ('pg_toast')        AND c.relpages + t.relpages > 65536) SE
LECT    per_table_stats.relation as _table FROM    per_table_stats where  round(100*(oldest_current_xid_table/vacuum_freeze_table_age::float)) >= 50"); do
  
  echo $(date +"%Y-%m-%d-%H.%M.%S") $DATABASENAME "Iniciando vacuum aggressive em " $tablename

  psql -h localhost -U $DATABASEUSER -d $DATABASENAME -c "vacuum (PROCESS_TOAST true, DISABLE_PAGE_SKIPPING  true ,VERBOSE) ${tablename};"
done
