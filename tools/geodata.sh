#!/usr/bin/env bash
# =============================================================================
# 脚本名称: geodata.sh
# 功能描述: 自动更新 Loyalsoldier 版 geoip.dat / geosite.dat
#           1. 并发加锁，防止 cron 调度与手动执行重叠
#           2. 下载最新 dat 到临时文件（.new），两个都成功且非空才继续
#           3. 与现有文件逐字节对比，有变化才替换并重启 xray
#           4. 重启失败时回滚旧 dat，避免坏数据弄停正在运行的服务
#           5. 输出带时间戳日志（供 cron 重定向到日志文件）
# 使用方式: 手动执行，或由 crontab 每天 06:30 调度
# =============================================================================
set -euo pipefail

# cron 环境的 PATH 很精简，显式设置，避免找不到 curl/systemctl/flock
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

XRAY_DIR="/usr/local/share/xray"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

log() { echo "[$(date '+%F %T')] $*"; }

# 并发锁：防止 cron 调度与手动执行同时替换 dat
mkdir -p "${XRAY_DIR}"
exec 9>"${XRAY_DIR}/.geodata.lock"
flock -n 9 || { log "已有 geodata 更新进程在运行，本次跳过"; exit 0; }

# 任意一步失败都清理临时文件
cleanup() { rm -f geoip.dat.new geosite.dat.new; }
trap cleanup EXIT

cd "${XRAY_DIR}"

log "开始下载 geodata（Loyalsoldier/v2ray-rules-dat）"
curl -fsSL --retry 3 -o geoip.dat.new "${GEOIP_URL}"
curl -fsSL --retry 3 -o geosite.dat.new "${GEOSITE_URL}"

# 内容校验：两个文件都非空才算下载成功
[[ -s geoip.dat.new && -s geosite.dat.new ]] || { log "下载的 dat 文件为空，放弃更新"; exit 1; }

# 逐字节对比，仅替换有变化的文件；替换前把旧文件备份为 .old
changed=0
for f in geoip geosite; do
    if [[ ! -f "${f}.dat" ]] || ! cmp -s "${f}.dat.new" "${f}.dat"; then
        [[ -f "${f}.dat" ]] && mv -f "${f}.dat" "${f}.dat.old"
        mv -f "${f}.dat.new" "${f}.dat"
        changed=1
        log "${f}.dat 已更新"
    else
        rm -f "${f}.dat.new"
    fi
done

if [[ "${changed}" -eq 1 ]]; then
    # 数据变化才重启 xray；xray 未运行属正常情况（如刚卸载/未启动），返回成功
    if systemctl -q is-active xray; then
        if systemctl restart xray; then
            log "xray 已重启以加载新 geodata"
            rm -f geoip.dat.old geosite.dat.old
        else
            # 重启失败：回滚旧 dat 并再次尝试重启，避免坏数据弄停服务
            log "xray 重启失败，回滚旧 geodata"
            for f in geoip geosite; do
                if [[ -f "${f}.dat.old" ]]; then
                    mv -f "${f}.dat.old" "${f}.dat"
                else
                    rm -f "${f}.dat"
                fi
            done
            systemctl restart xray || log "回滚后 xray 仍重启失败，请手动检查: systemctl status xray"
            exit 1
        fi
    else
        log "xray 未在运行，跳过重启"
        rm -f geoip.dat.old geosite.dat.old
    fi
else
    log "geodata 无变化"
fi

exit 0
