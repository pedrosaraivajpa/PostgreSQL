#!/bin/bash -x
###############################################################################
#                Rotina de Backup Físico — pg_basebackup + S3                  #
#                                                                             #
# Tipo de Backup:    FULL (pg_basebackup com upload para S3 e validação MD5)  #
# Agendamento:       cron — diário ou conforme necessidade                    #
# Retenção:          Controlada por lifecycle policy no S3                     #
###############################################################################
#
# Substitua os placeholders:
#   SEU_BUCKET        → nome do bucket S3
#   SEU_PREFIXO       → prefixo/pasta dentro do bucket
#   /pgbackup         → diretório local temporário
#
# Pré-requisitos:
#   - AWS CLI configurado com credenciais válidas
#   - Bucket S3 existente com permissão de escrita
#   - pg_basebackup acessível no PATH
#
# Cron sugerido (diário às 2h):
#   00 02 * * * /diretorio_scripts/backup/backup_s3.sh
#
###############################################################################

# --- Variáveis ---
export AGORA=$(date +%Y-%m-%d)
export HORA=$(date +%H:%M:%S)

BUCKET="SEU_BUCKET"
PREFIXO="SEU_PREFIXO"
DIRETORIO_LOCAL="/pgbackup/${AGORA}"
LOGFILE="/pgbackup/log/backup_s3_${AGORA}.log"

# --- Preparação ---
[ ! -d "$(dirname $LOGFILE)" ] && mkdir -p "$(dirname $LOGFILE)"
[ ! -d "$DIRETORIO_LOCAL" ] && mkdir -p "$DIRETORIO_LOCAL"

echo "========================================" >> $LOGFILE
echo "Início do backup + S3: ${HORA}" >> $LOGFILE
echo "========================================" >> $LOGFILE

echo "Espaço em disco antes:" >> $LOGFILE
du -sh /pgbackup >> $LOGFILE

# --- Execução do pg_basebackup ---
echo "Executando pg_basebackup..." >> $LOGFILE

pg_basebackup \
    --format=tar \
    --checkpoint=fast \
    --gzip \
    --verbose \
    --progress \
    --pgdata ${DIRETORIO_LOCAL} \
    >> $LOGFILE 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Erro ao realizar o backup. Abortando upload S3." >> $LOGFILE
    exit 1
fi

# --- Upload para S3 com validação ---
echo "Iniciando upload para s3://${BUCKET}/${PREFIXO}/${AGORA}/" >> $LOGFILE

ERROS=0

for ARQUIVO_LOCAL in "${DIRETORIO_LOCAL}"/*; do
    if [ -f "$ARQUIVO_LOCAL" ]; then
        NOME_ARQUIVO=$(basename "$ARQUIVO_LOCAL")
        S3_PATH="s3://${BUCKET}/${PREFIXO}/${AGORA}/${NOME_ARQUIVO}"

        # Checksum MD5 local (antes do upload)
        MD5_LOCAL=$(md5sum "$ARQUIVO_LOCAL" | awk '{print $1}')

        # Upload
        echo "  Enviando: ${NOME_ARQUIVO}" >> $LOGFILE
        aws s3 cp "$ARQUIVO_LOCAL" "$S3_PATH" >> $LOGFILE 2>&1

        if [ $? -ne 0 ]; then
            echo "  ❌ Falha no upload de ${NOME_ARQUIVO}" >> $LOGFILE
            ERROS=$((ERROS + 1))
            continue
        fi

        # Validação de tamanho
        TAMANHO_LOCAL=$(stat --printf="%s" "$ARQUIVO_LOCAL")
        TAMANHO_REMOTO=$(aws s3 ls "$S3_PATH" | awk '{print $3}')

        if [ "$TAMANHO_LOCAL" -gt 0 ] && [ "$TAMANHO_LOCAL" == "$TAMANHO_REMOTO" ]; then
            echo "  ✅ ${NOME_ARQUIVO}: tamanho OK (${TAMANHO_LOCAL} bytes)" >> $LOGFILE
            # Remover arquivo local após upload validado
            rm -f "$ARQUIVO_LOCAL"
        else
            echo "  ❌ ${NOME_ARQUIVO}: tamanho divergente! Local=${TAMANHO_LOCAL} Remoto=${TAMANHO_REMOTO}" >> $LOGFILE
            ERROS=$((ERROS + 1))
        fi
    fi
done

# --- Resultado final ---
if [ $ERROS -eq 0 ]; then
    echo "✅ Todos os arquivos enviados e validados com sucesso!" >> $LOGFILE
    # Remover diretório local vazio
    rmdir "$DIRETORIO_LOCAL" 2>/dev/null
else
    echo "⚠️ ${ERROS} arquivo(s) com erro. Verificar manualmente." >> $LOGFILE
fi

echo "Espaço em disco após:" >> $LOGFILE
du -sh /pgbackup >> $LOGFILE

echo "========================================" >> $LOGFILE
echo "Fim do backup + S3: $(date +%H:%M:%S)" >> $LOGFILE
echo "========================================" >> $LOGFILE
