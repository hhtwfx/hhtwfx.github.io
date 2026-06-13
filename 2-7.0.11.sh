#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${HOME}/liveos_workspace"
KERNEL_VER="7.0.11"
KERNEL_DIR="${WORKSPACE}/linux-${KERNEL_VER}"
ARCH_STAGING="${WORKSPACE}/rootfs_staging"

echo "[步骤 2] 正在宿主机上开辟 8GB 临时构建 Swapfile 交换防御区..."
AVAILABLE_SWAP=$(free -m | awk '/Swap:/ {print $2}')
if [ "${AVAILABLE_SWAP}" -lt 8192 ]; then
    SWAPFILE="${WORKSPACE}/temp_swapfile"
    if [ ! -f "${SWAPFILE}" ]; then
        dd if=/dev/zero of="${SWAPFILE}" bs=1M count=8192 status=progress
        chmod 600 "${SWAPFILE}"
        mkswap "${SWAPFILE}"
    fi
    sudo swapon "${SWAPFILE}"
    # 退出钩子：确保脚本结束或异常时自动卸载并清理临时 Swapfile
    trap 'echo "[清理] 正在释放宿主机临时交换分区..."; sudo swapoff "${SWAPFILE}" || true; rm -f "${SWAPFILE}"' EXIT
fi

cd "${WORKSPACE}"
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "正在拉取 Linux 内核官方源码树 ${KERNEL_VER}..."
    wget -c "https://kernel.org{KERNEL_VER}.tar.xz"
    tar -xf "linux-${KERNEL_VER}.tar.xz"
fi

cd "${KERNEL_DIR}"
make defconfig

inject_config() {
    local key=$1; local value=$2
    sed -i "/${key}=/d" .config
    sed -i "/# ${key} is not set/d" .config
    echo "${key}=${value}" >> .config
}

echo "正在注入 Linux 7.0.11 专属 AI Agent 推理加速与高性能内存置换配置..."
inject_config "CONFIG_RSEQ" "y"                    # 激活 7.0 RSEQ 时间片扩展，防止 AI 线程中途被强占
inject_config "CONFIG_LRU_GEN" "y"                 # 启用 MGLRU（多代最近最少使用算法）
inject_config "CONFIG_LRU_GEN_ENABLED" "y"
inject_config "CONFIG_KSM" "y"                     # 启用内核同页合并，削减 Python 开销
inject_config "CONFIG_TRANSPARENT_HUGEPAGE" "y"    # 启用大匿名页支持，配合 7.0 连续置换红利
inject_config "CONFIG_INTEL_TSX" "y"               # 启用硬件级锁执行消减，降低多线程切换损耗
inject_config "CONFIG_PREEMPT_LAZY" "y"            # 锁定 7.0.11 新型延迟抢占机制，平衡 AI 与图形渲染
inject_config "CONFIG_IO_URING" "y"                # 激活非循环 io_uring，提高 L3 缓存命中率

echo "正在将 HP 2540p 核心外设驱动内建硬编码（杜绝早期引导阶段发生内核恐慌 Panic）..."
inject_config "CONFIG_XFS_FS" "y"                  # 根文件系统强制使用 XFS
inject_config "CONFIG_XFS_ONLINE_REPAIR" "y"       # 激活 7.0 新版 XFS 线上静默自愈
inject_config "CONFIG_XFS_ONLINE_SCRUB" "y"
inject_config "CONFIG_IOSCHED_BFQ" "y"             # 启用重构的 BFQ 机械硬盘智能队列
inject_config "CONFIG_BFQ_GROUP_IOSCHED" "y"
inject_config "CONFIG_ATA_PIIX" "y"                # 第一代酷睿主板 SATA 总线控制器驱动
inject_config "CONFIG_SATA_AHCI" "y"                # AHCI 驱动
inject_config "CONFIG_DRM_I915" "y"                 # 酷睿第一代核心显卡驱动 (Westmere)
inject_config "CONFIG_E1000E" "y"                   # 板载千兆网卡驱动
inject_config "CONFIG_IWLWIFI" "m"                  # Intel 6200 无线网卡核心驱动栈
inject_config "CONFIG_IWLDVM" "m"
inject_config "CONFIG_USB_STORAGE" "y"              # USB 引导存储器常驻支持
inject_config "CONFIG_USB_HID" "y"                  # USB 物理鼠标键盘基础内建

make olddefconfig

echo "正在启动锁定双线程的 Westmere 微架构针对性本地化编译..."
export CFLAGS="-O2 -march=westmere -mtune=westmere -pipe"
export CXXFLAGS="-O2 -march=westmere -mtune=westmere -pipe"

nice -n 19 make -j2 --load-average=2.0 bzImage
nice -n 19 make -j2 --load-average=2.0 modules

echo "正在将内核模块写入 Staging 暂存区并进行极限符号裁剪 (Strip)..."
make modules_install INSTALL_MOD_PATH="${ARCH_STAGING}"
find "${ARCH_STAGING}/lib/modules/" -name "*.ko" -exec strip --strip-unneeded {} +
cp arch/x86/boot/bzImage "${ARCH_STAGING}/boot/vmlinuz-${KERNEL_VER}-custom"
echo "✅ 阶段 2：内核特性化编译任务完美交付！"
