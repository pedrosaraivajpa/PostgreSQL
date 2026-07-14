with tabela_info_fillfactor as (
SELECT
    schemaname AS schema_name,
    relname    AS table_name,      
    to_char(
        n_tup_upd::NUMERIC * 60 * 60 * 24 
        / NULLIF(EXTRACT (EPOCH FROM current_timestamp - stats_reset)::BIGINT,0),
        '999G999G990'
    ) AS UPDS_POR_DAY,
    to_char((coalesce(n_tup_upd,0)::NUMERIC / NULLIF(tup_updated::NUMERIC,0)) * 100,'990D999')  AS db_upd_perc,
    to_char((coalesce(n_tup_ins,0)::NUMERIC / NULLIF(tup_inserted::NUMERIC,0)) * 100,'990D999') AS db_insr_perc,
    to_char((coalesce(n_tup_del,0)::NUMERIC / NULLIF(tup_deleted::NUMERIC,0)) * 100,'990D999')  AS db_del_perc,
    to_char(coalesce(n_tup_hot_upd,0), '999G999G999G999')                                       AS hot_upd,
    coalesce((coalesce(n_tup_hot_upd,0)::numeric * 100 / NULLIF(n_tup_upd,0)),0)            AS hot_upd_perc,
    coalesce (fillfactor::integer, 100) AS fillfactor
FROM 
    pg_stat_user_tables t
    JOIN pg_stat_database ON datname = current_database()
    LEFT JOIN ( SELECT oid, option_value AS fillfactor FROM pg_class, pg_options_to_table(reloptions) WHERE option_name = 'fillfactor') f ON f.oid = t.relid

--WHERE (n_tup_upd::NUMERIC / tup_updated::NUMERIC) > 0.0001 
--AND n_tup_upd > 1000 AND n_tup_hot_upd * 100  / n_tup_upd < 95
 ),
tabela_info_autovaccum AS (
    SELECT 
        n.nspname AS schema_name,
        c.relname AS table_name,
        c.reltuples::bigint AS total_rows_baseado_planner,
        -- Valores específicos ou NULL usando regexp_match que retorna apenas 1 linha
        (regexp_match(coalesce(array_to_string(c.reloptions,' '), ''), 'autovacuum_vacuum_scale_factor=([0-9\.]+)'))[1]::numeric AS vacuum_sf,
        (regexp_match(coalesce(array_to_string(c.reloptions,' '), ''), 'autovacuum_analyze_scale_factor=([0-9\.]+)'))[1]::numeric AS analyze_sf,
        (regexp_match(coalesce(array_to_string(c.reloptions,' '), ''), 'autovacuum_vacuum_threshold=([0-9]+)'))[1]::int AS vacuum_th,
        (regexp_match(coalesce(array_to_string(c.reloptions,' '), ''), 'autovacuum_analyze_threshold=([0-9]+)'))[1]::int AS analyze_th,
        last_autovacuum,
        last_analyze,
        last_autoanalyze
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    inner join pg_stat_user_tables tab on tab.relid = c."oid"
    WHERE c.relkind = 'r'  -- apenas tabelas 
)
SELECT
    schemaname AS "Schema",
    relname AS "Table",
    to_char(coalesce(seq_scan,0) / reset_days,'999G999G999G999') AS "Seq Scans/Day",
    to_char(coalesce(idx_scan,0) / reset_days,'999G999G999G999') AS "Idx Scans/Day",
    to_char(n_tup_ins / reset_days,'999G999G999G999') AS "INSERTs/Day",
    to_char(n_tup_del / reset_days,'999G999G999G999') AS "DELETEs/Day",
    to_char(n_tup_upd / reset_days,'999G999G999G999') AS "UPDATEs/Day",
    to_char((n_tup_ins + n_tup_upd + n_tup_del)             / reset_days,'999G999G999G999') AS "Changes/Day",
    to_char((coalesce(n_tup_ins,0) - coalesce(n_tup_del,0)) / reset_days,'999G999G999G999') AS "New rows/Day",
    to_char(coalesce(seq_scan,0) + coalesce(idx_scan,0)     / reset_days,'999G999G999G999') AS "Reads/Day",
    CASE 
        WHEN (coalesce(n_tup_ins,0) + coalesce(n_tup_upd,0) + coalesce(n_tup_del,0)) = 0 THEN NULL
	ELSE to_char((coalesce(seq_scan,0) + coalesce(idx_scan,0))::numeric / ((coalesce(n_tup_ins,0) + coalesce(n_tup_upd,0) + coalesce(n_tup_del,0))),'999G990D9') END AS "R / W",
    to_char((coalesce(seq_scan,0) + coalesce(idx_scan,0) + coalesce(n_tup_ins,0) + coalesce(n_tup_upd,0) + coalesce(n_tup_del,0)) / reset_days,'999G999G999G999') AS "IOPS / Day",
    info.total_rows_baseado_planner,
    COALESCE(info.vacuum_th, current_setting('autovacuum_vacuum_threshold')::int) +
    COALESCE(info.vacuum_sf, current_setting('autovacuum_vacuum_scale_factor')::numeric) * total_rows_baseado_planner AS Linhas_para_executar_AUTOVACUUM,
    COALESCE(info.analyze_th, current_setting('autovacuum_analyze_threshold')::int) +
    COALESCE(info.analyze_sf, current_setting('autovacuum_analyze_scale_factor')::numeric) * total_rows_baseado_planner AS Linhas_para_executar_ANALYZE,
    db_upd_perc,
    db_insr_perc,
    db_del_perc,
    hot_upd,
    hot_upd_perc,
    fillfactor,
    tab.last_autovacuum,
    tab.last_analyze,
    tab.last_autoanalyze
FROM
    pg_stat_user_tables tab
    left join tabela_info_autovaccum as info on info.table_name = tab.relname
    left join tabela_info_fillfactor as info_f on info_f.table_name = tab.relname,
    (SELECT EXTRACT(EPOCH FROM current_timestamp - stats_reset)::numeric/(60*60*24) AS reset_days
    	FROM pg_stat_database
    	WHERE datname = current_database()) AS r
ORDER BY  n_tup_ins + n_tup_upd + n_tup_del desc
--LIMIT 40
;



select 
      current_setting('autovacuum_vacuum_threshold') as autovacuum_vacuum_threshold,
      current_setting('autovacuum_vacuum_scale_factor') as autovacuum_vacuum_scale_factor,
      current_setting('autovacuum_analyze_threshold') as autovacuum_analyze_threshold,
      current_setting('autovacuum_analyze_scale_factor') as autovacuum_analyze_scale_factor;
SELECT 
--    schemaname,
    relname,
    reloptions
FROM pg_class c
--JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE 
relkind = 'r'  -- apenas tabelas
--  AND 
--reloptions IS NOT null and 
--relname like 'epadoutbox'
;
select count(1) from schema_name.epadoutbox;
