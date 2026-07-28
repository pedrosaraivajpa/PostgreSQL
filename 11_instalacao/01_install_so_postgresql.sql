-- ============================================================================
-- PostgreSQL — Instalação Completa no CentOS/RHEL (7/8/9)
-- Compatível com PostgreSQL 16
-- ============================================================================
--
-- Substitua os placeholders antes de executar:
--   nome_servidor   → hostname do servidor
--   IP_REDE_LOCAL   → subnet permitida (ex: 10.0.0.0/8)
--   VERSAO_PG       → versão desejada (15, 16, etc.)
--
-- ============================================================================


-- ============================================================================
-- PRÉ-VALIDAÇÃO
-- ============================================================================

# 1. Validar conectividade de rede
ping -c 3 www.google.com

# 2. Validar configuração de rede (ONBOOT=yes)
cat /etc/sysconfig/network-scripts/ifcfg-enp0s3
# Se ONBOOT=no, alterar para ONBOOT=yes

# 3. Configurar hostname
vi /etc/hosts
# Adicionar: IP_DO_SERVIDOR  nome_servidor

# 4. Reiniciar serviço de rede
systemctl restart NetworkManager


-- ============================================================================
-- 1. CONFIGURAÇÃO DO FIREWALL (manter ativo, abrir apenas portas necessárias)
-- ============================================================================

# Verificar status
systemctl status firewalld
firewall-cmd --list-all

# Abrir porta do PostgreSQL
firewall-cmd --permanent --add-port=5432/tcp

# Abrir porta do Zabbix Agent (monitoramento)
firewall-cmd --permanent --add-port=10050/tcp
firewall-cmd --permanent --add-port=10050/udp

# Abrir porta do httpd (para pgBadger)
firewall-cmd --permanent --add-port=80/tcp

# Aplicar regras
firewall-cmd --reload

# Validar regras aplicadas
firewall-cmd --list-all


-- ============================================================================
-- 2. CONFIGURAÇÃO DO SELINUX
-- ============================================================================

# Verificar status atual
sestatus | grep -i mode

# Alterar para permissive
vi /etc/selinux/config
# Comentar:   #SELINUX=enforcing
# Adicionar:  SELINUX=permissive

# Aplicar sem reboot
setenforce permissive

# Confirmar
sestatus | grep -i mode


-- ============================================================================
-- 3. CONFIGURAÇÃO DA PARTIÇÃO /pgdata
-- ============================================================================

# 3.1 Criar partição no disco (ex: /dev/sdb)
fdisk /dev/sdb
# Sequência: n → p → 1 → ENTER → ENTER → w

# 3.2 Formatar como ext4
mkfs.ext4 /dev/sdb1

# 3.3 Criar ponto de montagem
mkdir /pgdata

# 3.4 Montar partição
mount /dev/sdb1 /pgdata

# 3.5 Obter UUID para fstab
blkid /dev/sdb1

# 3.6 Adicionar ao /etc/fstab (substituir UUID real)
vi /etc/fstab
# Adicionar linha:
# UUID=SEU_UUID_AQUI  /pgdata  ext4  defaults  0 0

# 3.7 Validar montagem
df -h /pgdata


-- ============================================================================
-- 4. INSTALAÇÃO DO POSTGRESQL 16
-- ============================================================================

# 4.1 Verificar se existe usuário postgres
id postgres

# 4.2 Instalar repositório oficial
yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# 4.3 Desabilitar módulo PostgreSQL do AppStream (RHEL/CentOS 8+)
dnf -qy module disable postgresql

# 4.4 Instalar PostgreSQL 16
yum install -y postgresql16-server
yum install -y postgresql16-contrib

# 4.5 Instalar locale pt_BR (se necessário)
dnf install -y glibc-langpack-pt glibc-all-langpacks

# 4.6 Reboot para aplicar SELinux e locale
reboot

# 4.7 Verificar status pós-reboot
systemctl status postgresql-16


-- ============================================================================
-- 5. CONFIGURAÇÃO DO CLUSTER EM /pgdata
-- ============================================================================

# 5.1 Parar serviço (se iniciado automaticamente)
systemctl stop postgresql-16

# 5.2 Criar estrutura de diretórios
mkdir -p /pgdata/16/data/

# 5.3 Alterar ownership
chown -R postgres:postgres /pgdata

# 5.4 Configurar systemd para usar /pgdata
vi /usr/lib/systemd/system/postgresql-16.service
# Alterar a linha Environment=PGDATA para:
# Environment=PGDATA=/pgdata/16/data/

# 5.5 Inicializar cluster com locale pt_BR
su - postgres
/usr/pgsql-16/bin/initdb -D /pgdata/16/data/ --locale=pt_BR.utf8
exit

# 5.6 Recarregar systemd e iniciar
systemctl daemon-reload
systemctl start postgresql-16
systemctl enable postgresql-16

# 5.7 Validar
systemctl status postgresql-16


-- ============================================================================
-- 6. CONFIGURAÇÃO DO pg_hba.conf (autenticação)
-- ============================================================================

# IMPORTANTE: Usar scram-sha-256 em vez de trust/md5 para segurança
vi /pgdata/16/data/pg_hba.conf

# Conteúdo recomendado:
# -----------------------------------------------------------------------
# TYPE  DATABASE  USER        ADDRESS           METHOD
# -----------------------------------------------------------------------
# Conexões locais via socket unix (DBA)
local   all       postgres                      peer
local   all       all                           scram-sha-256

# Conexões IPv4 - rede local (aplicação e DBA)
host    all       all         IP_REDE_LOCAL     scram-sha-256

# Conexões IPv4 - localhost
host    all       all         127.0.0.1/32      scram-sha-256

# Replicação - rede local
host    replication all       IP_REDE_LOCAL     scram-sha-256
# -----------------------------------------------------------------------


-- ============================================================================
-- 7. CONFIGURAÇÃO DO postgresql.conf (tuning + logging)
-- ============================================================================

vi /pgdata/16/data/postgresql.conf

# --- Conexões ---
listen_addresses = '*'
port = 5432
max_connections = 200

# --- Memória (ajustar conforme RAM do servidor) ---
# Para servidor com 16GB RAM:
shared_buffers = '4GB'
effective_cache_size = '12GB'
work_mem = '64MB'
maintenance_work_mem = '1GB'

# --- WAL ---
wal_level = replica
max_wal_senders = 5
wal_keep_size = '1GB'

# --- Checkpoints ---
checkpoint_completion_target = 0.9
max_wal_size = '2GB'
min_wal_size = '512MB'

# --- Logging (compatível com pgBadger) ---
logging_collector = on
log_directory = 'pg_log'
log_filename = 'postgresql-%a.log'
log_rotation_age = 1d
log_rotation_size = 0
log_truncate_on_rotation = on
log_min_duration_statement = 1000
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0
log_line_prefix = '%m:%r:%u@%d:[%c]:[%a]:[%p] '
lc_messages = 'C'

# --- Autovacuum ---
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = '1min'
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05


-- ============================================================================
-- 8. PRIMEIRO ACESSO E CONFIGURAÇÃO INICIAL
-- ============================================================================

# 8.1 Reiniciar PostgreSQL com novas configurações
systemctl restart postgresql-16

# 8.2 Alterar senha do usuário postgres
su - postgres
psql -c "\password postgres"

# 8.3 Criar roles iniciais
psql <<EOF
-- Role de administração (DBA)
CREATE ROLE role_admin WITH LOGIN CREATEROLE CREATEDB PASSWORD 'TROCAR_SENHA';

-- Role de aplicação (leitura + escrita)
CREATE ROLE role_app WITH LOGIN PASSWORD 'TROCAR_SENHA';

-- Role de leitura apenas
CREATE ROLE role_leitura WITH LOGIN PASSWORD 'TROCAR_SENHA';
EOF

# 8.4 Validar
psql -c "\du"
psql -c "\l"
psql -c "SHOW shared_buffers;"
psql -c "SHOW max_connections;"
psql -c "SHOW wal_level;"

exit


-- ============================================================================
-- 9. VALIDAÇÃO FINAL
-- ============================================================================

# Testar conexão remota (executar de outra máquina)
# psql -h IP_DO_SERVIDOR -U postgres -d postgres -p 5432

# Verificar que logging está funcionando
ls -la /pgdata/16/data/pg_log/

# Verificar partição montada corretamente
df -h /pgdata
mount | grep pgdata
