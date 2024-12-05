#!/usr/bin/env bash

shell_version="1.3.2"

declare -A osInfo

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
    sh_new_ver=$(curl https://raw.githubusercontent.com/faintx/public/main/syssetup.sh | grep 'shell_version="' | awk -F "=" '{print $NF}' | sed 's/\"//g' | head -1)
    [[ -z "${sh_new_ver}" ]] && _warn "检测最新版本失败 !" && return
    if [[ ${sh_new_ver} != "${shell_version}" ]]; then
        echo "发现新版本[ ${sh_new_ver} ]，是否更新？[Y/n]"
        read -rp "(默认:y):" yn
        [[ -z "${yn}" ]] && yn="y"
        if [[ ${yn} == [Yy] ]]; then
            curl -o syssetup.sh https://raw.githubusercontent.com/faintx/public/main/syssetup.sh && chmod +x syssetup.sh
            _info "脚本已更新为最新版本[ ${sh_new_ver} ]！"
            echo "3s后执行新脚本..."
            sleep 3s
            is_close=true
            bash syssetup.sh
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

install_dependencies() {

    _info "正在下载相关依赖 ..."

    ${installPackage} ca-certificates openssl curl wget jq tzdata

    case "${osInfo[ID]}" in
    centos)
        ${installPackage} crontabs util-linux iproute procps-ng
        ;;
    debian | ubuntu)
        ${installPackage} cron bsdmainutils iproute2 procps
        ;;
    esac

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

install_xray_server() {

    if command -v xray &>/dev/null; then
        _info "Xray-REALITY Server 已安装！"
        return 1
    fi

    if [[ ! -d "${XRAY_COINFIG_PATH}" ]]; then
        mkdir -p "${XRAY_COINFIG_PATH}"

        wget -O "${XRAY_COINFIG_PATH}config.json" https://raw.githubusercontent.com/faintx/public/main/configs/config.json
        wget -O "${XRAY_CONFIG_MANAGER}" https://raw.githubusercontent.com/faintx/public/main/tools/xray_config_manager.sh
        chmod a+x "${XRAY_CONFIG_MANAGER}"

        install_dependencies
        install_update_xray

        # 设置 Xray 端口
        local xs_port
        xs_port=$(jq '.xray.port' "${XRAY_COINFIG_PATH}config.json")
        read_port "xray config 配置默认使用: ${xs_port}" "${xs_port}"

        # 设置 Xray UUID
        read_uuid

        # 设置 Xray REALITY target & serverNames
        select_dest

        # 设置 Xray 配置文件
        config_xray

        # 显示配置信息 & 生成分享链接
        show_xray_config

        _info "Xray-REALITY Server 安装成功！"
    else
        _info "Xray-REALITY Server 已安装！"
    fi
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
        echoEnhance blue "配置管理 Xray-REALITY Server"

        if [ -f "${XRAY_COINFIG_PATH}config.json" ]; then
            local current_xray_version
            current_xray_version="$(jq -r '.xray.version' "${XRAY_COINFIG_PATH}config.json")"
            if [ -n "${current_xray_version}" ]; then
                echoEnhance green "当前 Xray 版本：${current_xray_version}"
            fi
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

        if [ -d "${XRAY_COINFIG_PATH}" ]; then
            wget -qO "${XRAY_CONFIG_MANAGER}" https://raw.githubusercontent.com/faintx/public/main/tools/xray_config_manager.sh
            chmod a+x "${XRAY_CONFIG_MANAGER}"
        fi

        case "${num}" in
        1)
            install_xray_server
            ;;
        2)
            update_xray_server
            ;;
        3)
            uninstall_xray_server
            ;;
        4)
            _systemctl "start" "xray"
            ;;
        5)
            _systemctl "stop" "xray"
            ;;
        6)
            _systemctl "restart" "xray"
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
        echoEnhance silver "3. 配置管理 Xray-REALITY Server"
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
