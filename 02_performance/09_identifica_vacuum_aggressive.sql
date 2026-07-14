--VISÃO DAS TABELAS E SUAS TOAST 
WITH per_table_stats AS (
    SELECT
        c.oid::regclass AS relation,
        age(c.relfrozenxid) AS oldest_current_xid_table,
        age(t.relfrozenxid) AS oldest_current_xid_toast,
        current_setting('vacuum_freeze_table_age')::float AS vacuum_freeze_table_age,
        pg_size_pretty(pg_total_relation_size(c.oid)) AS size
    FROM
        pg_class c
        JOIN pg_namespace n on c.relnamespace = n.oid
        LEFT JOIN pg_class t ON t.oid = c.reltoastrelid
    WHERE
        c.relkind IN ('r', 't', 'm')
        AND n.nspname NOT IN ('pg_toast')
        AND c.relpages + t.relpages > 65536
    ORDER BY
        oldest_current_xid_toast DESC
)
SELECT
    relation,
    oldest_current_xid_table,oldest_current_xid_toast,
    vacuum_freeze_table_age,
    round(100*(oldest_current_xid_table/vacuum_freeze_table_age::float)) AS percent_towards_emergency_autovacuum_table,
    round(100*(oldest_current_xid_toast/vacuum_freeze_table_age::float)) AS percent_towards_emergency_autovacuum_toast,
    size
FROM
    per_table_stats
where  round(100*(oldest_current_xid_table/vacuum_freeze_table_age::float)) >= 45
order by 6 desc, 1
LIMIT
    100
    ;
	
	
	
---considera apenas a tabela sem a toast
WITH per_table_stats AS (
  SELECT 
    c.oid :: regclass AS relation, 
    age(c.relfrozenxid) AS oldest_current_xid_table, 
    current_setting('vacuum_freeze_table_age'):: float AS vacuum_freeze_table_age, 
    pg_size_pretty(
      pg_total_relation_size(c.oid)
    ) AS size 
  FROM 
    pg_class c 
    JOIN pg_namespace n on c.relnamespace = n.oid 
    LEFT JOIN pg_class t ON t.oid = c.reltoastrelid 
  WHERE 
    c.relkind IN ('r', 't', 'm', 'i', 'I') 
    AND n.nspname NOT IN ('pg_toast') 
    AND c.relpages + t.relpages > 65536
) SELECT '' || per_table_stats.relation as _table , oldest_current_xid_table, vacuum_freeze_table_age
FROM 
  per_table_stats 
--where '' || per_table_stats.relation = 'schema_name.edigimagemdoc024' --and  
 --round(
    --100 *(
--      oldest_current_xid_table / vacuum_freeze_table_age::float
    --)
  --) >= 50
  order by oldest_current_xid_table desc;	
