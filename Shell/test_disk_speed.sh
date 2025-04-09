#!/bin/bash

# Projectname: XTYG
# Filename: test_disk_speed.sh
# Created Date: 2025-03-25 11:03:00
# Author: FloatLife
# -----
# Last Modified time: 2025-04-09 15:33:06
# Last Modified By: The developer formerly known as FloatLife at <wget@aliyun.com>
# -----
# Copyright (c) 2025 FloatLife. All rights reserved.

# GNU General Public License v3.0 or later
# -----
# HISTORY:
# Date      	By	Comments
# ----------	---	----------------------------------------------------------
# 2025-04-09	FS	Version 1.0
# ----------	---	----------------------------------------------------------

# 安全模式
set -euo pipefail
IFS=$'\n\t'

# 全局异常捕捉
trap 'printf "[%s]-[FAIL]: 执行出错，脚本终止。\n" "$(date +"%F %T")"' ERR

# 常量定义
readonly DEFAULT_TEST_SIZE="2G"
readonly DEFAULT_BLOCK_SIZE="1M"
readonly DEFAULT_NUM_JOBS="1"
readonly DEFAULT_IO_DEPTH="1"
readonly DEFAULT_RUNTIME="30"

# 参数检查
if [[ $# -lt 1 ]]; then
    printf "[%s]-[ERROR]: 缺少测试文件路径参数。\n" "$(date +"%F %T")"
    exit 1
fi

TEST_FILE="$1"

# 判断是否是块设备
if [[ -b "$TEST_FILE" ]]; then
    printf "[%s]-[WARN]: 输入的是块设备：%s\n" "$(date +"%F %T")" "$TEST_FILE"
    printf "继续操作将清除该设备上所有数据，请谨慎！\n"
    read -n 1 -s -r -p "请确认是否继续（按任意键继续）..."
    clear
fi

# FIO 测试函数
run_fio_test() {
    local test_name="$1"
    local rw_mode="$2"
    local bs="$3"
    local size="$4"
    local numjobs="$5"
    local iodepth="$6"
    local runtime="${7:-$DEFAULT_RUNTIME}"

    echo "🧪 测试名称: $test_name"
    echo "📄 测试路径: $TEST_FILE"
    echo "📦 数据大小: $size"
    echo "🧱 块大小:   $bs"
    echo "🧵 线程数:   $numjobs"
    echo "📚 IO深度:   $iodepth"
    echo "⏱️ 超时时间: ${runtime}s"

    printf -v separator '%*s' "$(tput cols)" ""
    echo "${separator// /-}"
    fio --name="$test_name" \
        --rw="$rw_mode" \
        --bs="$bs" \
        --size="$size" \
        --numjobs="$numjobs" \
        --iodepth="$iodepth" \
        --direct=1 \
        --ioengine=libaio \
        --filename="$TEST_FILE" \
        --runtime="$runtime" \
        --group_reporting |
        grep --color=always -E 'IOPS=|BW=|ioengine|lat|read:|write:|util=|err='
        printf -v separator '%*s' "$(tput cols)" ""; echo "${separator// /-}"
}

# 菜单展示
cat <<EOF

╔════════════════════╗
║   请选择测试模式   ║
║ ------------------ ║
║ 0)  高级模式       ║
║ 1)  顺序读写       ║
║ 2)  随机读写       ║
║ 3)  混合读写       ║
║ 4)  并发读写       ║
║ 9)  常规测试       ║
╚════════════════════╝
EOF

read -rp "请输入选项: " TEST_MODE

case "$TEST_MODE" in
0)
    read -rp "请输入测试模式 (rw, randrw, read, write, randread, randwrite): " RW_MODE
    RW_MODE="${RW_MODE:-rw}"

    read -rp "请输入测试数据大小 (默认: $DEFAULT_TEST_SIZE): " TEST_SIZE
    TEST_SIZE="${TEST_SIZE:-$DEFAULT_TEST_SIZE}"

    read -rp "请输入块大小 (默认: $DEFAULT_BLOCK_SIZE): " BLOCK_SIZE
    BLOCK_SIZE="${BLOCK_SIZE:-$DEFAULT_BLOCK_SIZE}"

    read -rp "请输入线程数 (默认: $DEFAULT_NUM_JOBS): " NUM_JOBS
    NUM_JOBS="${NUM_JOBS:-$DEFAULT_NUM_JOBS}"

    read -rp "请输入IO深度 (默认: $DEFAULT_IO_DEPTH): " IO_DEPTH
    IO_DEPTH="${IO_DEPTH:-$DEFAULT_IO_DEPTH}"

    read -rp "请输入超时时间 (默认: $DEFAULT_RUNTIME): " RUNTIME
    RUNTIME="${RUNTIME:-$DEFAULT_RUNTIME}"

    run_fio_test "自定义测试" "$RW_MODE" "$BLOCK_SIZE" "$TEST_SIZE" "$NUM_JOBS" "$IO_DEPTH" "$RUNTIME"
    ;;
1)
    run_fio_test "顺序写入" "write" "$DEFAULT_BLOCK_SIZE" "$DEFAULT_TEST_SIZE" "$DEFAULT_NUM_JOBS" "$DEFAULT_IO_DEPTH"
    run_fio_test "顺序读取" "read" "$DEFAULT_BLOCK_SIZE" "$DEFAULT_TEST_SIZE" "$DEFAULT_NUM_JOBS" "$DEFAULT_IO_DEPTH"
    ;;
2)
    run_fio_test "随机写入" "randwrite" "$DEFAULT_BLOCK_SIZE" "$DEFAULT_TEST_SIZE" "$DEFAULT_NUM_JOBS" "$DEFAULT_IO_DEPTH"
    run_fio_test "随机读取" "randread" "$DEFAULT_BLOCK_SIZE" "$DEFAULT_TEST_SIZE" "$DEFAULT_NUM_JOBS" "$DEFAULT_IO_DEPTH"
    ;;
3)
    run_fio_test "混合读写" "randrw" "$DEFAULT_BLOCK_SIZE" "$DEFAULT_TEST_SIZE" "$DEFAULT_NUM_JOBS" "$DEFAULT_IO_DEPTH"
    ;;
4)
    run_fio_test "高并发读写" "randrw" "1M" "4G" "16" "1"
    ;;
9)
    echo -e "开始常规测试 (2G/30s + 顺序 & 随机 + 4K & 1M)"
    for bs in 1M 4k; do
        for rw in read write randread randwrite; do
            test_name="test_${rw}_${bs}"
            # 分割行
            printf -v separator '%*s' "$(tput cols)" ""
            echo "${separator// /-}"
            echo "===> 当前任务测试模式: $rw | 块大小: $bs"
            fio --name="$test_name" \
                --filename="$TEST_FILE" \
                --ioengine=libaio \
                --size=2G \
                --rw="$rw" \
                --bs="$bs" \
                --direct=1 \
                --numjobs=1 \
                --iodepth=1 \
                --runtime=30s \
                --group_reporting | grep --color=always -E 'IOPS=|BW=|ioengine|read:|write:|util=|err='
        done
    done
    ;;
*)
    printf "[%s]-[ERROR]: 无效选项，请重新运行脚本。\n" "$(date +"%F %T")"
    exit 1
    ;;
esac
