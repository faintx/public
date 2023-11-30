#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

sh_ver="1.2.5"
SSHConfig="/etc/ssh/sshd_config"
fail2ban_dir="/root/fail2ban/"
FOLDER="/etc/ss-rust"
SSRUST_FILE="/usr/local/bin/ss-rust"
V2RAY_FILE="/usr/local/bin/v2ray-plugin"
CONF="/etc/ss-rust/config.json"
Now_ssrust_ver_File="/etc/ss-rust/ssrust_ver.txt"
Now_v2ray_ver_File="/etc/ss-rust/v2ray_ver.txt"
Local="/etc/sysctl.d/local.conf"
kms_file="/usr/bin/vlmcsd"
kms_pid="/var/run/vlmcsd.pid"
Now_kms_ver_File="/var/run/vlmcsd_ver.txt"
SSCLIENT_FILE="/usr/bin/sslocal"
SSCLIENT_V2RAY_FILE="/usr/bin/v2ray-plugin"
SSCLIENT_CONF="/etc/ssclient/local.json"
PRIVOXY_CONF="/etc/privoxy/config"
PROFILE_CONF="/etc/profile"
is_close=false

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m" && Yellow_font_prefix="\033[0;33m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"

check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && return 4
}

check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi
}

sysArch() {
    uname=$(uname -m)
    if [[ "$uname" == "i686" ]] || [[ "$uname" == "i386" ]]; then
        arch="i686"
    elif [[ "$uname" == *"armv7"* ]] || [[ "$uname" == "armv6l" ]]; then
        arch="arm"
    elif [[ "$uname" == *"armv8"* ]] || [[ "$uname" == "aarch64" ]]; then
        arch="aarch64"
    else
        arch="x86_64"
    fi
}

_exists() {
    local cmd="$1"
    if eval type type >/dev/null 2>&1; then
        eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
        command -v "$cmd" >/dev/null 2>&1
    else
        which "$cmd" >/dev/null 2>&1
    fi
    local rt=$?
    return ${rt}
}

_os() {
    local os=""
    [ -f "/etc/debian_version" ] && source /etc/os-release && os="${ID}" && printf -- "%s" "${os}" && return
    [ -f "/etc/redhat-release" ] && os="centos" && printf -- "%s" "${os}" && return
}

_os_full() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

_os_ver() {
    local main_ver="$(echo $(_os_full) | grep -oE "[0-9.]+")"
    printf -- "%s" "${main_ver%%.*}"
}

change_repo() {
    cat /etc/redhat-release
    echo "确定要切换至阿里源 （CentOS Stream 未实现，不要换） ? (y/N)"
    echo
    read -e -p "(默认：n)：" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Nn] ]]; then
        Start_Menu
        $is_close=true
        return
    fi

    case "$(_os)" in
    centos)
        sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
        sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
        if [ -n "$(_os_ver)" ]; then
            if [ "$(_os_ver)" -eq 7 ]; then
                echo -e "${Info} 开始切换 CentOS 7 源 ......"
                curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
            elif [ "$(_os_ver)" -eq 8 ]; then
                echo -e "${Info} 开始切换 CentOS 8 源 ......"
                curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo
            else
                echo -e "${Error} 暂不支持该系统版本."
                mv /etc/yum.repos.d/CentOS-Base.repo.backup /etc/yum.repos.d/CentOS-Base.repo
                return
            fi

            if [[ $? -eq 0 ]]; then
                #mv CentOS-Linux-AppStream.repo CentOS-Linux-AppStream.repo.bak
                #mv CentOS-Linux-BaseOS.repo CentOS-Linux-BaseOS.repo.bak
                yum clean all && yum makecache
                yum update -y
            else
                echo -e "${Error} 下载 repo 文件失败."
                mv /etc/yum.repos.d/CentOS-Base.repo.backup /etc/yum.repos.d/CentOS-Base.repo
            fi
        fi
        ;;
    ubuntu | debian)
        echo -e "${Info} 暂不支持该系统."
        ;;
    *) ;; # do nothing
    esac
}

view_selinux() {
    selinux_con=($(sed -n '/^SELINUX=/p' /etc/selinux/config))
    echo -e "${Info} SELinux 配置：${selinux_con}"
    sestatus
    set_selinux
}

disable_selinux() {
    selinux_con=($(sed -n '/^SELINUX=/p' /etc/selinux/config))
    echo -e "${Info} SELinux 配置：${selinux_con}"
    if [ ${selinux_con} != "SELINUX=disabled" ]; then
        #sed -i 's/^SELINUX=/#SELINUX=/g' /etc/selinux/config
        #echo "SELINUX=disabled" >>/etc/selinux/config
        sed -i "s/${selinux_con}/SELINUX=disabled/g" /etc/selinux/config
        echo -e "${Info} SELinux 配置已关闭，需要重启生效."
    fi
    set_selinux
}

set_selinux() {
    echo -e "设置 SELinux
==================================
${Green_font_prefix} 1. 查看 SELinux 配置 ${Font_color_suffix}
${Red_font_prefix} 2. 关闭 SELinux ${Font_color_suffix}
———————————————————————————————————
${Yellow_font_prefix} 0. 退出${Font_color_suffix}
=================================="
    read -e -p "(请输入序号)：" num
    case "${num}" in
    1)
        view_selinux
        ;;
    2)
        disable_selinux
        ;;
    0)
        Start_Menu
        $is_close=true
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        set_selinux
        ;;
    esac
}

set_ssh_port() {
    [[ ! -e ${SSHConfig} ]] && echo -e "${Error} SSH 配置文件不存在，请检查！" && return

    selinux_con=($(sed -n '/^SELINUX=/p' /etc/selinux/config))
    echo -e "${Info} SELinux 配置：${selinux_con}"
    if [ ${selinux_con} != "SELINUX=disabled" ]; then
        echo -e "${Info} SELinux 未关闭，更改 SSH 端口会无法连接."
        return
    fi

    old_IFS=IFS
    IFS=$'\n'
    old_port=($(sed -n '/^Port /p' ${SSHConfig}))
    len=${#old_port[*]}
    echo -e "${Info} 原 SSH 端口:"
    echo "----------"
    for ((i = 0; i < $len; i++)); do
        echo "${old_port[$i]}"
    done
    echo "----------"
    IFS=old_IFS

    while true; do
        read -e -p "请输入你想要设置的 SSH 端口(1-65535)(exit或q退出设置)：" sshport
        [[ $sshport == "exit" || $sshport == [Qq] ]] && break
        expr ${sshport} + 0 &>/dev/null
        if [[ $? -ne 0 || "$sshport" -le 0 || "$sshport" -gt 65535 ]]; then
            echo -e "${Error}输入了错误的端口:${sshport}，请重新输入 ！" && echo
            continue
        else
            #sed -i "s/Port 22/Port ${sshport}/g" ${SSHConfig}
            sed -i '/^Port /s/^\(.*\)$/#\1/g' "$SSHConfig"
            echo -e "${Info}屏蔽原 SSH 端口成功 ！" && echo

            echo "Port ${sshport}" >>"$SSHConfig"
            echo -e "${Info}设置新的 SSH 端口 成功！"
            echo "Port ${sshport}" && echo
            systemctl enable sshd
            systemctl restart sshd
            break
        fi
    done
}

install_service() {
    if ! type "$1" >/dev/null 2>&1; then
        echo -e "${Info}开始安装 $1 ......"
        yum install -y "$1"
    else
        echo -e "${Info} $1 已安装."
    fi

    if systemctl is-active "$1" &>/dev/null; then
        echo -e "${Info} $1 已启动."
    else
        echo -e "${Info}开始启动 $1 ......"
        systemctl start "$1"
    fi

    if systemctl is-enabled "$1" &>/dev/null; then
        echo -e "${Info} $1 是开机自启动项."
    else
        echo -e "${Info}设置开机启动 $1 ......"
        systemctl enable "$1"
    fi
}

open_firewall_port() {
    install_service firewalld

    if _exists "iptables"; then
        if systemctl is-active iptables &>/dev/null; then
            echo -e "${Info} 停用 iptables，有时会影响 firewalld 启动." && echo
            systemctl stop iptables
            systemctl disable iptables
        fi
    fi

    echo -e "${Info} 已打开端口：$(firewall-cmd --zone=public --list-ports)." && echo

    while true; do
        read -e -p "请输入你想要打开 firewalld 端口(1-65535)(exit或q退出设置)：" port
        [[ $port == "exit" || $port == [Qq] ]] && break
        expr ${port} + 0 &>/dev/null
        if [[ $? -ne 0 || "$port" -le 0 || "$port" -gt 65535 ]]; then
            echo -e "${Error}输入了错误的端口:${port}，请重新输入 ！" && echo
            continue
        else
            echo -e "${Info}打开端口 $port ......"
            firewall-cmd --zone=public --add-port=$port/tcp --permanent
            echo -e "${Info}重新加载配置 ......"
            firewall-cmd --reload
            continue
        fi
    done

    echo -e "${Info} 已打开端口：$(firewall-cmd --zone=public --list-ports)." && echo
    set_firewall
}

remove_firewall_port() {
    install_service firewalld

    echo -e "${Info} 已打开端口：$(firewall-cmd --zone=public --list-ports)." && echo

    while true; do
        read -e -p "请输入你想要关闭 firewalld 端口(1-65535)(exit或q退出设置)：" port
        [[ $port == "exit" || $port == [Qq] ]] && break
        expr ${port} + 0 &>/dev/null
        if [[ $? -ne 0 || "$port" -le 0 || "$port" -gt 65535 ]]; then
            echo -e "${Error}输入了错误的端口:${port}，请重新输入 ！" && echo
            continue
        else
            echo -e "${Info}关闭端口 $port ......"
            firewall-cmd --zone=public --remove-port=$port/tcp --permanent
            echo -e "${Info}重新加载配置 ......"
            firewall-cmd --reload
            continue
        fi
    done

    echo -e "${Info} 已打开端口：$(firewall-cmd --zone=public --list-ports)." && echo
    set_firewall
}

view_firewall_port() {
    echo -e "${Info} 已打开端口：$(firewall-cmd --zone=public --list-ports)." && echo
}

set_firewall() {
    echo -e "设置 firewalld 防火墙
==================================
${Green_font_prefix} 1. 打开防火墙端口${Font_color_suffix}
${Red_font_prefix} 2. 关闭防火墙端口${Font_color_suffix}
${Green_font_prefix} 3. 查看防火墙端口${Font_color_suffix}
———————————————————————————————————
${Yellow_font_prefix} 0. 退出${Font_color_suffix}
=================================="
    read -e -p "(请输入序号)：" num
    case "${num}" in
    1)
        open_firewall_port
        ;;
    2)
        remove_firewall_port
        ;;
    3)
        view_firewall_port
        ;;
    0)
        Start_Menu
        $is_close=true
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        set_firewall
        ;;
    esac
}

set_ntp_chrony() {
    if ! _exists "chronyd"; then
        echo -e "${Info} 开始安装 chrony ......" && echo
        yum install -y chrony
    fi

    ntp_ali=$(sed -n "/^server ntp.aliyun.com/p" /etc/chrony.conf)
    if [ ! -n "$ntp_ali" ]; then
        echo -e "${Info} 开始修改配置."
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
        echo -e "${Info} 配置不用修改."
    fi

    systemctl restart chronyd
    systemctl enable chronyd
    timedatectl set-timezone Asia/Shanghai
    chronyc sourcestats -v
    timedatectl
    systemctl restart rsyslog
}

view_python() {
    if ! type python >/dev/null 2>&1; then
        echo -e "${Info} 未安装 python."
    else
        echo -e "${Info} 已安装 python 版本：$(python --version 2>&1)"
    fi

    if ! type python2 >/dev/null 2>&1; then
        echo -e "${Info} 未安装 python2."
    else
        echo -e "${Info} 已安装 python2 版本：$(python2 --version 2>&1)"
    fi

    if ! type python3 >/dev/null 2>&1; then
        echo -e "${Info} 未安装 python3."
    else
        echo -e "${Info} 已安装 python3 版本：$(python3 --version 2>&1)"
    fi

    echo
    install_python
}

install_python_dependency() {
    yum -y install bzip2-devel sqlite-devel openssl-devel readline-devel gdbm-devel libffi-devel tcl-devel tk-devel
}

ins_python() {
    echo "----------"
    if type python >/dev/null 2>&1; then
        echo "已安装：$(python --version 2>&1)"
    fi
    if type python2 >/dev/null 2>&1; then
        echo "已安装：$(python2 --version 2>&1)"
    fi
    if type python3 >/dev/null 2>&1; then
        echo "已安装：$(python3 --version 2>&1)"
    fi
    echo "----------"

    inscheck=false
    while true; do
        read -e -p "请输入要安装的版本(默认3.9.9)(exit或q退出)：" PYTHON_VER
        [[ $PYTHON_VER == "exit" || $PYTHON_VER == [Qq] ]] && break
        [[ -z "${PYTHON_VER}" ]] && PYTHON_VER="3.9.9"
        if [[ $PYTHON_VER =~ ^[2-3]{1}\.[0-9]{1,2}\.[0-9]{1,2}$ ]]; then
            echo -e "${Info} 版本号 $PYTHON_VER 合法."
            inscheck=true
            break
        elif [[ $PYTHON_VER =~ ^[2-3]{1}\.[0-9]{1,2}$ ]]; then
            echo -e "${Info} 版本号 $PYTHON_VER 合法."
            inscheck=true
            break
        else
            echo -e "${Error} 版本号 $PYTHON_VER 不合法!请重新输入!" && echo
        fi
    done

    if $inscheck; then
        echo -e "${Info} 开始安装/配置 依赖......"
        install_python_dependency

        pv=${PYTHON_VER:0:1}
        dir=${PYTHON_VER%.*}
        pythondir="/usr/local/python${dir}"
        wget https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tgz
        if [[ ! -e "Python-${PYTHON_VER}.tgz" ]]; then
            echo -e "${Error} Python-${PYTHON_VER}.tgz 官方源下载失败！"
            return 1
        else
            tar zxvf Python-${PYTHON_VER}.tgz
            pushd Python-${PYTHON_VER}
            ./configure --enable-optimizations --prefix="${pythondir}"
            make && make altinstall
            popd
            sudo ldconfig
            rm -f Python-${PYTHON_VER}.tgz

            ln -fs "${pythondir}/bin/python${dir}" /usr/bin/python${pv}
            ln -fs "${pythondir}/bin/pip${dir}" /usr/bin/pip${pv}
        fi
    fi

    install_python
}

install_python() {
    echo -e "安装 python
==================================
${Green_font_prefix} 1. 检查 python${Font_color_suffix}
${Red_font_prefix} 2. 安装 python${Font_color_suffix}
———————————————————————————————————
${Yellow_font_prefix} 0. 退出${Font_color_suffix}
=================================="
    read -e -p "(请输入序号)：" num
    case "${num}" in
    1)
        view_python
        ;;
    2)
        ins_python
        ;;
    0)
        Start_Menu
        $is_close=true
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        install_python
        ;;
    esac
}

setup_fail2ban() {
    echo -e "${Info} 开始 git 下载、编译安装 Fail2Ban ......" && echo

    if [ ! -d "${fail2ban_dir}" ]; then
        git clone https://github.com/fail2ban/fail2ban.git ${fail2ban_dir}
        if [[ $? -eq 0 ]]; then
            pushd ${fail2ban_dir}
            python3 setup.py install
            popd
            echo -e "${Tip} Fail2Ban 安装完成，需要设置配置后才能启动运行!!!"
        else
            echo -e "${Error} git clone Fail2Ban 官方源下载失败！"
            echo -e "${Error} 请检查网络，或地址:https://github.com/fail2ban/fail2ban.git"
        fi
    else
        pushd ${fail2ban_dir}
        BRANCH=master
        LOCAL=$(git log $BRANCH -n 1 --pretty=format:"%H")
        REMOTE=$(git log remotes/origin/$BRANCH -n 1 --pretty=format:"%H")
        if [ $LOCAL = $REMOTE ]; then
            echo -e "${Info} Fail2Ban 已安装，不需要更新."
        else
            systemctl stop fail2ban

            git submodule update --init --recursive
            python3 setup.py install

            systemctl start fail2ban
            systemctl enable fail2ban
            echo -e "${Info} Fail2Ban 更新完成，已重新启动."
        fi
        popd
    fi

    install_fail2ban
}

configssh_fail2ban() {
    echo -e "${Info} 开始配置 Fail2Ban ......" && echo
    while true; do
        read -e -p "请输入 SSH 端口(1-65535)(exit或q退出设置)：" sshport
        [[ $sshport == "exit" || $sshport == [Qq] ]] && break
        expr ${sshport} + 0 &>/dev/null
        if [[ $? -ne 0 || "$sshport" -le 0 || "$sshport" -gt 65535 ]]; then
            echo -e "${Error}输入了错误的端口:${sshport}，请重新输入 ！" && echo
            continue
        else
            echo -e "${Info} 写入 Fail2Ban 配置文件:/etc/fail2ban/jail.local" && echo
            echo "[sshd]
enabled = true
port    = ${sshport}
bantime = 365d
findtime= 365d
logpath =/var/log/secure
maxretry = 2" >/etc/fail2ban/jail.local

            echo -e "${Info} 配置 Fail2Ban 启动服务:fail2ban.service" && echo
            cp "${fail2ban_dir}build/fail2ban.service" /etc/systemd/system/fail2ban.service

            f2b_con=$(sed -n "/^ExecStart=/p" "${fail2ban_dir}build/fail2ban.service" | awk -F"=" '{ print $2 }')
            f2b_path=${f2b_con%/*}
            ln -fs ${f2b_path}/fail2ban-server /usr/bin/fail2ban-server
            ln -fs ${f2b_path}/fail2ban-client /usr/bin/fail2ban-client

            systemctl daemon-reload
            systemctl enable fail2ban
            systemctl restart fail2ban
            systemctl restart rsyslog
            break
        fi
    done

    install_fail2ban
}

checkssh_fail2ban() {
    fail2ban-client status sshd
    install_fail2ban
}

# 定义函数来校验IP地址格式是否符合规范
validate_ip_address() {
    local ip_address=$1

    # 使用正则表达式校验IP地址格式是否符合规范
    if [[ $ip_address =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # 对IP地址进行拆分
        IFS='.' read -r -a ip_parts <<<"$ip_address"

        # 判断每个数字是否在0-255之间
        valid_ip=true
        for ip_part in "${ip_parts[@]}"; do
            if (($ip_part < 0 || $ip_part > 255)); then
                valid_ip=false
                break
            fi
        done

        # 输出结果
        if [ $valid_ip == true ]; then
            echo -e "${Info} IP地址 $ip_address 符合规范."
            return 0 # 返回0表示IP地址符合规范
        else
            echo -e "${Error} IP地址 $ip_address 不符合规范!请重新输入!" && echo
            return 1 # 返回1表示IP地址不符合规范
        fi
    else
        echo -e "${Error} IP地址 $ip_address 不符合规范!请重新输入!" && echo
        return 1 # 返回1表示IP地址不符合规范
    fi
}

upbanip_fail2ban() {
    while true; do
        read -e -p "请输入要解封的 IP 地址(exit或q退出)：" IPADDRESS
        [[ $IPADDRESS == "exit" || $IPADDRESS == [Qq] ]] && break
        if (validate_ip_address "${IPADDRESS}"); then
            if ! systemctl is-active fail2ban &>/dev/null; then
                echo -e "${Info}开始启动 fail2ban ......"
                systemctl start fail2ban
            fi

            echo -e "${Info} 解封 IP：${IPADDRESS}"
            fail2ban-client set sshd unbanip ${IPADDRESS}
        fi
    done

    install_fail2ban
}

install_fail2ban() {
    echo -e "安装设置 Fail2Ban
==================================
${Green_font_prefix} 1. 安装 Fail2Ban${Font_color_suffix}
${Green_font_prefix} 2. 设置 Fail2Ban${Font_color_suffix}
${Red_font_prefix} 3. 查看 Fail2Ban SSH 状态${Font_color_suffix}
${Green_font_prefix} 4. Fail2Ban 解封IP地址${Font_color_suffix}
———————————————————————————————————
${Yellow_font_prefix} 0. 退出${Font_color_suffix}
=================================="
    read -e -p "(请输入序号)：" num
    case "${num}" in
    1)
        setup_fail2ban
        ;;
    2)
        configssh_fail2ban
        ;;
    3)
        checkssh_fail2ban
        ;;
    4)
        upbanip_fail2ban
        ;;
    0)
        Start_Menu
        $is_close=true
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        install_fail2ban
        ;;
    esac
}

check_ssrust_installed() {
    [[ ! -e ${SSRUST_FILE} ]] && echo -e "${Error} Shadowsocks Rust 没有安装，请检查！" && setup_ssrust && return
}

check_ssrust_status() {
    status=$(systemctl status ss-rust | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
}

Set_ssrust_port() {
    while true; do
        echo -e "${Tip} 本步骤不涉及系统防火墙端口操作，请手动放行相应端口！"
        echo -e "请输入 Shadowsocks Rust 端口 [1-65535]"
        read -e -p "(默认：2525)：" ssrust_port
        [[ -z "${ssrust_port}" ]] && ssrust_port="2525"
        echo $((${ssrust_port} + 0)) &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [[ ${ssrust_port} -ge 1 ]] && [[ ${ssrust_port} -le 65535 ]]; then
                echo && echo "=================================="
                echo -e "${Info} Shadowsocks Rust 端口：${Red_background_prefix}${ssrust_port}${Font_color_suffix}"
                echo "==================================" && echo
                break
            else
                echo -e "${Error}输入了错误的端口:${ssrust_port}，请重新输入 ！" && echo
            fi
        else
            echo -e "${Error}输入了错误的端口:${ssrust_port}，请重新输入 ！" && echo
        fi
    done
}

# 判断密码复杂度，
check_passwd_chick() {
    if echo $1 | egrep "[0-9]" | egrep "[a-z]" | egrep "[A-Z]" | egrep "[^0-Z]" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 密码长度检测
check_passwd_lenth() {
    if (($(echo $1 | wc -L) > 8)); then
        return 0
    else
        return 1
    fi
}

Set_ssrust_password() {
    while true; do
        echo "请输入 Shadowsocks Rust 密码 (要求包含大小写，数字，特殊字符)"
        read -e -p "(默认：随机生成)：" ssrust_password
        #[[ -z "${ssrust_password}" ]] && ssrust_password=$(tr -dc A-Za-z0-9^0-Z </dev/urandom | head -c 16)
        if [ ! $ssrust_password ]; then
            while true; do
                ssrust_password=$(tr -dc A-Za-z0-9^0-Z </dev/urandom | head -c 16)
                if (check_passwd_chick "${ssrust_password}"); then
                    break
                else
                    continue
                fi
            done
        fi
        if (! check_passwd_chick "${ssrust_password}"); then
            echo -e "${Error} 密码复杂度不够！"
            echo -e "${Error} 密码必须同时包含大小写，数字，特殊字符！"
            continue
        else
            echo -e "${Info} 密码复杂度符合要求，包含大小写，数字，特殊字符！"
        fi
        if (! check_passwd_lenth "${ssrust_password}"); then
            echo -e "${Error} 您的密码长度不足8位！"
            continue
        else
            echo -e "${Info} 密码长度符合要求！"
        fi

        echo && echo "=================================="
        echo -e "${Info} Shadowsocks Rust 密码：${Red_background_prefix}${ssrust_password}${Font_color_suffix}"
        echo "==================================" && echo

        break
    done
}

Set_ssrust_cipher() {
    echo -e "请选择 Shadowsocks Rust 加密方式
==================================	
 ${Green_font_prefix} 1.${Font_color_suffix} chacha20-ietf-poly1305 ${Green_font_prefix}(推荐)${Font_color_suffix}
 ${Green_font_prefix} 2.${Font_color_suffix} aes-128-gcm ${Green_font_prefix}(推荐)${Font_color_suffix}
 ${Green_font_prefix} 3.${Font_color_suffix} aes-256-gcm ${Green_font_prefix}(默认)${Font_color_suffix}
 ${Green_font_prefix} 4.${Font_color_suffix} plain ${Red_font_prefix}(不推荐)${Font_color_suffix}
 ${Green_font_prefix} 5.${Font_color_suffix} none ${Red_font_prefix}(不推荐)${Font_color_suffix}
 ${Green_font_prefix} 6.${Font_color_suffix} table
 ${Green_font_prefix} 7.${Font_color_suffix} aes-128-cfb
 ${Green_font_prefix} 8.${Font_color_suffix} aes-256-cfb
 ${Green_font_prefix} 9.${Font_color_suffix} aes-256-ctr 
 ${Green_font_prefix}10.${Font_color_suffix} camellia-256-cfb
 ${Green_font_prefix}11.${Font_color_suffix} rc4-md5
 ${Green_font_prefix}12.${Font_color_suffix} chacha20-ietf
==================================
 ${Tip} AEAD 2022 加密（须v1.15.0及以上版本且密码须经过Base64加密）
==================================	
 ${Green_font_prefix}13.${Font_color_suffix} 2022-blake3-aes-128-gcm ${Green_font_prefix}(推荐)${Font_color_suffix}
 ${Green_font_prefix}14.${Font_color_suffix} 2022-blake3-aes-256-gcm ${Green_font_prefix}(推荐)${Font_color_suffix}
 ${Green_font_prefix}15.${Font_color_suffix} 2022-blake3-chacha20-poly1305
 ${Green_font_prefix}16.${Font_color_suffix} 2022-blake3-chacha8-poly1305
 ==================================
 ${Tip} 如需其它加密方式请手动修改配置文件 !" && echo
    read -e -p "(默认: 1. chacha20-ietf-poly1305)：" cipher
    [[ -z "${cipher}" ]] && cipher="1"
    if [[ ${cipher} == "1" ]]; then
        cipher="chacha20-ietf-poly1305"
    elif [[ ${cipher} == "2" ]]; then
        cipher="aes-128-gcm"
    elif [[ ${cipher} == "3" ]]; then
        cipher="aes-256-gcm"
    elif [[ ${cipher} == "4" ]]; then
        cipher="plain"
    elif [[ ${cipher} == "5" ]]; then
        cipher="none"
    elif [[ ${cipher} == "6" ]]; then
        cipher="table"
    elif [[ ${cipher} == "7" ]]; then
        cipher="aes-128-cfb"
    elif [[ ${cipher} == "8" ]]; then
        cipher="aes-256-cfb"
    elif [[ ${cipher} == "9" ]]; then
        cipher="aes-256-ctr"
    elif [[ ${cipher} == "10" ]]; then
        cipher="camellia-256-cfb"
    elif [[ ${cipher} == "11" ]]; then
        cipher="arc4-md5"
    elif [[ ${cipher} == "12" ]]; then
        cipher="chacha20-ietf"
    elif [[ ${cipher} == "13" ]]; then
        cipher="2022-blake3-aes-128-gcm"
    elif [[ ${cipher} == "14" ]]; then
        cipher="2022-blake3-aes-256-gcm"
    elif [[ ${cipher} == "15" ]]; then
        cipher="2022-blake3-chacha20-poly1305"
    elif [[ ${cipher} == "16" ]]; then
        cipher="2022-blake3-chacha8-poly1305"
    else
        cipher="aes-256-gcm"
    fi
    echo && echo "=================================="
    echo -e "${Info} 加密方式:${Red_background_prefix}${cipher}${Font_color_suffix}"
    echo "==================================" && echo
}

#开启系统 TCP Fast Open
enable_systfo() {
    kernel=$(uname -r | awk -F . '{print $1}')
    if [ "$kernel" -ge 3 ]; then
        echo 3 >/proc/sys/net/ipv4/tcp_fastopen
        [[ ! -e $Local ]] && echo "fs.file-max = 51200
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.netdev_max_backlog = 4096
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.d/local.conf && sysctl --system >/dev/null 2>&1
    else
        echo -e "$Error系统内核版本过低，无法支持 TCP Fast Open ！"
    fi
}

disable_tfo() {
    kernel=$(uname -r | awk -F . '{print $1}')
    if [ "$kernel" -ge 3 ]; then
        echo 0 >/proc/sys/net/ipv4/tcp_fastopen
        [[ -e $Local ]] && rm -f /etc/sysctl.d/local.conf && sysctl --system >/dev/null 2>&1
    else
        echo -e "$Error系统内核版本过低，无法支持 TCP Fast Open ！"
    fi

}

Set_tfo() {
    echo -e "是否开启 TCP Fast Open ？
==================================
${Green_font_prefix} 1. 开启${Font_color_suffix}  ${Red_font_prefix} 2. 关闭${Font_color_suffix}
=================================="
    read -e -p "(默认：1.开启)：" tfo
    [[ -z "${tfo}" ]] && tfo="1"
    case "${tfo}" in
    1)
        tfo=true
        enable_systfo
        ;;
    2)
        tfo=false
        disable_tfo
        ;;
    *)
        echo -e "${Error}输入错误数字:${tfo}，请重新输入 ！" && echo
        Set_tfo
        ;;
    esac

    echo && echo "=================================="
    echo -e "TCP Fast Open 开启状态：${Red_background_prefix}${tfo}${Font_color_suffix}"
    echo "==================================" && echo
}

Installation_dependency() {
    if [[ ${release} == "centos" ]]; then
        yum install jq gzip wget curl unzip xz -y
    else
        apt-get install jq gzip wget curl unzip xz-utils -y
    fi
    #\cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}

check_ssrust_new_ver() {
    ssrust_new_ver=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases | jq -r '[.[] | select(.prerelease == false) | select(.draft == false) | .tag_name] | .[0]')
    [[ -z ${ssrust_new_ver} ]] && echo -e "${Error} Shadowsocks Rust 最新版本获取失败！" && setup_ssrust && return
    echo -e "${Info} 检测到 Shadowsocks Rust 最新版本为 [ ${ssrust_new_ver} ]"
}

check_v2ray_new_ver() {
    v2ray_new_ver=$(wget -qO- https://api.github.com/repos/shadowsocks/v2ray-plugin/releases | jq -r '[.[] | select(.prerelease == false) | select(.draft == false) | .tag_name] | .[0]')
    [[ -z ${v2ray_new_ver} ]] && echo -e "${Error} Shadowsocks v2ray-plugin 最新版本获取失败！" && setup_ssrust && return
    echo -e "${Info} 检测到 Shadowsocks v2ray-plugin 最新版本为 [ ${v2ray_new_ver} ]"
}

official_ssrust_Download() {
    echo -e "${Info} 默认开始下载官方源 Shadowsocks Rust ……"
    wget --no-check-certificate -N "https://github.com/shadowsocks/shadowsocks-rust/releases/download/${ssrust_new_ver}/shadowsocks-${ssrust_new_ver}.${arch}-unknown-linux-gnu.tar.xz"
    if [[ ! -e "shadowsocks-${ssrust_new_ver}.${arch}-unknown-linux-gnu.tar.xz" ]]; then
        echo -e "${Error} Shadowsocks Rust 官方源下载失败！"
        return 1
    else
        tar -xvf "shadowsocks-${ssrust_new_ver}.${arch}-unknown-linux-gnu.tar.xz"
    fi
    if [[ ! -e "ssserver" ]]; then
        echo -e "${Error} Shadowsocks Rust 解压失败！"
        echo -e "${Error} Shadowsocks Rust 安装失败 !"
        return 1
    else
        rm -rf "shadowsocks-${ssrust_new_ver}.${arch}-unknown-linux-gnu.tar.xz"
        chmod +x ssserver
        mv -f ssserver "${SSRUST_FILE}"
        rm -f sslocal ssmanager ssservice ssurl
        echo "${ssrust_new_ver}" >${Now_ssrust_ver_File}

        echo -e "${Info} Shadowsocks Rust 主程序下载安装完毕！"
        return 0
    fi
}

official_v2ray_Download() {
    echo -e "${Info} 默认开始下载官方源 Shadowsocks v2ray-plugin ……"
    wget --no-check-certificate -N "https://github.com/shadowsocks/v2ray-plugin/releases/download/${v2ray_new_ver}/v2ray-plugin-linux-amd64-${v2ray_new_ver}.tar.gz"
    if [[ ! -e "v2ray-plugin-linux-amd64-${v2ray_new_ver}.tar.gz" ]]; then
        echo -e "${Error} Shadowsocks v2ray-plugin 官方源下载失败！"
        return 1
    else
        tar -xvf "v2ray-plugin-linux-amd64-${v2ray_new_ver}.tar.gz"
    fi
    if [[ ! -e "v2ray-plugin_linux_amd64" ]]; then
        echo -e "${Error} Shadowsocks v2ray-plugin 解压失败！"
        echo -e "${Error} Shadowsocks v2ray-plugin 安装失败 !"
        return 1
    else
        rm -rf "v2ray-plugin-linux-amd64-${v2ray_new_ver}.tar.gz"
        mv -f v2ray-plugin_linux_amd64 "${V2RAY_FILE}"
        echo "${v2ray_new_ver}" >${Now_v2ray_ver_File}

        echo -e "${Info} Shadowsocks v2ray-plugin 主程序下载安装完毕！"
        return 0
    fi
}

ssrust_Download() {
    if [[ ! -e "${FOLDER}" ]]; then
        mkdir "${FOLDER}"
    fi

    if (! official_ssrust_Download); then
        echo -e "${Error} Shadowsocks Rust 安装失败！"
    fi
}

v2ray_Download() {
    if [[ ! -e "${FOLDER}" ]]; then
        mkdir "${FOLDER}"
    fi

    if (! official_v2ray_Download); then
        echo -e "${Error} Shadowsocks v2ray-plugin 安装失败！"
    fi
}

ssrust_Service() {
    echo "[Unit]
Description= Shadowsocks Rust Service
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
Type=simple
Restart=always
RestartSec=3s
ExecStartPre=/bin/sh -c 'ulimit -n 51200'
ExecStart=${SSRUST_FILE} -c ${CONF}
[Install]
WantedBy=multi-user.target" >/etc/systemd/system/ss-rust.service
    systemctl daemon-reload
    systemctl enable ss-rust
    echo -e "${Info} Shadowsocks Rust 服务配置完成！"
}

Write_ssrust_config() {
    cat >${CONF} <<-EOF
{
    "server":"::",
    "server_port":${ssrust_port},
    "password":"${ssrust_password}",
    "method":"${cipher}",
    "fast_open":${tfo},
    "mode":"tcp_and_udp",
    "timeout":120,
    "plugin":"v2ray-plugin",
    "plugin_opts":"server;path=/admin;loglevel=none"
}
EOF
}

Start_ssrust() {
    check_ssrust_installed
    check_ssrust_status
    [[ "$status" == "running" ]] && echo -e "${Info} Shadowsocks Rust 已在运行 ！" && setup_ssrust && return
    systemctl start ss-rust
    check_ssrust_status
    [[ "$status" == "running" ]] && echo -e "${Info} Shadowsocks Rust 启动成功 ！"
    sleep 3s
    setup_ssrust
}

Stop_ssrust() {
    check_ssrust_installed
    check_ssrust_status
    [[ !"$status" == "running" ]] && echo -e "${Error} Shadowsocks Rust 没有运行，请检查！" && setup_ssrust && return
    systemctl stop ss-rust
    sleep 3s
    setup_ssrust
}

Restart_ssrust() {
    check_ssrust_installed
    systemctl restart ss-rust
    echo -e "${Info} Shadowsocks Rust 重启完毕 ！"
    sleep 3s
    View
    setup_ssrust
}

install_ssrust() {
    [[ -e ${SSRUST_FILE} ]] && echo -e "${Error} 检测到 Shadowsocks Rust 已安装！" && setup_ssrust && return

    echo -e "${Info} 开始设置 配置..."
    Set_ssrust_port
    Set_ssrust_password
    Set_ssrust_cipher
    Set_tfo

    echo -e "${Info} 开始安装/配置 依赖..."
    Installation_dependency

    echo -e "${Info} 开始下载/安装..."
    check_ssrust_new_ver
    check_v2ray_new_ver
    ssrust_Download
    v2ray_Download

    echo -e "${Info} 开始安装系统服务脚本..."
    ssrust_Service

    echo -e "${Info} 开始写入 配置文件..."
    Write_ssrust_config

    echo -e "${Info} 所有步骤 安装完毕，开始启动..."
    Start_ssrust
}

check_ver_comparison() {
    need_restart=false
    check_ssrust_new_ver
    now_ssrust_ver=$(cat ${Now_ssrust_ver_File})
    if [[ "${now_ssrust_ver}" != "${ssrust_new_ver}" ]]; then
        echo -e "${Info} 发现 Shadowsocks Rust 已有新版本 [ ${ssrust_new_ver} ]，旧版本 [ ${now_ssrust_ver} ]"
        read -e -p "是否更新 ？ [Y/n]：" yn
        [[ -z "${yn}" ]] && yn="y"
        if [[ $yn == [Yy] ]]; then
            check_ssrust_status
            [[ "$status" == "running" ]] && systemctl stop ss-rust
            #\cp "${CONF}" "/tmp/config.json"
            # rm -rf ${FOLDER}
            ssrust_Download
            #mv -f "/tmp/config.json" "${CONF}"
            need_restart=true
        fi
    else
        echo -e "${Info} 当前 Shadowsocks Rust 已是最新版本 [ ${ssrust_new_ver} ] ！"
    fi

    check_v2ray_new_ver
    now_v2ray_ver=$(cat ${Now_v2ray_ver_File})
    if [[ "${now_v2ray_ver}" != "${v2ray_new_ver}" ]]; then
        echo -e "${Info} 发现 Shadowsocks v2ray-plugin 已有新版本 [ ${v2ray_new_ver} ]，旧版本 [ ${now_v2ray_ver} ]"
        read -e -p "是否更新 ？ [Y/n]：" yn
        [[ -z "${yn}" ]] && yn="y"
        if [[ $yn == [Yy] ]]; then
            check_ssrust_status
            [[ "$status" == "running" ]] && systemctl stop ss-rust
            v2ray_Download
            need_restart=true
        fi
    else
        echo -e "${Info} 当前 Shadowsocks v2ray-plugin 已是最新版本 [ ${ssrust_new_ver} ] ！"
    fi

    if (${need_restart}); then
        Restart_ssrust
    fi
}

update_ssrust() {
    check_ssrust_installed
    check_ver_comparison
    echo -e "${Info} Shadowsocks Rust 更新完毕！"
    sleep 3s
    setup_ssrust
}

uninstall_ssrust() {
    #check_ssrust_installed
    echo "确定要卸载 Shadowsocks Rust ? (y/N)"
    echo
    read -e -p "(默认：n)：" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Yy] ]]; then
        check_ssrust_status
        [[ "$status" == "running" ]] && systemctl stop ss-rust
        systemctl disable ss-rust
        rm -rf "${FOLDER}"
        rm -rf "${SSRUST_FILE}"
        rm -rf "${V2RAY_FILE}"
        rm -rf /etc/systemd/system/ss-rust.service
        systemctl daemon-reload
        echo && echo "Shadowsocks Rust 卸载完成！" && echo
    else
        echo && echo "卸载已取消..." && echo
    fi
    sleep 3s
    setup_ssrust
}

Read_ssrust_config() {
    [[ ! -e ${CONF} ]] && echo -e "${Error} Shadowsocks Rust 配置文件不存在！" && setup_ssrust && return
    ssrust_port=$(cat ${CONF} | jq -r '.server_port')
    ssrust_password=$(cat ${CONF} | jq -r '.password')
    cipher=$(cat ${CONF} | jq -r '.method')
    tfo=$(cat ${CONF} | jq -r '.fast_open')
}

set_ssrust_config() {
    check_ssrust_installed
    echo && echo -e "你要做什么？
==================================
 ${Green_font_prefix}1.${Font_color_suffix}  修改 端口配置
 ${Green_font_prefix}2.${Font_color_suffix}  修改 密码配置
 ${Green_font_prefix}3.${Font_color_suffix}  修改 加密配置
 ${Green_font_prefix}4.${Font_color_suffix}  修改 TFO 配置
———————————————————————————————————
 ${Green_font_prefix}5.${Font_color_suffix}  修改 全部配置
———————————————————————————————————
 ${Yellow_font_prefix} 0. 退出${Font_color_suffix}
==================================" && echo
    read -e -p "(默认：取消)(exit或q退出)：" modify
    [[ $modify == "exit" || $modify == [Qq] ]] && setup_ssrust
    [[ -z "${modify}" ]] && echo "已取消..."
    case "${modify}" in
    1)
        Read_ssrust_config
        Set_ssrust_port
        Write_ssrust_config
        Restart_ssrust
        ;;
    2)
        Read_ssrust_config
        Set_ssrust_password
        Write_ssrust_config
        Restart_ssrust
        ;;
    3)
        Read_ssrust_config
        Set_ssrust_cipher
        Write_ssrust_config
        Restart_ssrust
        ;;
    4)
        Read_ssrust_config
        Set_tfo
        Write_ssrust_config
        Restart_ssrust
        ;;
    5)
        Read_ssrust_config
        Set_ssrust_port
        Set_ssrust_password
        Set_ssrust_cipher
        Set_tfo
        Write_ssrust_config
        Restart_ssrust
        ;;
    0)
        setup_ssrust
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        set_ssrust_config
        ;;
    esac
}

getipv4() {
    ipv4=$(wget -qO- -4 -t1 -T2 ipinfo.io/ip)
    if [[ -z "${ipv4}" ]]; then
        ipv4=$(wget -qO- -4 -t1 -T2 api.ip.sb/ip)
        if [[ -z "${ipv4}" ]]; then
            ipv4=$(wget -qO- -4 -t1 -T2 members.3322.org/dyndns/getip)
            if [[ -z "${ipv4}" ]]; then
                ipv4="IPv4_Error"
            fi
        fi
    fi
}
getipv6() {
    ipv6=$(wget -qO- -6 -t1 -T2 ifconfig.co)
    if [[ -z "${ipv6}" ]]; then
        ipv6="IPv6_Error"
    fi
}

urlsafe_base64() {
    date=$(echo -n "$1" | base64 | sed ':a;N;s/\n/ /g;ta' | sed 's/ //g;s/=//g;s/+/-/g;s/\//_/g')
    echo -e "${date}"
}

Link_QR() {
    if [[ "${ipv4}" != "IPv4_Error" ]]; then
        SSbase64=$(urlsafe_base64 "${cipher}:${ssrust_password}@${ipv4}:${ssrust_port}")
        SSurl="ss://${SSbase64}"
        SSQRcode="https://cli.im/api/qrcode/code?text=${SSurl}"
        link_ipv4=" 链接  [IPv4]：${Red_font_prefix}${SSurl}${Font_color_suffix} \n 二维码[IPv4]：${Red_font_prefix}${SSQRcode}${Font_color_suffix}"
    fi
    if [[ "${ipv6}" != "IPv6_Error" ]]; then
        SSbase64=$(urlsafe_base64 "${cipher}:${ssrust_password}@${ipv6}:${ssrust_port}")
        SSurl="ss://${SSbase64}"
        SSQRcode="https://cli.im/api/qrcode/code?text=${SSurl}"
        link_ipv6=" 链接  [IPv6]：${Red_font_prefix}${SSurl}${Font_color_suffix} \n 二维码[IPv6]：${Red_font_prefix}${SSQRcode}${Font_color_suffix}"
    fi
}

view_ssrust_config() {
    check_ssrust_installed
    Read_ssrust_config
    getipv4
    getipv6
    #Link_QR
    clear && echo
    echo -e "Shadowsocks Rust 配置："
    echo -e "——————————————————————————————————"
    [[ "${ipv4}" != "IPv4_Error" ]] && echo -e " 地址：${Green_font_prefix}${ipv4}${Font_color_suffix}"
    [[ "${ipv6}" != "IPv6_Error" ]] && echo -e " 地址：${Green_font_prefix}${ipv6}${Font_color_suffix}"
    echo -e " 端口：${Green_font_prefix}${ssrust_port}${Font_color_suffix}"
    echo -e " 密码：${Green_font_prefix}${ssrust_password}${Font_color_suffix}"
    echo -e " 加密：${Green_font_prefix}${cipher}${Font_color_suffix}"
    echo -e " TFO ：${Green_font_prefix}${tfo}${Font_color_suffix}"
    echo -e "——————————————————————————————————"
    #[[ ! -z "${link_ipv4}" ]] && echo -e "${link_ipv4}"
    #[[ ! -z "${link_ipv6}" ]] && echo -e "${link_ipv6}"
    #echo -e "——————————————————————————————————"

}

check_ssrsut() {
    echo -e "${Info} 获取 Shadowsocks Rust 活动日志 ……"
    echo -e "${Tip} 返回主菜单请按 q ！"
    systemctl status ss-rust
    setup_ssrust
}

setup_ssrust() {
    echo -e "安装设置 Shadowsocks Rust
==================================
${Green_font_prefix} 1. 安装 Shadowsocks Rust ${Font_color_suffix}
${Yellow_font_prefix} 2. 更新 Shadowsocks Rust ${Font_color_suffix}
${Red_font_prefix} 3. 卸载 Shadowsocks Rust ${Font_color_suffix}
———————————————————————————————————
${Red_font_prefix} 4. 设置 Shadowsocks Rust 配置信息 ${Font_color_suffix}
${Green_font_prefix} 5. 查看 Shadowsocks Rust 配置信息 ${Font_color_suffix}
${Green_font_prefix} 6. 查看 Shadowsocks Rust 运行状态 ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 7. 启动 Shadowsocks Rust ${Font_color_suffix}
${Red_font_prefix} 8. 停止 Shadowsocks Rust ${Font_color_suffix}
${Green_font_prefix} 9. 重启 Shadowsocks Rust ${Font_color_suffix}
———————————————————————————————————
${Yellow_font_prefix} 0. 退出${Font_color_suffix}
==================================" && echo
    if [[ -e ${SSRUST_FILE} ]]; then
        check_ssrust_status
        if [[ "$status" == "running" ]]; then
            echo -e " 当前状态：${Green_font_prefix} Shadowsocks Rust 已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
        else
            echo -e " 当前状态：${Green_font_prefix} Shadowsocks Rust 已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
        fi
    else
        echo -e " 当前状态：${Red_font_prefix} Shadowsocks Rust 未安装${Font_color_suffix}"
    fi
    echo

    read -e -p "(请输入序号)：" num
    case "${num}" in
    1)
        install_ssrust
        ;;
    2)
        update_ssrust
        ;;
    3)
        uninstall_ssrust
        ;;
    4)
        set_ssrust_config
        ;;
    5)
        view_ssrust_config
        ;;
    6)
        check_ssrsut
        ;;
    7)
        Start_ssrust
        ;;
    8)
        Stop_ssrust
        ;;
    9)
        Restart_ssrust
        ;;
    0)
        Start_Menu
        $is_close=true
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        setup_ssrust
        ;;
    esac
}

check_kms_installed() {
    [[ ! -e ${kms_file} ]] && echo -e "${Error} KMS Server 没有安装，请检查！" && setup_kmsserver && return
}

check_kms_status() {
    kms_status=$(systemctl status vlmcsd | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
}

Start_kms() {
    check_kms_installed
    check_kms_status
    [[ "$kms_status" == "running" ]] && echo -e "${Info} KMS Server 已在运行 ！" && setup_kmsserver && return
    systemctl start vlmcsd
    check_kms_status
    [[ "$kms_status" == "running" ]] && echo -e "${Info} KMS Server 启动成功 ！"
    sleep 3s
    setup_kmsserver
}

Stop_kms() {
    check_kms_installed
    check_kms_status
    [[ !"$kms_status" == "running" ]] && echo -e "${Error} KMS Server 没有运行，请检查！" && setup_kmsserver && return
    systemctl stop vlmcsd
    sleep 3s
    setup_kmsserver
}

Restart_kms() {
    check_kms_installed
    systemctl restart vlmcsd
    echo -e "${Info} KMS Server 重启完毕 ！"
    sleep 3s
    View
    setup_kmsserver
}

Set_kms_port() {
    while true; do
        echo -e "${Tip} 本步骤不涉及系统防火墙端口操作，请手动放行相应端口！"
        echo -e "请输入 KMS Server 端口 [1-65535]"
        read -e -p "(默认：1688)：" kms_port
        [[ -z "${kms_port}" ]] && kms_port="1688"
        echo $((${kms_port} + 0)) &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [[ ${kms_port} -ge 1 ]] && [[ ${kms_port} -le 65535 ]]; then
                echo && echo "=================================="
                echo -e "${Info} KMS Server 端口：${Red_background_prefix}${kms_port}${Font_color_suffix}"
                echo "==================================" && echo
                break
            else
                echo -e "${Error}输入了错误的端口:${kms_port}，请重新输入 ！" && echo
            fi
        else
            echo -e "${Error}输入了错误的端口:${kms_port}，请重新输入 ！" && echo
        fi
    done
}

check_kms_new_ver() {
    kms_new_ver=$(wget -qO- https://api.github.com/repos/Wind4/vlmcsd/releases | jq -r '[.[] | select(.prerelease == false) | select(.draft == false) | .tag_name] | .[0]')
    [[ -z ${kms_new_ver} ]] && echo -e "${Error} KMS Server 最新版本获取失败！" && setup_kmsserver && return
    echo -e "${Info} 检测到 KMS Server 最新版本为 [ ${kms_new_ver} ]"
}

kms_Service() {
    echo "" >${kms_pid}
    echo "[Unit]
Description=KMS Server By vlmcsd
After=syslog.target network.target

[Service]
Type=forking
PIDFile=${kms_pid}
ExecStart=${kms_file} -P${kms_port} -p ${kms_pid}
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/vlmcsd.service
    systemctl daemon-reload
    systemctl enable vlmcsd
    echo -e "${Info} KMS Server 服务配置完成！"
}

update_kms() {
    check_kms_new_ver
    now_kms_ver=$(cat ${Now_kms_ver_File})
    if [[ "${now_kms_ver}" != "${kms_new_ver}" ]]; then
        echo -e "${Info} 发现 KMS Server 已有新版本 [ ${kms_new_ver} ]，旧版本 [ ${now_kms_ver} ]"
        read -e -p "是否更新 ？ [Y/n]：" yn
        [[ -z "${yn}" ]] && yn="y"
        if [[ $yn == [Yy] ]]; then
            check_kms_status
            [[ "$kms_status" == "running" ]] && systemctl stop vlmcsd
            official_kms_Download
            echo -e "${Info} KMS Server 更新完毕！"
            sleep 3s
            Restart_kms
        fi
    else
        echo -e "${Info} 当前 KMS Server 已是最新版本 [ ${kms_new_ver} ] ！"
    fi
    setup_kmsserver
}

official_kms_Download() {
    echo -e "${Info} 默认开始下载官方源 KMS Server ……"
    wget --no-check-certificate -N "https://github.com/Wind4/vlmcsd/releases/download/${kms_new_ver}/binaries.tar.gz"
    if [[ ! -e "binaries.tar.gz" ]]; then
        echo -e "${Error} KMS Server 官方源下载失败！"
        return 1
    else
        tar -xvf "binaries.tar.gz"
    fi

    vlmcsd_x64_file="./binaries/Linux/intel/static/vlmcsd-x64-musl-static"
    if [[ ! -e "${vlmcsd_x64_file}" ]]; then
        echo -e "${Error} KMS Server 解压失败！"
        echo -e "${Error} KMS Server 安装失败 !"
        return 1
    else
        cp "${vlmcsd_x64_file}" "${kms_file}"
        chmod +x "${kms_file}"
        rm -f binaries.tar.gz
        rm -rf binaries floppy
        echo "${kms_new_ver}" >${Now_kms_ver_File}

        echo -e "${Info} KMS Server 主程序下载安装完毕！"
        return 0
    fi
}

install_kms() {
    if [ -f "${kms_file}" ]; then
        echo -e "${Error} 检测到 KMS Server 已安装！" && setup_kmsserver && return
    fi

    check_kms_new_ver
    Set_kms_port
    if (! official_kms_Download); then
        echo -e "${Error} KMS Server 安装失败！"
    else
        kms_Service
        Start_kms
    fi
}

uninstall_kms() {
    echo "确定要卸载 KMS Server ? (y/N)"
    echo
    read -e -p "(默认：n)：" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Yy] ]]; then
        check_kms_status
        [[ "$kms_status" == "running" ]] && systemctl stop vlmcsd
        systemctl disable vlmcsd
        rm -rf "${kms_file}"
        rm -rf "${kms_pid}"
        rm -rf "${Now_kms_ver_File}"
        rm -rf /etc/systemd/system/vlmcsd.service
        systemctl daemon-reload
        echo && echo "KMS Server 卸载完成！" && echo
    else
        echo && echo "卸载已取消..." && echo
    fi
    sleep 3s
    setup_kmsserver
}

view_kms_config() {
    echo -e "${Info} KMS Server 无配置文件，service文件中配置端口."
    echo -e "${Info} KMS Server service:/etc/systemd/system/vlmcsd.service"
    cat /etc/systemd/system/vlmcsd.service
    setup_kmsserver
}

check_kms() {
    echo -e "${Info} 获取 KMS Server 活动日志 ……"
    echo -e "${Tip} 返回主菜单请按 q ！"
    systemctl status vlmcsd
    setup_kmsserver
}

setup_kmsserver() {
    echo -e "安装设置 KMS Server
==================================
${Green_font_prefix} 1. 安装 KMS Server ${Font_color_suffix}
${Yellow_font_prefix} 2. 更新 KMS Server ${Font_color_suffix}
${Red_font_prefix} 3. 卸载 KMS Server ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 4. 查看 KMS Server 配置 ${Font_color_suffix}
${Green_font_prefix} 5. 查看 KMS Server 运行状态 ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 6. 启动 KMS Server ${Font_color_suffix}
${Red_font_prefix} 7. 停止 KMS Server ${Font_color_suffix}
${Green_font_prefix} 8. 重启 KMS Server ${Font_color_suffix}
———————————————————————————————————
${Yellow_font_prefix} 0. 退出${Font_color_suffix}
==================================" && echo
    if [[ -e ${kms_file} ]]; then
        check_kms_status
        if [[ "$kms_status" == "running" ]]; then
            echo -e " 当前状态：${Green_font_prefix} KMS Server 已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
        else
            echo -e " 当前状态：${Green_font_prefix} KMS Server 已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
        fi
    else
        echo -e " 当前状态：${Red_font_prefix} KMS Server 未安装${Font_color_suffix}"
    fi
    echo

    read -e -p "(请输入序号)：" num
    case "${num}" in
    1)
        install_kms
        ;;
    2)
        update_kms
        ;;
    3)
        uninstall_kms
        ;;
    4)
        view_kms_config
        ;;
    5)
        check_kms
        ;;
    6)
        Start_kms
        ;;
    7)
        Stop_kms
        ;;
    8)
        Restart_kms
        ;;
    0)
        Start_Menu
        $is_close=true
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        setup_kmsserver
        ;;
    esac
}

ins_ss() {
    echo -e "${Info} 开始安装 ss-client ..."
    mv -f sslocal "${SSCLIENT_FILE}"
    rm -f ssserver ssmanager ssservice ssurl

    echo -e "${Info} 开始安装 v2ray-plugin ..."
    mv -f v2ray-plugin_linux_amd64 "${SSCLIENT_V2RAY_FILE}"
}

set_ssserver_ip() {
    while true; do
        read -e -p "请输入 SS Server 的 IP 地址：" ssserver_ip
        if (validate_ip_address "${ssserver_ip}"); then
            echo && echo "=================================="
            echo -e "${Info} SS Server 的 IP 地址：${Red_background_prefix}${ssserver_ip}${Font_color_suffix}"
            echo "==================================" && echo
            break
        fi
    done
}

set_ssserver_port() {
    while true; do
        #echo -e "${Tip} 本步骤不涉及系统防火墙端口操作，请手动放行相应端口！"
        echo -e "请输入 SS Server 的端口 [1-65535]"
        read -e -p "(默认：2525)：" ssserver_port
        [[ -z "${ssserver_port}" ]] && ssserver_port="2525"
        echo $((${ssserver_port} + 0)) &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [[ ${ssserver_port} -ge 1 ]] && [[ ${ssserver_port} -le 65535 ]]; then
                echo && echo "=================================="
                echo -e "${Info} SS Server 端口：${Red_background_prefix}${ssserver_port}${Font_color_suffix}"
                echo "==================================" && echo
                break
            else
                echo -e "${Error}输入了错误的端口:${ssserver_port}，请重新输入 ！" && echo
            fi
        else
            echo -e "${Error}输入了错误的端口:${ssserver_port}，请重新输入 ！" && echo
        fi
    done
}

set_ssserver_passwd() {
    while true; do
        read -e -p "请输入 SS Server 的密码：" ssserver_passwd
        [[ -z "${ssserver_passwd}" ]] && echo -e "${Error} 密码不能为空，请重新输入 ！" && continue
        echo && echo "=================================="
        echo -e "${Info} SS Server 的密码：${Red_background_prefix}${ssserver_passwd}${Font_color_suffix}"
        echo "==================================" && echo
        break
    done
}

set_ssserver_cipher() {
    echo -e "请选择 SS Server 加密方式
==================================	
 ${Green_font_prefix} 1.${Font_color_suffix} chacha20-ietf-poly1305 ${Green_font_prefix}(推荐)${Font_color_suffix}
 ${Green_font_prefix} 2.${Font_color_suffix} aes-128-gcm ${Green_font_prefix}(推荐)${Font_color_suffix}
 ${Green_font_prefix} 3.${Font_color_suffix} aes-256-gcm ${Green_font_prefix}(默认)${Font_color_suffix}
 ${Green_font_prefix} 4.${Font_color_suffix} plain ${Red_font_prefix}(不推荐)${Font_color_suffix}
 ${Green_font_prefix} 5.${Font_color_suffix} none ${Red_font_prefix}(不推荐)${Font_color_suffix}
 ${Green_font_prefix} 6.${Font_color_suffix} table
 ${Green_font_prefix} 7.${Font_color_suffix} aes-128-cfb
 ${Green_font_prefix} 8.${Font_color_suffix} aes-256-cfb
 ${Green_font_prefix} 9.${Font_color_suffix} aes-256-ctr 
 ${Green_font_prefix}10.${Font_color_suffix} camellia-256-cfb
 ${Green_font_prefix}11.${Font_color_suffix} rc4-md5
 ${Green_font_prefix}12.${Font_color_suffix} chacha20-ietf
==================================
 ${Tip} AEAD 2022 加密（须v1.15.0及以上版本且密码须经过Base64加密）
==================================	
 ${Green_font_prefix}13.${Font_color_suffix} 2022-blake3-aes-128-gcm ${Green_font_prefix}(推荐)${Font_color_suffix}
 ${Green_font_prefix}14.${Font_color_suffix} 2022-blake3-aes-256-gcm ${Green_font_prefix}(推荐)${Font_color_suffix}
 ${Green_font_prefix}15.${Font_color_suffix} 2022-blake3-chacha20-poly1305
 ${Green_font_prefix}16.${Font_color_suffix} 2022-blake3-chacha8-poly1305
 ==================================
 ${Tip} 如需其它加密方式请手动修改配置文件 !" && echo
    read -e -p "(默认: 1. chacha20-ietf-poly1305)：" ssserver_cipher
    [[ -z "${ssserver_cipher}" ]] && ssserver_cipher="1"
    if [[ ${ssserver_cipher} == "1" ]]; then
        ssserver_cipher="chacha20-ietf-poly1305"
    elif [[ ${ssserver_cipher} == "2" ]]; then
        ssserver_cipher="aes-128-gcm"
    elif [[ ${ssserver_cipher} == "3" ]]; then
        ssserver_cipher="aes-256-gcm"
    elif [[ ${ssserver_cipher} == "4" ]]; then
        ssserver_cipher="plain"
    elif [[ ${ssserver_cipher} == "5" ]]; then
        ssserver_cipher="none"
    elif [[ ${ssserver_cipher} == "6" ]]; then
        ssserver_cipher="table"
    elif [[ ${ssserver_cipher} == "7" ]]; then
        ssserver_cipher="aes-128-cfb"
    elif [[ ${ssserver_cipher} == "8" ]]; then
        ssserver_cipher="aes-256-cfb"
    elif [[ ${ssserver_cipher} == "9" ]]; then
        ssserver_cipher="aes-256-ctr"
    elif [[ ${ssserver_cipher} == "10" ]]; then
        ssserver_cipher="camellia-256-cfb"
    elif [[ ${ssserver_cipher} == "11" ]]; then
        ssserver_cipher="arc4-md5"
    elif [[ ${ssserver_cipher} == "12" ]]; then
        ssserver_cipher="chacha20-ietf"
    elif [[ ${ssserver_cipher} == "13" ]]; then
        ssserver_cipher="2022-blake3-aes-128-gcm"
    elif [[ ${ssserver_cipher} == "14" ]]; then
        ssserver_cipher="2022-blake3-aes-256-gcm"
    elif [[ ${ssserver_cipher} == "15" ]]; then
        ssserver_cipher="2022-blake3-chacha20-poly1305"
    elif [[ ${ssserver_cipher} == "16" ]]; then
        ssserver_cipher="2022-blake3-chacha8-poly1305"
    else
        ssserver_cipher="aes-256-gcm"
    fi
    echo && echo "=================================="
    echo -e "${Info} SS Server 加密方式:${Red_background_prefix}${ssserver_cipher}${Font_color_suffix}"
    echo "==================================" && echo
}

set_sslocal_address() {
    while true; do
        read -e -p "请输入 SS local 的 IP 地址(默认127.0.0.1)：" sslocal_address
        [[ -z "${sslocal_address}" ]] && sslocal_address="127.0.0.1"
        if (validate_ip_address "${sslocal_address}"); then
            echo && echo "=================================="
            echo -e "${Info} SS local 的 IP 地址：${Red_background_prefix}${sslocal_address}${Font_color_suffix}"
            echo "==================================" && echo
            break
        fi
    done
}

set_sslocal_port() {
    while true; do
        #echo -e "${Tip} 本步骤不涉及系统防火墙端口操作，请手动放行相应端口！"
        echo -e "请输入 SS local 的端口 [1-65535]"
        read -e -p "(默认1080)：" sslocal_port
        [[ -z "${sslocal_port}" ]] && sslocal_port="1080"
        echo $((${sslocal_port} + 0)) &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [[ ${sslocal_port} -ge 1 ]] && [[ ${sslocal_port} -le 65535 ]]; then
                echo && echo "=================================="
                echo -e "${Info} SS local 端口：${Red_background_prefix}${sslocal_port}${Font_color_suffix}"
                echo "==================================" && echo
                break
            else
                echo -e "${Error}输入了错误的端口:${sslocal_port}，请重新输入 ！" && echo
            fi
        else
            echo -e "${Error}输入了错误的端口:${sslocal_port}，请重新输入 ！" && echo
        fi
    done
}

Write_ssclient_config() {
    mkdir "${SSCLIENT_CONF%\/*}"
    cat >${SSCLIENT_CONF} <<-EOF
{
"server":"${ssserver_ip}",
"server_port":${ssserver_port},
"password":"${ssserver_passwd}",
"method":"${ssserver_cipher}",
"fast_open":true,
"timeout":120,
"local_address":"${sslocal_address}",
"local_port":${sslocal_port},
"plugin":"v2ray-plugin",
"plugin_opts":"path=/admin;loglevel=none"
}
EOF
}

config_ss() {
    set_ssserver_ip
    set_ssserver_port
    set_ssserver_passwd
    set_ssserver_cipher
    set_sslocal_address
    set_sslocal_port
    Write_ssclient_config
    echo -e "${Info} ss-client 配置文件完成:${SSCLIENT_CONF}"
}

service_ss() {
    echo "
[Unit]
Description=ShadowSocks-rust local service
After=syslog.target network.target auditd.service

[Service]
Type=simple
ExecStart=${SSCLIENT_FILE} -c ${SSCLIENT_CONF}
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/ssrustlocal.service
    #SSCLIENT_SERVICE="/etc/systemd/system/ssrustlocal.service"

    systemctl daemon-reload
    systemctl enable ssrustlocal
    echo -e "${Info} ss-client 服务配置完成！服务名:ssrustlocal.service"
}

set_local_profile() {
    echo -e "${Info} 开始设置系统全局代理 ..."

    profile_con=($(sed -n "/http_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/http_proxy=http/d" "${PROFILE_CONF}"
    fi
    echo "export http_proxy=http://127.0.0.1:8118" >>"${PROFILE_CONF}"

    profile_con=($(sed -n "/https_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/https_proxy=http/d" "${PROFILE_CONF}"
    fi
    echo "export https_proxy=http://127.0.0.1:8118" >>"${PROFILE_CONF}"

    profile_con=($(sed -n "/ftp_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/ftp_proxy=http/d" "${PROFILE_CONF}"
    fi
    echo "export ftp_proxy=http://127.0.0.1:8118" >>"${PROFILE_CONF}"

    source "${PROFILE_CONF}"
}

remove_local_profile() {
    echo -e "${Info} 开始删除系统全局代理 ..."

    profile_con=($(sed -n "/http_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/http_proxy=http/d" "${PROFILE_CONF}"
    fi

    profile_con=($(sed -n "/https_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/https_proxy=http/d" "${PROFILE_CONF}"
    fi

    profile_con=($(sed -n "/ftp_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/ftp_proxy=http/d" "${PROFILE_CONF}"
    fi

    source "${PROFILE_CONF}"
}

open_privoxy() {
    echo -e "${Info} 打开系统全局代理 ..."

    profile_con=($(sed -n "/http_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/http_proxy=http/d" "${PROFILE_CONF}"
    fi
    echo "export http_proxy=http://127.0.0.1:8118" >>"${PROFILE_CONF}"

    profile_con=($(sed -n "/https_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/https_proxy=http/d" "${PROFILE_CONF}"
    fi
    echo "export https_proxy=http://127.0.0.1:8118" >>"${PROFILE_CONF}"

    profile_con=($(sed -n "/ftp_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/ftp_proxy=http/d" "${PROFILE_CONF}"
    fi
    echo "export ftp_proxy=http://127.0.0.1:8118" >>"${PROFILE_CONF}"

    source "${PROFILE_CONF}"
    echo -e "${Info} 已经打开系统全局代理."
    setup_ssclient
}

close_privoxy() {
    echo -e "${Info} 关闭系统全局代理 ..."

    profile_con=($(sed -n "/http_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/http_proxy=http/d" "${PROFILE_CONF}"
    fi
    echo "export -n http_proxy=http://127.0.0.1:8118" >>"${PROFILE_CONF}"

    profile_con=($(sed -n "/https_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/https_proxy=http/d" "${PROFILE_CONF}"
    fi
    echo "export -n https_proxy=http://127.0.0.1:8118" >>"${PROFILE_CONF}"

    profile_con=($(sed -n "/ftp_proxy=http/p" "${PROFILE_CONF}"))
    if [[ ! -z ${profile_con} ]]; then
        sed -i "/ftp_proxy=http/d" "${PROFILE_CONF}"
    fi
    echo "export -n ftp_proxy=http://127.0.0.1:8118" >>"${PROFILE_CONF}"

    source "${PROFILE_CONF}"
    echo -e "${Info} 已经关闭系统全局代理."
    setup_ssclient
}

ins_local_privoxy() {
    echo -e "${Info} 开始安装配置 privoxy ..."
    yum install -y privoxy

    privoxy_con=($(sed -n '/^forward-socks5t/p' "${PRIVOXY_CONF}"))
    if [[ ! -z ${privoxy_con} ]]; then
        sed -i "s/^forward-socks5t/#forward-socks5t/g" "${PRIVOXY_CONF}"
    fi
    echo "forward-socks5t   /   ${sslocal_address}:${sslocal_port} ." >>"${PRIVOXY_CONF}"

    privoxy_con=($(sed -n '/^listen-address/p' "${PRIVOXY_CONF}"))
    if [[ ! -z ${privoxy_con} ]]; then
        sed -i "s/^listen-address/#listen-address/g" "${PRIVOXY_CONF}"
    fi
    echo "listen-address  127.0.0.1:8118" >>"${PRIVOXY_CONF}"

    systemctl restart privoxy
    systemctl enable privoxy

}

ins_local_ss() {
    echo -e "${Info} 开始安装/配置 依赖..."
    #Installation_dependency

    read -e -p "(请输入本地 Shadowsocks Rust 文件名)：" ssclientfile
    [[ -z "${ssclientfile}" ]] && ssclientfile="shadowsocks-v1.17.0.x86_64-unknown-linux-gnu.tar.xz"

    read -e -p "(请输入本地 v2ray-plugin 文件名)：" v2rayclientfile
    [[ -z "${v2rayclientfile}" ]] && v2rayclientfile="v2ray-plugin-linux-amd64-v1.3.2.tar.gz"

    tar -xvf "${ssclientfile}"
    tar -xvf "${v2rayclientfile}"

    if [[ ! -e "sslocal" ]]; then
        echo -e "${Error} 未找到 sslocal 文件，安装失败！"
        setup_ssclient
    fi
    if [[ ! -e "v2ray-plugin_linux_amd64" ]]; then
        echo -e "${Error} 未找到 sslocal 文件，安装失败！"
        setup_ssclient
    fi

    ins_ss
    config_ss
    service_ss
    systemctl start ssrustlocal

    ins_local_privoxy
    set_local_profile

    echo -e "${Info} 安装完成."
    setup_ssclient
}

ins_online_ss() {
    echo -e "${Info} 在线安装 ss-client 暂未实现..."
    install_ssclient
}

install_ssclient() {
    [[ -e ${SSCLIENT_FILE} ]] && echo -e "${Error} 检测到 ss-client 已安装！" && setup_ssclient && return

    echo -e "选择 ss-client 安装方式
==================================
${Green_font_prefix} 1. 在线安装 ss-client ${Font_color_suffix}
${Red_font_prefix} 2. 本地安装 ss-client ${Font_color_suffix}
———————————————————————————————————
${Yellow_font_prefix} 0. 退出${Font_color_suffix}
=================================="
    read -e -p "(请输入序号)：" num
    case "${num}" in
    1)
        ins_online_ss
        ;;
    2)
        ins_local_ss
        ;;
    0)
        setup_ssclient
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        install_ssclient
        ;;
    esac

}

uninstall_ssclient() {
    systemctl stop ssrustlocal
    systemctl disable ssrustlocal
    rm -f "${SSCLIENT_FILE}"
    rm -f "${SSCLIENT_V2RAY_FILE}"
    rm -rf "${SSCLIENT_CONF%\/*}"
    rm -f /etc/systemd/system/ssrustlocal.service

    systemctl stop privoxy
    systemctl disable privoxy
    yum remove -y privoxy
    rm -f "${PRIVOXY_CONF}"
    remove_local_profile
    setup_ssclient
}

check_ssclient() {
    echo -e "${Info} 获取 ss-client & privoxy 活动日志 ……"
    echo -e "${Tip} 返回主菜单请按 q ！"
    systemctl status ssrustlocal
    systemctl status privoxy
    setup_ssclient
}

setup_ssclient() {
    echo -e "安装设置 ss-client & privoxy
==================================
${Green_font_prefix} 1. 安装 ss-client & privoxy ${Font_color_suffix}
${Red_font_prefix} 2. 卸载 ss-client & privoxy ${Font_color_suffix}
${Green_font_prefix} 3. 查看 ss-client & privoxy 状态 ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 4. 打开 privoxy 全局代理 ${Font_color_suffix}
${Red_font_prefix} 5. 关闭 privoxy 全局代理 ${Font_color_suffix}
———————————————————————————————————
${Yellow_font_prefix} 0. 退出${Font_color_suffix}
=================================="
    read -e -p "(请输入序号)：" num
    case "${num}" in
    1)
        install_ssclient
        ;;
    2)
        uninstall_ssclient
        ;;
    3)
        check_ssclient
        ;;
    4)
        open_privoxy
        ;;
    5)
        close_privoxy
        ;;
    0)
        Start_Menu
        $is_close=true
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        setup_ssclient
        ;;
    esac
}

do_swap() {
    swap_file="/root/swapfile"
    echo -e "${Info} 删除 swap 交换分区"
    #swapoff -a
    swapoff "${swap_file}"
    rm -f ${swap_file}

    echo -e "${Info} 创建 swap 交换分区文件"
    #fallocate -l $1G $swap_file
    dd if=/dev/zero of=${swap_file} bs=1M count=$(($1 * 1024))

    echo -e "${Info} 加载 swap 交换分区文件"
    chmod 600 "${swap_file}"
    mkswap "${swap_file}"
    swapon "${swap_file}"

    echo -e "${Info} 持久化 swap 交换分区文件"
    if grep -q "${swap_file}" /etc/fstab; then
        echo "Flag exists"
    else
        echo "${swap_file} swap swap defaults 0 0" >>/etc/fstab
    fi

    echo -e "${Info} 显示 swap 交换分区"
    swapon --show
    free -h
}

add_swapfile() {
    echo -e "${Info} 开始添加 swap 交换分区......"

    read -e -p "请输入你想要创建的交换分区大小(单位GB，默认1GB)(exit退出)：" swapgb
    [[ $swapgb == "exit" || $swapgb == [Qq] ]] && Start_Menu && $is_close=true && return
    [[ -z ${swapgb} ]] && swapgb=1
    do_swap ${swapgb}
}

Update_Shell() {
    echo -e "当前版本为 [ ${sh_ver} ]，开始检测最新版本..."
    sh_new_ver=$(curl https://raw.githubusercontent.com/faintx/public/main/syssetup.sh | grep 'sh_ver="' | awk -F "=" '{print $NF}' | sed 's/\"//g' | head -1)
    [[ -z ${sh_new_ver} ]] && echo -e "${Error} 检测最新版本失败 !" && Start_Menu && $is_close=true && return
    if [[ ${sh_new_ver} != ${sh_ver} ]]; then
        echo -e "发现新版本[ ${sh_new_ver} ]，是否更新？[Y/n]"
        read -p "(默认：y)：" yn
        [[ -z "${yn}" ]] && yn="y"
        if [[ ${yn} == [Yy] ]]; then
            curl -o syssetup.sh https://raw.githubusercontent.com/faintx/public/main/syssetup.sh && chmod +x syssetup.sh
            echo -e "脚本已更新为最新版本[ ${sh_new_ver} ]！"
            echo -e "3s后执行新脚本"
            sleep 3s
            source syssetup.sh
        else
            echo && echo "	已取消..." && echo
            sleep 3s
            Start_Menu
            $is_close=true
        fi
    else
        echo -e "当前已是最新版本[ ${sh_new_ver} ] ！"
        sleep 3s
        Start_Menu
        $is_close=true
    fi
}

Start_Menu() {
    clear
    cr=check_root
    check_sys
    sysArch

    if (! $cr -eq 4 || ! $is_close); then
        while true; do
            echo -e "
=========================================
${Red_font_prefix}System Set Up 管理脚本 [v${sh_ver}]${Font_color_suffix}
=========================================
${Yellow_font_prefix} 1. 更新本脚本 ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 2. 添加 swap 交换分区 ${Font_color_suffix}
${Red_font_prefix} 3. 更换阿里源 ${Font_color_suffix}
${Green_font_prefix} 4. 更新系统，安装常用工具 ${Font_color_suffix}
${Red_font_prefix} 5. 设置 SELinux ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 6. 设置 SSH 端口 ${Font_color_suffix}
${Red_font_prefix} 7. 设置 firewalld 防火墙 ${Font_color_suffix}
${Green_font_prefix} 8. 安装设置 NTP chrony ${Font_color_suffix}
${Green_font_prefix} 9. 编译安装 Python ${Font_color_suffix}
${Red_font_prefix} 10. 安装设置 Fail2Ban ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 11. 安装设置 Shadowsocks Rust ${Font_color_suffix}
${Green_font_prefix} 12. 安装设置 ss-client & privoxy ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 13. 安装设置 KMS Server ${Font_color_suffix}
———————————————————————————————————
${Yellow_font_prefix} 0. 退出${Font_color_suffix}
========================================="
            read -e -p "(请输入序号)：" num
            case "${num}" in
            1)
                Update_Shell
                ;;
            2)
                add_swapfile
                ;;
            3)
                change_repo
                ;;
            4)
                yum update -y
                yum install -y epel-release
                yum install -y wget git gcc automake autoconf libtool make net-tools jq
                ;;
            5)
                set_selinux
                ;;
            6)
                set_ssh_port
                ;;
            7)
                set_firewall
                ;;
            8)
                set_ntp_chrony
                ;;
            9)
                install_python
                ;;
            10)
                install_fail2ban
                ;;
            11)
                setup_ssrust
                ;;
            12)
                setup_ssclient
                ;;
            13)
                setup_kmsserver
                ;;
            0)
                break
                ;;
            *)
                echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
                ;;
            esac
        done
    fi
}
Start_Menu
