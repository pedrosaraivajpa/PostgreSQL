#!/bin/bash
# ==============================================================================
# Linux — Tuning de Kernel para PostgreSQL (On-Premises / EC2)
# ==============================================================================
#
# Ajustes no sistema operacional para servidores que rodam PostgreSQL.
# Executar como root.
#
# Referências:
#   - https://www.postgresql.org/docs/current/kernel-resources.html
#   - https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server
#
# ==============================================================================


# ==============================================================================
# 1. TRANSPARENT HUGE PAGES (THP) — DESABILITAR
# ==============================================================================
#
# THP causa latência imprevisível em bancos de dados porque o kernel tenta
# alocar blocos de 2MB em vez de 4KB. Isso gera pauses durante compactação.
# Recomendação: SEMPRE desabilitar para PostgreSQL (e qualquer SGBD).

# 1.1 Verificar status atual
echo "=== Status atual do THP ==="
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag

# 1.2 Desabilitar imediatamente (não sobrevive reboot)
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# 1.3 Criar serviço systemd para desabilitar permanentemente
cat <<'EOF' > /etc/systemd/system/disable-thp.service
[Unit]
Description=Disable Transparent Huge Pages (THP) for PostgreSQL
DefaultDependencies=no
After=sysinit.target local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled /sys/kernel/mm/transparent_hugepage/defrag > /dev/null'

[Install]
WantedBy=basic.target
EOF

systemctl daemon-reload
systemctl enable disable-thp.service
systemctl start disable-thp.service

# 1.4 Validar
echo "=== Validação THP (deve mostrar [never]) ==="
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag


# ==============================================================================
# 2. PARÂMETROS DO KERNEL (/etc/sysctl.conf)
# ==============================================================================
#
# Adicionar ao /etc/sysctl.conf e aplicar com: sysctl -p

cat <<'EOF' >> /etc/sysctl.conf

# ==============================================================================
# Tuning para PostgreSQL
# ==============================================================================

# --- Memória Virtual ---

# Porcentagem máxima de RAM com dirty pages antes de forçar flush
# Padrão: 20 → Recomendado: 10 (evita flush massivo e picos de I/O)
vm.dirty_ratio = 10

# Porcentagem de RAM com dirty pages antes de iniciar flush em background
# Padrão: 10 → Recomendado: 3 (inicia flush mais cedo, mais suave)
vm.dirty_background_ratio = 3

# Overcommit: modo 2 = não permitir overcommit além do ratio
# Evita OOM killer matando o PostgreSQL
vm.overcommit_memory = 2

# Porcentagem da RAM que pode ser "comprometida" (RAM + swap ratio)
# 95% = permite usar quase toda a RAM, mas não overcommit
vm.overcommit_ratio = 95

# Swappiness: 1 = usar swap SOMENTE em emergência
# Padrão: 60 → Recomendado: 1 para DB servers
vm.swappiness = 1

# --- Rede ---

# Aumentar buffer de rede (útil para muitas conexões simultâneas)
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096

# Reusar conexões TCP em TIME_WAIT (útil com connection pooling)
net.ipv4.tcp_tw_reuse = 1

# --- Semáforos e Shared Memory (para shared_buffers grandes) ---

# Formato: SEMMSL SEMMNS SEMOPM SEMMNI
kernel.sem = 250 32000 100 128

# Memória compartilhada máxima (em bytes) — ajustar >= shared_buffers
# Para shared_buffers=4GB: usar 4.5GB aqui
kernel.shmmax = 4831838208

# Total de páginas de shared memory
kernel.shmall = 1179648

EOF

# Aplicar imediatamente
sysctl -p

echo "=== Parâmetros de kernel aplicados ==="


# ==============================================================================
# 3. LIMITES DO USUÁRIO POSTGRES (/etc/security/limits.conf)
# ==============================================================================
#
# Aumentar limites de file descriptors e processos para o usuário postgres

cat <<'EOF' >> /etc/security/limits.conf

# PostgreSQL - limites do usuário postgres
postgres    soft    nofile    65536
postgres    hard    nofile    65536
postgres    soft    nproc     65536
postgres    hard    nproc     65536
postgres    soft    memlock   unlimited
postgres    hard    memlock   unlimited

EOF

echo "=== Limites do usuário postgres configurados ==="


# ==============================================================================
# 4. I/O SCHEDULER (para discos SSD/NVMe)
# ==============================================================================
#
# Para SSD/NVMe, usar 'none' (ou 'noop' em kernels antigos)
# Para HDD, manter 'mq-deadline'

echo "=== Scheduler atual ==="
cat /sys/block/sda/queue/scheduler 2>/dev/null
cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null

# Para SSD (ajustar nome do dispositivo):
# echo none > /sys/block/sda/queue/scheduler

# Para persistir via udev:
# cat <<'EOF' > /etc/udev/rules.d/60-scheduler.rules
# ACTION=="add|change", KERNEL=="sd*", ATTR{queue/scheduler}="none"
# ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"
# EOF


# ==============================================================================
# 5. VALIDAÇÃO FINAL
# ==============================================================================

echo ""
echo "=== Resumo da Configuração ==="
echo "THP enabled:       $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
echo "THP defrag:        $(cat /sys/kernel/mm/transparent_hugepage/defrag)"
echo "vm.swappiness:     $(sysctl -n vm.swappiness)"
echo "vm.dirty_ratio:    $(sysctl -n vm.dirty_ratio)"
echo "vm.overcommit:     $(sysctl -n vm.overcommit_memory)"
echo "nofile (postgres): $(su - postgres -c 'ulimit -n' 2>/dev/null || echo 'verificar após re-login')"
echo ""
echo "=== Concluído. Reiniciar PostgreSQL para aplicar shared memory ==="
