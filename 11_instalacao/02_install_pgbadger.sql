# ==============================================================================
# PostgreSQL — Instalação/Atualização do pgBadger 12.4
# ==============================================================================
#
# Pré-requisitos:
#   - PostgreSQL instalado e rodando com logging configurado (ver 01_install_so_postgresql.sql)
#   - Acesso root ao servidor
#
# Substitua os placeholders:
#   VERSAO_PG       → versão do PostgreSQL (13, 15, 16)
#   DIAS_RETENCAO   → dias de retenção dos relatórios (padrão: 14)
#
# ==============================================================================


# ==============================================================================
# 1. VERIFICAR PRÉ-REQUISITOS DO POSTGRESQL.CONF
# ==============================================================================

# O pgBadger precisa que o PostgreSQL esteja com logging configurado.
# Verificar parâmetros essenciais (conectar via psql):
#
#   SHOW logging_collector;          -- deve ser 'on'
#   SHOW log_line_prefix;            -- deve conter %m %r %u %d %c %a %p
#   SHOW log_min_duration_statement; -- recomendado: 1000 (1 segundo)
#   SHOW log_checkpoints;            -- deve ser 'on'
#   SHOW log_connections;            -- deve ser 'on'
#   SHOW log_disconnections;         -- deve ser 'on'
#   SHOW lc_messages;                -- deve ser 'C' (inglês)
#
# Se algum parâmetro estiver diferente, ajustar no postgresql.conf:
#
#   logging_collector = on
#   log_directory = 'pg_log'
#   log_filename = 'postgresql-%a.log'
#   log_rotation_age = 1d
#   log_rotation_size = 0
#   log_truncate_on_rotation = on
#   log_min_duration_statement = 1000
#   log_checkpoints = on
#   log_connections = on
#   log_disconnections = on
#   log_lock_waits = on
#   log_temp_files = 0
#   log_autovacuum_min_duration = 0
#   log_line_prefix = '%m:%r:%u@%d:[%c]:[%a]:[%p] '
#   lc_messages = 'C'
#
# Após alterar, reiniciar: systemctl restart postgresql-VERSAO_PG


# ==============================================================================
# 2. INSTALAR HTTPD (servidor web para relatórios)
# ==============================================================================

yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Verificar se porta 80 está aberta no firewall
firewall-cmd --list-all | grep 80
# Se não estiver:
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload


# ==============================================================================
# 3. DESABILITAR CRON EXISTENTE (se atualizando)
# ==============================================================================

crontab -l | grep pgbadger
# Se existir, comentar temporariamente:
# crontab -e → comentar linha do pgbadger


# ==============================================================================
# 4. REMOVER VERSÃO ANTIGA (se atualizando)
# ==============================================================================

# Verificar versão atual
pgbadger --version 2>/dev/null

# Remover via yum (se instalado por pacote)
yum remove -y pgbadger 2>/dev/null

# Ou remover manualmente (se instalado por source)
rm -f /usr/local/bin/pgbadger 2>/dev/null


# ==============================================================================
# 5. BACKUP DOS RELATÓRIOS HTML EXISTENTES (se atualizando)
# ==============================================================================

mkdir -p ~/bkp_pgbadger_$(date +%Y%m%d)
cd /var/www/html

# Copiar arquivos existentes
cp -a LAST_PARSED ~/bkp_pgbadger_$(date +%Y%m%d)/ 2>/dev/null
cp -a index.html ~/bkp_pgbadger_$(date +%Y%m%d)/ 2>/dev/null
cp -a 20*/ ~/bkp_pgbadger_$(date +%Y%m%d)/ 2>/dev/null


# ==============================================================================
# 6. INSTALAR DEPENDÊNCIAS
# ==============================================================================

yum install -y wget perl-devel make gcc


# ==============================================================================
# 7. DOWNLOAD E INSTALAÇÃO DO PGBADGER 12.4
# ==============================================================================

cd /tmp

# Download da versão 12.4
wget https://github.com/darold/pgbadger/archive/refs/tags/v12.4.tar.gz

# Descompactar
tar -xzf v12.4.tar.gz
cd pgbadger-12.4

# Compilar e instalar
perl Makefile.PL
make && make install

# Verificar instalação
pgbadger --version
# Saída esperada: pgBadger version 12.4

# Verificar caminho do executável
which pgbadger
# Saída esperada: /usr/local/bin/pgbadger


# ==============================================================================
# 8. CRIAR SCRIPT DE REFRESH AUTOMÁTICO
# ==============================================================================

cat <<'EOF' > /root/pgbadger_refresh.sh
#!/bin/bash
# ==============================================================================
# pgBadger - Script de geração incremental de relatórios
# Executado via cron a cada hora
# ==============================================================================

PGLOG_DIR="/pgdata/16/data/pg_log"
OUTPUT_DIR="/var/www/html"
RETENTION=14
LOG_PREFIX='%m:%r:%u@%d:[%c]:[%a]:[%p] '

/usr/local/bin/pgbadger \
    --incremental \
    --retention ${RETENTION} \
    --outdir ${OUTPUT_DIR} \
    --prefix "${LOG_PREFIX}" \
    --format stderr \
    ${PGLOG_DIR}/postgresql-*.log

EOF

chmod +x /root/pgbadger_refresh.sh


# ==============================================================================
# 9. PRIMEIRA EXECUÇÃO MANUAL (validar que funciona)
# ==============================================================================

/root/pgbadger_refresh.sh

# Verificar se gerou os arquivos
ls -la /var/www/html/index.html
ls -la /var/www/html/LAST_PARSED

# Testar acesso via browser: http://IP_DO_SERVIDOR/


# ==============================================================================
# 10. CONFIGURAR CRON (execução a cada hora)
# ==============================================================================

# Adicionar ao crontab do root
(crontab -l 2>/dev/null; echo "0 * * * * /root/pgbadger_refresh.sh > /dev/null 2>&1") | crontab -

# Validar crontab
crontab -l


# ==============================================================================
# 11. LIMPEZA
# ==============================================================================

rm -f /tmp/v12.4.tar.gz
rm -rf /tmp/pgbadger-12.4


# ==============================================================================
# TROUBLESHOOTING
# ==============================================================================
#
# Problema: pgBadger não gera relatório
# Solução:  Verificar se os logs existem em PGLOG_DIR e se o formato está correto
#           ls -la /pgdata/16/data/pg_log/
#           head -5 /pgdata/16/data/pg_log/postgresql-Mon.log
#
# Problema: Relatório vazio (0 queries)
# Solução:  Verificar log_min_duration_statement no postgresql.conf
#           SHOW log_min_duration_statement; -- se -1, nenhuma query é logada
#
# Problema: Erro de permissão no /var/www/html
# Solução:  chown -R root:root /var/www/html && chmod 755 /var/www/html
#
# Problema: httpd não inicia
# Solução:  journalctl -u httpd --no-pager -n 20
#
# ==============================================================================
