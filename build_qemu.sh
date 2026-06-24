#!/bin/bash
set -e

# 1. 定义版本变量
KERNEL_VER="7.1.1"
DIR_NAME="linux-${KERNEL_VER}"
TAR_BALL="${DIR_NAME}.tar.xz"

# 2. 下载并解压内核源码
if [ ! -d "$DIR_NAME" ]; then
    if [ ! -f "$TAR_BALL" ]; then
        echo "[+] Downloading Linux Kernel ${KERNEL_VER}..."
        wget https://cdn.kernel.org/pub/linux/kernel/v7.x/${TAR_BALL}
    fi
    echo "[+] Extracting ${TAR_BALL}..."
    tar -xf ${TAR_BALL}
fi

cd "$DIR_NAME"

# 3. 创建最小功能补丁配置文件 (qemu_min.config)
# 这些是让 tinyconfig 能在 QEMU (x86_64) 中启动并打印日志的绝对死理。
cat << 'EOF' > qemu_min.config
# 基础架构与处理器
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_SMP=y

# 核心可执行文件支持 (不加这个连 init 都无法运行)
CONFIG_BINFMT_ELF=y
CONFIG_BINFMT_SCRIPT=y

# 串口与控制台驱动 (核心：确保 QEMU -nographic 有输出)
CONFIG_TTY=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y

# 内存文件系统 (让内核可以挂载 initramfs)
CONFIG_BLK_DEV_INITRD=y

# 基础显示/早期打印 (非必须但强烈建议，用于观测更早期的死机)
CONFIG_PRINTK=y
CONFIG_EARLY_PRINTK=y
EOF

# 4. 生成内核配置：以 tinyconfig 为起点，合并最小配置
echo "[+] Generating base tinyconfig..."
make tinyconfig

echo "[+] Merging QEMU required minimal configs..."
./scripts/kconfig/merge_config.sh .config qemu_min.config

# 5. 编译内核 (仅编译压缩后的内核镜像 bzImage)
echo "[+] Compiling Linux Kernel (bzImage)..."
make -j$(nproc) bzImage

# 6. 准备一个极其微小的 initramfs (使用内存中的 /init 作为启动终点)
cd ..
echo "[+] Creating a dummy initramfs..."
rm -rf initramfs && mkdir initramfs && cd initramfs
cat << 'EOF' > init
#!/bin/sh
echo "===================================================="
echo " Hello from Linux Kernel 7.1.1 (Tinyconfig Booted!) "
echo "===================================================="
# 保持运行不让内核 panic
while true; do sleep 100; done
EOF
chmod +x init
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initramfs.cpio.gz
cd ..

# 7. 使用 QEMU 启动
echo "[+] Launching QEMU..."
qemu-system-x86_64 \
    -kernel "${DIR_NAME}/arch/x86/boot/bzImage" \
    -initrd ../initramfs.cpio.gz \
    -nographic \
    -append "console=ttyS0 earlyprintk=serial,ttyS0"
