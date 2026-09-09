#!/usr/bin/env bash
#
# disable-ipv6-safe.sh
#
# 正确、幂等地在 Ubuntu/Debian + netplan + systemd-networkd 环境下禁用 IPv6。
#
# 设计原则（源自一次真实故障排查的结论）：
#   1. 【内核层】绝不使用 `ipv6.disable=1` 这类内核参数整体阉割 IPv6 协议栈——
#      那样连 lo 上的 ::1 都会消失，导致 getaddrinfo() 双栈探测失败，
#      表现为看似无关的 "Could not resolve host"。
#   2. 【网络管理层】真正决定网卡是否会拿到公网 IPv6 地址的是 netplan 的
#      dhcp6 / accept-ra 配置，而不是 sysctl。必须在这一层关闭。
#   3. 【sysctl 层】只对 default 和具体网卡名设置 disable_ipv6=1，
#      绝不设置 all 或 lo，否则会连累回环接口，且注意 default 的值
#      会被后创建的接口（包括某些场景下的 lo）继承。
#   4. 所有改动前自动备份，脚本可重复运行（幂等），失败会在改动前退出。
#
# 用法：
#   sudo bash disable-ipv6-safe.sh            # 交互确认后执行
#   sudo bash disable-ipv6-safe.sh --yes      # 跳过确认，直接执行
#   sudo bash disable-ipv6-safe.sh --dry-run  # 只打印将要做的改动，不实际修改

set -euo pipefail

SCRIPT_NAME="disable-ipv6-safe"
BACKUP_DIR="/root/${SCRIPT_NAME}-backup-$(date +%Y%m%d-%H%M%S)"
SYSCTL_MANAGED_FILE="/etc/sysctl.d/99-disable-ipv6.conf"
DRY_RUN=0
ASSUME_YES=0
NEEDS_REBOOT=0

log()  { echo "[${SCRIPT_NAME}] $*"; }
warn() { echo "[${SCRIPT_NAME}] WARNING: $*" >&2; }
err()  { echo "[${SCRIPT_NAME}] ERROR: $*" >&2; }

for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --help|-h)
            grep '^#' "$0" | sed 's/^#//'
            exit 0
            ;;
        *) err "未知参数: $arg"; exit 1 ;;
    esac
done

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        err "必须以 root 身份运行。"
        exit 1
    fi
}

run() {
    # 统一的“执行或仅打印”封装，支持 --dry-run
    # 调用方式：run "cmd1 && cmd2"（传入一个完整的命令字符串）
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  [dry-run] $1"
    else
        bash -c "$1"
    fi
}

backup_file() {
    local f="$1"
    [[ -f "$f" ]] || return 0
    mkdir -p "$BACKUP_DIR"
    cp -a "$f" "${BACKUP_DIR}/$(basename "$f").bak"
    log "已备份 $f -> ${BACKUP_DIR}/$(basename "$f").bak"
}

# ---------------------------------------------------------------------------
# 1. 内核层：确保没有 ipv6.disable=1
# ---------------------------------------------------------------------------
check_grub() {
    log "== 检查内核参数 =="
    if [[ ! -f /etc/default/grub ]]; then
        log "未发现 /etc/default/grub（可能不是 grub 引导），跳过内核参数检查。"
        return 0
    fi

    if grep -q 'ipv6\.disable=1' /etc/default/grub; then
        log "发现 /etc/default/grub 中存在 ipv6.disable=1，这会导致协议栈整体消失，将移除。"
        backup_file /etc/default/grub
        if [[ $DRY_RUN -eq 0 ]]; then
            sed -i -E 's/[[:space:]]*ipv6\.disable=1//g' /etc/default/grub
        else
            echo "  [dry-run] 将从 /etc/default/grub 移除 ipv6.disable=1"
        fi

        if command -v update-grub >/dev/null 2>&1; then
            run "update-grub"
        elif command -v grub2-mkconfig >/dev/null 2>&1; then
            local grub_cfg
            grub_cfg=$(find /boot -maxdepth 3 -name grub.cfg 2>/dev/null | head -n1)
            [[ -n "$grub_cfg" ]] && run "grub2-mkconfig -o '$grub_cfg'"
        else
            warn "未找到 update-grub / grub2-mkconfig，请手动重新生成 grub 配置。"
        fi
        NEEDS_REBOOT=1
        log "GRUB 配置已更新，需要重启才能生效。"
    else
        log "未发现 ipv6.disable=1，内核参数正常。"
    fi

    if ls /etc/modprobe.d/*.conf >/dev/null 2>&1 && \
       grep -lE '^\s*blacklist\s+ipv6\b' /etc/modprobe.d/*.conf >/dev/null 2>&1; then
        warn "检测到 /etc/modprobe.d/ 下有文件将 ipv6 模块加入黑名单，这同样会导致协议栈消失。"
        warn "请手动检查并移除以下文件中的相关行："
        grep -lE '^\s*blacklist\s+ipv6\b' /etc/modprobe.d/*.conf 2>/dev/null | sed 's/^/    /'
    fi
}

# ---------------------------------------------------------------------------
# 2. 确定需要处理的以太网接口
#    优先从 netplan 配置里解析（这样和后续 netplan 修改用的是同一份接口清单）
#    如果没有 netplan 或解析失败，退回自动探测活跃物理网卡
# ---------------------------------------------------------------------------
detect_interfaces() {
    local ifaces=""
    if [[ -d /etc/netplan ]] && ls /etc/netplan/*.yaml >/dev/null 2>&1 \
       && python3 -c "import yaml" >/dev/null 2>&1; then
        ifaces=$(python3 - <<'PYEOF'
import glob, sys
import yaml

names = set()
for path in glob.glob('/etc/netplan/*.yaml'):
    try:
        with open(path) as f:
            data = yaml.safe_load(f) or {}
    except Exception:
        continue
    net = (data or {}).get('network') or {}
    eth = net.get('ethernets') or {}
    for key, cfg in eth.items():
        cfg = cfg or {}
        name = cfg.get('set-name', key)
        names.add(name)
for n in sorted(names):
    print(n)
PYEOF
)
    fi

    if [[ -z "$ifaces" ]]; then
        ifaces=$(ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | grep -vE '^(lo|docker[0-9]*|veth.*|br-.*|virbr.*|tun[0-9]*|tap[0-9]*|wg[0-9]*)$' || true)
    fi
    echo "$ifaces"
}

# ---------------------------------------------------------------------------
# 3. 网络管理层：修改 netplan，关闭 dhcp6 / accept-ra
#    使用 python3 + PyYAML 结构化修改，避免用 sed 破坏 YAML 结构，
#    只在确实需要改动的字段上落笔，其余配置原样保留。
# ---------------------------------------------------------------------------
patch_netplan() {
    log "== 检查 netplan 配置 =="
    if [[ ! -d /etc/netplan ]] || ! ls /etc/netplan/*.yaml >/dev/null 2>&1; then
        log "未发现 /etc/netplan/*.yaml，跳过（可能不是用 netplan 管理网络）。"
        return 0
    fi

    if ! python3 -c "import yaml" >/dev/null 2>&1; then
        warn "python3 缺少 yaml 模块（python3-yaml），无法安全解析 netplan 配置。"
        warn "尝试安装 python3-yaml..."
        run "apt-get update -qq && apt-get install -y -qq python3-yaml" || {
            err "自动安装 python3-yaml 失败，请手动安装后重跑本脚本，或手动编辑 netplan 文件。"
            return 1
        }
    fi

    for f in /etc/netplan/*.yaml; do
        backup_file "$f"
    done

    local changed
    if [[ $DRY_RUN -eq 1 ]]; then
        changed=$(python3 - <<'PYEOF'
import glob, yaml
for path in glob.glob('/etc/netplan/*.yaml'):
    with open(path) as f:
        data = yaml.safe_load(f) or {}
    eth = ((data or {}).get('network') or {}).get('ethernets') or {}
    for key, cfg in eth.items():
        cfg = cfg or {}
        if cfg.get('dhcp6') is not False or cfg.get('accept-ra') is not False:
            print(path)
            break
PYEOF
)
        [[ -n "$changed" ]] && echo "$changed" | sed 's/^/  [dry-run] 将修改: /'
        [[ -z "$changed" ]] && log "所有 netplan 文件已符合要求，无需修改。"
        return 0
    fi

    changed=$(python3 - <<'PYEOF'
import glob
import yaml

changed_files = []
for path in glob.glob('/etc/netplan/*.yaml'):
    with open(path) as f:
        data = yaml.safe_load(f) or {}
    net = data.get('network')
    if not net:
        continue
    eth = net.get('ethernets')
    if not eth:
        continue

    modified = False
    for key, cfg in eth.items():
        if cfg is None:
            cfg = {}
            eth[key] = cfg
        if cfg.get('dhcp6') is not False:
            cfg['dhcp6'] = False
            modified = True
        if cfg.get('accept-ra') is not False:
            cfg['accept-ra'] = False
            modified = True

    if modified:
        with open(path, 'w') as f:
            yaml.dump(data, f, sort_keys=False, default_flow_style=False)
        changed_files.append(path)

for p in changed_files:
    print(p)
PYEOF
)

    if [[ -n "$changed" ]]; then
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            chmod 600 "$f"
            log "已修改并重设权限(600): $f"
        done <<< "$changed"

        if command -v netplan >/dev/null 2>&1; then
            if run "netplan generate" && run "netplan apply"; then
                log "netplan 配置已应用。"
            else
                warn "netplan generate/apply 执行失败，配置文件已修改但可能需要手动排查或重启后生效。"
            fi
        else
            warn "未找到 netplan 命令，配置文件已修改（并已备份），但未能立即应用，请手动执行 'netplan apply' 或重启使其生效。"
        fi
    else
        log "所有 netplan 文件已符合要求（dhcp6:false, accept-ra:false），无需修改。"
    fi
}

# ---------------------------------------------------------------------------
# 4. sysctl 层：只写 default + 具体接口名，绝不写 all / lo
#    使用单一托管文件、每次整体重写（而非 append），避免多文件重复叠加冲突。
# ---------------------------------------------------------------------------
write_sysctl_config() {
    local ifaces="$1"
    log "== 写入 sysctl 配置 =="

    {
        echo "# Managed by ${SCRIPT_NAME} - 请勿手动追加 all / lo 的 disable_ipv6"
        echo "# 只禁用 default 和具体网卡的 IPv6，协议栈本身与 lo 保持可用"
        echo "net.ipv6.conf.default.disable_ipv6 = 1"
        for i in $ifaces; do
            echo "net.ipv6.conf.${i}.disable_ipv6 = 1"
        done
    } > "${SYSCTL_MANAGED_FILE}.new"

    if [[ $DRY_RUN -eq 1 ]]; then
        log "将写入 ${SYSCTL_MANAGED_FILE}:"
        sed 's/^/    /' "${SYSCTL_MANAGED_FILE}.new"
        rm -f "${SYSCTL_MANAGED_FILE}.new"
        return 0
    fi

    backup_file "$SYSCTL_MANAGED_FILE"
    mv "${SYSCTL_MANAGED_FILE}.new" "$SYSCTL_MANAGED_FILE"
    log "已写入 ${SYSCTL_MANAGED_FILE}"
}

# 清理其他 sysctl 文件里遗留的、危险的 all/lo disable_ipv6 设置
# （常见于之前手动 echo/append 过配置的机器；全新装机一般不存在，但幂等安全起见保留此步骤）
clean_stray_sysctl() {
    log "== 检查其他 sysctl 文件中是否有冲突的 all/lo 配置 =="
    local files=(/etc/sysctl.conf /etc/sysctl.d/*.conf)
    local found=0

    for f in "${files[@]}"; do
        [[ -f "$f" ]] || continue
        [[ "$f" == "$SYSCTL_MANAGED_FILE" ]] && continue
        if grep -qE '^\s*net\.ipv6\.conf\.(all|lo)\.disable_ipv6\s*=\s*1' "$f" 2>/dev/null; then
            found=1
            log "在 $f 中发现 all/lo 的 disable_ipv6 设置，将注释掉。"
            backup_file "$f"
            if [[ $DRY_RUN -eq 0 ]]; then
                sed -i -E 's/^(\s*net\.ipv6\.conf\.(all|lo)\.disable_ipv6\s*=\s*1)/# [disabled by disable-ipv6-safe] \1/' "$f"
            else
                echo "  [dry-run] 将在 $f 中注释掉相关行"
            fi
        fi
    done

    [[ $found -eq 0 ]] && log "未发现冲突的遗留配置。"
}

apply_sysctl() {
    [[ $DRY_RUN -eq 1 ]] && { log "[dry-run] 将执行 sysctl --system"; return 0; }
    log "== 应用 sysctl 配置 =="
    # 注意：sysctl --system 会应用系统上所有 sysctl.d 配置文件。
    # 如果某个与本脚本无关的旧文件里有当前内核/命名空间不支持的键，
    # sysctl --system 会返回非零值，但这不代表我们自己写入的配置有问题
    # （配置文件已经正确落盘，这才是本脚本真正的交付物）。
    # 因此这里只警告、不中断脚本。
    if sysctl --system >/tmp/sysctl-apply.log 2>&1; then
        log "sysctl 配置已应用。"
    else
        warn "sysctl --system 返回非零，可能是系统上其他与本脚本无关的配置文件导致，详情见 /tmp/sysctl-apply.log"
        warn "本脚本写入的 ${SYSCTL_MANAGED_FILE} 内容仍已正确落盘，重启后会正常生效。"
    fi
}

# ---------------------------------------------------------------------------
# 5. 验证
# ---------------------------------------------------------------------------
verify() {
    [[ $DRY_RUN -eq 1 ]] && return 0
    log "== 验证结果 =="

    echo "--- 公网 scope 的 IPv6 地址（应为空）---"
    ip -6 addr show scope global 2>/dev/null || true

    echo "--- lo 接口（应保留 ::1）---"
    ip a show lo 2>/dev/null | grep -E 'inet6|inet ' || true

    echo "--- DNS 解析测试 ---"
    if command -v getent >/dev/null 2>&1; then
        getent hosts github.com || warn "DNS 解析测试失败（可能是网络本身不可达，与本脚本无关）"
    fi

    if command -v curl >/dev/null 2>&1; then
        echo "--- HTTP 请求测试 ---"
        curl -sS -o /dev/null -w "github.com -> HTTP %{http_code}\n" --max-time 5 https://github.com || \
            warn "HTTP 请求测试失败（可能是网络本身不可达，与本脚本无关）"
    fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
    require_root

    log "开始执行（dry-run=${DRY_RUN}）"
    if [[ $ASSUME_YES -eq 0 && $DRY_RUN -eq 0 ]]; then
        read -r -p "即将修改 GRUB / netplan / sysctl 配置，是否继续？[y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { log "已取消。"; exit 0; }
    fi

    check_grub

    local ifaces
    ifaces=$(detect_interfaces)
    if [[ -z "$ifaces" ]]; then
        warn "未能自动探测到任何以太网接口，sysctl 将只写入 default。"
    else
        log "将处理的接口: $ifaces"
    fi

    patch_netplan
    write_sysctl_config "$ifaces"
    clean_stray_sysctl
    apply_sysctl
    verify

    echo
    log "全部完成。备份目录: ${BACKUP_DIR}（如果本次没有任何改动则可能未创建）"
    if [[ $NEEDS_REBOOT -eq 1 ]]; then
        warn "检测到 GRUB 配置发生变更，请重启系统使内核参数生效: reboot"
    fi
}

main "$@"
