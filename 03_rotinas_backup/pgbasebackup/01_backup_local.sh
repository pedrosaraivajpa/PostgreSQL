#!/bin/bash -x
###############################################################################
#                Rotina de Backup Físico — pg_basebackup                       #
#                                                                             #
# Tipo de Backup:    FULL (pg_basebackup com rotação local)                   #
# Agendamento:       cron — 2x/semana (ajustar conforme necessidade)          #
# Retenção:          2 cópias (bak1 = atual, bak2 = anterior)                 #
###############################################################################
#
# Substitua os placeholders:
#   IP_REPLICA        → IP do servidor de réplica (ou primary se não houver)
#   nome_database     → nome do banco de dados
#   usuario_backup    → usuário com permissão de replicação
#   sua_senha         → senha do usuário de backup
#   /pgbackup         → diretório de destino dos backups
#
# Cron sugerido (seg e sex às 18h):
#   00 18 * * Mon,Fri /diretorio_scripts/backup/backup_full.sh
#
###############################################################################

# --- Variáveis ---
PATH=$PATH:$HOME/bin
export PATH
source /var/lib/pgsql/.bash_profile

DATA=$(date '+%d_%m_%Y')
FILECONTROL=/tmp/exec_pgbasebackup.flag
export PGPASSWORD='sua_senha'

BACKUP_DIR="/pgbackup/backup"
LOG=$(date +"/diretorio_scripts/backup/logs/backup_%Y%m%d%H%M%S.log")

echo "========================================" >> ${LOG}
echo "Início do backup FULL: $(date)" >> ${LOG}
echo "========================================" >> ${LOG}

# --- Controle de execução concorrente ---
if [ -f "$FILECONTROL" ]; then
    echo "AVISO: Backup já em execução (flag encontrada). Abortando." >> ${LOG}
    exit 1
fi

touch $FILECONTROL

# --- Rotação de backups (bak1 → bak2) ---
echo "Listando backups em bak1:" >> ${LOG}
ls -lh ${BACKUP_DIR}/bak1 2>>${LOG}

echo "Listando backups em bak2:" >> ${LOG}
ls -lh ${BACKUP_DIR}/bak2 2>>${LOG}

echo "Removendo bak2 antigo..." >> ${LOG}
rm -rf ${BACKUP_DIR}/bak2/* 2>>${LOG}

echo "Movendo bak1 → bak2..." >> ${LOG}
mv -v ${BACKUP_DIR}/bak1/* ${BACKUP_DIR}/bak2/ 2>>${LOG}

# --- Execução do backup ---
echo "Iniciando pg_basebackup em $(hostname) - ${DATA}" >> ${LOG}

pg_basebackup \
    -h IP_REPLICA \
    -p 5432 \
    -U postgres \
    -D ${BACKUP_DIR}/bak1 \
    -Ft \
    -z \
    --checkpoint=fast \
    --progress \
    >> ${LOG} 2>&1

# --- Verificação de resultado ---
if grep -q -i "ERROR:" "${LOG}"; then
    echo "❌ ERRO encontrado no backup!" >> ${LOG}
else
    echo "✅ Backup concluído com sucesso!" >> ${LOG}
fi

# --- Relatório final ---
echo "Arquivos gerados:" >> ${LOG}
ls -lh ${BACKUP_DIR}/bak1 >> ${LOG} 2>&1

echo "Espaço em disco:" >> ${LOG}
df -h ${BACKUP_DIR} >> ${LOG}

echo "========================================" >> ${LOG}
echo "Fim do backup: $(date)" >> ${LOG}
echo "========================================" >> ${LOG}

# --- Limpeza ---
rm -f $FILECONTROL
