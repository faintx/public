#!/usr/bin/env bash

shell_version="2.0.1"

declare -A osInfo

declare SCRIPT_CONFIG="" # 存储脚本配置内容
declare XRAY_CONFIG=""   # 存储 Xray 配置 (通常在运行时加载)

# 声明一个关联数组，用于在脚本运行时临时存储用户输入的配置数据
declare -A CONFIG_DATA # 用于临时存储用户输入的配置数据

declare -A CLIENT_CONFIG # 关联数组，存储当前处理的客户端配置片段

initEnvironment() {
    echoType="echo -e"
    printN=""

    installPackage="apt install -y"
    # removePackage="apt remove -y"
    updatePackage="apt update -y"
    upgradePackage="apt upgrade -y"

    SSH_CONFIG="/etc/ssh/sshd_config"
    ETC_PROFILE="/etc/profile"
    FAIL2BAN_DIR="$(pwd)/fail2ban/"
    KMS_SERVER_FILE="/usr/bin/vlmcsd"
    KMS_SERVER_PID="/run/vlmcsd.pid"
    KMS_SERVER_CURRENT_VERSION="/var/run/vlmcsd_ver.txt"
    VLMCSD_SERVICE_FILE="/etc/systemd/system/vlmcsd.service"

    # config manager
    # readonly XRAY_SERVER_PATH="/usr/local/etc/xray/"
    : "${XRAY_SERVER_PATH:="/usr/local/etc/xray/"}"
    readonly XRAY_SERVER_PATH

    # readonly XRAY_COINFIG_PATH="/usr/local/etc/xray-script/"
    : "${XRAY_COINFIG_PATH:="/usr/local/etc/xray-script/"}"
    readonly XRAY_COINFIG_PATH

    # readonly XRAY_CONFIG_MANAGER="${XRAY_COINFIG_PATH}xray_config_manager.sh"
    : "${XRAY_CONFIG_MANAGER:="${XRAY_COINFIG_PATH}xray_config_manager.sh"}"
    readonly XRAY_CONFIG_MANAGER

    # 定义配置文件和相关目录的路径
    SCRIPT_CONFIG_DIR="${HOME}/.xray-script" # 主配置文件目录
    readonly SCRIPT_CONFIG_DIR
    SCRIPT_CONFIG_PATH="${SCRIPT_CONFIG_DIR}/config.json" # 脚本主配置文件路径
    readonly SCRIPT_CONFIG_PATH

    XRAY_CONFIG_PATH="/usr/local/etc/xray/config.json" # Xray 最终配置文件路径
    readonly XRAY_CONFIG_PATH

    # --- 正则表达式常量 ---
    # 定义各种数据格式的正则表达式，用于验证输入
    readonly DOMAIN_REGEX="^([a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$" # 域名
    #readonly IPV4_REGEX='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$' # IPv4
    #readonly IPV6_REGEX='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'                                            # IPv6 (简化版)
    readonly HEX_REGEX='^[0-9a-fA-F]+$'                                                                         # 十六进制字符串
    readonly UUID_REGEX='^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$' # UUID
    #readonly EMAIL_REGEX='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'                                     # 邮箱地址

    XTLS_CONFIG="Vision"

    is_close=false
}
initEnvironment

echoEnhance() {
    # Function to print text in different colors.
    # Arguments:
    #   $1: Color name (e.g., "red", "skyBlue", "green", "white", "magenta", "yellow", etc.)
    #   ${*:2}: Text to be printed

    case $1 in
    # 红色 (Red)
    "red")
        ${echoType} "\033[31m${printN}${*:2} \033[0m"
        ;;
    # 天蓝色 (Sky Blue)
    "skyBlue")
        ${echoType} "\033[1;36m${printN}${*:2} \033[0m"
        ;;
    # 绿色 (Green)
    "green")
        ${echoType} "\033[32m${printN}${*:2} \033[0m"
        ;;
    # 白色 (White)
    "white")
        ${echoType} "\033[37m${printN}${*:2} \033[0m"
        ;;
    # 芒果色 (Magenta)
    "magenta")
        ${echoType} "\033[35m${printN}${*:2} \033[0m"
        ;;
    # 黄色 (Yellow)
    "yellow")
        ${echoType} "\033[33m${printN}${*:2} \033[0m"
        ;;
    # 青色 (Cyan)
    "cyan")
        ${echoType} "\033[36m${printN}${*:2} \033[0m"
        ;;
    # 蓝色 (Blue)
    "blue")
        ${echoType} "\033[34m${printN}${*:2} \033[0m"
        ;;
    # 粉色 (Pink)
    "pink")
        ${echoType} "\033[95m${printN}${*:2} \033[0m"
        ;;
    # 灰色 (Gray)
    "gray")
        ${echoType} "\033[90m${printN}${*:2} \033[0m"
        ;;
    # 银色 (Silver)
    "silver")
        ${echoType} "\033[38;5;251m${printN}${*:2} \033[0m"
        ;;
    # 黑色 (Black)
    "black")
        ${echoType} "\033[30m${printN}${*:2} \033[0m"
        ;;
    esac
}

function _info() {
    echoEnhance green "[信息] $*"
    #printf -- "%s" "$@"
    printf "\n"
}

function _warn() {
    echoEnhance yellow "[警告] $*"
    #printf -- "%s" "$@"
    printf "\n"
}

function _error() {
    echoEnhance red "[错误] $*"
    #printf -- "%s" "$@"
    printf "\n"
    is_close=true
}

function _pass() {
    echoEnhance green "[通过] $*"
    #printf -- "%s" "$@"
    printf "\n"
}

function _fail() {
    echoEnhance red "[失败] $*"
    #printf -- "%s" "$@"
    printf "\n"
}

function _get_os_info() {

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release

        osInfo[ID]=${ID}
        osInfo[VERSION_ID]=${VERSION_ID}
        osInfo[NAME]=${NAME}
        # shellcheck disable=SC2153
        osInfo[VERSION]=${VERSION}
        osInfo[PRETTY_NAME]=${PRETTY_NAME}
        osInfo[VERSION_CODENAME]=${VERSION_CODENAME}

        osInfo[KERNEL_NAME]=$(uname -s)
        osInfo[KERNEL_VERSION]=$(uname -v)
        osInfo[KERNEL_RELEASE]=$(uname -r)
        osInfo[KERNEL_ARCH]=$(uname -m)
        osInfo[KERNEL_OS]=$(uname -o)
    fi
}

function check_os() {
    _get_os_info
    [[ -z "${osInfo[ID]}" ]] && _error "Not supported OS" && return
    case "${osInfo[ID]}" in
    ubuntu)
        [ -n "${osInfo[VERSION_ID]}" ] && [[ $(echo "${osInfo[VERSION_ID]}" | cut -d '.' -f 1) -lt 20 ]] && _error "Not supported OS, please change to Ubuntu 20+ and try again."
        ;;
    debian)
        [ -n "${osInfo[VERSION_ID]}" ] && [[ $(echo "${osInfo[VERSION_ID]}" | cut -d '.' -f 1) -lt 11 ]] && _error "Not supported OS, please change to Debian 11+ and try again."
        ;;
    centos)
        [ -n "${osInfo[VERSION_ID]}" ] && [[ $(echo "${osInfo[VERSION_ID]}" | cut -d '.' -f 1) -lt 7 ]] && _error "Not supported OS, please change to CentOS 7+ and try again."
        installPackage="yum install -y"
        # removePackage="yum remove -y"
        updatePackage="yum update -y"
        # upgradePackage="yum upgrade -y"
        ;;
    *)
        _error "Not supported OS"
        ;;
    esac
}

check_root() {
    [[ $EUID != 0 ]] && _error "当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 sudo su 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。"
}

check_systemctl() {
    # if ! systemctl --version >/dev/null 2>&1; then
    #     _error "系统未安装systemctl"
    # fi

    # 检查 systemctl 是否存在
    if ! command -v systemctl &>/dev/null; then
        _info "systemctl 未安装，正在尝试安装..."
        # 检查发行版
        case "${osInfo[ID]}" in
        debian | ubuntu)
            _info "检测到 Debian/Ubuntu 系统，安装 systemd..."
            ${updatePackage}
            ${installPackage} systemd
            ;;
        centos | rhel)
            _info "检测到 CentOS/RHEL 系统，安装 systemd..."
            ${updatePackage}
            ${installPackage} systemd
            ;;
        *)
            _error "不支持的发行版: ${osInfo[ID]}"
            ;;
        esac
    # else
    #     _info "检测到系统已安装 systemctl，跳过安装..."
    fi
}
check_os
check_root
check_systemctl

function _systemctl() {
    local cmd="$1"
    local server_name="$2"
    case "${cmd}" in
    start)
        _info "正在启动 ${server_name} 服务"
        systemctl -q is-active "${server_name}" || systemctl -q start "${server_name}"
        systemctl -q is-enabled "${server_name}" || systemctl -q enable "${server_name}"
        sleep 2

        # systemctl -q is-active "${server_name}" && _info "已启动 ${server_name} 服务" || _error "${server_name} 启动失败"
        if systemctl -q is-active "${server_name}"; then
            _info "已启动 ${server_name} 服务"
        else
            _error "${server_name} 启动失败, 请检查日志"
        fi
        ;;
    stop)
        _info "正在暂停 ${server_name} 服务"
        systemctl -q is-active "${server_name}" && systemctl -q stop "${server_name}"
        systemctl -q is-enabled "${server_name}" && systemctl -q disable "${server_name}"
        sleep 2

        systemctl -q is-active "${server_name}" || _info "已暂停 ${server_name} 服务"
        ;;
    restart)
        _info "正在重启 ${server_name} 服务"
        # systemctl -q is-active "${server_name}" && systemctl -q restart "${server_name}" || systemctl -q start "${server_name}"
        if systemctl -q is-active "${server_name}"; then
            systemctl -q restart "${server_name}"
        else
            systemctl -q start "${server_name}"
        fi

        systemctl -q is-enabled "${server_name}" || systemctl -q enable "${server_name}"
        sleep 2

        # systemctl -q is-active "${server_name}" && _info "已重启 ${server_name} 服务" || _error "${server_name} 启动失败"
        if systemctl -q is-active "${server_name}"; then
            _info "已重启 ${server_name} 服务"
        else
            _error "${server_name} 启动失败, 请检查日志"
        fi
        ;;
    reload)
        _info "正在重载 ${server_name} 服务"
        # systemctl -q is-active "${server_name}" && systemctl -q reload "${server_name}" || systemctl -q start "${server_name}"
        if systemctl -q is-active "${server_name}"; then
            systemctl -q reload "${server_name}"
        else
            systemctl -q start "${server_name}"
        fi

        systemctl -q is-enabled "${server_name}" || systemctl -q enable "${server_name}"
        sleep 2

        systemctl -q is-active "${server_name}" && _info "已重载 ${server_name} 服务"
        ;;
    dr)
        _info "正在重载 systemd 配置文件"
        systemctl daemon-reload
        ;;
    esac
}

function _error_detect() {
    local cmd="$1"
    _info "${cmd}"
    if ! eval "${cmd}"; then
        _error "Execution command (${cmd}) failed, please check it and try again."
    fi
}

update_shell() {
    _info "当前版本为 [ ${shell_version} ]，开始检测最新版本..."
    sh_new_ver=$(curl https://raw.githubusercontent.com/faintx/public/refs/heads/main/sysset.sh | grep 'shell_version="' | awk -F "=" '{print $NF}' | sed 's/\"//g' | head -1)
    [[ -z "${sh_new_ver}" ]] && _warn "检测最新版本失败 !" && return
    if [[ ${sh_new_ver} != "${shell_version}" ]]; then
        echo "发现新版本[ ${sh_new_ver} ]，是否更新？[Y/n]"
        read -rp "(默认:y):" yn
        [[ -z "${yn}" ]] && yn="y"
        if [[ ${yn} == [Yy] ]]; then
            curl -o sysset.sh https://raw.githubusercontent.com/faintx/public/refs/heads/main/sysset.sh && chmod +x sysset.sh
            _info "脚本已更新为最新版本[ ${sh_new_ver} ]！"
            echo "3s后执行新脚本..."
            sleep 3s
            is_close=true
            bash sysset.sh
        else
            _info "已取消..."
        fi
    else
        _info "当前已是最新版本[ ${sh_new_ver} ] ！"
    fi
}

do_swap() {

    swap_file_size="$1"

    # 检查 /proc/swaps 是否存在
    if [[ ! -f /proc/swaps ]]; then
        _warn "文件 /proc/swaps 不存在"
    fi

    # 使用 awk 提取交换文件名，并将其赋值给变量
    swap_file=$(awk 'NR > 1 { if ($1 ~ /^\/.*$/) print $1 }' /proc/swaps)

    # 检查是否找到了交换文件名
    if [[ -z "${swap_file}" ]]; then
        _info "没有找到交换文件"
    else
        _info "找到的交换文件名：$swap_file"
        # rm -rf "${swap_file}"
    fi

    swap_file="/root/swapfile"
    if [[ -e "${swap_file}" ]]; then
        _info "删除 swap 交换分区"
        #swapoff -a
        swapoff "${swap_file}"
        rm -f "${swap_file}"
    fi

    _info "创建 swap 交换分区文件"
    #fallocate -l $1G $swap_file
    if [[ "${swap_file_size}" =~ ^[1-9][0-9]*$ ]]; then
        _info "将要创建 ${swap_file_size}GB 的 swap 交换分区文件"
    else
        _warn "${swap_file_size} 不是一个正整数，默认创建 1GB 的 swap 交换分区文件"
        swap_file_size=1
    fi

    dd if=/dev/zero of=${swap_file} bs=1M count=$((swap_file_size * 1024))

    _info "加载 swap 交换分区文件"
    chmod 600 "${swap_file}"
    mkswap "${swap_file}"
    swapon "${swap_file}"

    _info "持久化 swap 交换分区文件"
    if grep -q "${swap_file}" /etc/fstab; then
        echo "Persistence flag exists"
    else
        echo "${swap_file} swap swap defaults 0 0" >>/etc/fstab
    fi

    _info "显示 swap 交换分区"
    swapon --show
    echo
    free -h
    echo
}

config_swapfile() {
    _info "设置 swap 交换分区"
    read -rp "请输入 swap 分区大小(单位GB，默认1GB)(q退出):" swap_size
    [[ $swap_size == "exit" || $swap_size == [Qq] ]] && return
    [[ -z "${swap_size}" ]] && swap_size=1
    do_swap "${swap_size}"
}

show_repo() {

    case "${osInfo[ID]}" in
    debian | ubuntu)
        _info "当前 repo 源 /etc/apt/sources.list"
        cat /etc/apt/sources.list
        ;;
    centos)
        os_version=$(cat /etc/centos-release)
        echo "$os_version"
        if [[ "$os_version" == *"Stream"* ]]; then
            if [[ -e "/etc/yum.repos.d/CentOS-Stream-BaseOS.repo" ]]; then
                grep "name\|http" /etc/yum.repos.d/CentOS-Stream-BaseOS.repo
            fi

            if [[ -e "/etc/yum.repos.d/CentOS-Stream-AppStream.repo" ]]; then
                grep "name\|http" /etc/yum.repos.d/CentOS-Stream-AppStream.repo
            fi

            if [[ -e "/etc/yum.repos.d/centos.repo" ]]; then
                grep "name\|http" /etc/yum.repos.d/centos.repo
            fi
        else
            if [[ -e "/etc/yum.repos.d/CentOS-Base.repo" ]]; then
                grep "name\|http" /etc/yum.repos.d/CentOS-Base.repo
            fi

            if [[ -e "/etc/yum.repos.d/CentOS-Linux-BaseOS.repo" ]]; then
                grep "name\|http" /etc/yum.repos.d/CentOS-Linux-BaseOS.repo
            elif [[ -e "/etc/yum.repos.d/CentOS-BaseOS.repo" ]]; then
                grep "name\|http" /etc/yum.repos.d/CentOS-BaseOS.repo
            fi

            if [[ -e "/etc/yum.repos.d/CentOS-Linux-AppStream.repo" ]]; then
                grep "name\|http" /etc/yum.repos.d/CentOS-Linux-AppStream.repo
            elif [[ -e "/etc/yum.repos.d/CentOS-AppStream.repo" ]]; then
                grep "name\|http" /etc/yum.repos.d/CentOS-AppStream.repo
            fi
        fi
        ;;
    *) ;;
    esac
}

set_target_repo() {

    local target_repo="$1"
    _info "target repo: $target_repo"

    # 备份当前的 sources.list 文件
    cp -f /etc/apt/sources.list /etc/apt/sources.list.bak

    # 输出备份成功消息
    _info "当前 sources.list 已备份为 /etc/apt/sources.list.bak"

    # 写入 target repo 到 sources.list
    _info "正在替换为 target repo ..."

    debian_repolist=$(
        cat <<'EOF'
deb https://TARGET_REPO_ADDRESS/debian/ VERSION_CODENAME_REPLACE main contrib non-free non-free-firmware
deb-src https://TARGET_REPO_ADDRESS/debian/ VERSION_CODENAME_REPLACE main contrib non-free non-free-firmware

deb https://TARGET_REPO_ADDRESS/debian/ VERSION_CODENAME_REPLACE-updates main contrib non-free non-free-firmware
deb-src https://TARGET_REPO_ADDRESS/debian/ VERSION_CODENAME_REPLACE-updates main contrib non-free non-free-firmware

deb https://TARGET_REPO_ADDRESS/debian/ VERSION_CODENAME_REPLACE-backports main contrib non-free non-free-firmware
deb-src https://TARGET_REPO_ADDRESS/debian/ VERSION_CODENAME_REPLACE-backports main contrib non-free non-free-firmware

deb https://TARGET_REPO_ADDRESS/debian-security VERSION_CODENAME_REPLACE-security main contrib non-free non-free-firmware
deb-src https://TARGET_REPO_ADDRESS/debian-security VERSION_CODENAME_REPLACE-security main contrib non-free non-free-firmware
EOF
    )

    ubuntu_repolist=$(
        cat <<'EOF'
deb https://TARGET_REPO_ADDRESS/ubuntu/ VERSION_CODENAME_REPLACE main restricted universe multiverse
deb-src https://TARGET_REPO_ADDRESS/ubuntu/ VERSION_CODENAME_REPLACE main restricted universe multiverse

deb https://TARGET_REPO_ADDRESS/ubuntu/ VERSION_CODENAME_REPLACE-updates main restricted universe multiverse
deb-src https://TARGET_REPO_ADDRESS/ubuntu/ VERSION_CODENAME_REPLACE-updates main restricted universe multiverse

deb https://TARGET_REPO_ADDRESS/ubuntu/ VERSION_CODENAME_REPLACE-backports main restricted universe multiverse
deb-src https://TARGET_REPO_ADDRESS/ubuntu/ VERSION_CODENAME_REPLACE-backports main restricted universe multiverse

deb https://TARGET_REPO_ADDRESS/ubuntu/ VERSION_CODENAME_REPLACE-security main restricted universe multiverse
deb-src https://TARGET_REPO_ADDRESS/ubuntu/ VERSION_CODENAME_REPLACE-security main restricted universe multiverse
EOF
    )

    case "${osInfo[ID]}" in
    debian)
        case "${osInfo[VERSION_CODENAME]}" in
        bullseye)
            modified_repolist="${debian_repolist//VERSION_CODENAME_REPLACE/bullseye}"
            ;;
        bookworm | *)
            modified_repolist="${debian_repolist//VERSION_CODENAME_REPLACE/bookworm}"
            ;;
        esac
        modified_repolist="${modified_repolist//TARGET_REPO_ADDRESS/$target_repo}"
        ;;
    ubuntu)
        case "${osInfo[VERSION_CODENAME]}" in
        focal)
            modified_repolist="${ubuntu_repolist//VERSION_CODENAME_REPLACE/focal}"
            ;;
        jammy)
            modified_repolist="${ubuntu_repolist//VERSION_CODENAME_REPLACE/jammy}"
            ;;
        lunar)
            modified_repolist="${ubuntu_repolist//VERSION_CODENAME_REPLACE/lunar}"
            ;;
        mantic)
            modified_repolist="${ubuntu_repolist//VERSION_CODENAME_REPLACE/mantic}"
            ;;
        noble | *)
            modified_repolist="${ubuntu_repolist//VERSION_CODENAME_REPLACE/noble}"
            ;;
        esac
        modified_repolist="${modified_repolist//TARGET_REPO_ADDRESS/$target_repo}"
        ;;
    *)
        modified_repolist="${debian_repolist//VERSION_CODENAME_REPLACE/bookworm}"
        ;;
    esac

    # 写入 target repo 到 sources.list
    echo "${modified_repolist}" | tee /etc/apt/sources.list

    # 更新 APT 软件包列表
    ${updatePackage}

}

set_tuna_tsinghua_repo() {

    read -rp "确定要切换至清华源?(y/N)(默认:n):" unyn
    [[ -z "${unyn}" ]] && unyn="n"
    if [[ ${unyn} != [Yy] ]]; then
        _info "已取消..."
        return
    fi

    set_target_repo "mirrors.tuna.tsinghua.edu.cn"

    _info "源已更换为清华源。"
}

set_huaweicloud_repo() {

    read -rp "确定要切换至华为云源?(y/N)(默认:n):" unyn
    [[ -z "${unyn}" ]] && unyn="n"
    if [[ ${unyn} != [Yy] ]]; then
        _info "已取消..."
        return
    fi

    set_target_repo "mirrors.huaweicloud.com"

    _info "源已更换为华为云源。"
}

set_tencent_repo() {

    read -rp "确定要切换至腾讯云源?(y/N)(默认:n):" unyn
    [[ -z "${unyn}" ]] && unyn="n"
    if [[ ${unyn} != [Yy] ]]; then
        _info "已取消..."
        return
    fi

    set_target_repo "mirrors.tencent.com"

    _info "源已更换为腾讯云源。"
}

set_vault_centos_repo() {

    os_version=$(cat /etc/centos-release)
    echo "$os_version"
    if [[ "$os_version" == *"Stream"* ]]; then
        _info "CentOS Stream 系统不需要切换源."
        return
    fi

    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
    yum clean all && yum makecache
}

set_aliyun_repo() {

    os_version=$(cat /etc/centos-release)
    echo "$os_version"
    if [[ "$os_version" == *"Stream"* ]]; then
        _info "CentOS Stream 系统不需要切换源."
        return
    fi

    echo "确定要切换至阿里源 ? (y/N)"
    read -rp "(默认:n):" unyn
    [[ -z "${unyn}" ]] && unyn="n"
    if [[ ${unyn} == [Nn] ]]; then
        return
    fi

    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
    if [ -n "${osInfo[VERSION_ID]}" ]; then
        if [ "${osInfo[VERSION_ID]}" -eq 7 ]; then
            _info "开始切换 CentOS 7 源 ......"
            # curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
            if curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo; then
                yum clean all && yum makecache
            else
                _warn "下载 repo 文件失败."
                mv /etc/yum.repos.d/CentOS-Base.repo.backup /etc/yum.repos.d/CentOS-Base.repo
            fi

        elif [ "${osInfo[VERSION_ID]}" -eq 8 ]; then
            _info "开始切换 CentOS 8 源 ......"
            # curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo
            if curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo; then
                yum clean all && yum makecache
            else
                _warn "下载 repo 文件失败."
                mv /etc/yum.repos.d/CentOS-Base.repo.backup /etc/yum.repos.d/CentOS-Base.repo
            fi

        else
            _warn "暂不支持该系统版本."
            mv /etc/yum.repos.d/CentOS-Base.repo.backup /etc/yum.repos.d/CentOS-Base.repo
        fi

        # if [[ $? -eq 0 ]]; then
        #     #mv CentOS-Linux-AppStream.repo CentOS-Linux-AppStream.repo.bak
        #     #mv CentOS-Linux-BaseOS.repo CentOS-Linux-BaseOS.repo.bak
        #     yum clean all && yum makecache
        #     #yum update -y
        # else
        #     _warn "下载 repo 文件失败."
        #     mv /etc/yum.repos.d/CentOS-Base.repo.backup /etc/yum.repos.d/CentOS-Base.repo
        # fi
    fi
}

make_update_file() {

    # shellcheck disable=SC1078
    # shellcheck disable=SC2028
    # shellcheck disable=SC2016
    # shellcheck disable=SC2026
    # shellcheck disable=SC1079

    cat <<'EOF' >~/update_mirror.pl
#!/usr/bin/perl

use strict;
use warnings;
use autodie;

my $mirrors = 'https://mirrors.tuna.tsinghua.edu.cn/centos-stream';

if (@ARGV < 1) {
    die "Usage: $0 <filename1> <filename2> ...\n";
}

while (my $filename = shift @ARGV) {
    my $backup_filename = $filename . '.bak';
    rename $filename, $backup_filename;

    open my $input, "<", $backup_filename;
    open my $output, ">", $filename;

    while (<$input>) {
        s/^metalink/# metalink/;

        if (m/^name/) {
            my (undef, $repo, $arch) = split /-/;
            $repo =~ s/^\s+|\s+$//g;
            ($arch = defined $arch ? lc($arch) : '') =~ s/^\s+|\s+$//g;

            if ($repo =~ /^Extras/) {
                $_ .= "baseurl=${mirrors}/SIGs/\$releasever-stream/extras" . ($arch eq 'source' ? "/${arch}/" : "/\$basearch/") . "extras-common\n";
            } else {
                $_ .= "baseurl=${mirrors}/\$releasever-stream/$repo" . ($arch eq 'source' ? "/" : "/\$basearch/") . ($arch ne '' ? "${arch}/tree/" : "os") . "\n";
            }
        }

        print $output $_;
    }
}
EOF

}

set_centos_tsinghua_repo() {

    # 写入清华源官方 perl 脚本
    make_update_file

    # 检查 Perl 是否已安装
    if ! command -v perl >/dev/null 2>&1; then
        # yum install -y perl
        ${installPackage} perl --setopt=install_weak_deps=False
    fi

    perl ~/update_mirror.pl /etc/yum.repos.d/centos*.repo
    _info "清华源官方 perl 脚本执行完毕.开始 makecache ..."

    yum clean all && yum makecache

    _info "源已更换为清华源。"
}

config_repo() {
    while true; do
        [[ true = "${is_close}" ]] && break
        echo
        echoEnhance gray "========================================="
        echoEnhance blue "设置 repo 源"
        echoEnhance gray "========================================="
        echoEnhance silver "1. 查看当前源"
        echoEnhance gray "———————————————————————————————————"

        case "${osInfo[ID]}" in
        debian | ubuntu)
            echoEnhance silver "2. 切换至 tuna.tsinghua.edu.cn 源"
            echoEnhance silver "3. 切换至 huaweicloud.com 源"
            echoEnhance silver "4. 切换至 tencent.com 源"
            ;;
        centos)
            echoEnhance gray "5. 切换至 vault.centos.org 源 (deprecated)"
            echoEnhance gray "6. 切换至 aliyun 源 (deprecated)"
            echoEnhance silver "7. 切换至 tuna.tsinghua.edu.cn 源 (CentOS Stream 9)"
            ;;
        *) ;;
        esac

        echoEnhance gray "———————————————————————————————————"
        echoEnhance cyan "0. 返回上级菜单"
        echoEnhance gray "========================================="

        read -rp "请输入序号:" num
        case "${num}" in
        1)
            show_repo
            ;;
        2)
            set_tuna_tsinghua_repo
            ;;
        3)
            set_huaweicloud_repo
            ;;
        4)
            set_tencent_repo
            ;;
        5)
            set_vault_centos_repo
            ;;
        6)
            set_aliyun_repo
            ;;
        7)
            set_centos_tsinghua_repo
            ;;
        0)
            break
            ;;
        *)
            _warn "输入错误数字:${num}！请重新输入 ！"
            ;;
        esac
    done
}

init_system() {
    ${updatePackage}
    ${upgradePackage}
    ${installPackage} epel-release
    ${installPackage} wget curl git gcc automake autoconf libtool make net-tools jq
}

disable_SELinux() {

    case "${osInfo[ID]}" in
    debian | ubuntu)
        _info "Debian/Ubuntu 默认安全模块是 AppArmor. Nothing to do."
        ;;
    centos)
        selinux_con=$(sed -n '/^SELINUX=/p' /etc/selinux/config)
        _info "SELinux 配置：${selinux_con}"
        if [[ "${selinux_con}" != "SELINUX=disabled" ]]; then
            #sed -i 's/^SELINUX=/#SELINUX=/g' /etc/selinux/config
            #echo "SELINUX=disabled" >>/etc/selinux/config
            sed -i "s/${selinux_con}/SELINUX=disabled/g" /etc/selinux/config
            _warn "SELinux 配置已关闭，需要重启生效."
            read -rp "是否现在重启系统?[Y/n]" is_reboot
            is_reboot=${is_reboot:-Y}
            [[ "${is_reboot}" == [Yy] ]] && reboot
        fi
        ;;
    *) ;;
    esac
}

check_ssh_port_open() {
    # 检查 SSH 端口是否开启

    local PORT_TO_OPEN="$1"
    # _info "需要检查的端口：$PORT_TO_OPEN"

    # 检查 firewalld 是否存在
    if ! command -v firewall-cmd &>/dev/null; then
        return 1
    fi

    # 检查 firewalld 是否正在运行
    if ! systemctl is-active --quiet firewalld; then
        return 1
    fi

    local OPEN_PORTS
    OPEN_PORTS=$(firewall-cmd --list-ports)
    # _info "当前防火墙规则：${OPEN_PORTS}"

    if ! echo "${OPEN_PORTS}" | grep -q "${PORT_TO_OPEN}"; then
        # 打开指定端口
        if firewall-cmd --zone=public --add-port="${PORT_TO_OPEN}"/tcp --permanent; then
            _info "成功打开端口 $PORT_TO_OPEN。"
        else
            _warn "打开端口 $PORT_TO_OPEN 失败。"
            return 2
        fi

        # 重新加载防火墙规则
        firewall-cmd --reload
        _info "防火墙规则已重新加载:$(firewall-cmd --list-ports)"
    fi

    return 0

}

config_ssh() {

    # SSH 配置文件路径
    [[ ! -e ${SSH_CONFIG} ]] && _warn "${SSH_CONFIG} 配置文件不存在，请检查！" && return

    if [[ "${osInfo[ID]}" == "centos" ]]; then
        selinux_con=$(sed -n '/^SELINUX=/p' /etc/selinux/config)
        _info "SELinux 配置：${selinux_con}"
        if [[ "${selinux_con}" != "SELINUX=disabled" ]]; then
            _warn "SELinux 未关闭，更改 SSH 端口会无法连接."
            return
        fi
    fi

    # 检查 sshd.service 或 ssh.service 的启用状态
    if systemctl is-enabled sshd.service &>/dev/null || systemctl is-enabled ssh.service &>/dev/null; then
        _info "SSH service already enabled."
    else
        _info "SSH service not enabled, enable it now..."
        # systemctl enable sshd.service 2>/dev/null || systemctl enable ssh.service
        # if [ $? -eq 0 ]; then
        #     _info "SSH service successfully enabled."
        # else
        #     _warn "enable SSH service failed. please check."
        #     return
        # fi
        if systemctl enable sshd.service &>/dev/null || systemctl enable ssh.service &>/dev/null; then
            _info "SSH service successfully enabled."
        else
            _warn "enable SSH service failed. please check."
            return
        fi
    fi

    local read_config_ssh_port
    read_config_ssh_port=$(grep "^Port " "${SSH_CONFIG}" | awk '{print $2}')
    # 检查 Port
    if [ -n "$read_config_ssh_port" ]; then
        _info "SSH 当前端口的设置为: ${read_config_ssh_port}"
    else
        read_config_ssh_port=22
        _info "未找到 Port 设置，默认为 22 端口."
    fi

    read -rp "请输入 SSH 端口号(默认为:${read_config_ssh_port})(q退出):" SSH_PORT
    [[ ${SSH_PORT} == [Qq] ]] && return
    SSH_PORT=${SSH_PORT:-${read_config_ssh_port}}
    # expr "${SSH_PORT}" + 0 &>/dev/null
    if [[ ! "${SSH_PORT}" =~ ^[0-9]+$ || "$SSH_PORT" -le 0 || "$SSH_PORT" -gt 65535 ]]; then
        _warn "输入了错误的端口:${SSH_PORT}" && echo
        return
    else
        #sed -i "s/Port 22/Port ${sshport}/g" ${SSHConfig}
        #sed -i '/^Port /s/^\(.*\)$/#\1/g' "$SSHConfig"
        #echo -e "${Info}屏蔽原 SSH 端口成功 ！" && echo

        if grep -q "^Port " "${SSH_CONFIG}"; then
            current_port=${read_config_ssh_port}
            if [[ "${current_port}" != "${SSH_PORT}" ]]; then
                _info "Port 当前设置为: ${current_port}，正在修改为 ${SSH_PORT}..."
                check_ssh_port_open "${SSH_PORT}"
                if [ $? -ne 2 ]; then
                    sed -i.bak "s/^Port .*/Port $SSH_PORT/" "${SSH_CONFIG}"
                    _info "已将端口修改为: $SSH_PORT"
                else
                    _warn "打开防火墙 firewalld 端口出错，不能修改端口。"
                fi
            else
                _info "端口已设置为: $SSH_PORT，无需修改。"
            fi
        else
            _info "未找到 Port 设置，正在添加..."
            check_ssh_port_open "${SSH_PORT}"
            if [ $? -ne 2 ]; then
                echo "Port $SSH_PORT" >>"${SSH_CONFIG}"
                _info "已添加 SSH 端口设置为: $SSH_PORT"
            else
                _warn "打开防火墙 firewalld 端口出错，不能修改端口。"
            fi
        fi

        if ! systemctl restart sshd.service &>/dev/null && ! systemctl restart ssh.service &>/dev/null; then
            _warn "重启 SSH 服务失败，请检查!"
        fi

    fi

    # 检查 PermitRootLogin
    if grep -q "^PermitRootLogin " "${SSH_CONFIG}"; then
        _info "当前 PermitRootLogin 设置为: $(grep "^PermitRootLogin " "${SSH_CONFIG}")"
    else
        case "${osInfo[ID]}" in
        debian | ubuntu)
            _info "未找到 PermitRootLogin 设置，默认值：PermitRootLogin prohibit-password."
            ;;
        centos)
            _info "未找到 PermitRootLogin 设置，默认值：PermitRootLogin yes."
            ;;
        *) ;;
        esac
    fi

    read -rp "设置 SSH 是否允许 root 登录?[Y/n](q退出):" is_allow_root_login
    [[ ${is_allow_root_login} == [Qq] ]] && return
    if [[ ${is_allow_root_login} == [Nn] ]]; then
        YES_NO="no"
    else
        YES_NO="yes"
    fi
    # 检查并修改 PermitRootLogin
    if grep -q "^PermitRootLogin " "${SSH_CONFIG}"; then
        current_permit_root_login=$(grep "^PermitRootLogin " "${SSH_CONFIG}" | awk '{print $2}')
        if [[ "$current_permit_root_login" != "${YES_NO}" ]]; then
            _info "PermitRootLogin 当前设置为: $current_permit_root_login，正在修改为 ${YES_NO}..."
            sed -i.bak "s/^PermitRootLogin .*/PermitRootLogin ${YES_NO}/" "${SSH_CONFIG}"
            _info "PermitRootLogin 已设置为: ${YES_NO}"
        else
            _info "PermitRootLogin 已设置为: ${YES_NO}，无需修改。"
        fi
    else
        _info "未找到 PermitRootLogin 设置，正在添加..."
        echo "PermitRootLogin ${YES_NO}" >>"${SSH_CONFIG}"
        _info "已添加 PermitRootLogin 设置为: ${YES_NO}"
    fi
    if ! systemctl restart sshd.service &>/dev/null && ! systemctl restart ssh.service &>/dev/null; then
        _warn "重启 SSH 服务失败，请检查!"
    fi

    # 检查 PasswordAuthentication
    if grep -q "^PasswordAuthentication " "${SSH_CONFIG}"; then
        _info "当前 PasswordAuthentication 设置为: $(grep "^PasswordAuthentication " "${SSH_CONFIG}")"
    else
        _info "未找到 PasswordAuthentication 设置，默认为 yes."
    fi

    read -rp "设置 SSH 是否允许密码登录?[Y/n](q退出):" is_allow_password_login
    [[ ${is_allow_password_login} == [Qq] ]] && return
    if [[ ${is_allow_password_login} == [Nn] ]]; then
        YES_NO="no"
    else
        YES_NO="yes"
    fi
    # 检查并修改 PasswordAuthentication
    if grep -q "^PasswordAuthentication " "${SSH_CONFIG}"; then
        current_password_authentication=$(grep "^PasswordAuthentication " "${SSH_CONFIG}" | awk '{print $2}')
        if [[ "$current_password_authentication" != "${YES_NO}" ]]; then
            _info "PasswordAuthentication 当前设置为: $current_password_authentication，正在修改为 ${YES_NO}..."
            sed -i.bak "s/^PasswordAuthentication .*/PasswordAuthentication ${YES_NO}/" "${SSH_CONFIG}"
            _info "PasswordAuthentication 已设置为: ${YES_NO}"
        else
            _info "PasswordAuthentication 已设置为: ${YES_NO}，无需修改。"
        fi
    else
        _info "未找到 PasswordAuthentication 设置，正在添加..."
        echo "PasswordAuthentication ${YES_NO}" >>"${SSH_CONFIG}"
        _info "已添加 PasswordAuthentication 设置为: ${YES_NO}"
    fi
    if ! systemctl restart sshd.service &>/dev/null && ! systemctl restart ssh.service &>/dev/null; then
        _warn "重启 SSH 服务失败，请检查!"
    fi

    # 检查 PubkeyAuthentication
    if grep -q "^PubkeyAuthentication " "${SSH_CONFIG}"; then
        _info "当前 PubkeyAuthentication 设置为: $(grep "^PubkeyAuthentication " "${SSH_CONFIG}")"
    else
        _info "未找到 PubkeyAuthentication 设置，默认为 yes."
    fi

    read -rp "设置 SSH 是否允许公钥登录?[Y/n](q退出):" is_allow_pubkey_login
    [[ ${is_allow_pubkey_login} == [Qq] ]] && return
    if [[ ${is_allow_pubkey_login} == [Nn] ]]; then
        YES_NO="no"
    else
        YES_NO="yes"
    fi
    # 检查并修改 PubkeyAuthentication
    if grep -q "^PubkeyAuthentication " "${SSH_CONFIG}"; then
        current_pubkey_authentication=$(grep "^PubkeyAuthentication " "${SSH_CONFIG}" | awk '{print $2}')
        if [[ "$current_pubkey_authentication" != "${YES_NO}" ]]; then
            _info "PubkeyAuthentication 当前设置为: $current_pubkey_authentication，正在修改为 ${YES_NO}..."
            sed -i.bak "s/^PubkeyAuthentication .*/PubkeyAuthentication ${YES_NO}/" "${SSH_CONFIG}"
            _info "PubkeyAuthentication 已设置为: ${YES_NO}"
        else
            _info "PubkeyAuthentication 已设置为: ${YES_NO}，无需修改。"
        fi
    else
        _info "未找到 PubkeyAuthentication 设置，正在添加..."
        echo "PubkeyAuthentication ${YES_NO}" >>"${SSH_CONFIG}"
        _info "已添加 PubkeyAuthentication 设置为: ${YES_NO}"
    fi
    if ! systemctl restart sshd.service &>/dev/null && ! systemctl restart ssh.service &>/dev/null; then
        _warn "重启 SSH 服务失败，请检查!"
    fi

    # 检查 AuthorizedKeysFile
    if grep -q "^AuthorizedKeysFile " "${SSH_CONFIG}"; then
        _info "当前 AuthorizedKeysFile 设置为: $(grep "^AuthorizedKeysFile " "${SSH_CONFIG}")"
    else
        _info "未找到 AuthorizedKeysFile 设置，默认为 .ssh/authorized_keys"
    fi

    read -rp "是否设置 SSH AuthorizedKeysFile?[Y/n](q退出):" is_set_authorized_keys_file
    [[ ${is_set_authorized_keys_file} == [Qq] ]] && return
    is_set_authorized_keys_file=${is_set_authorized_keys_file:-Y}
    if [[ ${is_set_authorized_keys_file} == [Yy] ]]; then
        # 检查并修改 AuthorizedKeysFile
        if grep -q "^AuthorizedKeysFile " "${SSH_CONFIG}"; then
            current_authorized_keys_file=$(grep "^AuthorizedKeysFile " "${SSH_CONFIG}" | awk '{print $2}')
            if [[ "$current_authorized_keys_file" != ".ssh/authorized_keys" ]]; then
                _info "AuthorizedKeysFile 当前设置为: $current_authorized_keys_file，正在修改为 .ssh/authorized_keys..."
                sed -i.bak "s/^AuthorizedKeysFile .*/AuthorizedKeysFile .ssh/authorized_keys/" "${SSH_CONFIG}"
                _info "AuthorizedKeysFile 已设置为: .ssh/authorized_keys"
            else
                _info "AuthorizedKeysFile 已设置为: .ssh/authorized_keys，无需修改。"
            fi
        else
            _info "未找到 AuthorizedKeysFile 设置，正在添加..."
            echo "AuthorizedKeysFile .ssh/authorized_keys" >>"${SSH_CONFIG}"
            _info "已添加 AuthorizedKeysFile 设置为: .ssh/authorized_keys"
        fi
        if ! systemctl restart sshd.service &>/dev/null && ! systemctl restart ssh.service &>/dev/null; then
            _warn "重启 SSH 服务失败，请检查!"
        fi
    else
        _info "已取消..."
    fi

    _info "SSH 配置已完成。"
}

view_system_proxy() {
    _info "read ${ETC_PROFILE} proxy config..."
    grep "http_proxy\|https_proxy\|ftp_proxy" "${ETC_PROFILE}" && echo
}

open_sysstem_proxy() {

    proxy_address="$1"
    proxy_protocol="${2}_proxy"

    # # 检查是否已有 proxy 设置（包括被注释掉的情况）
    # if grep -q "export ${proxy_protocol}=${proxy_address}" "${ETC_PROFILE}"; then
    #     # 如果存在代理设置，去掉注释符号
    #     sed -i "s|^#*\(export ${proxy_protocol}=${proxy_address}.*\)|\1|" "${ETC_PROFILE}"
    #     # 更新代理地址
    #     sed -i "s|^export ${proxy_protocol}=${proxy_address}.*|export ${proxy_protocol}=${proxy_address}|" "${ETC_PROFILE}"
    # fi

    sed -i "/export ${proxy_protocol}=/d" "${ETC_PROFILE}"

    # sed -i "/^unset ${proxy_protocol}/s/^/#/" "${ETC_PROFILE}"
    sed -i "/unset ${proxy_protocol}/d" "${ETC_PROFILE}"

    # 添加新的设置
    echo "export ${proxy_protocol}=${proxy_address}" >>"${ETC_PROFILE}"

    _info "open ${proxy_protocol} success."
}

close_system_proxy() {

    proxy_protocol="${1}_proxy"

    # sed -i "/^export ${proxy_protocol}/s/^/#/" "${ETC_PROFILE}"

    # # 检查是否已有 unset 设置（包括被注释掉的情况）
    # if grep -q "unset ${proxy_protocol}" "${ETC_PROFILE}"; then
    #     # 如果存在 unset 设置，去掉注释符号
    #     sed -i "s|^#*\(unset ${proxy_protocol}.*\)|\1|" "${ETC_PROFILE}"
    # else
    #     # 如果没有 unset 设置，添加新的设置
    #     echo "unset ${proxy_protocol}" >>"${ETC_PROFILE}"
    # fi

    sed -i "/export ${proxy_protocol}=/d" "${ETC_PROFILE}"

    # sed -i "/^unset ${proxy_protocol}/s/^/#/" "${ETC_PROFILE}"
    sed -i "/unset ${proxy_protocol}/d" "${ETC_PROFILE}"

    # 添加新的设置
    echo "unset ${proxy_protocol}" >>"${ETC_PROFILE}"

    _info "close ${proxy_protocol} success."
}

do_system_proxy() {
    proxy_action="$1"

    if [[ "${proxy_action}" == "on" ]]; then
        _info "open ${ETC_PROFILE} proxy config..."
        read -rp "proxy address (eg: [http://127.0.0.1:10809] or [socks5://127.0.0.1:10808] )(q退出):" proxy_address
        [[ "${proxy_address}" == [Qq] ]] && return
        open_sysstem_proxy "${proxy_address}" "http"
        open_sysstem_proxy "${proxy_address}" "https"
        open_sysstem_proxy "${proxy_address}" "ftp"
        # echo "http_proxy=http://127.0.0.1:7890" >>"${ETC_PROFILE}"
        # echo "https_proxy=http://127.0.0.1:7890" >>"${ETC_PROFILE}"
        # echo "ftp_proxy=http://127.0.0.1:7890" >>"${ETC_PROFILE}"
    elif [[ "${proxy_action}" == "off" ]]; then
        close_system_proxy "http"
        close_system_proxy "https"
        close_system_proxy "ftp"
        # _info "删除 ${ETC_PROFILE} 全局代理配置..."
        # sed -i '/http_proxy/d' "${ETC_PROFILE}"
        # sed -i '/https_proxy/d' "${ETC_PROFILE}"
        # sed -i '/ftp_proxy/d' "${ETC_PROFILE}"
    else
        _warn "不支持的操作:${proxy_action}"
    fi

    # shellcheck disable=SC1090
    source "${ETC_PROFILE}"
    _warn "如果不能自动生效（使用 source 运行此脚本才会自动生效），请手动执行:source ${ETC_PROFILE}"

}

config_system_proxy() {

    while true; do
        [[ true = "${is_close}" ]] && break
        echo
        echoEnhance gray "========================================="
        echoEnhance blue "config system proxy"
        echoEnhance gray "========================================="
        echoEnhance silver "1. view system proxy status"
        echoEnhance silver "2. open system proxy"
        echoEnhance silver "3. close system proxy"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance cyan "0. 返回上级菜单"
        echoEnhance gray "========================================="

        read -rp "请输入序号:" num
        case "${num}" in
        1)
            view_system_proxy
            ;;
        2)
            do_system_proxy "on"
            ;;
        3)
            do_system_proxy "off"
            ;;
        0)
            break
            ;;
        *)
            _warn "输入错误数字:${num}，请重新输入 ！"
            ;;
        esac

    done

}

check_firewalld() {

    # 检查 firewalld 是否存在
    if ! command -v firewall-cmd &>/dev/null; then
        _info "firewalld 未安装，正在尝试安装..."
        ${installPackage} firewalld
    fi

    # 检查 firewalld 是否正在运行
    if ! systemctl is-active --quiet firewalld; then
        systemctl start firewalld
    fi

    # 检查 firewalld 是否已启用
    if ! systemctl is-enabled firewalld &>/dev/null; then
        if systemctl enable firewalld &>/dev/null; then
            _info "firewalld service already enabled."
        else
            _warn "enable firewalld service failed. please check."
        fi
    fi

    if systemctl is-active --quiet firewalld; then
        local read_config_ssh_port
        read_config_ssh_port=$(grep "^Port " "${SSH_CONFIG}" | awk '{print $2}')

        if ! firewall-cmd --zone=public --query-port="${read_config_ssh_port}"/tcp &>/dev/null; then
            _info "默认自动打开 SSH 端口：${read_config_ssh_port}"
            firewall-cmd --zone=public --add-port="${read_config_ssh_port}"/tcp --permanent
            firewall-cmd --reload
            _info "当前已打开端口：$(firewall-cmd --list-ports)."
        fi
    fi

}

open_firewalld_port() {

    if systemctl list-unit-files | grep -q "iptables"; then
        _info "停用 iptables，有时会影响 firewalld 启动."
        if systemctl is-active iptables &>/dev/null; then
            systemctl stop iptables
        fi
        systemctl disable iptables
    fi

    _info "当前已打开端口：$(firewall-cmd --list-ports)."

    read -rp "请输入需要打开的端口号(q退出):" open_port
    [[ "${open_port}" == [Qq] ]] && return
    if [[ ! "${open_port}" =~ ^[0-9]+$ || "$open_port" -le 0 || "$open_port" -gt 65535 ]]; then
        _warn "输入了错误的端口号：[ ${open_port} ]"
    else
        firewall-cmd --zone=public --add-port="${open_port}"/tcp --permanent
        firewall-cmd --reload
        _info "当前已打开端口：$(firewall-cmd --list-ports)."
    fi

}

close_firewalld_port() {

    _info "当前已打开端口：$(firewall-cmd --list-ports)."

    read -rp "请输入需要关闭的端口号(q退出):" close_port
    [[ "${close_port}" == [Qq] ]] && return
    if [[ ! "${close_port}" =~ ^[0-9]+$ || "$close_port" -le 0 || "$close_port" -gt 65535 ]]; then
        _warn "输入了错误的端口号：[ ${close_port} ]"
    else
        firewall-cmd --zone=public --remove-port="${close_port}"/tcp --permanent
        firewall-cmd --reload
        _info "当前已打开端口：$(firewall-cmd --list-ports)."
    fi

}

view_firewalld_status() {

    if systemctl list-unit-files | grep -q "firewalld"; then
        systemctl status firewalld
    fi

    echo
    _info "当前已打开端口：[ $(firewall-cmd --list-ports) ]"

}

config_firewalld() {

    check_firewalld

    while true; do
        [[ true = "${is_close}" ]] && break
        echo
        echoEnhance gray "========================================="
        echoEnhance blue "设置 firewalld"

        if systemctl is-active --quiet firewalld; then
            if command -v firewall-cmd &>/dev/null; then
                echoEnhance green "当前已打开端口：[ $(firewall-cmd --list-ports) ]"
            fi
        fi

        echoEnhance gray "========================================="
        echoEnhance silver "1. 打开防火墙端口"
        echoEnhance silver "2. 关闭防火墙端口"
        echoEnhance silver "3. 查看防火墙状态"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance cyan "0. 返回上级菜单"
        echoEnhance gray "========================================="

        read -rp "请输入序号:" num
        case "${num}" in
        1)
            open_firewalld_port
            ;;
        2)
            close_firewalld_port
            ;;
        3)
            view_firewalld_status
            ;;
        0)
            break
            ;;
        *)
            _warn "输入错误数字:${num}，请重新输入 ！"
            ;;
        esac

    done
}

install_ntp_chrony() {

    # 检查 chrony 是否存在
    if ! command -v chronyd &>/dev/null; then
        _info "chrony 未安装，正在尝试安装..."
        ${installPackage} chrony
    fi

    # 检查 chrony 是否正在运行
    if ! systemctl is-active --quiet chronyd; then
        systemctl start chronyd
    fi

    # 检查 chrony 是否已启用
    if ! systemctl is-enabled chronyd &>/dev/null; then
        if systemctl enable chronyd &>/dev/null; then
            _info "chrony service already enabled."
        else
            _warn "enable chrony service failed. please check."
        fi
    fi

    ntp_ali=$(sed -n "/^server ntp.aliyun.com/p" /etc/chrony.conf)
    if [[ -z "$ntp_ali" ]]; then
        _info "开始修 NTP chrony 改配置..."
        sed -i 's/^pool/#pool/g' /etc/chrony.conf
        sed -i 's/^server/#server/g' /etc/chrony.conf
        cat >>/etc/chrony.conf <<EOF
# Start custom config
# add time server address
server ntp.aliyun.com iburst
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server ntp3.aliyun.com iburst
server ntp4.aliyun.com iburst
server ntp5.aliyun.com iburst
server ntp6.aliyun.com iburst
server ntp7.aliyun.com iburst
# End custom config
EOF
    else
        _info "NTP chrony 配置不用修改."
    fi

    systemctl restart chronyd
    timedatectl set-timezone Asia/Shanghai
    chronyc sourcestats -v
    chronyc -a makestep
    sleep 2s
    timedatectl

}

view_ntp_chrony() {

    if command -v chronyd &>/dev/null; then
        systemctl status chronyd
        chronyc sourcestats -v
        chronyc -a makestep
        sleep 2s
        timedatectl
    else
        install_ntp_chrony
    fi

}

config_ntp_chrony() {

    echo
    echoEnhance gray "========================================="
    echoEnhance blue "设置 NTP chrony"
    echoEnhance gray "========================================="
    echoEnhance silver "1. 安装 NTP chrony"
    echoEnhance silver "2. 查看并同步 NTP chrony"
    echoEnhance gray "———————————————————————————————————"
    echoEnhance cyan "0. 返回上级菜单"
    echoEnhance gray "========================================="

    read -rp "请输入序号:" num
    case "${num}" in
    1)
        install_ntp_chrony
        ;;
    2)
        view_ntp_chrony
        ;;
    0) ;;
    *)
        _warn "输入错误数字:${num} ！"
        ;;
    esac

}

check_python() {

    # 检查 Python 是否安装
    if command -v python3 &>/dev/null; then
        # 获取 Python 版本
        version=$(python3 --version 2>&1 | awk '{print $2}')
        _info "已安装的 Python 版本: $version"

        # 比较版本
        # if [[ $(echo "$version < 3.9.9" | bc -l) -eq 1 ]]; then
        # if [[ $(printf '%s\n' "$version" "3.9.9" | sort -V | head -n1) == "$version" ]]; then
        # if [[ "$version" < "3.9.9" ]]; then
        if printf "%s\n%s" "$version" "3.9.9" | sort -V | head -n 1 | grep -q "^$version$"; then
            _info "Python 版本小于 3.9.9，需要安装高版本 Python。"
            return 1
        else
            _info "Python 版本满足要求。"
            return 0
        fi
    else
        _info "未安装 Python。需要安装高版本 Python。"
        return 1
    fi

}

config_python() {

    if check_python; then
        _info "Python 无需安装。"
        return
    fi

    # 询问需要安装的版本号，默认 3.9.9
    read -rp "请输入要安装的 Python 版本号 (默认 3.9.9): " version_to_install
    version_to_install=${version_to_install:-3.9.9}

    # 下载和安装指定的 Python 版本
    _info "正在安装 Python $version_to_install ..."

    case "${osInfo[ID]}" in
    debian | ubuntu)
        ${updatePackage}
        ${installPackage} software-properties-common
        ${installPackage} "python${version_to_install}"
        ;;
    centos)
        ${updatePackage}
        ${installPackage} epel-release
        ${installPackage} "python${version_to_install}"
        ;;
    *) ;;
    esac

    if check_python; then
        return
    fi

    _info "开始下载源码，编译安装 Python $version_to_install ..."

    # 设置安装目录
    install_dir="/usr/local"

    # 安装必要的依赖
    case "${osInfo[ID]}" in
    debian | ubuntu)
        ${updatePackage}
        ${installPackage} build-essential libssl-dev libbz2-dev libffi-dev \
            libgdbm-dev liblzma-dev libncurses5-dev libsqlite3-dev \
            libreadline-dev libtk8.6-dev zlib1g-dev wget
        ;;
    centos)
        ${updatePackage}
        ${installPackage} gcc make openssl-devel bzip2-devel \
            libffi-devel zlib-devel wget
        ;;
    *) ;;
    esac

    # 下载指定版本的 Python 源码
    _info "正在下载 Python $version_to_install 源码..."

    wget "https://www.python.org/ftp/python/$version_to_install/Python-$version_to_install.tgz"

    if [[ ! -e "Python-$version_to_install.tgz" ]]; then
        _warn "Python-$version_to_install.tgz 官方源下载失败！"
        return
    else
        # 解压源码包
        _info "正在解压源码包..."
        tar -xzf "Python-$version_to_install.tgz"
        if ! cd "Python-$version_to_install"; then
            _warn "Failed to change directory to Python-$version_to_install"
            return
        fi

        # 编译和安装
        echo "正在编译和安装 Python $version_to_install ..."
        ./configure --enable-optimizations --prefix=$install_dir
        make -j"$(nproc)"
        sudo make altinstall

        # 清理临时文件
        cd ..
        rm -rf "Python-$version_to_install" "Python-$version_to_install.tgz"

    fi

    # 检查是否安装成功
    if check_python; then
        _info "Python $version_to_install 安装成功!"
    else
        _warn "Python $version_to_install 安装失败!"
    fi

}

check_fail2ban() {

    if ! command -v fail2ban-client &>/dev/null; then
        return 1
    fi

    return 0
}

install_fail2ban() {

    if ! check_fail2ban; then

        if ! check_python; then
            return
        fi

        # 安装必要的依赖
        ${installPackage} python3-setuptools python3-systemd

        _info "尝试安装 Fail2Ban..."

        if [ ! -d "${FAIL2BAN_DIR}" ]; then
            if git clone https://github.com/fail2ban/fail2ban.git "${FAIL2BAN_DIR}"; then
                if ! pushd "${FAIL2BAN_DIR}"; then
                    _warn "进入目录 ${FAIL2BAN_DIR} 失败!"
                    return
                fi

                _info "正在编译安装 Fail2Ban..."
                python3 setup.py install

                if ! popd; then
                    _error "切换回目录失败,请检查!"
                    return
                fi

                _info "配置 Fail2Ban 启动服务:fail2ban.service" && echo
                cp "${FAIL2BAN_DIR}build/fail2ban.service" /etc/systemd/system/fail2ban.service

                # site_packages=$(python3 -c "import site; import os; print('\n'.join([p for p in site.getsitepackages() if os.path.isdir(os.path.join(p, 'fail2ban'))]))")
                site_packages=$(python3 -c "import site; import os; print(next((p for p in site.getsitepackages() if os.path.isdir(os.path.join(p, 'fail2ban'))), ''))")

                # 判断 site_packages 是否不为空，如果为空则不设置环境变量
                if [ -n "$site_packages" ]; then
                    sed -i "/^ExecStartPre/i Environment=\"PYTHONPATH=${site_packages}/\"" /etc/systemd/system/fail2ban.service
                else
                    _warn "PYTHONPATH 未设置，找不到 /python3.*/site-packages/fail2ban/ 目录，请确认 fail2ban 是否安装正确。"
                fi

                # f2b_con=$(sed -n "/^ExecStart=/p" "${FAIL2BAN_DIR}build/fail2ban.service" | awk -F"=" '{ print $2 }')
                # f2b_path=${f2b_con%/*}
                # ln -fs "${f2b_path}/fail2ban-server" /usr/bin/fail2ban-server
                # ln -fs "${f2b_path}/fail2ban-client" /usr/bin/fail2ban-client

                _warn "Fail2Ban 安装完成!首次运行前需要修改配置才能正常使用。"
            else
                _warn "git clone Fail2Ban 官方源下载失败！"
                _warn "请检查网络，或地址:https://github.com/fail2ban/fail2ban.git"
                if [ -d "${FAIL2BAN_DIR}" ]; then
                    rm -rf "${FAIL2BAN_DIR}"
                fi
                return
            fi
        else
            update_fail2ban
        fi
    fi

    JAIL_FILE="/etc/fail2ban/jail.local"
    # if [ -f "$JAIL_FILE" ]; then
    #     return
    # fi

    # 询问是否修改 Fail2Ban 配置
    read -rp "Fail2Ban 已安装，是否修改配置(Y/n):" yn
    yn=${yn:-Y}
    if [[ ${yn} == [Yy] ]]; then

        local read_config_ssh_port
        read_config_ssh_port=$(grep "^Port " "${SSH_CONFIG}" | awk '{print $2}')

        read -rp "请输入 SSH 端口号(SSH 端口号:${read_config_ssh_port})(q退出):" port
        [[ $port == "exit" || $port == [Qq] ]] && return
        port=${port:-${read_config_ssh_port}}
        if [[ ! "${port}" =~ ^[0-9]+$ || "$port" -le 0 || "$port" -gt 65535 ]]; then
            _warn "输入了错误的端口:${port}" && echo
            return
        else
            _info "写入 Fail2Ban 配置文件:${JAIL_FILE}"
            echo "[sshd]
enabled = true
port    = ${port}
bantime = 365d
findtime= 365d
logpath =/var/log/secure
maxretry = 2
backend = systemd
" >"${JAIL_FILE}"

            systemctl daemon-reload
            systemctl enable fail2ban
            systemctl restart fail2ban
            # systemctl restart rsyslog
        fi
    else
        _info "已取消 Fail2Ban 配置..."
    fi

}

view_fail2ban() {

    systemctl status fail2ban

    if check_fail2ban; then
        fail2ban-client status sshd
    fi

}

# 定义函数来校验IP地址格式是否符合规范
validate_ip_address() {
    local ip_address="$1"

    # 使用正则表达式校验IP地址格式是否符合规范
    if [[ $ip_address =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # 对IP地址进行拆分
        IFS='.' read -r -a ip_parts <<<"$ip_address"

        # 判断每个数字是否在0-255之间
        valid_ip=true
        for ip_part in "${ip_parts[@]}"; do
            if ((ip_part < 0 || ip_part > 255)); then
                valid_ip=false
                break
            fi
        done

        # 输出结果
        if [ $valid_ip == true ]; then
            _info "IP地址 $ip_address 符合规范."
            return 0 # 返回0表示IP地址符合规范
        else
            _warn "$IP地址 $ip_address 不符合规范!"
            return 1 # 返回1表示IP地址不符合规范
        fi
    else
        _warn "IP地址 $ip_address 不符合规范!"
        return 1 # 返回1表示IP地址不符合规范
    fi
}

unlock_fail2ban() {

    if ! check_fail2ban; then
        _warn "Fail2Ban 未安装，无法解锁。"
    else

        read -rp "请输入要解锁的IP地址(q退出):" IPADDRESS
        [[ $IPADDRESS == "exit" || $IPADDRESS == [Qq] ]] && return
        if (validate_ip_address "${IPADDRESS}"); then
            if ! systemctl is-active fail2ban &>/dev/null; then
                _info "开始启动 fail2ban ......"
                systemctl start fail2ban
            fi

            _info "解封 IP:${IPADDRESS}"
            fail2ban-client set sshd unbanip "${IPADDRESS}"
        else
            _info "已取消操作..."
        fi

    fi
}

update_fail2ban() {

    if ! check_fail2ban; then
        _warn "Fail2Ban 未安装，无法更新。"
    else
        if [ ! -d "${FAIL2BAN_DIR}" ]; then
            _warn "找不到 Fail2Ban 目录，无法更新。"
        else
            # pushd "${FAIL2BAN_DIR}" || _warn "进入目录 ${FAIL2BAN_DIR} 失败!" && return
            if ! pushd "${FAIL2BAN_DIR}"; then
                _warn "进入目录 ${FAIL2BAN_DIR} 失败!"
                return
            fi

            BRANCH=master
            LOCAL=$(git log $BRANCH -n 1 --pretty=format:"%H")
            REMOTE=$(git log remotes/origin/$BRANCH -n 1 --pretty=format:"%H")
            if [ "$LOCAL" = "$REMOTE" ]; then
                _info "Fail2Ban 已安装最新，不需要更新."
            else
                systemctl stop fail2ban

                git pull --recurse-submodules
                # git submodule update --init --recursive
                python3 setup.py install

                systemctl start fail2ban
                systemctl enable fail2ban
                _info "Fail2Ban 更新完成，已重新启动."
            fi

            if ! popd; then
                _error "切换回目录失败,请检查!"
            fi

        fi
    fi
}

config_fail2ban() {

    while true; do
        [[ true = "${is_close}" ]] && break
        echo
        echoEnhance gray "========================================="
        echoEnhance blue "设置 Fail2Ban"
        echoEnhance gray "========================================="
        echoEnhance silver "1. 安装设置 Fail2Ban"
        echoEnhance silver "2. 查看 Fail2Ban SSH 状态"
        echoEnhance silver "3. Fail2Ban 解封IP地址"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance silver "4. 更新 Fail2Ban"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance cyan "0. 返回上级菜单"
        echoEnhance gray "========================================="

        read -rp "请输入序号:" num
        case "${num}" in
        1)
            install_fail2ban
            ;;
        2)
            view_fail2ban
            ;;
        3)
            unlock_fail2ban
            ;;
        4)
            update_fail2ban
            ;;
        0)
            break
            ;;
        *)
            _warn "输入错误数字:${num} ！"
            ;;
        esac

    done

}

system_config() {

    while true; do
        [[ true = "${is_close}" ]] && break
        echo
        echoEnhance gray "========================================="
        echoEnhance blue "操作系统配置"
        echoEnhance gray "========================================="
        echoEnhance silver "1. 设置 swap 交换分区"
        echoEnhance silver "2. 设置 repo 源"
        echoEnhance silver "3. 更新系统，安装常用工具"
        echoEnhance silver "4. 取消 SELinux"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance silver "5. 设置 SSH"
        echoEnhance silver "6. 设置 firewalld"
        echoEnhance silver "7. 设置 NTP chrony"
        echoEnhance silver "8. 设置 Python3"
        echoEnhance silver "9. 设置 Fail2Ban"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance silver "66. config system proxy"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance cyan "0. 返回上级菜单"
        echoEnhance gray "========================================="

        read -rp "请输入序号:" num
        case "${num}" in
        1)
            config_swapfile
            ;;
        2)
            config_repo
            ;;
        3)
            init_system
            ;;
        4)
            disable_SELinux
            ;;
        5)
            config_ssh
            ;;
        6)
            config_firewalld
            ;;
        7)
            config_ntp_chrony
            ;;
        8)
            config_python
            ;;
        9)
            config_fail2ban
            ;;
        66)
            config_system_proxy
            ;;
        0)
            break
            ;;
        *)
            _warn "输入错误数字:${num}，请重新输入 ！"
            ;;
        esac
    done
}

check_kms_server() {

    # if ! command -v $KMS_SERVER_FILE &>/dev/null; then
    #     return 1
    # fi

    if [ -f "${KMS_SERVER_FILE}" ]; then
        _info "KMS Server 已安装！"
        return 0
    fi

    return 1

}

start_kms_server() {

    if ! check_kms_server; then
        _warn "未安装 KMS Server！"
        return 1
    fi

    _info "开始启动 KMS Server ..."
    systemctl start vlmcsd
    sleep 3s
    _info "KMS Server 启动完成 ！"

}

stop_kms_server() {

    if ! check_kms_server; then
        _warn "未安装 KMS Server！"
        return 1
    fi

    _info "开始停止 KMS Server ..."
    systemctl stop vlmcsd
    sleep 3s
    _info "KMS Server 停止完成 ！"

}

restart_kms_server() {

    if ! check_kms_server; then
        _warn "未安装 KMS Server！"
        return 1
    fi

    _info "开始重启 KMS Server ..."
    systemctl restart vlmcsd
    sleep 3s
    _info "KMS Server 重启完成 ！"

}

check_kms_new_version() {

    if ! command -v jq &>/dev/null; then
        ${installPackage} jq
    fi

    kms_new_version=$(curl -s https://api.github.com/repos/Wind4/vlmcsd/releases | jq -r '.[] | select(.prerelease == false and .draft == false) | .tag_name' | head -n 1)
    if [[ -z ${kms_new_version} ]]; then
        _warn "检测 KMS Server 最新版本失败!"
        return 1
    fi

    _info "检测到 KMS Server 最新版本为 [ ${kms_new_version} ]"
    return 0
}

official_kms_download() {

    _info "开始下载官方 KMS Server ..."
    wget --no-check-certificate -N "https://github.com/Wind4/vlmcsd/releases/download/${kms_new_version}/binaries.tar.gz"
    if [[ ! -e "binaries.tar.gz" ]]; then
        _warn "KMS Server 官方源下载失败！"
        return 1
    else
        tar -xvf "binaries.tar.gz"
    fi

    vlmcsd_x64_file="./binaries/Linux/intel/static/vlmcsd-x64-musl-static"
    if [[ ! -e "${vlmcsd_x64_file}" ]]; then
        _warn "找不到 vlmcsd-x64-musl-static 文件！"
        _warn "KMS Server 安装失败 !"
        return 1
    else
        cp "${vlmcsd_x64_file}" "${KMS_SERVER_FILE}"
        chmod +x "${KMS_SERVER_FILE}"
        rm -f binaries.tar.gz
        rm -rf binaries floppy
        echo "${kms_new_version}" >"${KMS_SERVER_CURRENT_VERSION}"

        _info "KMS Server 主程序下载安装完毕！"
        return 0
    fi
}

config_kms_service() {

    read -rp "请输入 KMS Server 端口号(默认:1688):" kms_port
    kms_port=${kms_port:-1688}
    if [[ ! "${kms_port}" =~ ^[0-9]+$ || "$kms_port" -le 100 || "$kms_port" -gt 65535 ]]; then
        _warn "输入了错误的端口:${kms_port}, 使用默认端口 1688"
        kms_port=1688
    fi

    _info "检查防火墙，需要打开防火墙端口:${kms_port}"
    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --zone=public --add-port="${kms_port}"/tcp --permanent
        firewall-cmd --reload
        _info "防火墙端口:${kms_port} 打开成功！"
    fi

    echo "" >"${KMS_SERVER_PID}"
    echo "[Unit]
Description=KMS Server By vlmcsd
After=syslog.target network.target

[Service]
Type=forking
PIDFile=${KMS_SERVER_PID}
ExecStart=${KMS_SERVER_FILE} -P${kms_port} -p ${KMS_SERVER_PID}
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
" >"${VLMCSD_SERVICE_FILE}"

    systemctl daemon-reload
    systemctl enable vlmcsd
    _info "KMS Server 服务配置完成！"

}

install_kms_server() {

    if ! check_kms_server; then

        if ! check_kms_new_version; then
            _info "已取消 KMS Server 安装"
            return 1
        fi

        _info "开始安装 KMS Server"
        if ! official_kms_download; then
            _warn "已取消 KMS Server 安装"
            return 1
        fi

        _info "开始配置 KMS Server 服务..."
        config_kms_service

        start_kms_server

    else
        _info "KMS Server 已安装"
    fi
}

update_kms_server() {

    if ! check_kms_server; then
        _warn "未安装 KMS Server！"
        return 1
    fi

    if ! check_kms_new_version; then
        _info "已取消 KMS Server 更新"
        return 1
    fi

    now_kms_ver=$(cat ${KMS_SERVER_CURRENT_VERSION})
    if [[ "${kms_new_version}" == "${now_kms_ver}" ]]; then
        _info "KMS Server 已是最新版本！"
        return 1
    fi

    _info "发现 KMS Server 已有新版本 [ ${kms_new_version} ]，当前版本 [ ${now_kms_ver} ]"
    read -rp "是否更新 ？ [Y/n]：" yn
    yn=${yn:-y}
    if [[ $yn == [Yy] ]]; then

        # 检查 KMS Server 服务是否存在
        if ! systemctl list-unit-files | grep -q "vlmcsd"; then
            _warn "KMS Server 服务不存在！"
            config_kms_service
        fi

        # 检查 KMS Server 进程状态
        if systemctl is-active vlmcsd &>/dev/null; then
            systemctl stop vlmcsd
        fi

        if ! official_kms_download; then
            _warn "已取消 KMS Server 安装"
            return 1
        fi

        sleep 3s
        restart_kms_server
        _info "KMS Server 更新完成！"

    else
        _info "已取消 KMS Server 更新"
    fi

}

uninstall_kms_server() {

    if ! check_kms_server; then
        _warn "未安装 KMS Server！"
        return 1
    fi

    read -rp "是否卸载 KMS Server ？ [Y/n] :" yn
    yn=${yn:-y}
    if [[ $yn == [Yy] ]]; then

        _info "开始卸载 KMS Server ..."

        if systemctl is-enabled vlmcsd &>/dev/null; then
            systemctl disable vlmcsd
        fi

        # 检查 KMS Server 进程状态
        if systemctl is-active vlmcsd &>/dev/null; then
            systemctl stop vlmcsd
        fi

        rm -f "${KMS_SERVER_FILE}"
        rm -f "${VLMCSD_SERVICE_FILE}"
        rm -f "${KMS_SERVER_PID}"
        rm -f "${KMS_SERVER_CURRENT_VERSION}"
        _info "KMS Server 卸载完成！"

    else
        _info "已取消 KMS Server 卸载"
    fi

}

view_kms_server_config() {

    _info "KMS Server service:${VLMCSD_SERVICE_FILE}"
    if [ -f "${VLMCSD_SERVICE_FILE}" ]; then
        cat ${VLMCSD_SERVICE_FILE}
    fi

}

view_kms_server_status() {

    # 检查 KMS Server 服务是否存在
    if systemctl list-unit-files | grep -q "vlmcsd"; then
        systemctl status vlmcsd
    else
        _warn "KMS Server 服务不存在！"
    fi

}

config_kms_server() {
    while true; do
        [[ true = "${is_close}" ]] && break
        echo
        echoEnhance gray "========================================="
        echoEnhance blue "配置管理 KMS Server"

        if [ -f "${KMS_SERVER_CURRENT_VERSION}" ]; then
            now_kms_ver=$(cat ${KMS_SERVER_CURRENT_VERSION})
            if [ -n "${now_kms_ver}" ]; then
                echoEnhance green "当前 KMS Server 版本：${now_kms_ver}"
            fi
        fi

        echoEnhance gray "========================================="
        echoEnhance silver "1. 安装 KMS Server"
        echoEnhance silver "2. 更新 KMS Server"
        echoEnhance silver "3. 卸载 KMS Server"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance silver "4. 查看 KMS Server 配置"
        echoEnhance silver "5. 查看 KMS Server 状态"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance silver "6. 启动 KMS Server"
        echoEnhance silver "7. 停止 KMS Server"
        echoEnhance silver "8. 重启 KMS Server"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance cyan "0. 返回上级菜单"
        echoEnhance gray "========================================="

        read -rp "请输入序号:" num
        case "${num}" in
        1)
            install_kms_server
            ;;
        2)
            update_kms_server
            ;;
        3)
            uninstall_kms_server
            ;;
        4)
            view_kms_server_config
            ;;
        5)
            view_kms_server_status
            ;;
        6)
            start_kms_server
            ;;
        7)
            stop_kms_server
            ;;
        8)
            restart_kms_server
            ;;
        0)
            break
            ;;
        *)
            _warn "输入错误数字:${num}，请重新输入 ！"
            ;;
        esac

    done

}

function _print_list() {
    local p_list=("$@")
    for ((i = 1; i <= ${#p_list[@]}; i++)); do
        hint="${p_list[$i - 1]}"
        echo -e "${GREEN}${i}${NC}) ${hint}"
    done
}

function _is_digit() {
    local input=${1}
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

function _is_tlsv1_3_h2() {

    local check_url
    check_url=$(echo "$1" | grep -oE '[^/]+(\.[^/]+)+\b' | head -n 1)

    local check_num
    check_num=$(echo QUIT | stdbuf -oL openssl s_client -connect "${check_url}:443" -tls1_3 -alpn h2 2>&1 | grep -Eoi '(TLSv1.3)|(^ALPN\s+protocol:\s+h2$)|(X25519)' | sort -u | wc -l)
    if [[ ${check_num} -eq 3 ]]; then
        return 0
    else
        return 1
    fi

}

function _version_ge() {
    test "$(echo "$@" | tr ' ' '\n' | sort -rV | head -n 1)" == "$1"
}

function select_data() {
    # shellcheck disable=SC2207
    local data_list=($(awk -v FS=',' '{for (i=1; i<=NF; i++) arr[i]=$i} END{for (i in arr) print arr[i]}' <<<"${1}"))
    # shellcheck disable=SC2207
    local index_list=($(awk -v FS=',' '{for (i=1; i<=NF; i++) arr[i]=$i} END{for (i in arr) print arr[i]}' <<<"${2}"))
    local result_list=()
    if [[ ${#index_list[@]} -ne 0 ]]; then
        for i in "${index_list[@]}"; do
            if _is_digit "${i}" && [ "${i}" -ge 1 ] && [ "${i}" -le ${#data_list[@]} ]; then
                i=$((i - 1))
                result_list+=("${data_list[${i}]}")
            fi
        done
    else
        result_list=("${data_list[@]}")
    fi
    if [[ ${#result_list[@]} -eq 0 ]]; then
        result_list=("${data_list[@]}")
    fi
    echo "${result_list[@]}"
}

function read_port() {
    local prompt="${1}"
    local cur_port="${2}"
    until [[ ${is_port} =~ ^[Yy]$ ]]; do
        echo "${prompt}"
        read -rp "请输入自定义的端口(1-65535), 默认不修改: " new_port
        if [[ "${new_port}" == "" || ${new_port} -eq ${cur_port} ]]; then
            new_port=${cur_port}
            _info "不修改，继续使用原端口: ${cur_port}"
            break
        fi
        if ! _is_digit "${new_port}" || [[ ${new_port} -lt 1 || ${new_port} -gt 65535 ]]; then
            prompt="输入错误, 端口范围是 1-65535 之间的数字"
            continue
        fi
        read -rp "请确认端口: \"${new_port}\" [Y/n] " is_port
        is_port=${is_port:-y}
        prompt="${1}"
    done
}

function read_uuid() {
    _info '自定义输入的 uuid ，如果不是标准格式，将会使用 xray uuid -i "自定义字符串" 进行 UUIDv5 映射后填入配置'
    read -rp "请输入自定义 UUID, 默认则自动生成: " in_uuid
}

function read_domain() {
    until [[ ${is_domain} =~ ^[Yy]$ ]]; do
        read -rp "请输入域名：" domain
        check_domain=$(echo "${domain}" | grep -oE '[^/]+(\.[^/]+)+\b' | head -n 1)
        read -rp "请确认域名: \"${check_domain}\" [Y/n] " is_domain
        is_domain=${is_domain:-y}
    done
    domain_path=$(echo "${domain}" | sed -En "s|.*${check_domain}(/.*)?|\1|p")
    domain=${check_domain}
}

function select_dest() {

    local dest_list
    # shellcheck disable=SC2207
    dest_list=($(jq '.xray.serverNames | keys_unsorted' "${XRAY_COINFIG_PATH}config.json" | grep -Eoi '".*"' | sed -En 's|"(.*)"|\1|p'))
    # mapfile -t dest_list <<<"$(jq '.xray.serverNames | keys_unsorted' "${XRAY_COINFIG_PATH}config.json" | grep -Eoi '".*"' | sed -En 's|"(.*)"|\1|p')"

    local cur_dest
    cur_dest=$(jq -r '.xray.dest' "${XRAY_COINFIG_PATH}config.json")

    local pick_dest=""
    local all_sns=""
    local sns=""
    local is_dest=""

    local prompt="请选择你的 dest, 当前默认使用 \"${cur_dest}\", 自填选 0: "
    until [[ ${is_dest} =~ ^[Yy]$ ]]; do

        echo -e "---------------- dest 列表 -----------------"
        _print_list "${dest_list[@]}"

        read -rp "${prompt}" pick
        if [[ "${pick}" == "" && "${cur_dest}" != "" ]]; then
            pick_dest=${cur_dest}
            break
        fi

        if ! _is_digit "${pick}" || [[ "${pick}" -lt 0 || "${pick}" -gt ${#dest_list[@]} ]]; then
            prompt="输入错误, 请输入 0-${#dest_list[@]} 之间的数字: "
            continue
        fi

        if [[ "${pick}" == "0" ]]; then

            _warn "如果输入列表中已有域名将会导致 serverNames 被修改"
            _warn "使用自填域名时，请确保该域名在国内的连通性"
            read_domain

            _info "正在检查 \"${domain}\" 是否支持 TLSv1.3 与 h2"
            if ! _is_tlsv1_3_h2 "${domain}"; then
                _warn "\"${domain}\" 不支持 TLSv1.3 或 h2 ，亦或者 Client Hello 不是 X25519"
                continue
            fi
            _info "\"${domain}\" 支持 TLSv1.3 与 h2"

            _info "正在获取 Allowed domains"
            pick_dest=${domain}
            all_sns=$(xray tls ping "${pick_dest}" | sed -n '/with SNI/,$p' | sed -En 's/\[(.*)\]/\1/p' | sed -En 's/Allowed domains:\s*//p' | jq -R -c 'split(" ")' | jq --arg sni "${pick_dest}" '. += [$sni]')
            sns=$(echo "${all_sns}" | jq 'map(select(test("^[^*]+$"; "g")))' | jq -c 'map(select(test("^((?!cloudflare|akamaized|edgekey|edgesuite|cloudfront|azureedge|msecnd|edgecastcdn|fastly|googleusercontent|kxcdn|maxcdn|stackpathdns|stackpathcdn).)*$"; "ig")))')

            _info "过滤通配符前的 SNI"
            _print_list "$(echo "${all_sns}" | jq -r '.[]')"

            _info "过滤通配符后的 SNI"
            _print_list "$(echo "${sns}" | jq -r '.[]')"

            read -rp "请选择要使用的 serverName ，用英文逗号分隔， 默认全选: " pick_num
            sns=$(select_data "$(awk 'BEGIN{ORS=","} {print}' <<<"$(echo "${sns}" | jq -r -c '.[]')")" "${pick_num}" | jq -R -c 'split(" ")')

            _info "如果有更多的 serverNames 请在 ${XRAY_COINFIG_PATH}config.json 中自行编辑"
        else
            pick_dest="${dest_list[${pick} - 1]}"
        fi

        read -rp "是否使用 dest: \"${pick_dest}\" [Y/n] " is_dest
        is_dest=${is_dest:-y}
        prompt="请选择你的 dest, 当前默认使用 \"${cur_dest}\", 自填选 0: "
        echo -e "-------------------------------------------"

    done

    _info "正在修改配置"
    [[ "${domain_path}" != "" ]] && pick_dest="${pick_dest}${domain_path}"
    if echo "${pick_dest}" | grep -q '/$'; then
        pick_dest=$(echo "${pick_dest}" | sed -En 's|/+$||p')
    fi
    [[ "${sns}" != "" ]] && jq --argjson sn "{\"${pick_dest}\": ${sns}}" '.xray.serverNames += $sn' "${XRAY_COINFIG_PATH}config.json" >"${XRAY_COINFIG_PATH}new.json" && mv -f "${XRAY_COINFIG_PATH}new.json" "${XRAY_COINFIG_PATH}config.json"
    jq --arg dest "${pick_dest}" '.xray.dest = $dest' "${XRAY_COINFIG_PATH}config.json" >"${XRAY_COINFIG_PATH}new.json" && mv -f "${XRAY_COINFIG_PATH}new.json" "${XRAY_COINFIG_PATH}config.json"

}

install_update_xray() {

    _info "正在安装或更新 Xray ..."

    # 官方安装脚本安装 Xray
    # _error_detect "bash -c \"$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)\" @ install -u root"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root

    # 更新 Xray 版本号
    jq --arg ver "$(xray version | head -n 1 | cut -d \( -f 1 | grep -Eoi '[0-9.]*')" '.xray.version = $ver' "${XRAY_COINFIG_PATH}config.json" >"${XRAY_COINFIG_PATH}new.json" && mv -f "${XRAY_COINFIG_PATH}new.json" "${XRAY_COINFIG_PATH}config.json"

    # 更新 geoip geosite
    wget -O "${XRAY_COINFIG_PATH}update-dat.sh" https://raw.githubusercontent.com/faintx/public/main/tools/update-dat.sh
    chmod a+x "${XRAY_COINFIG_PATH}update-dat.sh"

    # 更新定时任务
    (
        crontab -l 2>/dev/null
        echo "30 05 * * * ${XRAY_COINFIG_PATH}update-dat.sh >/dev/null 2>&1"
    ) | awk '!x[$0]++' | crontab -

    _info "获取 geoip geosite 数据 ..."
    "${XRAY_COINFIG_PATH}update-dat.sh"

}

function config_xray() {

    _info "正在配置 xray config.json"
    "${XRAY_CONFIG_MANAGER}" --path "${HOME}/config.json" --download

    local xray_x25519
    xray_x25519=$(xray x25519)

    local xs_private_key
    xs_private_key=$(echo "${xray_x25519}" | head -1 | awk '{print $3}')

    local xs_public_key
    xs_public_key=$(echo "${xray_x25519}" | tail -n 1 | awk '{print $3}')

    # Xray-script config.json
    jq --arg privateKey "${xs_private_key}" '.xray.privateKey = $privateKey' "${XRAY_COINFIG_PATH}config.json" >"${XRAY_COINFIG_PATH}new.json" && mv -f "${XRAY_COINFIG_PATH}new.json" "${XRAY_COINFIG_PATH}config.json"
    jq --arg publicKey "${xs_public_key}" '.xray.publicKey = $publicKey' "${XRAY_COINFIG_PATH}config.json" >"${XRAY_COINFIG_PATH}new.json" && mv -f "${XRAY_COINFIG_PATH}new.json" "${XRAY_COINFIG_PATH}config.json"

    # Xray-core config.json
    "${XRAY_CONFIG_MANAGER}" --path "${HOME}/config.json" -p "${new_port}"
    "${XRAY_CONFIG_MANAGER}" --path "${HOME}/config.json" -u "${in_uuid}"
    "${XRAY_CONFIG_MANAGER}" --path "${HOME}/config.json" -d "$(jq -r '.xray.dest' "${XRAY_COINFIG_PATH}config.json" | grep -Eoi '([a-zA-Z0-9](\-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}')"
    "${XRAY_CONFIG_MANAGER}" --path "${HOME}/config.json" -sn "$(jq -c -r '.xray | .serverNames[.dest] | .[]' "${XRAY_COINFIG_PATH}config.json" | tr '\n' ',')"
    "${XRAY_CONFIG_MANAGER}" --path "${HOME}/config.json" -x "${xs_private_key}"
    # "${XRAY_CONFIG_MANAGER}" --path "${HOME}/config.json" -rsid

    mv -f "${HOME}/config.json" "${XRAY_SERVER_PATH}config.json"

    _systemctl "restart" "xray"

}

function show_share_link() {

    local sl=""
    # share lnk contents
    local sl_host
    sl_host=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
    local sl_inbound
    sl_inbound=$(jq '.inbounds[] | select(.tag == "xray-script-xtls-reality")' "${XRAY_SERVER_PATH}config.json")
    local sl_port
    sl_port=$(echo "${sl_inbound}" | jq -r '.port')
    local sl_protocol
    sl_protocol=$(echo "${sl_inbound}" | jq -r '.protocol')
    local sl_ids
    sl_ids=$(echo "${sl_inbound}" | jq -r '.settings.clients[] | .id')
    local sl_public_key
    sl_public_key=$(jq -r '.xray.publicKey' "${XRAY_COINFIG_PATH}config.json")

    local sl_serverNames
    sl_serverNames=$(echo "${sl_inbound}" | jq -r '.streamSettings.realitySettings.serverNames[]')

    local sl_shortIds
    sl_shortIds=$(echo "${sl_inbound}" | jq '.streamSettings.realitySettings.shortIds[]')

    # share link fields
    local sl_uuid=""
    local sl_security='security=reality'
    local sl_flow='flow=xtls-rprx-vision'
    local sl_fingerprint='fp=chrome'
    local sl_publicKey="pbk=${sl_public_key}"
    local sl_sni=""
    local sl_shortId=""
    local sl_spiderX='spx=%2F'
    local sl_descriptive_text='VLESS-XTLS-uTLS-REALITY'

    # select show
    _print_list "${sl_ids[@]}"
    read -rp "请选择生成分享链接的 UUID ，用英文逗号分隔， 默认全选: " pick_num
    # shellcheck disable=SC2207
    sl_id=($(select_data "$(awk 'BEGIN{ORS=","} {print}' <<<"${sl_ids[@]}")" "${pick_num}"))

    _print_list "${sl_serverNames[@]}"
    read -rp "请选择生成分享链接的 serverName ，用英文逗号分隔， 默认全选: " pick_num
    # shellcheck disable=SC2207
    sl_serverNames=($(select_data "$(awk 'BEGIN{ORS=","} {print}' <<<"${sl_serverNames[@]}")" "${pick_num}"))

    _print_list "${sl_shortIds[@]}"
    read -rp "请选择生成分享链接的 shortId ，用英文逗号分隔， 默认全选: " pick_num
    # shellcheck disable=SC2207
    sl_shortIds=($(select_data "$(awk 'BEGIN{ORS=","} {print}' <<<"${sl_shortIds[@]}")" "${pick_num}"))

    echo -e "--------------- share link ---------------"
    for sl_id in "${sl_ids[@]}"; do
        sl_uuid="${sl_id}"
        for sl_serverName in "${sl_serverNames[@]}"; do
            sl_sni="sni=${sl_serverName}"
            echo -e "---------- serverName ${sl_sni} ----------"
            for sl_shortId in "${sl_shortIds[@]}"; do
                [[ "${sl_shortId//\"/}" != "" ]] && sl_shortId="sid=${sl_shortId//\"/}" || sl_shortId=""
                sl="${sl_protocol}://${sl_uuid}@${sl_host}:${sl_port}?${sl_security}&${sl_flow}&${sl_fingerprint}&${sl_publicKey}&${sl_sni}&${sl_spiderX}&${sl_shortId}"
                echo "${sl%&}#${sl_descriptive_text}"
            done
            echo -e "------------------------------------------------"
        done
    done
    echo -e "------------------------------------------"
    echo -e "${RED}此脚本仅供交流学习使用，请勿使用此脚本行违法之事。${NC}"
    echo -e "${RED}网络非法外之地，行非法之事，必将接受法律制裁。${NC}"
    echo -e "------------------------------------------"
}

function show_xray_config() {

    local IPv4
    IPv4=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)

    local xs_inbound
    xs_inbound=$(jq '.inbounds[] | select(.tag == "xray-script-xtls-reality")' "${XRAY_SERVER_PATH}config.json")

    local xs_port
    xs_port=$(echo "${xs_inbound}" | jq '.port')

    local xs_protocol
    xs_protocol=$(echo "${xs_inbound}" | jq '.protocol')

    local xs_ids
    xs_ids=$(echo "${xs_inbound}" | jq '.settings.clients[] | .id' | tr '\n' ',')

    local xs_public_key
    xs_public_key=$(jq '.xray.publicKey' "${XRAY_COINFIG_PATH}config.json")

    local xs_serverNames
    xs_serverNames=$(echo "${xs_inbound}" | jq '.streamSettings.realitySettings.serverNames[]' | tr '\n' ',')

    local xs_shortIds
    xs_shortIds=$(echo "${xs_inbound}" | jq '.streamSettings.realitySettings.shortIds[]' | tr '\n' ',')

    local xs_spiderX
    xs_spiderX=$(jq '.xray.dest' "${XRAY_COINFIG_PATH}config.json")

    [[ "${xs_spiderX}" == "${xs_spiderX##*/}" ]] && xs_spiderX='"/"' || xs_spiderX="\"/${xs_spiderX#*/}"
    echo -e "-------------- client config --------------"
    echo -e "address     : \"${IPv4}\""
    echo -e "port        : ${xs_port}"
    echo -e "protocol    : ${xs_protocol}"
    echo -e "id          : ${xs_ids%,}"
    echo -e "flow        : \"xtls-rprx-vision\""
    echo -e "network     : \"raw\""
    echo -e "TLS         : \"reality\""
    echo -e "SNI         : ${xs_serverNames%,}"
    echo -e "Fingerprint : \"chrome\""
    echo -e "PublicKey   : ${xs_public_key}"
    echo -e "ShortId     : ${xs_shortIds%,}"
    echo -e "SpiderX     : ${xs_spiderX}"
    echo -e "------------------------------------------"
    read -rp "是否生成分享链接[Y/n]: " is_show_share_link
    echo
    is_show_share_link=${is_show_share_link:-Y}
    if [[ ${is_show_share_link} =~ ^[Yy]$ ]]; then
        show_share_link
    else
        echo -e "------------------------------------------"
        echo -e "${RED}此脚本仅供交流学习使用，请勿使用此脚本行违法之事。${NC}"
        echo -e "${RED}网络非法外之地，行非法之事，必将接受法律制裁。${NC}"
        echo -e "------------------------------------------"
    fi
}

check_xray_dependencies() {
    # 定义基础必需的软件包列表
    local packages=("openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode")
    local missing_packages=() # 声明数组存储缺失的包

    # 根据操作系统类型检查特定的软件包
    case "$(_os)" in
    centos)
        # 为 CentOS/RHEL 添加系统管理工具
        packages+=("crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        # 遍历包列表，检查是否安装
        for pkg in "${packages[@]}"; do
            if ! rpm -q "$pkg" &>/dev/null; then
                missing_packages+=("$pkg") # 如果未安装，添加到缺失列表
            fi
        done
        ;;
    debian | ubuntu)
        # 为 Debian/Ubuntu 添加系统管理工具
        packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        # 遍历包列表，检查是否安装
        for pkg in "${packages[@]}"; do
            if ! dpkg -s "$pkg" &>/dev/null; then
                missing_packages+=("$pkg") # 如果未安装，添加到缺失列表
            fi
        done
        ;;
    esac

    # 如果缺失包列表为空，则返回 0 (成功)
    [[ ${#missing_packages[@]} -eq 0 ]]
}

install_xray_dependencies() {
    # 定义基础必需的软件包列表
    local packages=("openssl" "curl" "wget" "git" "jq" "tzdata" "qrencode")

    # 根据操作系统类型添加特定的软件包并执行安装
    case "$(_os)" in
    centos)
        # 为 CentOS/RHEL 添加系统管理工具
        packages+=("crontabs" "util-linux" "iproute" "procps-ng" "bind-utils")
        # 检查是否使用 dnf 包管理器 (较新版本)
        if cmd_exists "dnf"; then
            # 使用 dnf 更新系统并安装软件包
            dnf update -y
            dnf install -y dnf-plugins-core
            dnf update -y
            for pkg in "${packages[@]}"; do
                dnf install -y "${pkg}"
            done
        else
            # 使用 yum 包管理器 (较旧版本)
            yum update -y
            yum install -y epel-release yum-utils
            yum update -y
            for pkg in "${packages[@]}"; do
                yum install -y "${pkg}"
            done
        fi
        ;;
    ubuntu | debian)
        # 为 Debian/Ubuntu 添加系统管理工具
        packages+=("cron" "bsdmainutils" "iproute2" "procps" "dnsutils")
        # 更新包列表并安装软件包
        apt update -y
        for pkg in "${packages[@]}"; do
            apt install -y "${pkg}"
        done
        ;;
    esac
}

# =============================================================================
# 函数名称: cmd_exists
# 功能描述: 检查系统中是否存在指定的命令。
# 参数:
#   $1: 要检查的命令名称
# 返回值: 无 (通过 return $rt 返回检查结果)
# 退出码: 0 (命令存在), 非 0 (命令不存在)
# =============================================================================
function cmd_exists() {
    local cmd="$1" # 获取要检查的命令名称
    local rt=0     # 初始化返回码为 0 (表示存在)
    # 尝试使用不同的方法检查命令是否存在
    if eval type type >/dev/null 2>&1; then
        # 使用 type 命令检查
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        # 使用 command -v 命令检查
        command -v "$cmd" >/dev/null 2>&1
    else
        # 使用 which 命令检查
        which "$cmd" >/dev/null 2>&1
    fi
    # 获取检查命令的退出码
    rt=$?
    # 返回检查结果
    return ${rt}
}

# =============================================================================
# 函数名称: check_xray_config_exists
# 功能描述: 检查指定名称的 Xray 配置文件是否存在。
# 参数:
#   $1: 配置文件名（不含扩展名）(SCRIPT_FILE)
# 返回值: 0-文件存在 1-文件不存在 (并打印相应的提示信息到 >&2)
# =============================================================================
function check_xray_config_exists() {
    local SCRIPT_FILE="$1" # 获取配置文件名参数
    CONFIG_XRAY_DIR="${SCRIPT_CONFIG_DIR}/config"
    # 构造完整的配置文件路径
    local CONFIG_FILE="${CONFIG_XRAY_DIR}/${SCRIPT_FILE}.json"

    # 打印正在检查的信息
    _info "正在检查 Xray 配置原文件是否存在:${CONFIG_FILE}"

    # 检查文件是否存在
    if [[ -f "${CONFIG_FILE}" ]]; then
        _info "Xray 配置原文件存在:${CONFIG_FILE}"
        return 0
    else
        _warn "Xray 配置原文件不存在:${CONFIG_FILE}"
        return 1
    fi
}

# =============================================================================
# 函数名称: valid_domain
# 功能描述: 使用正则表达式检查给定字符串是否为有效的域名格式。
# 参数:
#   $1: 待检查的域名字符串 (domain)
# 返回值: 0-有效 1-无效 (直接由 [[ =~ ]] 命令的退出码决定)
# =============================================================================
function valid_domain() {
    local domain="$1" # 获取域名参数

    # 使用正则表达式匹配域名格式，成功匹配返回 0，否则返回 1
    [[ "${domain}" =~ ${DOMAIN_REGEX} ]] && return 0 || return 1
}

# =============================================================================
# 函数名称: resolve_domain
# 功能描述: 使用 dig 命令尝试解析域名，检查是否有有效的 IP 地址记录。
# 参数:
#   $1: 待解析的域名 (domain)
# 返回值: 0-解析成功 1-解析失败或无记录
# =============================================================================
function resolve_domain() {
    # 使用 dig +short 命令解析域名，并将输出通过管道传递给 grep
    # 如果 grep 能在输出中找到至少一个 '.' 字符（通常是 IP 地址的一部分），则返回 0
    # 否则返回 1
    if dig +short "$1" | grep -q '.'; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# 函数名称: test_tcp_connection
# 功能描述: 测试到指定主机和端口的 TCP 连接是否可达。
#           利用 bash 内建的 /dev/tcp 特性。
# 参数:
#   $1: 主机名或 IP 地址 (host)
#   $2: 端口号 (port)
# 返回值: 0-连接成功 1-连接失败 (由 /dev/tcp 操作的退出码决定)
# =============================================================================
function test_tcp_connection() {
    # 尝试打开到 host:port 的 TCP 连接，将输出重定向到 /dev/null
    # 成功则返回 0，失败（如连接被拒绝、超时）则返回非 0
    echo >/dev/tcp/"$1"/"$2" 2>/dev/null
    return #$? # 返回上一条命令的退出码
}

# =============================================================================
# 函数名称: get_tls_info
# 功能描述: 使用 openssl s_client 命令获取指定域名的 TLS 信息。
# 参数:
#   $1: 域名 (domain)
# 返回值: TLS 连接的详细信息 (echo 输出)
# 注意: 会过滤掉空字节 (\0)
# =============================================================================
function get_tls_info() {
    # 向域名的 443 端口发起 TLS 1.3 连接请求，并指定 ALPN 为 h2
    # 使用 echo QUIT 发送退出命令，stdbuf -oL 确保输出行缓冲
    # 2>&1 将错误输出合并到标准输出，tr -d '\0' 过滤掉空字节
    echo QUIT | stdbuf -oL openssl s_client -connect "${1}:443" -tls1_3 -alpn h2 2>&1 | tr -d '\0'
}

# =============================================================================
# 函数名称: domain_check
# 功能描述: 全面检查域名的安全性，包括格式、解析、TCP 连接和 TLS 信息。
# 参数:
#   $1: 待检查的域名 (domain)
# 返回值: 0-安全检查通过 1-安全检查失败 (并打印详细的检查过程和结果到 >&2)
# =============================================================================
domain_check() {
    local domain="$1" # 获取域名参数

    # 打印正在检查的信息
    _info "正在检查域名安全性："

    # 如果域名为空，则认为是有效的（可能表示不使用域名）
    if [[ -z "${domain}" ]]; then
        _pass "输入值为空，将随机在配置中选择一个目标域名"
        return 0
    fi

    # 检查域名格式是否有效
    if ! valid_domain "${domain}"; then
        _fail "域名格式不合法：[${domain}]"
        return 1
    fi

    # 测试域名解析
    _info "正在解析域名：${domain}"
    if ! resolve_domain "$domain"; then
        _fail "域名解析失败：[${domain}]"
        return 1
    fi

    # 测试到域名 443 端口的 TCP 连接
    _info "正在测试 TCP 连接：${domain}:443"
    if ! test_tcp_connection "$domain" 443; then
        _fail "无法连接到：[${domain}:443]"
        return 1
    fi

    # 获取域名的 TLS 信息
    _info "正在获取 TLS 信息：${domain}"
    local tls_info
    tls_info=$(get_tls_info "$domain")

    # 检查是否支持 TLS 1.3
    if ! echo "$tls_info" | grep -q "TLSv1.3"; then
        _fail "TLS 连接失败，可能不支持 TLS 1.3："
        return 1
    else
        _pass "支持 TLS 1.3"
    fi

    # 检查是否使用 X25519 密钥交换算法
    if echo "$tls_info" | grep -q "X25519"; then
        _pass "使用 X25519 密钥交换算法"
    else
        _fail "未使用 X25519 密钥交换算法"
        return 1
    fi

    # 如果所有检查都通过，则域名安全检查通过
    _pass "域名 [${domain}] 安全性检查通过"
    return 0
}

# =============================================================================
# 函数名称: shortid_check
# 功能描述: 验证 Short ID 是否符合要求（空、单数字、或有效的十六进制字符串）。
# 参数:
#   $1: 待检查的 Short ID (short_id)
# 返回值: 0-有效 1-无效 (并打印相应的提示信息到 >&2)
# =============================================================================
function shortid_check() {
    local short_id="$1" # 获取 Short ID 参数

    # 打印正在检查的信息
    _info "正在检查 shortId 合法性："

    # 如果 Short ID 为空，则认为是有效的
    if [[ -z "${short_id}" ]]; then
        _pass "输入值为空，将随机生成 shortId"
        return 0
    fi

    # 如果 Short ID 是 0-8 的单个数字，则认为是有效的（表示生成指定长度的 ID）
    if [[ ${short_id} =~ ^[0-8]$ ]]; then
        _pass "输入值为单个数字，将生成指定长度的 shortId"
        return 0
    fi

    # 检查 Short ID 的长度是否为奇数或超过 16
    if ((${#short_id} % 2 != 0 || ${#short_id} > 16)); then
        _fail "输入值长度为奇数或超过 16，将随机生成 shortId"
        return 1
    fi

    # 检查 Short ID 是否为有效的十六进制字符串
    if ! [[ "${short_id}" =~ $HEX_REGEX ]]; then
        _fail "输入值不是有效的十六进制字符串，将随机生成 shortId"
        return 1
    fi

    # 如果所有检查都通过，则 Short ID 有效
    _pass "输入值是有效的十六进制字符串，将使用该 shortId"
    return 0
}

# =============================================================================
# 函数名称: path_check
# 功能描述: 验证路径字符串是否符合 URL 路径格式要求。
# 参数:
#   $1: 待检查的路径字符串 (path)
# 返回值: 0-有效 1-无效 (并打印相应的提示信息到 >&2)
# =============================================================================
function path_check() {
    local path="$1" # 获取路径参数

    # 打印正在检查的信息
    _info "正在检查 path 合法性：[${path}]"

    # 如果路径为空，则认为是有效的（可能表示使用根路径）
    if [[ -z "${path}" ]]; then
        _pass "输入值为空，将使用根路径"
        return 0
    fi

    # 检查路径中是否包含空格
    if [[ "${path}" == *" "* ]]; then
        _fail "路径不能包含空格：[${path}]"
        return 1
    fi

    # 检查路径长度是否超过 128
    if ((${#path} > 128)); then
        _fail "路径长度超过 128：[${path}]"
        return 1
    fi

    # 检查路径是否包含不允许的字符（只允许字母、数字、下划线、斜杠、点、连字符）
    if [[ "${path}" =~ [^a-zA-Z0-9_/.\-] ]]; then
        _fail "路径包含不允许的字符：[${path}]"
        return 1
    fi

    # 检查路径是否包含连续的斜杠
    if [[ "${path}" =~ // ]]; then
        _fail "路径包含连续的斜杠：[${path}]"
        return 1
    fi

    # 如果所有检查都通过，则路径有效
    _pass "路径合法：[${path}]"
    return 0
}

function read_input() {
    local msg="$1"
    local opt="$2" # 获取配置项名称
    local read_result
    local return_result
    local flag=true # 初始化循环标志为 true

    while ${flag}; do
        read -rp "${msg}" read_result

        case "${opt}" in
        rules)
            # 为规则选项设置默认值 'N'
            return_result="${return_result:-N}"
            ;;
        block-bt | block-cn | block-ad)
            # 归一化，空输入按 Y
            ans="${read_result:-Y}"
            case "${ans}" in
            [Yy])
                return_result="Y"
                ;;
            [Nn])
                return_result="N"
                ;;
            *)
                _warn "无效输入，请输入 [Y/n] 。"
                continue
                ;;
            esac
            ;;
        port)
            # 验证端口号
            read_result=${read_result:-443}
            if [[ ! "${read_result}" =~ ^[0-9]+$ || "${read_result}" -le 0 || "${read_result}" -gt 65535 ]]; then
                _warn "输入了错误的端口:${read_result}" >&2 && echo
                continue
            else
                return_result="${read_result}"
            fi
            ;;
        uuid)
            # 验证 UUID
            # 打印正在检查的信息
            _info "正在检查 UUID 类型：" >&2

            # 如果 UUID 为空，则认为是有效的（可能表示使用默认值或自动生成）
            if [[ -z "${read_result}" ]]; then
                _pass "输入值为空，将自动生成一份 UUID" >&2
            # 如果 UUID 不符合标准格式，则认为是有效的字符串（可能表示使用普通字符串）
            elif ! [[ "${read_result}" =~ $UUID_REGEX ]]; then
                _pass "输入值为普通字符串，将使用 Xray 映射生成 UUID：[${read_result}]" >&2
            else
                # 如果符合标准格式，则为有效 UUID
                _pass "UUID 合法：[${read_result}]" >&2
            fi
            return_result="${read_result}"
            ;;
        target)
            # 验证目标域名
            domain_check "${read_result}" 1>&2 || continue
            return_result="${read_result}"
            ;;
        short)
            # 特殊处理 Short IDs
            # 如果输入为空，进行验证 (可能是检查默认值)
            [[ -z "${read_result}" ]] && shortid_check "${read_result}" 1>&2 && break
            # 将逗号分隔的输入分割成数组
            IFS=',' read -r -a values <<<"${read_result}"
            # 遍历每个 Short ID 进行验证
            for value in "${values[@]}"; do
                if shortid_check "${value}" 1>&2; then
                    # 验证通过则追加到 CONFIG_DATA['short_ids']
                    CONFIG_DATA['short_ids']="${CONFIG_DATA['short_ids']} ${value}"
                fi
            done
            ;;
        path)
            # 验证路径
            path_check "${read_result}" 1>&2 || continue
            return_result="${read_result}"
            ;;
        esac
        # 输入验证通过，设置 flag 为 false 退出循环
        flag=false
    done

    echo "${return_result}"

}

function exec_read() {
    local opt="$1" # 获取配置项名称
    local read_result

    case "${opt}" in
    rules)
        CONFIG_DATA['rules']=$(read_input "是否重置路由规则 [y/N] :" "rules")
        ;;
    block-bt)
        CONFIG_DATA['block-bt']=$(read_input "是否开启 bittorrent 屏蔽? [Y/n] :" "block-bt")
        ;;
    block-cn)
        CONFIG_DATA['block-cn']=$(read_input "是否开启大陆屏蔽? [Y/n] :" "block-cn")
        ;;
    block-ad)
        CONFIG_DATA['block-ad']=$(read_input "是否开启广告屏蔽? [Y/n] :" "block-ad")
        ;;
    port)
        CONFIG_DATA['port']=$(read_input "请输入 port (端口范围是 1-65535 ，默认: 443): " "port")
        ;;
    uuid)
        CONFIG_DATA['uuid']=$(read_input "请输入 UUID (支持自定义字符串，默认自动生成): " "uuid")
        ;;
    target)
        CONFIG_DATA['target']=$(read_input "请输入目标域名 target (默认随机选择): " "target")
        ;;
    short)
        read_input "请输入 shortId (多个值请用英文逗号分隔，默认自动生成): " "short"
        ;;
    path)
        CONFIG_DATA['path']=$(read_input "请输入 path (默认自动生成): " "path")
        ;;
    esac
}

# =============================================================================
# 函数名称: reset_json_fields
# 功能描述: 重置 JSON 对象中指定键下的字段值。
#           1. 如果指定了目标键 ($2)，则只重置该键下的字段。
#           2. 如果未指定目标键，则重置整个 JSON 对象的字段。
#           3. 保留指定的字段 ($3, $4, ...) 不变，其他字段根据类型重置为空值。
# 参数:
#   $1: 原始 JSON 字符串
#   $2: 目标键名 (例如 'xray' 或 'nginx')，如果为 "null" 则重置整个对象
#   $@: (从 $3 开始) 需要保留的字段名列表
# 返回值: 重置后的 JSON 字符串 (echo 输出)
# =============================================================================
function reset_json_fields() {
    local raw_json="$1"   # 获取原始 JSON 字符串
    local target_key="$2" # 获取目标键名

    # 移除前两个参数，剩下的就是需要保留的字段名
    shift 2

    local keep_fields=("$@") # 获取需要保留的字段名数组

    # 将保留字段名数组转换为 jq 可用的 JSON 数组
    local jq_keep
    jq_keep=$(printf '%s\n' "${keep_fields[@]}" | jq -R . | jq -s .)

    # 使用 jq 脚本进行重置操作
    raw_json=$(echo "${raw_json}" | jq --arg key "${target_key}" --argjson keep "$jq_keep" '
        # 定义递归函数 clear_recursive，用于清空值
        def clear_recursive:
            if type == "object" then with_entries(.value |= clear_recursive)
            elif type == "array" then map(clear_recursive) | unique
            elif type == "number" then 0
            elif type == "boolean" then false
            else ""
            end;
        # 定义函数 exec_clear，用于判断字段是否需要保留
        def exec_clear:
            if .key | IN($keep[]) then .
            else .value |= clear_recursive
            end;
        # 根据是否指定了目标键来决定重置范围
        if $key != "null" then .[$key] |= with_entries(exec_clear)
        else . |= with_entries(exec_clear)
        end
    ')

    # 输出重置后的 JSON 字符串
    echo "${raw_json}"
}

# =============================================================================
# 函数名称: handler_reset_script_config
# 功能描述: 重置脚本配置文件 (config.json) 中指定部分的字段。
#           1. 根据目标配置部分 (xray/nginx) 调用 reset_json_fields。
#           2. 保留特定字段不变，其他字段清空。
#           3. 将重置后的配置写回 SCRIPT_CONFIG_PATH 文件。
# 参数:
#   $1: TARGET_CONFIG - 目标配置部分 ("xray" 或 "nginx")，默认为 "xray"
# 返回值: 无 (直接修改 SCRIPT_CONFIG 全局变量和 SCRIPT_CONFIG_PATH 文件)
# =============================================================================
function handler_reset_script_config() {
    local TARGET_CONFIG="${1:-xray}" # 获取目标配置部分，默认为 xray
    # 根据目标配置部分调用 reset_json_fields 进行重置
    case "${TARGET_CONFIG,,}" in
    xray)
        # 重置 xray 部分，保留 version, warp, rules 字段
        SCRIPT_CONFIG=$(reset_json_fields "${SCRIPT_CONFIG}" 'xray' 'version' 'warp' 'rules')
        ;;
    nginx)
        # 重置 nginx 部分，保留 version, ca 字段
        SCRIPT_CONFIG=$(reset_json_fields "${SCRIPT_CONFIG}" 'nginx' 'version' 'ca')
        ;;
    esac
    # 将重置后的脚本配置写入文件
    echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
}

# =============================================================================
# 函数名称: generate_uuid
# 功能描述: 生成一个 UUID。如果系统安装了 `xray` 命令，优先使用它来生成；
#           否则使用系统自带的 `/proc/sys/kernel/random/uuid`。
# 参数:
#   $1 (可选): 输入字符串，用于生成基于该输入的 UUID (需要 xray 支持)
# 返回值: 生成的 UUID 字符串 (echo 输出)
# =============================================================================
function generate_uuid() {
    local input="${1}" # 获取可选的输入参数
    local uuid         # 声明用于存储 UUID 的局部变量

    # 检查系统中是否存在 xray 命令
    if command -v xray &>/dev/null; then
        # 如果没有提供输入参数
        if [[ -z "${input}" ]]; then
            # 直接生成一个新的 UUID
            uuid=$(xray uuid)
        # 如果提供的输入参数已经是标准格式的 UUID
        elif [[ "${input}" =~ ^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$ ]]; then
            # 则直接使用该输入作为 UUID
            uuid=${input}
        else
            # 否则，使用提供的输入字符串生成一个基于该输入的 UUID
            uuid=$(xray uuid -i "${input}")
        fi
    else
        # 如果没有安装 xray，则使用系统方法生成 UUID
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    # 输出生成的 UUID
    echo "${uuid}"
}

# =============================================================================
# 函数名称: generate_password
# 功能描述: 生成一个随机密码，长度在 16 到 64 个字符之间。
#           密码由数字、大小写字母以及部分特殊字符 (!@$%*) 组成。
# 参数: 无
# 返回值: 生成的随机密码 (echo 输出)
# =============================================================================
function generate_password() {
    # 首先生成一个 16 到 64 之间的随机数作为密码长度
    local length
    length="$(generate_random 16 64)"

    # 从 /dev/urandom 读取随机字节，通过 tr 过滤出指定字符集，
    # 再用 fold 按指定长度换行，最后用 head 取第一行作为密码
    cat /dev/urandom | tr -cd '0-9a-zA-Z!@$%*' | fold -w "${length}" | head -n 1
}

# =============================================================================
# 函数名称: generate_path
# 功能描述: 生成一个随机的 URL 路径，以 '/' 开头。
#           路径由 16 到 64 个随机字母和数字组成。
# 参数: 无
# 返回值: 生成的随机路径字符串 (echo 输出)
# =============================================================================
function generate_path() {
    # 生成一个 16 到 64 之间的随机数作为路径长度
    local length
    length="$(generate_random 16 64)"

    # 从 /dev/urandom 读取随机字节，通过 tr 过滤出字母和数字，
    # 再用 fold 按指定长度换行，最后用 head 取第一行作为路径主体
    local domain_path
    domain_path="$(cat /dev/urandom | tr -cd 'a-zA-Z0-9' | fold -w "${length}" | head -n 1)"

    # 在路径主体前加上 '/' 并输出
    echo "/${domain_path}"
}

# =============================================================================
# 函数名称: generate_random
# 功能描述: 生成一个随机数。如果不提供参数或参数无效，则生成一个无符号32位随机整数；
#           如果提供了有效的最小值和最大值，则生成该范围内的随机整数。
# 参数:
#   $1 (可选): 自定义最小值 (custom_min)
#   $2 (可选): 自定义最大值 (custom_max)
# 返回值: 生成的随机数 (echo 输出)
# =============================================================================
function generate_random() {
    local custom_min=${1} # 获取第一个参数作为自定义最小值
    local custom_max=${2} # 获取第二个参数作为自定义最大值

    # 使用 /dev/urandom 生成一个无符号32位随机整数
    local random
    random=$(od -An -N4 -tu4 </dev/urandom)

    # 检查自定义的最小值和最大值是否为有效正整数，并且最小值小于最大值
    if [[ ${custom_min} =~ ^[0-9]+$ && ${custom_max} =~ ^[0-9]+$ ]] && ((custom_min < custom_max)); then
        # 计算范围大小
        local range=$((custom_max - custom_min + 1))
        # 使用取模运算将随机数映射到指定范围内，并加上最小值偏移
        echo $((random % range + custom_min))
    else
        # 如果参数无效，则直接输出原始随机数
        echo "${random}"
    fi
}

# =============================================================================
# 函数名称: generate_target
# 功能描述: 从配置文件 ${SCRIPT_CONFIG_PATH} 的 'target' 键中，
#           随机选择一个键名作为目标。
# 参数: 无 (依赖内部 generate_random 生成随机索引)
# 返回值: 随机选中的 target 键名 (echo 输出)
# 注意: 需要确保 ${SCRIPT_CONFIG_PATH} 文件存在且格式正确 (包含 .target 键)
# =============================================================================
function generate_target() {
    # 生成一个随机数作为索引
    local random
    random="$(generate_random)"

    # 使用 jq 读取配置文件，获取 .target 对象的所有键名(keys)，
    # 然后计算随机索引对键名数组长度取模，从而随机选择一个键名
    jq -r --argjson random "${random}" '.target | keys | .[$random % length?]' "${SCRIPT_CONFIG_PATH}"
}

# =============================================================================
# 函数名称: generate_server_names
# 功能描述: 为给定的 target 生成或获取其对应的服务器名称列表。
#           如果 target 在配置文件中不存在，则将其添加到 .target 对象中，
#           其值为一个仅包含该 target 名称的数组。
#           最后返回该 target 对应的服务器名称数组。
# 参数:
#   $1: 目标名称 (target)
# 返回值: JSON 格式的数组，包含服务器名称 (echo 输出)
# 注意: 会修改 ${SCRIPT_CONFIG_PATH} 文件内容
# =============================================================================
function generate_server_names() {
    local target=${1} # 获取目标名称参数

    # 使用 jq 读取并可能修改配置文件内容：
    # 如果 .target 对象中已存在 $key (即 $target)，
    # 则返回原配置；
    # 否则，将新的键值对 ($target: [$target]) 添加到 .target 对象中
    local SCRIPT_CONFIG_LOCAL
    SCRIPT_CONFIG_LOCAL=$(jq --arg key "${target}" '
    if .target | has($key) then
        .
    else
        .target += { ($key): [$key] }
    end
    ' "${SCRIPT_CONFIG_PATH}")

    # 将修改后的配置内容写回配置文件
    echo "${SCRIPT_CONFIG_LOCAL}" >"${SCRIPT_CONFIG_PATH}" && sleep 2

    # 从修改后的配置中提取并输出指定 target 的服务器名称列表
    echo "${SCRIPT_CONFIG_LOCAL}" | jq --arg key "${target}" '.target[$key]'
}

# =============================================================================
# 函数名称: generate_short_id
# 功能描述: 生成一个指定长度的 Short ID (十六进制字符串)。
#           如果输入是 0-8 的数字，则生成对应长度的 ID；
#           如果输入是 0，则返回空字符串；
#           其他情况（包括非数字输入）则随机生成 0-8 位的 ID。
# 参数:
#   $1 (可选): 指定的长度 (0-8) 或任意输入
# 返回值: 生成的 Short ID (echo 输出)
# 注意: 需要 openssl 命令支持
# =============================================================================
function generate_short_id() {
    local input=$1 # 获取输入参数

    # 使用 sed 去除输入参数首尾的空白字符
    local trimmed_input
    trimmed_input=$(echo "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    local length # 声明存储最终长度的变量

    # 检查处理后的输入是否为 0-8 的数字
    if [[ $trimmed_input =~ ^[0-8]$ ]]; then
        # 如果是，则使用该数字作为长度
        length=$trimmed_input
    else
        # 如果不是，则生成一个 0-8 之间的随机长度
        length=$(generate_random 0 8)
    fi

    # 如果长度为 0，则输出空字符串
    # 否则，使用 openssl 生成指定长度的十六进制随机字符串
    if [[ $length -eq 0 ]]; then
        printf '%s\n' ""
    else
        openssl rand -hex "$length"
    fi
}

# =============================================================================
# 函数名称: generate_short_ids
# 功能描述: 批量生成多个 Short ID。
#           对于每个输入参数：如果是 0-8 的数字，则生成对应长度的 ID；
#           否则，直接将输入作为 ID (需为十六进制字符串)。
#           最终输出一个去重并按长度排序的 JSON 数组。
# 参数:
#   $@: 一系列参数，每个参数代表一个 Short ID 的生成要求或直接值
# 返回值: JSON 格式的数组，包含去重并排序后的 Short ID (echo 输出)
# 注意: 依赖 jq 进行数组处理和去重排序
# =============================================================================
function generate_short_ids() {
    local -a ids=()  # 声明一个数组用于存储生成的 ID
    local -a args=() # 声明一个数组用于存储输入参数

    # 将所有输入参数按空格分割并存入 args 数组
    IFS=' ' read -r -a args <<<"$@"

    # 遍历每个输入参数
    for arg in "${args[@]}"; do
        # 如果参数是 0-8 的数字
        if [[ $arg =~ ^[0-8]$ ]]; then
            # 调用 generate_short_id 生成对应长度的 ID，
            # 并使用 jq -R 将其转换为 JSON 字符串格式后添加到 ids 数组
            ids+=("$(generate_short_id "${arg}" | jq -R)")
        else
            # 如果不是数字，则直接将参数作为 ID 值，
            # 同样使用 jq -R 转换为 JSON 字符串格式后添加到 ids 数组
            ids+=("$(printf '%s' "${arg}" | jq -R)")
        fi
    done

    # 将 ids 数组中的所有元素作为独立参数传递给 echo，
    # 然后通过管道传递给 jq：
    # -s : 将多个输入项收集到一个数组中
    # unique : 对数组进行去重
    # sort_by(length) : 按字符串长度对数组元素进行排序
    echo "${ids[@]}" | jq -s 'unique | sort_by(length)'
}

# =============================================================================
# 函数名称: handler_script_config
# 功能描述: 处理并更新脚本配置文件 (config.json)。
#           1. 打印配置更新提示。
#           2. 调用 handler_reset_script_config 重置配置。
#           3. 从 CONFIG_DATA 中获取或生成配置值。
#           4. 根据配置标签 (tag) 更新不同的字段。
#           5. 将更新后的配置写回 SCRIPT_CONFIG_PATH 文件。
# 参数:
#   $1: CONFIG_TAG - 配置标签 (例如 Vision, XHTTP, SNI 等)，默认从 CONFIG_DATA 获取
# 返回值: 无 (直接修改 SCRIPT_CONFIG 全局变量和 SCRIPT_CONFIG_PATH 文件)
# =============================================================================
function handler_script_config() {

    # 打印绿色的配置更新提示
    _info "正在更新脚本配置 ... "

    # 重置脚本配置 (默认重置 xray 部分)
    handler_reset_script_config

    # 从 CONFIG_DATA 或生成器获取配置值
    # 获取配置标签
    local CONFIG_TAG="${1:-${CONFIG_DATA['tag']}}"
    # 获取规则状态
    local XRAY_RULES_STATUS="${CONFIG_DATA['rules']}"
    # 获取 block bt 状态
    local XRAY_RULES_BT="${CONFIG_DATA['block-bt']}"
    # 获取 block cn 状态
    local XRAY_RULES_CN="${CONFIG_DATA['block-cn']}"
    # 获取 block ad 状态
    local XRAY_RULES_AD="${CONFIG_DATA['block-ad']}"
    # 获取端口，默认 443
    local XRAY_PORT="${CONFIG_DATA['port']:-443}"
    # 获取或生成 UUID
    local XRAY_UUID
    XRAY_UUID="$(generate_uuid "${CONFIG_DATA['uuid']}")"
    # 获取或生成 Fallback UUID
    local FALLBACK_UUID
    FALLBACK_UUID="${CONFIG_DATA['fallback']:-$(generate_uuid)}"
    # 获取或生成 Trojan 密码
    local TROJAN_PASSWORD
    TROJAN_PASSWORD="${CONFIG_DATA['password']:-$(generate_password)}"
    # 获取或生成 mKCP Seed
    local KCP_SEED="${CONFIG_DATA['seed']:-$(generate_password)}"
    # 获取或生成 XHTTP 路径
    local XHTTP_PATH
    XHTTP_PATH="${CONFIG_DATA['path']:-$(generate_path)}"
    # 获取或生成目标域名
    local TARGET_DOMAIN
    TARGET_DOMAIN="${CONFIG_DATA['target']:-$(generate_target)}"
    # 生成服务器名称列表
    local SERVER_NAMES
    SERVER_NAMES="$(generate_server_names "${TARGET_DOMAIN}")"
    # 获取 CDN 域名
    # local CDN_DOMAIN="${CONFIG_DATA['cdn']}"
    # 获取或生成 Short IDs
    local SHORT_IDS
    SHORT_IDS="$(generate_short_ids "${CONFIG_DATA['short_ids']:-8 8}")"
    # 获取 CA 邮箱
    # local CA_EMAIL="${CONFIG_DATA['email']}"

    # 更新脚本配置中的规则状态
    SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg reset "${XRAY_RULES_STATUS,,}" ' if $reset != "n" then .xray.rules.reset = 1 else .xray.rules.reset = 0 end ')"
    # 更新脚本配置中的 block bt 状态
    SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg bt "${XRAY_RULES_BT,,}" ' if $bt != "n" then .xray.rules.bt = 1 else .xray.rules.bt = 0 end ')"
    # 更新脚本配置中的 block cn 状态
    SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg cn "${XRAY_RULES_CN,,}" ' if $cn != "n" then .xray.rules.cn = 1 else .xray.rules.cn = 0 end ')"
    # 更新脚本配置中的 block ad 状态
    SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg ad "${XRAY_RULES_AD,,}" ' if $ad != "n" then .xray.rules.ad = 1 else .xray.rules.ad = 0 end ')"

    # 根据配置标签更新特定字段
    case "${CONFIG_TAG,,}" in
    trojan)
        # 更新 Trojan 密码
        SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg password "${TROJAN_PASSWORD}" '.xray.trojan = $password')"
        ;;
    mkcp | vision | xhttp | fallback | sni)
        # 更新 UUID
        SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg uuid "${XRAY_UUID}" '.xray.uuid = $uuid')"
        ;;
    esac
    # 根据配置标签更新特定字段 (第二部分)
    # case "${CONFIG_TAG,,}" in
    # fallback)
    #     # 更新 Fallback UUID
    #     SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg uuid "${FALLBACK_UUID}" '.xray.fallback = $uuid')"
    #     ;;
    # mkcp)
    #     # 为 mKCP 生成随机端口并更新 Seed
    #     XRAY_PORT="$(exec_generate '--port')"
    #     SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg seed "${KCP_SEED}" '.xray.kcp = $seed')"
    #     ;;
    # sni)
    #     # 更新 Fallback UUID
    #     SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg uuid "${FALLBACK_UUID}" '.xray.fallback = $uuid')"
    #     # 为 SNI 更新 CA 邮箱、域名和 CDN
    #     [[ -n "${CA_EMAIL}" ]] && SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg ca "${CA_EMAIL}" '.nginx.ca = $ca')"
    #     SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg domain "${TARGET_DOMAIN}" '.nginx.domain = $domain')"
    #     SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg cdn "${CDN_DOMAIN}" '.nginx.cdn = $cdn')"
    #     ;;
    # esac
    # 根据配置标签更新特定字段 (第三部分)
    case "${CONFIG_TAG,,}" in
    xhttp | trojan | fallback | sni)
        # 更新路径
        SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg path "${XHTTP_PATH}" '.xray.path = $path')"
        ;;
    esac
    # 根据配置标签更新特定字段 (第四部分)
    case "${CONFIG_TAG,,}" in
    vision | xhttp | trojan | fallback | sni)
        # 更新目标域名、服务器名称和 Short IDs
        SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg target "${TARGET_DOMAIN}" '.xray.target = $target')"
        SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --argjson serverNames "${SERVER_NAMES}" '.xray.serverNames = $serverNames')"
        SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --argjson shortIds "${SHORT_IDS}" '.xray.shortIds = $shortIds')"
        ;;
    esac
    # 更新配置标签和端口
    SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg tag "${CONFIG_TAG}" '.xray.tag = $tag')"
    SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --argjson port "${XRAY_PORT}" '.xray.port = $port')"
    # 将更新后的脚本配置写入文件
    echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
}

# =============================================================================
# 函数名称: handler_install
# 功能描述: 安装 Xray 核心。
#           1. 确定要安装的 Xray 版本。
#           2. 检查系统中是否已安装 Xray。
#           3. 如果未安装或强制安装，则从 Xray-install 脚本安装。
# 参数:
#   $1: xray_version - (可选) 要安装的 Xray 版本
#   $2: force_install - (可选) 是否强制安装 ('y' 表示强制)，默认为 'n'
# 返回值: 无 (通过调用外部脚本执行安装)
# =============================================================================
function handler_install() {
    # local xray_version="$1"       # 获取版本参数
    local force_install="${2:-n}" # 获取强制安装参数，默认为 'n'

    # # 如果提供了版本参数，则处理版本配置
    # if [[ -n "${xray_version}" ]]; then
    #     handler_xray_version "${xray_version}"
    # else
    #     # 否则从脚本配置中读取版本
    #     CONFIG_DATA['version']="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.version')"
    # fi

    # 检查 Xray 命令是否存在，或是否强制安装
    if ! cmd_exists 'xray' || [[ "${force_install}" != n ]]; then
        # 调用 Xray-install 脚本进行安装
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root #--version "${CONFIG_DATA['version']}"
    fi
}

# =============================================================================
# 函数名称: generate_x25519
# 功能描述: 使用 xray 命令生成一对 X25519 密钥（私钥和公钥）。
# 参数: 无
# 返回值: 以逗号分隔的字符串 "私钥,公钥" (echo 输出)
# 注意: 需要确保系统已安装 xray 命令
# =============================================================================
function generate_x25519() {
    # 调用 xray x25519 命令生成密钥对，输出通常为两行：
    # Private key: <private_key>
    # Public key: <public_key>
    local X25519_KEY
    X25519_KEY=$(xray x25519)

    # 使用 sed 提取第一行中的私钥部分
    local PRIVATE_KEY
    PRIVATE_KEY=$(echo "${X25519_KEY}" | sed -ne '1s/.*:\s*//p')
    # 使用 sed 提取第二行中的公钥部分
    local PUBLIC_KEY
    PUBLIC_KEY=$(echo "${X25519_KEY}" | sed -ne '2s/.*:\s*//p')
    # 使用 sed 提取第三行中的哈希部分
    local HASH32
    HASH32=$(echo "${X25519_KEY}" | sed -ne '3s/.*:\s*//p')

    # 将私钥和公钥，以及哈希用逗号连接后输出
    echo "${PRIVATE_KEY},${PUBLIC_KEY},${HASH32}"
}

# =============================================================================
# 函数名称: handler_x25519_config
# 功能描述: 处理并更新脚本配置文件 (config.json)。
#           1. 获取 X25519 密钥对。
#           2. 将 X25519 密钥对写入 SCRIPT_CONFIG_PATH 文件。
# 参数: 无
# 返回值: 无 (直接修改 SCRIPT_CONFIG 全局变量和 SCRIPT_CONFIG_PATH 文件)
# =============================================================================
function handler_x25519_config() {
    # 打印绿色的配置更新提示
    # echo -e "${GREEN}[$(echo "$I18N_DATA" | jq -r '.title.config')]${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.script.config_update")" >&2
    _info "正在更新脚本配置 ..."

    # 生成 X25519 密钥对
    local X25519
    X25519=$(generate_x25519)
    # 提取私钥
    local PRIVATE_KEY
    PRIVATE_KEY="$(echo "${X25519}" | awk -F, '{print $1}')"
    # 提取公钥
    local PUBLIC_KEY
    PUBLIC_KEY="$(echo "${X25519}" | awk -F, '{print $2}')"
    # 提取 Hash32
    local HASH32
    HASH32="$(echo "${X25519}" | awk -F, '{print $3}')"

    # 输出显示 x25519 密钥对
    # echo -e "${GREEN}[Private Key]${NC} "${PRIVATE_KEY}"" >&2
    # echo -e "${GREEN}[Public Key]${NC} "${PUBLIC_KEY}"" >&2
    # echo -e "${GREEN}[Hash32]${NC} "${HASH32}"" >&2
    _info "Private Key: ${PRIVATE_KEY}"
    _info "Public Key: ${PUBLIC_KEY}"
    _info "Hash32: ${HASH32}"

    # 更新脚本配置中的私钥和公钥，以及哈希值
    SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg privateKey "${PRIVATE_KEY}" '.xray.privateKey = $privateKey')"
    SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg publicKey "${PUBLIC_KEY}" '.xray.publicKey = $publicKey')"
    SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg hash32 "${HASH32}" '.xray.hash32 = $hash32')"
    # 将更新后的脚本配置写入文件
    echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
}

# =============================================================================
# 函数名称: add_rule
# 功能描述: 在 Xray 配置的 routing.rules 中添加或更新路由规则。
#           1. 检查是否存在具有相同 ruleTag 的规则。
#           2. 如果存在且是 domain 或 ip 规则，则追加新值。
#           3. 如果不存在，则创建新规则。
#           4. 新规则可以插入到指定位置或相对于其他规则的位置。
#           5. 更新后的配置写入 XRAY_CONFIG_PATH 文件。
# 参数:
#   $1: rule_tag - 规则标签 (ruleTag)，用于唯一标识规则
#   $2: domain_or_ip - 规则类型 ("domain" 或 "ip")
#   $3: value - 要添加的值 (可以是逗号分隔的多个值)
#   $4: outboundTag - 出站标签 (例如 "block", "warp")
#   $5: position - (可选) 插入位置或相对于 target_tag 的位置 ("before", "after", 数字索引)
#   $6: target_tag - (可选) 用于定位插入位置的参考规则标签
# 返回值: 无 (直接修改 XRAY_CONFIG_PATH 文件)
# =============================================================================
function add_rule() {
    local rule_tag=$1     # 获取规则标签
    local domain_or_ip=$2 # 获取规则类型 (domain/ip)
    # 将逗号分隔的值转换为 JSON 数组
    local value
    value=$(echo "$3" | tr ',' '\n' | jq -R | jq -s)
    local outboundTag=$4 # 获取出站标签
    local position=$5    # 获取插入位置参数
    local target_tag=$6  # 获取目标规则标签参数
    # 如果 XRAY_CONFIG 未初始化，则从文件加载
    XRAY_CONFIG="${XRAY_CONFIG:-$(jq '.' "${XRAY_CONFIG_PATH}")}"
    # 检查是否存在具有相同 ruleTag 的规则
    local existing_rule
    existing_rule=$(echo "${XRAY_CONFIG}" | jq -r --arg ruleTag "${rule_tag}" '.routing.rules[] | select(.ruleTag == $ruleTag)')
    # 如果规则已存在
    if [[ "${existing_rule}" ]]; then
        # 如果是 domain 规则
        if [[ "${domain_or_ip}" == "domain" ]]; then
            # 将新值追加到现有 domain 数组并去重
            XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --arg ruleTag "${rule_tag}" --argjson value "${value}" '.routing.rules |= map(if .ruleTag == $ruleTag then .domain += $value | .domain |= unique else . end)')"
        # 如果是 ip 规则
        elif [[ "${domain_or_ip}" == "ip" ]]; then
            # 将新值追加到现有 ip 数组并去重
            XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --arg ruleTag "${rule_tag}" --argjson value "${value}" '.routing.rules |= map(if .ruleTag == $ruleTag then .ip += $value | .ip |= unique else . end)')"
        fi
    else
        # 规则不存在，创建新的规则 JSON 对象
        local new_rule="[{\"ruleTag\":\"${rule_tag}\",\"${domain_or_ip}\":${value},\"outboundTag\":\"${outboundTag}\"}]"
        # 如果指定了 target_tag
        if [[ -n "${target_tag}" ]]; then
            # 检查 target_tag 对应的规则是否存在
            local target_rule
            target_rule=$(echo "${XRAY_CONFIG}" | jq -r --arg ruleTag "${target_tag}" '.routing.rules[] | select(.ruleTag == $ruleTag)')
            if [[ "${target_rule}" ]]; then
                # 获取 target_tag 对应规则的索引
                local target_index
                target_index=$(echo "${XRAY_CONFIG}" | jq -r --arg ruleTag "${target_tag}" '.routing.rules | to_entries | map(select(.value.ruleTag == $ruleTag)) | .[0].key')
                # 根据 position 参数决定插入位置
                if [[ "${position}" == "before" ]]; then
                    # 插入到 target_tag 规则之前
                    XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --argjson target_index "${target_index}" --argjson new_rule "${new_rule}" '.routing.rules |= .[:$target_index] + $new_rule + .[$target_index:]')"
                elif [[ "${position}" == "after" ]]; then
                    # 插入到 target_tag 规则之后
                    XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --argjson target_index $((target_index + 1)) --argjson new_rule "${new_rule}" '.routing.rules |= .[:$target_index] + $new_rule + .[$target_index:]')"
                else
                    # 默认追加到末尾
                    XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --argjson new_rule "${new_rule}" '.routing.rules += $new_rule')"
                fi
            else
                # target_tag 规则不存在，追加到末尾
                XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --argjson new_rule "${new_rule}" '.routing.rules += $new_rule')"
            fi
        else
            # 未指定 target_tag
            # 如果指定了数字位置
            if [[ -n "${position}" && "${position}" -ge 0 ]]; then
                # 插入到指定索引位置
                XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --argjson position "${position}" --argjson new_rule "${new_rule}" '.routing.rules |= .[:$position] + $new_rule + .[$position:]')"
            else
                # 默认追加到末尾
                XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --argjson new_rule "${new_rule}" '.routing.rules += $new_rule')"
            fi
        fi
    fi
    # 将更新后的 Xray 配置写入文件
    echo "${XRAY_CONFIG}" >"${XRAY_CONFIG_PATH}" && sleep 2
}

# =============================================================================
# 函数名称: handler_xray_config
# 功能描述: 处理并更新 Xray 核心配置文件 (/usr/local/etc/xray/config.json)。
#           1. 打印配置更新提示。
#           2. 从脚本配置中读取各项参数。
#           3. 加载对应配置标签的模板文件。
#           4. 根据配置标签和参数替换模板中的占位符。
#           5. 处理路由规则 (保留当前规则或重置并添加默认规则)。
#           6. 将更新后的配置写回 XRAY_CONFIG_PATH 和 SCRIPT_CONFIG_PATH 文件。
# 参数: 无
# 返回值: 无 (直接修改 XRAY_CONFIG 全局变量和 XRAY_CONFIG_PATH/SCRIPT_CONFIG_PATH 文件)
# =============================================================================
function handler_xray_config() {
    # 打印绿色的 Xray 配置更新提示
    # echo -e "${GREEN}[$(echo "$I18N_DATA" | jq -r '.title.config')]${NC} $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.xray.config_update")" >&2
    _info "正在更新 Xray 配置 ..."

    # 从脚本配置中读取各项参数
    local CONFIG_TAG
    CONFIG_TAG="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.tag')" # 获取配置标签
    local XRAY_PORT
    XRAY_PORT="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.port')" # 获取端口
    local XRAY_UUID
    XRAY_UUID="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.uuid')" # 获取 UUID
    local FALLBACK_UUID
    FALLBACK_UUID="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.fallback')" # 获取 Fallback UUID
    local TROJAN_PASSWORD
    TROJAN_PASSWORD="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.trojan')" # 获取 Trojan 密码
    local KCP_SEED
    KCP_SEED="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.kcp')" # 获取 mKCP Seed
    local TARGET_DOMAIN
    TARGET_DOMAIN="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.target')" # 获取目标域名
    local SERVER_NAMES
    SERVER_NAMES="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.serverNames')" # 获取服务器名称
    local PRIVATE_KEY
    PRIVATE_KEY="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.privateKey')" # 获取私钥
    local SHORT_IDS
    SHORT_IDS="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.shortIds')" # 获取 Short IDs
    local XHTTP_PATH
    XHTTP_PATH="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.path')" # 获取路径
    local XRAY_RULES_STATUS
    XRAY_RULES_STATUS="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.rules.reset')" # 获取规则状态
    local XRAY_RULES_BT
    XRAY_RULES_BT="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.rules.bt')" # 获取 bt 规则状态
    local XRAY_RULES_CN
    XRAY_RULES_CN="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.rules.cn')" # 获取 cn 规则状态
    local XRAY_RULES_AD
    XRAY_RULES_AD="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.rules.ip')" # 获取 ad 规则状态
    local XRAY_RULES
    XRAY_RULES="$(echo "${SCRIPT_CONFIG}" | jq -r '.rules')" # 获取路由规则
    local WARP_STATUS
    WARP_STATUS="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.warp')" # 获取 WARP 状态

    # 加载对应配置标签的 Xray 配置模板
    XRAY_CONFIG="$(jq '.' "${SCRIPT_CONFIG_DIR}/config/${CONFIG_TAG}.json")"
    # 如果配置标签不是 sni，则更新端口
    if [[ "${CONFIG_TAG,,}" != 'sni' ]]; then
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --argjson port "${XRAY_PORT}" '.inbounds[1].port = $port')"
    fi
    # 根据配置标签更新特定字段 (第一部分)
    case "${CONFIG_TAG,,}" in
    mkcp | vision | xhttp | fallback | sni)
        # 更新客户端 UUID
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --arg uuid "${XRAY_UUID}" '.inbounds[1].settings.clients[0].id = $uuid')"
        ;;
    trojan)
        # 更新 Trojan 客户端密码
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --arg password "${TROJAN_PASSWORD}" '.inbounds[1].settings.clients[0].password = $password')"
        ;;
    esac
    # 根据配置标签更新特定字段 (第二部分)
    case "${CONFIG_TAG,,}" in
    mkcp)
        # 更新 mKCP Seed
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --arg seed "${KCP_SEED}" '.inbounds[1].streamSettings.kcpSettings.seed = $seed')"
        ;;
    vision | xhttp | trojan | fallback | sni)
        # 如果不是 sni 配置，更新 Reality 目标
        if [[ "${CONFIG_TAG,,}" != 'sni' ]]; then
            XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --arg target "${TARGET_DOMAIN}:443" '.inbounds[1].streamSettings.realitySettings.target = $target')"
        fi
        # 更新 Reality 服务器名称、私钥和 Short IDs
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --argjson serverNames "${SERVER_NAMES}" '.inbounds[1].streamSettings.realitySettings.serverNames = $serverNames')"
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --arg privateKey "${PRIVATE_KEY}" '.inbounds[1].streamSettings.realitySettings.privateKey = $privateKey')"
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --argjson shortIds "${SHORT_IDS}" '.inbounds[1].streamSettings.realitySettings.shortIds = $shortIds')"
        ;;
    esac
    # 根据配置标签更新特定字段 (第三部分)
    case "${CONFIG_TAG,,}" in
    xhttp | trojan)
        # 更新 XHTTP 路径
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --arg path "${XHTTP_PATH}" '.inbounds[1].streamSettings.xhttpSettings.path = $path')"
        ;;
    fallback | sni)
        # 更新 Fallback 客户端 UUID 和 XHTTP 路径
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --arg uuid "${FALLBACK_UUID}" '.inbounds[2].settings.clients[0].id = $uuid')"
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --arg path "${XHTTP_PATH}" '.inbounds[2].streamSettings.xhttpSettings.path = $path')"
        ;;
    esac
    # 处理路由规则
    case "${XRAY_RULES_STATUS}" in
    0)
        # 保留当前路由规则
        XRAY_CONFIG="$(echo "${XRAY_CONFIG}" | jq --argjson rules "${XRAY_RULES}" '.routing.rules = $rules')"
        ;;
    1)
        # 重置并添加默认路由规则
        [[ "${XRAY_RULES_BT}" -eq 1 ]] && add_rule "bt" "protocol" "bittorrent" "block" 1
        [[ "${XRAY_RULES_CN}" -eq 1 ]] && add_rule "cn-ip" "ip" "geoip:cn" "block" "after" "private-ip"
        [[ "${XRAY_RULES_AD}" -eq 1 ]] && add_rule "ad-domain" "domain" "geosite:category-ads-all" "block"
        ;;
    esac
    # 处理 WARP 状态
    if [[ ${WARP_STATUS} -eq 1 ]]; then
        # 获取 WARP 容器 IP
        local container_ip
        container_ip="$(exec_docker '--obtain-container-ip')"
        # 构造 WARP Socks 出站配置 JSON
        local socks_config='[{"tag":"warp","protocol":"socks","settings":{"servers":[{"address":"'"${container_ip}"'","port":40001}]}}]'
        # 将 WARP 出站配置添加到 Xray 配置中
        XRAY_CONFIG=$(echo "${XRAY_CONFIG}" | jq --argjson socks_config "${socks_config}" '.outbounds += $socks_config')
    fi
    # 获取更新后的路由规则
    XRAY_RULES="$(echo "${XRAY_CONFIG}" | jq '.routing.rules')"
    # 更新脚本配置中的路由规则
    SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --argjson rules "${XRAY_RULES}" '.rules = $rules')"
    # 将更新后的脚本配置和 Xray 配置写入文件
    echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
    echo "${XRAY_CONFIG}" >"${XRAY_CONFIG_PATH}" && sleep 2
}

# =============================================================================
# 函数名称: cache_json_data
# 功能描述: 将 Xray 和脚本的配置文件内容读取到全局变量中进行缓存，
#           避免重复读取文件，提高脚本执行效率。
# 参数: 无
# 返回值: 无 (直接修改全局变量 XRAY_CONFIG 和 SCRIPT_CONFIG)
# =============================================================================
function cache_json_data() {
    # 读取 Xray 配置文件的完整 JSON 内容到全局变量 XRAY_CONFIG
    XRAY_CONFIG="$(jq '.' "${XRAY_CONFIG_PATH}")"
    # 读取脚本配置文件的完整 JSON 内容到全局变量 SCRIPT_CONFIG
    SCRIPT_CONFIG="$(jq '.' "${SCRIPT_CONFIG_PATH}")"
}

# =============================================================================
# 函数名称: get_common_config
# 功能描述: 从缓存的 Xray 和脚本配置中提取指定 inbound 索引的通用客户端配置参数，
#           并存储到 CLIENT_CONFIG 关联数组中。
# 参数:
#   $1: Xray 配置中 inbound 数组的索引 (inbound_index)
# 返回值: 无 (直接修改全局变量 CLIENT_CONFIG)
# =============================================================================
function get_common_config() {
    local inbound_index=$1 # 获取 inbound 索引参数

    # 获取服务器的公网 IPv4 地址作为远程主机地址
    CLIENT_CONFIG[remote_host]="$(curl -fsSL ipv4.icanhazip.com)"
    # 从脚本配置中获取端口号
    CLIENT_CONFIG[port]="$(echo "${SCRIPT_CONFIG}" | jq -r ".xray.port")"
    # 从脚本配置中获取 Reality 公钥
    CLIENT_CONFIG[public_key]="$(echo "${SCRIPT_CONFIG}" | jq -r ".xray.publicKey")"
    # 从脚本配置中获取配置标签 (tag)
    CLIENT_CONFIG[tag]="$(echo "${SCRIPT_CONFIG}" | jq -r ".xray.tag")"

    # 从 Xray 配置中获取协议类型 (如 vless, trojan)
    CLIENT_CONFIG[protocol]="$(echo "${XRAY_CONFIG}" | jq -r --argjson i "${inbound_index}" '.inbounds[$i].protocol? | if . == null then empty else . end')"
    # 从 Xray 配置中获取客户端 UUID (VLESS) 或密码 (Trojan)
    CLIENT_CONFIG[uuid]="$(echo "${XRAY_CONFIG}" | jq -r --argjson i "${inbound_index}" '.inbounds[$i].settings.clients[0].id? | if . == null then empty else . end')"
    # 从 Xray 配置中获取客户端密码 (Trojan)
    CLIENT_CONFIG[password]="$(echo "${XRAY_CONFIG}" | jq -r --argjson i "${inbound_index}" '.inbounds[$i].settings.clients[0].password? | if . == null then empty else . end')"
    # 从 Xray 配置中获取 mKCP 的种子 (seed)
    CLIENT_CONFIG[seed]="$(echo "${XRAY_CONFIG}" | jq -r --argjson i "${inbound_index}" '.inbounds[$i].streamSettings.kcpSettings.seed? | if . == null then empty else . end')"
    # 从 Xray 配置中获取网络传输类型 (如 tcp, kcp, xhttp)
    CLIENT_CONFIG[type]="$(echo "${XRAY_CONFIG}" | jq -r --argjson i "${inbound_index}" '.inbounds[$i].streamSettings.network? | if . == null then empty else . end')"
    # 从 Xray 配置中获取 Flow 控制参数 (如 xtls-rprx-vision)
    CLIENT_CONFIG[flow]="$(echo "${XRAY_CONFIG}" | jq -r --argjson i "${inbound_index}" '.inbounds[$i].settings.clients[0].flow? | if . == null then empty else . end')"
    # 从 Xray 配置中获取安全传输类型 (如 none, tls, reality)
    CLIENT_CONFIG[security]="$(echo "${XRAY_CONFIG}" | jq -r --argjson i "${inbound_index}" '.inbounds[$i].streamSettings.security? | if . == null then empty else . end')"
    # 从 Xray 配置中获取 XHTTP 的路径 (path)
    CLIENT_CONFIG[path]="$(echo "${XRAY_CONFIG}" | jq -r --argjson i "${inbound_index}" '.inbounds[$i].streamSettings.xhttpSettings.path? | if . == null then empty else . end')"
    # 从 Xray 配置中随机获取一个 Reality 的服务器名称 (serverNames)
    CLIENT_CONFIG[server_name]="$(echo "${XRAY_CONFIG}" | jq -r --argjson i "${inbound_index}" --argjson random "$(generate_random)" '.inbounds[$i].streamSettings.realitySettings.serverNames? | if . == null then empty else .[$random % length] end')"
    # 从 Xray 配置中随机获取一个 Reality 的 Short ID (shortIds)
    CLIENT_CONFIG[short_id]="$(echo "${XRAY_CONFIG}" | jq -r --argjson i "${inbound_index}" --argjson random "$(generate_random)" '.inbounds[$i].streamSettings.realitySettings.shortIds? | if . == null then empty else .[$random % length] end')"
}

# =============================================================================
# 函数名称: get_share_link_component
# 功能描述: 根据当前 CLIENT_CONFIG 中的参数，生成分享链接的各个组成部分。
#           这些组件可以被后续的特定链接生成函数组合使用。
# 参数: 无 (直接使用全局变量 CLIENT_CONFIG)
# 返回值: 无 (直接修改一系列 SHARE_LINK_COMPONENT_* 全局变量)
# =============================================================================
function get_share_link_component() {
    # 生成 VLESS 协议基础链接部分 (协议://UUID@地址:端口?网络类型=...)
    SHARE_LINK_COMPONENT_VLESS="${CLIENT_CONFIG[protocol]}://${CLIENT_CONFIG[uuid]}@${CLIENT_CONFIG[remote_host]}:${CLIENT_CONFIG[port]}?type=${CLIENT_CONFIG[type]}"

    # # 生成 Trojan 协议基础链接部分 (协议://密码@地址:端口?网络类型=...)
    # SHARE_LINK_COMPONENT_TROJAN="${CLIENT_CONFIG[protocol]}://${CLIENT_CONFIG[password]}@${CLIENT_CONFIG[remote_host]}:${CLIENT_CONFIG[port]}?type=${CLIENT_CONFIG[type]}"
    # # 生成 mKCP 网络传输参数部分 (&seed=...)
    # SHARE_LINK_COMPONENT_MKCP="&seed=${CLIENT_CONFIG[seed]}"
    # # 生成 TLS 安全传输参数部分 (&security=tls&sni=...&alpn=h2&fp=chrome)
    # SHARE_LINK_COMPONENT_TLS="&security=${CLIENT_CONFIG[security]}&sni=${CLIENT_CONFIG[server_name]}&alpn=h2&fp=chrome"

    # 生成 Reality 安全传输参数部分 (&security=reality&sni=...&pbk=...&sid=...&spx=%2F&fp=chrome)
    SHARE_LINK_COMPONENT_REALITY="&security=${CLIENT_CONFIG[security]}&sni=${CLIENT_CONFIG[server_name]}&pbk=${CLIENT_CONFIG[public_key]}&sid=${CLIENT_CONFIG[short_id]}&spx=%2F&fp=chrome"
    # 生成 XHTTP 网络传输路径参数部分 (&path=...), 注意去除路径开头的 '/'
    SHARE_LINK_COMPONENT_XHTTP="&path=%2F${CLIENT_CONFIG[path]#/}"
    # 生成 Flow 控制参数部分 (&flow=...)
    SHARE_LINK_COMPONENT_FLOW="&flow=${CLIENT_CONFIG[flow]}"

    # # 生成额外参数部分 (&extra=...), 使用之前编码好的 XHTTP_EXTRA_ENCODED
    # SHARE_LINK_COMPONENT_EXTRA="&extra=${XHTTP_EXTRA_ENCODED}"

}

# =============================================================================
# 函数名称: get_xhttp_share_link
# 功能描述: 为 XHTTP + Reality 网络传输类型生成完整的分享链接。
# 参数: 无 (直接使用全局变量 CLIENT_CONFIG 和 XHTTP_EXTRA)
# 返回值: 无 (直接修改全局变量 SHARE_LINK)
# =============================================================================
function get_xhttp_share_link() {
    # 获取分享链接的各个组件
    get_share_link_component
    # 将 VLESS 基础部分、Reality 安全参数和 XHTTP 路径参数拼接成完整链接
    SHARE_LINK="${SHARE_LINK_COMPONENT_VLESS}${SHARE_LINK_COMPONENT_REALITY}${SHARE_LINK_COMPONENT_XHTTP}"
}

# =============================================================================
# 函数名称: get_vision_share_link
# 功能描述: 为 Vision (XTLS) + Reality 网络传输类型生成完整的分享链接。
# 参数: 无 (直接使用全局变量 CLIENT_CONFIG)
# 返回值: 无 (直接修改全局变量 SHARE_LINK)
# =============================================================================
function get_vision_share_link() {
    # 获取分享链接的各个组件
    get_share_link_component
    # 将 VLESS 基础部分、Reality 安全参数和 Flow 控制参数拼接成完整链接
    SHARE_LINK="${SHARE_LINK_COMPONENT_VLESS}${SHARE_LINK_COMPONENT_REALITY}${SHARE_LINK_COMPONENT_FLOW}"
}

# =============================================================================
# 函数名称: show_client_config
# 功能描述: 在终端打印格式化的客户端配置信息。
# 参数: 无 (直接使用全局变量 CLIENT_CONFIG)
# 返回值: 无 (直接打印到标准输出)
# =============================================================================
function show_client_config() {
    # 使用 Here Document 打印客户端配置的标题和各项参数
    cat <<EOF
------------------ 客户端配置 (${CLIENT_CONFIG[tag]}) ------------------
address          : ${CLIENT_CONFIG[remote_host]}
port             : ${CLIENT_CONFIG[port]}
protocol         : ${CLIENT_CONFIG[protocol]}
uuid             : ${CLIENT_CONFIG[uuid]}
password(trojan) : ${CLIENT_CONFIG[password]}
seed(mKCP)       : ${CLIENT_CONFIG[seed]}
flow             : ${CLIENT_CONFIG[flow]}
network          : ${CLIENT_CONFIG[type]}
security         : ${CLIENT_CONFIG[security]}
ServerName       : ${CLIENT_CONFIG[server_name]}
path             : ${CLIENT_CONFIG[path]}
Fingerprint      : chrome
PublicKey        : ${CLIENT_CONFIG[public_key]}
ShortId          : ${CLIENT_CONFIG[short_id]}
SpiderX          : /
EOF
}

# =============================================================================
# 函数名称: show_config
# 功能描述: 打印完整的客户端配置信息、额外配置 (如果有的话)、
#           最终的分享链接以及对应的二维码。
# 参数: 无 (直接使用全局变量 CLIENT_CONFIG, XHTTP_EXTRA, SHARE_LINK, I18N_DATA)
# 返回值: 无 (直接打印到标准输出)
# =============================================================================
function show_config() {
    # 在分享链接末尾追加标签作为锚点 (例如 #my_tag)
    SHARE_LINK="${SHARE_LINK}#${CLIENT_CONFIG[tag]}"

    # 显示客户端配置信息
    show_client_config

    # 如果存在额外配置 (XHTTP_EXTRA)，则显示它
    # if [[ "${XHTTP_EXTRA}" ]]; then
    #     echo -e "------------------ $(echo "$I18N_DATA" | jq -r ".${CUR_FILE}.extra") ------------------"
    #     # 使用 jq 格式化输出额外配置的 JSON
    #     echo "${XHTTP_EXTRA}" | jq -r '.'
    # fi

    # 显示分享链接
    echo -e "------------------ 分享链接 ------------------"
    echo -e "${SHARE_LINK}"

    # 显示分享链接的二维码 (需要 qrencode 命令)
    echo -e "------------------ 二维码 ------------------"
    echo -e "${SHARE_LINK}" | qrencode -t ansiutf8

    # 打印分隔线结束
    echo -e "------------------------------------------------------"
}

# =============================================================================
# 函数名称: share_xray_link
# 功能描述: 生成 Xray 服务的客户端配置信息和分享链接 (如 VLESS, Trojan)。
#           根据服务端配置 (Xray 和 Script) 自动提取必要参数，
#           构造多种类型的分享链接 (包括 Reality, XHTTP, mKCP, TLS 等)，
#           并可选地生成二维码。
# 参数: 无
# 返回值: 无 (通过 systemctl 命令执行操作)
# =============================================================================
function share_xray_link() {

    # 缓存 Xray 和脚本配置数据
    cache_json_data

    # 获取第一个 inbound (index 1) 的通用配置
    get_common_config 1

    # 根据脚本配置中的 tag (转换为小写) 选择不同的处理分支
    case "$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.tag | ascii_downcase')" in
    # mkcp) get_mkcp_share_link ;;      # mKCP 模式
    xhttp) get_xhttp_share_link ;; # XHTTP 模式
    # trojan) get_trojan_share_link ;;  # Trojan 模式
    # fallback) show_fallback_config ;; # Fallback 模式
    # sni) show_sni_config ;;           # SNI 模式
    *) get_vision_share_link ;; # 默认为 Vision 模式
    esac

    # 显示最终的配置和链接信息 (重定向到标准错误输出 >&2，虽然不太常见)
    show_config

}

Xray_normal_install() {

    # 将配置标签存储到 CONFIG_DATA
    CONFIG_DATA['tag']="${XTLS_CONFIG}"

    # 检查脚本配置中的规则状态，如果是 current 或 reset 则读取规则输入
    if echo "${SCRIPT_CONFIG}" | jq -r '.xray.rules.reset' | grep -Eq '^(0|1)$'; then
        exec_read 'rules'
    fi

    # 如果规则状态不是 'n'，则读取阻止选项
    if [[ "${CONFIG_DATA['rules'],,}" != 'n' ]]; then
        exec_read 'block-bt'
        exec_read 'block-cn'
        exec_read 'block-ad'
    fi

    # 读取端口
    exec_read 'port'

    # 读取 UUID
    exec_read 'uuid'

    # 读取目标域名
    exec_read 'target'

    # 读取 Short IDs
    exec_read 'short'

    case "${XTLS_CONFIG,,}" in
    xhttp) exec_read 'path' ;; # 读取路径
    esac

    handler_script_config

    handler_install

    handler_x25519_config

    handler_xray_config

    handler_restart

    share_xray_link

}

# ===========================================================================
# Xray_quick_install - Xray 一键（无交互）安装
#
# 从 SCRIPT_CONFIG（~/.xray-script/config.json 的内存版）读取字段，校验后
# 翻译为 CONFIG_DATA，复用 Xray_normal_install 同款 handler 管线。
#
# 字段规则见 docs/superpowers/specs/2026-05-11-xray-quick-install-design.md
# ===========================================================================
Xray_quick_install() {
    _info "一键安装：使用 ~/.xray-script/config.json 的已有值，缺失字段自动生成"

    # tag 由外部 XTLS_CONFIG 决定（install_xray_server 菜单预先选定）
    CONFIG_DATA['tag']="${XTLS_CONFIG}"

    # port: 空/0 走默认 443；非空须 1-65535
    local q_port
    q_port="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.port // empty')"
    if [[ -n "${q_port}" && "${q_port}" != "0" ]]; then
        if [[ ! "${q_port}" =~ ^[0-9]+$ || "${q_port}" -lt 1 || "${q_port}" -gt 65535 ]]; then
            _error "xray.port 非法: ${q_port}（须为 1-65535 的整数）"
            return 1
        fi
        CONFIG_DATA['port']="${q_port}"
    fi

    # uuid: 空则让 handler 走 generate_uuid 随机；非空原样传入
    local q_uuid
    q_uuid="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.uuid // empty')"
    [[ -n "${q_uuid}" ]] && CONFIG_DATA['uuid']="${q_uuid}"

    # target: 空则让 handler 随机选；非空须通过 domain_check
    local q_target
    q_target="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.target // empty')"
    if [[ -n "${q_target}" ]]; then
        if ! domain_check "${q_target}"; then
            _error "xray.target 非法域名: ${q_target}"
            return 1
        fi
        CONFIG_DATA['target']="${q_target}"
    fi

    # path: 仅 XHTTP 处理；空则 handler 自动生成；非空须通过 path_check
    if [[ "${XTLS_CONFIG,,}" == "xhttp" ]]; then
        local q_path
        q_path="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.path // empty')"
        if [[ -n "${q_path}" ]]; then
            if ! path_check "${q_path}"; then
                _error "xray.path 非法: ${q_path}"
                return 1
            fi
            CONFIG_DATA['path']="${q_path}"
        fi
    fi

    # shortIds: [] / [""] / 全空串 视为未设置 → handler 用 "8 8" 生成
    local q_sid_unset
    q_sid_unset="$(echo "${SCRIPT_CONFIG}" | jq -r '
        .xray.shortIds |
        if type != "array" or length == 0 or all(. == "") then "true" else "false" end
    ')"
    if [[ "${q_sid_unset}" == "false" ]]; then
        local -a q_sids=()
        while IFS= read -r sid; do
            q_sids+=("${sid}")
        done < <(echo "${SCRIPT_CONFIG}" | jq -r '.xray.shortIds[]')
        for sid in "${q_sids[@]}"; do
            if [[ -n "${sid}" ]] && ! shortid_check "${sid}"; then
                _error "xray.shortIds 含非法值: ${sid}"
                return 1
            fi
        done
        # handler_script_config 内部通过 IFS=' ' 重新拆分，所以这里用空格连接
        CONFIG_DATA['short_ids']="${q_sids[*]}"
    fi

    # 路由规则开关：1→Y，其他→N
    local q_bt q_cn q_ad
    q_bt="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.rules.bt')"
    q_cn="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.rules.cn')"
    q_ad="$(echo "${SCRIPT_CONFIG}" | jq -r '.xray.rules.ad')"
    [[ "${q_bt}" == "1" ]] && CONFIG_DATA['block-bt']='Y' || CONFIG_DATA['block-bt']='N'
    [[ "${q_cn}" == "1" ]] && CONFIG_DATA['block-cn']='Y' || CONFIG_DATA['block-cn']='N'
    [[ "${q_ad}" == "1" ]] && CONFIG_DATA['block-ad']='Y' || CONFIG_DATA['block-ad']='N'

    # rules: quick 模式固定 Y（等价 reset=1，按开关重算规则）
    # 待 rules.reset 机制清理后可移除本行，详见 memory: project_sysset_cleanup_backlog
    CONFIG_DATA['rules']='Y'

    # 复用 normal 模式同款 handler 管线
    handler_script_config
    handler_install
    handler_x25519_config
    handler_xray_config
    handler_restart

    # 分享链接（其内部三个 read -rp 保持不变，回车即全选，与 normal 一致）
    share_xray_link
}

install_xray_server() {

    if command -v xray &>/dev/null; then
        _info "Xray Server 已安装！"
        return 1
    fi

    # 检查依赖，如果缺失则安装
    if ! check_xray_dependencies; then
        install_xray_dependencies
    fi

    # 再次检查依赖 (安装后)
    if ! check_xray_dependencies; then
        install_xray_dependencies
    fi

    # 检查脚本配置目录和配置文件是否存在，如果不存在则创建并下载默认配置
    if [[ ! -d "${SCRIPT_CONFIG_DIR}" && ! -f "${SCRIPT_CONFIG_PATH}" ]]; then

        mkdir -p "${SCRIPT_CONFIG_DIR}"
        wget -O "${SCRIPT_CONFIG_PATH}" https://raw.githubusercontent.com/faintx/public/refs/heads/main/Xconfigs/config.json
        mkdir -p "${SCRIPT_CONFIG_DIR}/config"
        wget -O "${SCRIPT_CONFIG_DIR}/config/Vision.json" https://raw.githubusercontent.com/faintx/public/refs/heads/main/Xconfigs/config/Vision.json
        wget -O "${SCRIPT_CONFIG_DIR}/config/XHTTP.json" https://raw.githubusercontent.com/faintx/public/refs/heads/main/Xconfigs/config/XHTTP.json

        SCRIPT_CONFIG="$(jq --arg path "${SCRIPT_CONFIG_DIR}" '.path = $path' "${SCRIPT_CONFIG_PATH}")"
        echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2

    fi

    # # 从脚本配置文件中读取已记录的安装路径
    # local script_path
    # script_path="$(jq -r '.path' "${SCRIPT_CONFIG_PATH}")"
    # # 如果配置文件中没有记录路径，且命令行也未指定，则使用默认路径
    # if [[ -z "${script_path}" && -z "${PROJECT_ROOT}" ]]; then
    #     PROJECT_ROOT='/usr/local/xray-script' # 设置默认项目根目录
    #     # 将默认路径更新到脚本配置文件中
    #     SCRIPT_CONFIG="$(jq --arg path "${PROJECT_ROOT}" '.path = $path' "${SCRIPT_CONFIG_PATH}")"
    #     echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2

    # # 如果配置文件中已有记录的路径，则使用该路径
    # elif [[ -n "${script_path}" ]]; then
    #     PROJECT_ROOT="${script_path}"

    # fi

    # # 检查项目根目录是否存在
    # if [[ -d "${PROJECT_ROOT}" ]]; then
    #     # 如果存在，则检查版本更新
    #     check_xray_script_version
    # else
    #     # 如果不存在，则下载项目文件
    #     download_xray_script_files "${PROJECT_ROOT}"
    # fi

    # 获取最新的 release 版本
    CONFIG_DATA['version']="$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name')"

    # 更新脚本配置中的 Xray 版本
    # SCRIPT_CONFIG="$(echo "${SCRIPT_CONFIG}" | jq --arg xray "${CONFIG_DATA['version']}" '.xray.version = $xray')"
    SCRIPT_CONFIG="$(jq --arg xray "${CONFIG_DATA['version']}" '.xray.version = $xray' "${SCRIPT_CONFIG_PATH}")"
    # 将更新后的脚本配置写入文件
    echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2

    echo
    echoEnhance gray "========================================="
    echoEnhance blue "选择传输协议配置类型"
    echoEnhance gray "========================================="
    echoEnhance silver "1. Vision (VLESS+Vision+REALITY) (默认)"
    echoEnhance silver "2. XHTTP  (VLESS+XHTTP+REALITY)"
    echoEnhance gray "———————————————————————————————————"
    echoEnhance magenta "[INFO] 1. XTLS(Vision) 解决 TLS in TLS 问题"
    echoEnhance magenta "[INFO] 2. XTLS(XHTTP) 全场景通吃的时代正式到来(详情: https://github.com/XTLS/Xray-core/discussions/4113"
    echoEnhance magenta "[INFO]   2.1 XHTTP 默认有多路复用，延迟比 Vision 低但多线程测速不如它"
    echoEnhance magenta "[INFO]   2.2 此外 v2rayN&G 客户端有全局 mux.cool 设置，用 XHTTP 前记得关闭，不然连不上新版 Xray 服务端"
    echoEnhance gray "========================================="
    echo
    read -rp "请输入序号:" num
    case "${num}" in
    1)
        XTLS_CONFIG="Vision"
        ;;
    2)
        XTLS_CONFIG="XHTTP"
        ;;
    *)
        XTLS_CONFIG="Vision"
        ;;
    esac

    if ! check_xray_config_exists "${XTLS_CONFIG}"; then
        exit 1
    fi

    echo
    echoEnhance gray "========================================="
    echoEnhance blue "选择通讯协议配置类型"
    echoEnhance gray "========================================="
    echoEnhance silver "1. 一键快速安装 (默认, 使用 ~/.xray-script/config.json 的已有值, 缺失则自动生成)"
    echoEnhance silver "2. 进入 Xray 配置流程 (逐项询问)"
    echoEnhance gray "========================================="
    echo
    read -rp "请输入序号:" num
    case "${num}" in
    1)
        Xray_quick_install
        ;;
    2)
        Xray_normal_install
        ;;
    *)
        Xray_quick_install
        ;;
    esac

}

purge_xray_server() {
    # 调用 Xray-install 脚本进行卸载 (带 --purge 参数)
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
    # 重置 xray 字段
    SCRIPT_CONFIG=$(reset_json_fields "${SCRIPT_CONFIG}" 'xray')
    # 将重置后的脚本配置写入文件
    echo "${SCRIPT_CONFIG}" >"${SCRIPT_CONFIG_PATH}" && sleep 2
}

# =============================================================================
# 函数名称: handler_start
# 功能描述: 启动 Xray 服务。
#           1. 检查 Xray 服务是否已在运行。
#           2. 如果未运行则启动服务。
#           3. 检查 Xray 服务是否已设置开机自启。
#           4. 如果未设置则启用开机自启。
# 参数: 无
# 返回值: 无 (通过 systemctl 命令执行操作)
# =============================================================================
function handler_start() {
    # 检查 Xray 服务是否活跃，如果不活跃则启动
    systemctl -q is-active xray || systemctl -q start xray
    # 检查 Xray 服务是否已启用，如果未启用则启用
    systemctl -q is-enabled xray || systemctl -q enable xray
}

# =============================================================================
# 函数名称: handler_stop
# 功能描述: 停止 Xray 服务。
#           1. 检查 Xray 服务是否正在运行。
#           2. 如果正在运行则停止服务。
#           3. 检查 Xray 服务是否已设置开机自启。
#           4. 如果已设置则禁用开机自启。
# 参数: 无
# 返回值: 无 (通过 systemctl 命令执行操作)
# =============================================================================
function handler_stop() {
    # 检查 Xray 服务是否活跃，如果活跃则停止
    systemctl -q is-active xray && systemctl -q stop xray
    # 检查 Xray 服务是否已启用，如果启用则禁用
    systemctl -q is-enabled xray && systemctl -q disable xray
}

# =============================================================================
# 函数名称: handler_restart
# 功能描述: 重启 Xray 服务。
#           1. 检查 Xray 服务是否正在运行。
#           2. 如果正在运行则重启服务，否则启动服务。
#           3. 检查 Xray 服务是否已设置开机自启。
#           4. 如果未设置则启用开机自启。
# 参数: 无
# 返回值: 无 (通过 systemctl 命令执行操作)
# =============================================================================
function handler_restart() {
    # 检查 Xray 服务是否活跃，如果活跃则重启，否则启动
    systemctl -q is-active xray && systemctl -q restart xray || systemctl -q start xray
    # 检查 Xray 服务是否已启用，如果未启用则启用
    systemctl -q is-enabled xray || systemctl -q enable xray
}

update_xray_server() {

    _info "判断 Xray 是否用新版本"

    local current_xray_version
    current_xray_version="$(jq -r '.xray.version' "${XRAY_COINFIG_PATH}config.json")"

    local latest_xray_version
    latest_xray_version="$(wget -qO- --no-check-certificate https://api.github.com/repos/XTLS/Xray-core/releases | jq -r '.[0].tag_name ' | cut -d v -f 2)"

    # if _version_ge "${latest_xray_version}" "${current_xray_version}"; then
    if [ "${latest_xray_version}" != "${current_xray_version}" ]; then
        _info "检测到有新版可用"
        install_update_xray
    else
        _info "当前已是最新版本: ${current_xray_version}"
    fi

}

function purge_xray() {

    _info "正在卸载 Xray"

    crontab -l | grep -v "/usr/local/etc/xray-script/update-dat.sh >/dev/null 2>&1" | crontab -

    _systemctl "stop" "xray"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge

    rm -rf /etc/systemd/system/xray.service
    rm -rf /etc/systemd/system/xray@.service
    rm -rf /usr/local/bin/xray
    rm -rf /usr/local/etc/xray
    rm -rf /usr/local/share/xray
    rm -rf /var/log/xray

}

uninstall_xray_server() {

    purge_xray

    [[ -f ${XRAY_COINFIG_PATH}sysctl.conf.bak ]] && mv -f "${XRAY_COINFIG_PATH}sysctl.conf.bak" /etc/sysctl.conf && _info "已还原网络连接设置"
    rm -rf "${XRAY_COINFIG_PATH}"

    if docker ps | grep -q cloudflare-warp; then
        _info '正在停止 cloudflare-warp'
        docker container stop cloudflare-warp
        docker container rm cloudflare-warp
    fi

    if docker images | grep -q e7h4n/cloudflare-warp; then
        _info '正在卸载 cloudflare-warp'
        docker image rm e7h4n/cloudflare-warp
    fi

    # rm -rf "${HOME}"/.warp
    # _info 'Docker 请自行卸载'

    _info "Xray-REALITY Server 已经完成卸载."

}

edit_xray_config() {

    while true; do
        [[ true = "${is_close}" ]] && break
        echo
        echoEnhance gray "========================================="
        echoEnhance blue "Xray-REALITY Server 修改配置"
        echoEnhance gray "========================================="
        echoEnhance silver "1. 修改 uuid"
        echoEnhance silver "2. 修改 target"
        echoEnhance silver "3. 修改 x25519 key"
        echoEnhance silver "4. 修改 shortIds"
        echoEnhance silver "5. 修改 xray 监听端口"
        echoEnhance silver "6. 刷新已有的 shortIds (重新自动生成新的)"
        echoEnhance silver "7. 追加自定义 shortIds"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance cyan "0. 返回上级菜单"
        echoEnhance gray "========================================="

        read -rp "请输入序号:" num
        case "${num}" in
        1)
            read_uuid
            _info "正在修改用户 id"
            "${XRAY_CONFIG_MANAGER}" -u "${in_uuid}"
            _info "已成功修改用户 id"
            _systemctl "restart" "xray"
            show_xray_config
            ;;
        2)
            _info "正在修改 target 与 serverNames"
            select_dest
            "${XRAY_CONFIG_MANAGER}" -d "$(jq -r '.xray.dest' "${XRAY_COINFIG_PATH}config.json" | grep -Eoi '([a-zA-Z0-9](\-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}')"
            "${XRAY_CONFIG_MANAGER}" -sn "$(jq -c -r '.xray | .serverNames[.dest] | .[]' "${XRAY_COINFIG_PATH}config.json" | tr '\n' ',')"
            _info "已成功修改 dest 与 serverNames"
            _systemctl "restart" "xray"
            show_xray_config
            ;;
        3)
            _info "正在修改 x25519 key"

            local xray_x25519
            xray_x25519=$(xray x25519)

            local xs_private_key
            xs_private_key=$(echo "${xray_x25519}" | head -1 | awk '{print $3}')

            local xs_public_key
            xs_public_key=$(echo "${xray_x25519}" | tail -n 1 | awk '{print $3}')

            # Xray-script config.json
            jq --arg privateKey "${xs_private_key}" '.xray.privateKey = $privateKey' "${XRAY_COINFIG_PATH}config.json" >"${XRAY_COINFIG_PATH}new.json" && mv -f "${XRAY_COINFIG_PATH}new.json" "${XRAY_COINFIG_PATH}config.json"
            jq --arg publicKey "${xs_public_key}" '.xray.publicKey = $publicKey' "${XRAY_COINFIG_PATH}config.json" >"${XRAY_COINFIG_PATH}new.json" && mv -f "${XRAY_COINFIG_PATH}new.json" "${XRAY_COINFIG_PATH}config.json"

            # Xray-core config.json
            "${XRAY_CONFIG_MANAGER}" -x "${xs_private_key}"
            _info "已成功修改 x25519 key"
            _systemctl "restart" "xray"
            show_xray_config
            ;;
        4)
            _info "shortId 值定义: 接受一个十六进制数值 ，长度为 2 的倍数，长度上限为 16"
            _info "shortId 列表默认为值为[\"\"]，若有此项，客户端 shortId 可为空"
            read -rp "请输入自定义 shortIds 值，多个值以英文逗号进行分隔: " sid_str
            _info "正在修改 shortIds"
            "${XRAY_CONFIG_MANAGER}" -sid "${sid_str}"
            _info "已成功修改 shortIds"
            _systemctl "restart" "xray"
            show_xray_config
            ;;
        5)
            local xs_port
            xs_port=$(jq '.inbounds[] | select(.tag == "xray-script-xtls-reality") | .port' "${XRAY_COINFIG_PATH}config.json")
            read_port "当前 xray 监听端口为: ${xs_port}" "${xs_port}"
            if [[ "${new_port}" && ${new_port} -ne ${xs_port} ]]; then
                "${XRAY_CONFIG_MANAGER}" -p "${new_port}"
                _info "当前 xray 监听端口已修改为: ${new_port}"
                _systemctl "restart" "xray"
                show_xray_config
            fi
            ;;
        6)
            _info "正在修改 shortIds"
            "${XRAY_CONFIG_MANAGER}" -rsid
            _info "已成功修改 shortIds"
            _systemctl "restart" "xray"
            show_xray_config
            ;;
        7)
            until [ ${#sid_str} -gt 0 ] && [ ${#sid_str} -le 16 ] && [ $((${#sid_str} % 2)) -eq 0 ]; do
                _info "shortId 值定义: 接受一个十六进制数值 ，长度为 2 的倍数，长度上限为 16"
                read -rp "请输入自定义 shortIds 值，不能为空，多个值以英文逗号进行分隔: " sid_str
            done
            _info "正在添加自定义 shortIds"
            "${XRAY_CONFIG_MANAGER}" -asid "${sid_str}"
            _info "已成功添加自定义 shortIds"
            _systemctl "restart" "xray"
            show_xray_config
            ;;
        0)
            break
            ;;
        *)
            _warn "输入错误数字:${num}，请重新输入 ！"
            ;;
        esac
    done

}

# 3. 配置管理 Xray-REALITY Server
config_xray_server() {

    while true; do
        [[ true = "${is_close}" ]] && break
        echo
        echoEnhance gray "========================================="
        echoEnhance blue "配置管理 Xray Server"

        if [ -f "${SCRIPT_CONFIG_PATH}" ]; then
            SCRIPT_CONFIG="$(jq '.' "${SCRIPT_CONFIG_PATH}")" # 存储从 config.json 读取的脚本配置
            # local current_xray_version
            # current_xray_version="$(jq -r '.xray.version' "${XRAY_COINFIG_PATH}config.json")"
            # if [ -n "${current_xray_version}" ]; then
            #     echoEnhance green "当前 Xray 版本：${current_xray_version}"
            # fi
        fi

        echoEnhance gray "========================================="
        echoEnhance silver "1. 安装"
        echoEnhance silver "2. 更新"
        echoEnhance silver "3. 卸载"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance silver "4. 启动"
        echoEnhance silver "5. 停止"
        echoEnhance silver "6. 重启"
        echoEnhance silver "11. 查看服务状态"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance silver "7. 修改配置"
        echoEnhance silver "8. 查看配置信息"
        echoEnhance silver "9. 信息统计"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance cyan "0. 返回上级菜单"
        echoEnhance gray "========================================="

        read -rp "请输入序号:" num

        # if [ -d "${XRAY_COINFIG_PATH}" ]; then
        #     wget -qO "${XRAY_CONFIG_MANAGER}" https://raw.githubusercontent.com/faintx/public/main/tools/xray_config_manager.sh
        #     chmod a+x "${XRAY_CONFIG_MANAGER}"
        # fi

        case "${num}" in
        1)
            install_xray_server
            ;;
        2)
            update_xray_server
            ;;
        3)
            purge_xray_server
            ;;
        4)
            handler_start
            ;;
        5)
            handler_stop
            ;;
        6)
            handler_restart
            ;;
        7)
            edit_xray_config
            ;;
        8)
            show_xray_config
            ;;
        9)
            [[ -f "${XRAY_CONFIG_MANAGER}traffic.sh" ]] || wget -O "${XRAY_CONFIG_MANAGER}traffic.sh" https://raw.githubusercontent.com/faintx/public/main/tools/traffic.sh
            bash "${XRAY_CONFIG_MANAGER}traffic.sh"
            ;;
        11)
            systemctl status xray
            ;;
        0)
            break
            ;;
        *)
            _warn "输入错误数字:${num}，请重新输入 ！"
            ;;
        esac

    done

}

start_menu() {
    # clear

    while true; do
        [[ true = "${is_close}" ]] && break

        echo
        echoEnhance gray "========================================="
        echoEnhance blue "System Set Up 管理脚本"
        echoEnhance green "当前版本：${shell_version}"
        echoEnhance green "系统信息：${osInfo[NAME]}" "${osInfo[VERSION]}"
        echoEnhance gray "========================================="
        echoEnhance silver "1. 操作系统配置"
        echoEnhance silver "2. 配置管理 KMS Server"
        echoEnhance silver "3. 配置管理 Xray Server"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance silver "99. 更新此脚本"
        echoEnhance gray "———————————————————————————————————"
        echoEnhance cyan "0. 退出"
        echoEnhance gray "========================================="

        read -rp "请输入序号:" num
        case "${num}" in
        99)
            update_shell
            ;;
        1)
            system_config
            ;;
        2)
            config_kms_server
            ;;
        3)
            config_xray_server
            ;;
        0)
            break
            ;;
        *)
            _warn "输入错误数字:${num}，请重新输入 ！"
            ;;
        esac
    done

    # 获取所有键和值
    # echo "OS Information Details:"
    # for key in "${!osInfo[@]}"; do
    #     echo "$key: ${osInfo[$key]}"
    # done

}
start_menu
