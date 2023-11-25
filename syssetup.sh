#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

sh_ver="1.0.1"
SSHConfig="/etc/ssh/sshd_config"
fail2ban_dir="/root/fail2ban/"
FOLDER="/etc/ss-rust"
SSRUST_FILE="/usr/local/bin/ss-rust"
V2RAY_FILE="/usr/local/bin/v2ray-plugin"
CONF="/etc/ss-rust/config.json"
Now_ssrust_ver_File="/etc/ss-rust/ssrust_ver.txt"
Now_v2ray_ver_File="/etc/ss-rust/v2ray_ver.txt"
Local="/etc/sysctl.d/local.conf"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m" && Yellow_font_prefix="\033[0;33m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"

check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
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
    fi

    case "$(_os)" in
    centos)
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
                mv CentOS-Linux-AppStream.repo CentOS-Linux-AppStream.repo.bak
                mv CentOS-Linux-BaseOS.repo CentOS-Linux-BaseOS.repo.bak
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

set_ssh_port() {
    [[ ! -e ${SSHConfig} ]] && echo -e "${Error} SSH 配置文件不存在，请检查！" && return

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
        echo -e "${Info} 停用 iptables，有时会影响 firewalld 启动." && echo
        systemctl stop iptables
        systemctl disable iptables
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

            ln -fs ${pythondir}/bin/python${dir} /usr/bin/python${pv}
            ln -fs ${pythondir}/bin/pip${dir} /usr/bin/pip${pv}
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
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        install_fail2ban
        ;;
    esac
}

check_installed_status() {
    [[ ! -e ${SSRUST_FILE} ]] && echo -e "${Error} Shadowsocks Rust 没有安装，请检查！" && setup_ssrust && return
}

check_status() {
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
    read -e -p "(默认: 3. aes-256-gcm)：" cipher
    [[ -z "${cipher}" ]] && cipher="3"
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
    echo -e "加密方式:${Red_background_prefix}${cipher}${Font_color_suffix}"
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
        rm sslocal ssmanager ssservice ssurl
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
    echo "
[Unit]
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
    systemctl enable --now ss-rust
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
    check_installed_status
    check_status
    [[ "$status" == "running" ]] && echo -e "${Info} Shadowsocks Rust 已在运行 ！" && setup_ssrust && return
    systemctl start ss-rust
    check_status
    [[ "$status" == "running" ]] && echo -e "${Info} Shadowsocks Rust 启动成功 ！"
    sleep 3s
    setup_ssrust
}

Stop_ssrust() {
    check_installed_status
    check_status
    [[ !"$status" == "running" ]] && echo -e "${Error} Shadowsocks Rust 没有运行，请检查！" && setup_ssrust && return
    systemctl stop ss-rust
    sleep 3s
    setup_ssrust
}

Restart_ssrust() {
    check_installed_status
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
            check_status
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
            check_status
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
    check_installed_status
    check_ver_comparison
    echo -e "${Info} Shadowsocks Rust 更新完毕！"
    sleep 3s
    setup_ssrust
}

uninstall_ssrust() {
    #check_installed_status
    echo "确定要卸载 Shadowsocks Rust ? (y/N)"
    echo
    read -e -p "(默认：n)：" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Yy] ]]; then
        check_status
        [[ "$status" == "running" ]] && systemctl stop ss-rust
        systemctl disable ss-rust
        rm -rf "${FOLDER}"
        rm -rf "${SSRUST_FILE}"
        rm -rf "${V2RAY_FILE}"
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
    check_installed_status
    echo && echo -e "你要做什么？
==================================
 ${Green_font_prefix}1.${Font_color_suffix}  修改 端口配置
 ${Green_font_prefix}2.${Font_color_suffix}  修改 密码配置
 ${Green_font_prefix}3.${Font_color_suffix}  修改 加密配置
 ${Green_font_prefix}4.${Font_color_suffix}  修改 TFO 配置
==================================
 ${Green_font_prefix}5.${Font_color_suffix}  修改 全部配置" && echo
    read -e -p "(默认：取消)：" modify
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
    check_installed_status
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
        check_status
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
        check_ssrsut
        ;;
    9)
        Restart_ssrust
        ;;
    0)
        Start_Menu
        ;;
    *)
        echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
        setup_ssrust
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
    [[ $swapgb == "exit" || $swapgb == [Qq] ]] && Start_Menu
    [[ -z ${swapgb} ]] && swapgb=1
    do_swap ${swapgb}
}

Start_Menu() {
    clear
    check_root
    check_sys
    sysArch

    while true; do
        echo -e "
=========================================
${Red_font_prefix}System Set Up 管理脚本 [v${sh_ver}]${Font_color_suffix}
=========================================
${Yellow_font_prefix} 1. 更新本脚本 ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 2. 添加 swap 交换分区 ${Font_color_suffix}
${Green_font_prefix} 3. 更换阿里源 ${Font_color_suffix}
${Green_font_prefix} 4. 更新系统，安装常用工具 ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 5. 设置 SSH 端口 ${Font_color_suffix}
${Red_font_prefix} 6. 设置 firewalld 防火墙 ${Font_color_suffix}
${Green_font_prefix} 7. 安装设置 NTP chrony ${Font_color_suffix}
${Green_font_prefix} 8. 编译安装 Python ${Font_color_suffix}
${Red_font_prefix} 9. 安装设置 Fail2Ban ${Font_color_suffix}
———————————————————————————————————
${Green_font_prefix} 10. 安装设置 Shadowsocks Rust ${Font_color_suffix}
———————————————————————————————————
${Yellow_font_prefix} 0. 退出${Font_color_suffix}
========================================="
        read -e -p "(请输入序号)：" num
        case "${num}" in
        1)
            echo
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
            yum install -y wget git gcc automake autoconf libtool make net-tools
            ;;
        5)
            set_ssh_port
            ;;
        6)
            set_firewall
            ;;
        7)
            set_ntp_chrony
            ;;
        8)
            install_python
            ;;
        9)
            install_fail2ban
            ;;
        10)
            setup_ssrust
            ;;
        0)
            exit 1
            ;;
        *)
            echo -e "${Error}输入错误数字:${num}，请重新输入 ！" && echo
            ;;
        esac
    done
}
Start_Menu
