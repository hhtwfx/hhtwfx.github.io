#!/usr/bin/env bash
set -e

echo "=============================================="
echo "   Debian Trixie systemd-nspawn 配置生成器"
echo "   RootFS 将放置在用户家目录 ~/machines"
echo "=============================================="

# ---- 输入容器名称 ----
read -p "容器名称（如 trixie）： " NAME
if [[ -z "$NAME" ]]; then
    echo "容器名称不能为空"
    exit 1
fi

# ---- RootFS 路径（自动使用用户家目录） ----
ROOTFS="$HOME/machines/${NAME}"
echo "RootFS 将创建在：$ROOTFS"

mkdir -p "$ROOTFS"

# ---- 是否创建 RootFS ----
read -p "是否使用 debootstrap 创建 RootFS？(y/n): " CREATE_ROOTFS
if [[ "$CREATE_ROOTFS" == "y" ]]; then
    echo "开始创建 RootFS..."
    sudo apt install -y debootstrap systemd-container
    sudo debootstrap trixie "$ROOTFS" http://deb.debian.org/debian
    echo "RootFS 创建完成：$ROOTFS"
fi

# ---- 网络配置 ----
read -p "加入的 bridge（默认 br0）： " BR
BR=${BR:-br0}

# ---- 端口映射 ----
PORTS=""
read -p "是否启用端口映射？(y/n): " PORTMAP
if [[ "$PORTMAP" == "y" ]]; then
    while true; do
        read -p "输入端口映射（格式：host:container，空行结束）： " P
        [[ -z "$P" ]] && break
        PORTS+="Port=tcp:${P}\n"
    done
fi

# ---- 目录挂载 ----
BINDS=""
read -p "是否绑定目录？(y/n): " BINDMAP
if [[ "$BINDMAP" == "y" ]]; then
    while true; do
        read -p "输入绑定目录（格式：/host:/container，空行结束）： " B
        [[ -z "$B" ]] && break
        BINDS+="Bind=${B}\n"
    done
fi

# ---- 生成配置文件 ----
CONF="/etc/systemd/nspawn/${NAME}.nspawn"
sudo mkdir -p /etc/systemd/nspawn

echo "生成配置文件：$CONF"

sudo bash -c "cat > '$CONF' <<EOF
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
EOF"

echo "=== 配置文件生成完成 ==="
echo "$CONF"

# ---- 是否启用 systemd 服务 ----
read -p "是否启用 systemd-nspawn@${NAME} 开机自启？(y/n): " ENABLE_SERVICE
if [[ "$ENABLE_SERVICE" == "y" ]]; then
    sudo systemctl enable systemd-nspawn@"${NAME}"
    echo "已启用 systemd-nspawn@${NAME}"
fi

echo "=============================================="
echo "  完成！你可以使用以下命令启动容器："
echo "    sudo systemd-nspawn -D $ROOTFS --boot"
echo "  或使用 machinectl："
echo "    machinectl start ${NAME}"
echo "  进入容器："
echo "    machinectl shell ${NAME}"
echo "=============================================="
