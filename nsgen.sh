#!/usr/bin/env bash

echo "=== systemd-nspawn 配置生成器（Debian Trixie） ==="

read -p "容器名称（如 trixie）： " NAME
read -p "加入的 bridge（默认 br0）： " BR
BR=${BR:-br0}

read -p "是否启用端口映射？(y/n): " PORTMAP
PORTS=""
if [[ "$PORTMAP" == "y" ]]; then
    while true; do
        read -p "输入端口映射（格式：host:container，空行结束）： " P
        [[ -z "$P" ]] && break
        PORTS+="Port=tcp:${P}\n"
    done
fi

read -p "是否绑定目录？(y/n): " BINDMAP
BINDS=""
if [[ "$BINDMAP" == "y" ]]; then
    while true; do
        read -p "输入绑定目录（格式：/host:/container，空行结束）： " B
        [[ -z "$B" ]] && break
        BINDS+="Bind=${B}\n"
    done
fi

CONF="/etc/systemd/nspawn/${NAME}.nspawn"

echo "生成配置文件：$CONF"

mkdir -p /etc/systemd/nspawn

cat > "$CONF" <<EOF
[Exec]
Boot=yes
PrivateUsers=no
ResolvConf=copy-host
Timezone=host
Capability=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Network]
VirtualEthernet=yes
Bridge=${BR}
${PORTS}

[Files]
${BINDS}
TemporaryFileSystem=/tmp:size=1G

[Machine]
SystemCallFilter=@system-service
ProtectKernelTunables=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectHostname=yes

[Resource]
MemoryMax=1G
CPUQuota=50%
TasksMax=500
EOF

echo "=== 完成！配置文件已生成：$CONF ==="
echo "你可以使用以下命令启动容器："
echo "  machinectl start ${NAME}"
echo "或启用开机自启："
echo "  systemctl enable systemd-nspawn@${NAME}"
