#!/bin/bash
#################################################################
# pg_repack - Desfragmentação de tabela sem lock exclusivo
#
# Uso: ./05_pg_repack.sh <schema.tabela> <database> [host] [port]
# Exemplo: ./05_pg_repack.sh public.orders meu_banco localhost 5432
#################################################################

set -euo pipefail

### Parametros de entrada ###
vTableName=${1:-}
vDataBase=${2:-}
vHost=${3:-localhost}
vPort=${4:-5432}

### Validação de parâmetros ###
if [ -z "$vTableName" ] || [ -z "$vDataBase" ]; then
  echo "USAGE: ./$(basename $0) <schema.tabela> <database> [host] [port]"
  echo ""
  echo "Exemplos:"
  echo "  ./$(basename $0) public.orders meu_banco"
  echo "  ./$(basename $0) public.orders meu_banco dbhost 5433"
  exit 1
fi

### Verifica se pg_repack está instalado ###
PG_REPACK=$(command -v pg_repack 2>/dev/null || find /usr/pgsql-*/bin/ -name pg_repack 2>/dev/null | head -1)

if [ -z "$PG_REPACK" ]; then
  echo "ERRO: pg_repack não encontrado no PATH nem em /usr/pgsql-*/bin/"
  echo "Instale com: yum install pg_repack_XX ou apt install postgresql-XX-repack"
  exit 2
fi

### Variáveis de controle ###
dirLog=${PG_REPACK_LOG_DIR:-/var/log/pg_repack}
date=$(date +"%Y-%m-%d")
dirLogDate=$dirLog/$date
logFile=$dirLogDate/repack_${vDataBase}_$(echo "$vTableName" | tr '.' '_')_$(date +"%H%M%S").log

### Cria diretório de logs ###
mkdir -p "$dirLogDate"

### Funções auxiliares ###
log() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$logFile"
}

### Verifica conectividade com o banco ###
if ! psql -h "$vHost" -p "$vPort" -d "$vDataBase" -c "SELECT 1" &>/dev/null; then
  log "ERRO: Não foi possível conectar em $vHost:$vPort/$vDataBase"
  exit 3
fi

### Verifica se a extensão pg_repack existe no banco ###
EXTENSION_EXISTS=$(psql -h "$vHost" -p "$vPort" -d "$vDataBase" -t -A -c "SELECT count(*) FROM pg_extension WHERE extname = 'pg_repack'")
if [ "$EXTENSION_EXISTS" -eq 0 ]; then
  log "ERRO: Extensão pg_repack não está instalada no banco '$vDataBase'"
  log "Execute: CREATE EXTENSION pg_repack;"
  exit 4
fi

### Verifica se a tabela existe ###
TABLE_EXISTS=$(psql -h "$vHost" -p "$vPort" -d "$vDataBase" -t -A -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname||'.'||c.relname = '$vTableName' AND c.relkind IN ('r','m')")
if [ "$TABLE_EXISTS" -eq 0 ]; then
  log "ERRO: Tabela '$vTableName' não encontrada no banco '$vDataBase'"
  exit 5
fi

### Captura tamanho antes ###
SIZE_BEFORE=$(psql -h "$vHost" -p "$vPort" -d "$vDataBase" -t -A -c "SELECT pg_size_pretty(pg_total_relation_size('$vTableName'::regclass))")

### Execução do pg_repack ###
log "=========================================="
log "Inicio do pg_repack"
log "Host......: $vHost:$vPort"
log "Database..: $vDataBase"
log "Tabela....: $vTableName"
log "Tamanho...: $SIZE_BEFORE"
log "=========================================="

SECONDS=0

if $PG_REPACK -h "$vHost" -p "$vPort" -d "$vDataBase" -t "$vTableName" -j 2 --no-superuser-check >> "$logFile" 2>&1; then
  ELAPSED=$SECONDS
  SIZE_AFTER=$(psql -h "$vHost" -p "$vPort" -d "$vDataBase" -t -A -c "SELECT pg_size_pretty(pg_total_relation_size('$vTableName'::regclass))")
  log "=========================================="
  log "SUCESSO"
  log "Antes.....: $SIZE_BEFORE"
  log "Depois....: $SIZE_AFTER"
  log "Duração...: $(($ELAPSED / 60))m $(($ELAPSED % 60))s"
  log "=========================================="
  exit 0
else
  ELAPSED=$SECONDS
  log "=========================================="
  log "FALHA no pg_repack (exit code: $?)"
  log "Duração...: $(($ELAPSED / 60))m $(($ELAPSED % 60))s"
  log "Verifique o log: $logFile"
  log "=========================================="
  exit 6
fi
