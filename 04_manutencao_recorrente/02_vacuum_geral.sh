#!/bin/bash -x

DATABASENAME=$1
DATABASEUSER=$2

if [ -z $DATABASENAME ] || [ -z $DATABASEUSER ]; then
  echo "USAGE: ./$(basename $0) db_name db_user"
  exit 1
fi

for tablename in $(psql -h localhost -U $DATABASEUSER -d $DATABASENAME -t -c "select table_schema||'.'||table_name as _table from information_schema.tables t where t.table_type = 'BASE TABLE' and not exists( select isparent from ( select ns.nspname||'.'||relname as isparent from pg_class c join pg_namespace ns on ns.oid=c.relnamespace where c.oid in ( select i.inhparent from pg_inherits i group by inhparent having count(*)>0) ) a where a.isparent=t.table_schema||'.'||t.table_name )  order by _table"); do
  echo $(date +"%Y-%m-%d-%H.%M.%S") $DATABASENAME "Iniciando vacuum analyze em " $tablename
  psql -h localhost -U $DATABASEUSER -d $DATABASENAME -c "vacuum verbose analyze ${tablename};"
done
