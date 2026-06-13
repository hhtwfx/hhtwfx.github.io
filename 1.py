#!/usr/bin/env python3
import os
import sys
import gc
import psutil
from crewai import Agent, Task, Crew, Process, LLM

def memory_guard_callback(output):
    """
    极限内存回收钩子：在每个智能体任务迭代结束时强制释放碎片，
    严密监控 RAM 状态，防止系统发生严重的 HDD 交换分区抖动。
    """
    print("\n[Memory Guard] 触发内核级任务完成内存清理...")
    gc.collect() 
    
    process = psutil.Process(os.getpid())
    ram_usage_mb = process.memory_info().rss / (1024 * 1024)
    print(f"[Memory Guard] Python 进程静态内存占用: {ram_usage_mb:.2f} MB")
    
    virtual_mem = psutil.virtual_memory()
    available_ram_mb = virtual_mem.available / (1024 * 1024)
    print(f"[Memory Guard] 系统当前剩余可用物理内存: {available_ram_mb:.2f} MB")
    
    if available_ram_mb < 250:
        print("[CRITICAL WARNING] 物理内存跌破安全线！机械硬盘物理 Swapfile 即将发生剧烈抖动！")

# 高性能 native llama.cpp 服务端连接配置（OpenAI 兼容协议模式）
# 部署于目标 Live 系统后，启动命令为：
# ./llama-server -m qwen2.5-1.5b-instruct-q4_k_m.gguf -c 2048 -t 2 --host 127.0.0.1 --port 8080 --no-mmap
local_llama_cpp = LLM(
    model="openai/local-model",
    base_url="http://127.0.0",
    api_key="not-needed",
    config={
        "options": {
            "num_ctx": 2048, 
            "temperature": 0.1,
            "max_tokens": 1000
        }
    }
)

print("[System Initialization] 正在配置极其受限环境下的 2-Agent 智能体集群...")

# 智能体 1：负责监控与底层编译调度
engineering_agent = Agent(
    role="Linux Kernel 7.0.11 性能调优专家",
    goal="针对 i7-640LM CPU 和慢速 HDD 优化 Linux 7.0.11 的编译参数并动态控制系统负载",
    backstory="""你是一名专门在极端受限环境下工作的内核开发者。你的职责是确保编译 Linux 7.0.11 时，
    激活 MGLRU、RSEQ 时间片扩展和 XFS 线上自愈编译开关，并使用 'nice -n 19' 防止机械硬盘 I/O 锁死。""",
    verbose=True,
    allow_delegation=False,
    llm=local_llama_cpp,
    step_callback=memory_guard_callback
)

# 智能体 2：负责上层部署与结构审计
sysadmin_agent = Agent(
    role="LFS 最简 Live ISO 部署专家",
    goal="构建不占用多余内存的 Xorg+i3wm 根文件系统，支持中英双语且杜绝方块字乱码",
    backstory="""你是一名精通从零构建 Linux（LFS）的高级系统运维。你了解老旧机器的底层依赖，
    你必须设计一种按需读取的引导文件系统，并制定延迟启动策略以保护机械硬盘磁头。""",
    verbose=True,
    allow_delegation=False,
    llm=local_llama_cpp,
    step_callback=memory_guard_callback
)

task_kernel_optimize = Task(
    description="""审计并优化 Linux Kernel 7.0.11 的编译管道：
    1. 指定匹配 Intel Westmere (i7-640LM) 的微架构编译参数。
    2. 硬编码必要的内建存储与显卡核心驱动（i915, ahci）以防系统 panic。
    3. 输出通过 BASH 控制 'make -j2 --load-average=2.0' 的节流监控命令。""",
    expected_output="一份包含指定硬件 CFLAGS、内建驱动清单以及系统 nice 节流机制的 BASH 优化块。",
    agent=engineering_agent,
    callback=memory_guard_callback
)

task_iso_deploy = Task(
    description="""审计 Rootfs 结构与 Live ISO 封装逻辑：
    1. 规划最简 i3wm 启动流。
    2. 制定注入中文字体、生成 zh_CN.UTF-8 以及强制执行 fc-cache 刷新缓存的命令序列。
    3. 生成最终具备 isohybrid 传统 BIOS 引导兼容性的 ISO 打包终端指令。""",
    expected_output="一份包含中英环境修复、.xinitrc 延迟启动序列以及混合引导包装命令的自动化部署脚本指南。",
    agent=sysadmin_agent,
    callback=memory_guard_callback
)

# 装配 Crew，memory=False 强制切断本地向量数据库
kernel_crew = Crew(
    agents=[engineering_agent, sysadmin_agent],
    tasks=[task_kernel_optimize, task_iso_deploy],
    process=Process.sequential,
    memory=False, 
    verbose=True
)

if __name__ == "__main__":
    try:
        result = kernel_crew.kickoff()
        print("\n======================================================================")
        print("[PIPELINE COMPLETE] 双智能体工程综合审计报告:")
        print("======================================================================")
        print(result)
    except Exception as e:
        print(f"\n[CRITICAL ERROR] 运行时执行异常中断: {e}", file=sys.stderr)
