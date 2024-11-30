#!/usr/bin/env bash

# This script is used to manage xray configuration
#
# Usage:
#   ./xray_config_manage.sh [--path PATH] [--download|--reset] [-t TAG] [-l [LISTEN]] [-p [PORT]] [-e EMAIL] [-prcl [PROTOCOL]] [-u [UUID]] [-n [NETWORK]] [-d DEST] [-sn SERVERNAMES] [-asn SERVERNAMES] [-x PRIVATE KEY] [-sid [SHORTIDS]] [-rsid] [-asid SHORTIDS]
#
# Options:
#   -h, --help                    Display help message.
#   --path                        Xray config full path, default: /usr/local/etc/xray/config.json
#   --download, --reset           Download xray config template
#   -t, --tag                     The inbounds match tag. default: xray-script-xtls-reality
#   -l, --listen                  Set listen, default: 0.0.0.0
#   -p, --port                    Set port, default: 443
#   -prcl, --protocol             Set protocol, 1: vless, default: 1 (Protocol supports only vless)
#   -e, --email                   Clients match email, default: vless@xtls.reality
#   -u, --uuid                    Reset UUID, default: random UUID
#   -n, --network                 Pick network, 1: tcp, 2: h2, 3: grpc, default: 1
#                                 tcp -> flow: "xtls-rprx-vision", h2 or grpc -> flow: "", grpc -> random serviceName
#   -d, --dest                    Set dest
#   -sn, --server-names           Set server names, e.g. xxx.com,www.xxx.com
#   -asn, --append-server-names   Append server names, e.g. xxx.com,www.xxx.com
#   --not-validate                Do not validate serverNames
#   -x, --x25519                  Set x25519
#   -sid, --shortIds              Set shortIds, e.g. -sid ; -sid 402a ; -sid fd,81d5,,2d5ac952d7a7
#   -rsid, --reset-shortIds       Reset shortIds
#   -asid, --append-shortIds      Append shortIds, e.g. -asid 402a ; -asid fd,81d5,,2d5ac952d7a7
#
# Explanation:
# - All parameters, except for "tag" itself, should be used with the "tag" parameter. The "tag" parameter is used to find the inbound object in the inbounds array that contains the corresponding "tag". If the -t/--tag parameter is not used, the default value is "xray-script-xtls-reality".
# - After finding the inbound element corresponding to the "tag", use the "email" parameter to find the client object in the clients array that contains the corresponding "email". If the -e/--email parameter is not used, the default value is "vless@xtls.reality".
#
# Examples:
#   ./xray_config_manage.sh -t xray-script-xtls-reality -e vless@xtls.reality -l 0.0.0.0 -p 443 -prcl vless -n 1 -d dest -sn servernames -u -x 2KZ4uouMKgI8nR-LDJNP1_MHisCJOmKGj9jUjZLncVU -sid
#   ./xray_config_manage.sh --tag xray-script-xtls-reality --email vless@xtls.reality --listen 0.0.0.0 --port 443 --protocol vless --network 1 --dest dest --server-names servernames --uuid --x25519 2KZ4uouMKgI8nR-LDJNP1_MHisCJOmKGj9jUjZLncVU --short-ids
#
# Dependencies: [xray jq openssl]
#
# Disclaimer: This document was generated by ChatGPT and has been modified by the author before publication.
#
# Author: zxcvos
# Version: 0.1
# Date: 2023-03-21

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/snap/bin
export PATH

readonly op_regex='^(^--(help|path|download|reset|tag|listen|port|protocol|email|uuid|network|dest|(append-)?server-names|not-validate|x25519|((reset|append)-)?shortIds)$)|(^-(prcl|a?sn|(r|a)?sid|[htpeundxl])$)$'
readonly proto_list=('vless')
readonly network_list=('tcp' 'h2' 'grpc')

declare configPath='/usr/local/etc/xray/config.json'
declare isDownload=0
declare matchTag='xray-script-xtls-reality'
declare isSetListen=0
declare setListen=''
declare isSetPort=0
declare setPort=0
declare isSetProto=0
declare setProto=0
declare matchEmail='vless@xtls.reality'
declare isResetUUID=0
declare resetUUID=''
declare isPickNetwork=0
declare pickNetwork=0
declare setDest=''
declare setServerNames=''
declare appendServerNames=''
declare isNotValidate=0
declare x25519PrivateKey=''
declare isResetShortIds=0
declare isSetShortIds=0
declare setShortIds=''
declare appendShortIds=''

if [ $# -eq 0 ]; then
    set -- '-h'
fi

while [[ $# -ge 1 ]]; do
    case "${1}" in
    --path)
        shift
        (printf "%s" "${1}" | grep -Eq "${op_regex}" || [ -z "$1" ]) && echo 'Error: path not provided' && exit 1
        configPath="$1"
        shift
        ;;
    --download | --reset)
        shift
        isDownload=1
        ;;
    -t | --tag)
        shift
        (printf "%s" "${1}" | grep -Eq "${op_regex}" || [ -z "$1" ]) && echo 'Error: tag not provided' && exit 1
        matchTag="$1"
        shift
        ;;
    -l | --listen)
        shift
        isSetListen=1
        if printf "%s" "${1}" | grep -Evq "${op_regex}"; then
            setListen="$1"
            shift
        fi
        ;;
    -p | --port)
        shift
        isSetPort=1
        if printf "%s" "${1}" | grep -Evq "${op_regex}"; then
            setPort="$1"
            shift
        fi
        ;;
    -prcl | --protocol)
        shift
        isSetProto=1
        if printf "%s" "${1}" | grep -Evq "${op_regex}"; then
            { [ "$1" -lt 1 ] || [ "$1" -gt ${#proto_list[@]} ]; } && echo "Error: -prcl|--protocol [1-${#proto_list[@]}]" && exit 1
            setProto="$1"
            shift
        fi
        ;;
    -e | --email)
        shift
        (printf "%s" "${1}" | grep -Eq "${op_regex}" || [ -z "$1" ]) && echo 'Error: email not provided' && exit 1
        matchEmail="$1"
        shift
        ;;
    -u | --uuid)
        shift
        isResetUUID=1
        param=$1
        [[ -z "$param" ]] && param="NOTNONE"
        if printf "%s" "${param}" | grep -Evq "${op_regex}"; then
            resetUUID="${param}"
            shift
        fi
        ;;
    -n | --network)
        shift
        isPickNetwork=1
        if printf "%s" "${1}" | grep -Evq "${op_regex}"; then
            { [ "$1" -lt 1 ] || [ "$1" -gt ${#network_list[@]} ]; } && echo "Error: -n|--network [1-${#network_list[@]}]" && exit 1
            pickNetwork="$1"
            shift
        fi
        ;;
    -d | --dest)
        shift
        (printf "%s" "${1}" | grep -Eq "${op_regex}" || [ -z "$1" ]) && echo 'Error: dest not provided' && exit 1
        setDest="$1"
        shift
        ;;
    -sn | --server-names)
        shift
        (printf "%s" "${1}" | grep -Eq "${op_regex}" || [ -z "$1" ]) && echo 'Error: server names not provided' && exit 1
        setServerNames="$1"
        shift
        ;;
    -asn | --append-server-names)
        shift
        (printf "%s" "${1}" | grep -Eq "${op_regex}" || [ -z "$1" ]) && echo 'Error: server names not provided' && exit 1
        appendServerNames="$1"
        shift
        ;;
    --not-validate)
        shift
        isNotValidate=1
        ;;
    -x | --x25519)
        shift
        (printf "%s" "${1}" | grep -Eq "${op_regex}" || [ -z "$1" ]) && echo 'Error: x25519 private key not provided' && exit 1
        x25519PrivateKey="$1"
        shift
        ;;
    -sid | --shortIds)
        shift
        isSetShortIds=1
        if printf "%s" "${1}" | grep -Evq "${op_regex}"; then
            setShortIds="$1"
            shift
        fi
        ;;
    -rsid | --reset-shortIds)
        shift
        isResetShortIds=1
        ;;
    -asid | --append-shortIds)
        shift
        (printf "%s" "${1}" | grep -Eq "${op_regex}" || [ -z "$1" ]) && echo 'Error: shortIds not provided' && exit 1
        appendShortIds="$1"
        shift
        ;;
    -h | --help)
        echo
        echo "$0 - A script to xray config manage."
        echo
        awk '/^# Usage:/,/^# Disclaimer:/ {if (/^# Disclaimer:/) exit;gsub(/^#\s?/,"");print $0}' "$0"
        exit 0
        ;;
    *)
        echo -ne "\nInvalid option: '$1'.\n"
        shift $#
        set -- '-h'
        ;;
    esac
done

function _exists() {
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

function is_digit() {
    local input=${1}
    if [[ "${input}" =~ ^[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

function is_port() {
    local input=${1}
    local port_regex='^((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([0-5]{0,5})|([0-9]{1,4}))$'
    if [[ "${input}" =~ ${port_regex} ]]; then
        return 0
    else
        return 1
    fi
}

function is_valid_IPv4_address() {
    local ip_regex='^((2(5[0-5]|[0-4][0-9]))|[0-1]?[0-9]{1,2})(\.((2(5[0-5]|[0-4][0-9]))|[0-1]?[0-9]{1,2})){3}$'
    local IPv4="${1}"
    local fields=()
    if [[ ! "${IPv4}" =~ ${ip_regex} ]]; then
        return 1
    fi
    #   fields=($(awk -v FS='.' '{for (i = 1; i<=NF; i++) arr[i] = $i} END{for (i in arr) print arr[i]}' <<<"${IPv4}"))
    mapfile -t fields < <(awk -v FS='.' '{for (i = 1; i<=NF; i++) arr[i] = $i} END{for (i in arr) print arr[i]}' <<<"${IPv4}")
    for field in "${fields[@]}"; do
        if ((field > 255)); then
            return 1
        fi
    done
    if ((${#fields[@]} != 4)); then
        return 1
    fi
    return 0
}

function is_valid_IPv6_address() {
    local ip_regex='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$'
    local IPv6="${1}"
    if [[ "${IPv6}" =~ ${ip_regex} ]]; then
        return 0
    else
        return 1
    fi
}

function is_UDS() {
    local input="${1}"
    if echo "${input}" | grep -Eq "^(\/[a-zA-Z0-9\_\-\+\.]+)*\/[a-zA-Z0-9\_\-\+]+\.sock$" || echo "${input}" | grep -Eq "^@{1,2}[a-zA-Z0-9\_\-\+\.]+$"; then
        return 0
    else
        return 1
    fi
}

function is_config_path() {
    local input="${1}"
    if echo "${input}" | grep -Eq "^(\/[a-zA-Z0-9\_\-\+\.]+)*\/[a-zA-Z0-9\_\-\+]+\.json$"; then
        return 0
    else
        return 1
    fi
}

function is_domain() {
    local input="${1}"
    local domain_regex='^((https?:\/\/)?([a-zA-Z0-9](\-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}(:((6553[0-5])|(655[0-2][0-9])|(65[0-4][0-9]{2})|(6[0-4][0-9]{3})|([1-5][0-9]{4})|([0-5]{0,5})|([0-9]{1,4})))?)$'
    if [[ "${input}" =~ ${domain_regex} ]]; then
        return 0
    else
        return 1
    fi
}

function is_valid_uuid() {
    local input="${1}"
    if printf "%s" "${input}" | grep -Eq '^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$'; then
        return 0
    else
        return 1
    fi
}

function set_listen() {
    local in_tag="${1}"
    local in_listen="${2}"
    [ -z "${in_listen}" ] && in_listen='0.0.0.0'
    if is_valid_IPv4_address "${in_listen}" || is_valid_IPv6_address "${in_listen}" || is_UDS "${in_listen}"; then
        jq --arg in_tag "${in_tag}" --arg in_listen "${in_listen}" '.inbounds |= map(if .tag == $in_tag then .listen = $in_listen else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
    else
        echo "Invalid IPv4 address format: ${in_listen}"
        echo "Invalid IPv6 address format: ${in_listen}"
        echo "Invalid UDS file path or abstract socket format: ${in_listen}"
        exit 1
    fi
}

function set_port() {
    local in_tag="${1}"
    local in_port="${2}"
    [ "${in_port}" -eq 0 ] && in_port=443
    if is_port "${in_port}"; then
        jq --arg in_tag "${in_tag}" --argjson in_port "${in_port}" '.inbounds |= map(if .tag == $in_tag then .port = $in_port else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
    else
        echo "Error: Please enter a valid port number between 1-65535"
        exit 1
    fi
}

function select_proto() {
    local in_tag="${1}"
    local pick="${2}"
    local in_proto=''
    [ "${pick}" -eq 0 ] && pick=1
    if is_digit "${pick}" && [ "${pick}" -ge 1 ] && [ "${pick}" -le ${#proto_list[@]} ]; then
        in_proto="${proto_list[$(("${pick}" - 1))]}"
        jq --arg in_tag "${in_tag}" --arg in_proto "${in_proto}" '.inbounds |= map(if .tag == $in_tag then .protocol = $in_proto else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
    else
        echo "Error: Please enter a valid protocol list index between 1-${#proto_list[@]}"
        exit 1
    fi
}

function reset_uuid() {
    local in_tag="${1}"
    local c_email="${2}"
    local c_id="${3}"
    if [ -z "${c_id}" ]; then
        c_id=$(xray uuid)
    elif ! is_valid_uuid "${c_id}"; then
        c_id=$(xray uuid -i "${c_id}")
    fi
    jq --arg in_tag "${in_tag}" --arg c_email "${c_email}" --arg c_id "${c_id}" '.inbounds |= map(if .tag == $in_tag then .settings.clients |= map(if .email == $c_email then .id = $c_id else . end) else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
}

function select_network() {
    local in_tag="${1}"
    local pick="${2}"
    local in_network=''
    [ "${pick}" -eq 0 ] && pick=1
    if is_digit "${pick}" && [ "${pick}" -ge 1 ] && [ "${pick}" -le ${#network_list[@]} ]; then
        in_network="${network_list[$(("${pick}" - 1))]}"
        jq --arg in_tag "${in_tag}" '.inbounds |= map(if .tag == $in_tag then del(.streamSettings.grpcSettings) else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
        jq --arg in_tag "${in_tag}" '.inbounds |= map(if .tag == $in_tag then .settings.clients |= map(.flow = "") else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
        jq --arg in_tag "${in_tag}" --arg in_network "${in_network}" '.inbounds |= map(if .tag == $in_tag then .streamSettings.network = $in_network else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
        case "${in_network}" in
        tcp)
            jq --arg in_tag "${in_tag}" '.inbounds |= map(if .tag == $in_tag then .settings.clients |= map(.flow = "xtls-rprx-vision") else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
            ;;
        grpc)
            jq --arg in_tag "${in_tag}" --arg serviceName "$(head -c 32 /dev/urandom | md5sum | head -c 8)" '.inbounds |= map(if .tag == $in_tag then .streamSettings.grpcSettings |= {"serviceName": $serviceName} else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
            ;;
        esac
    else
        echo "Error: Please enter a valid network list index between 1-${#network_list[@]}"
        exit 1
    fi
}

function set_dest() {
    local in_tag="${1}"
    local dest="${2}"
    if is_UDS "${dest}" || is_domain "${dest}"; then
        dest="${dest#*//}"
        if ! is_UDS "${dest}" && [ "${dest}" == "${dest%:*}" ]; then
            dest="${dest}:443"
        fi
        jq --arg in_tag "${in_tag}" --arg dest "${dest}" '.inbounds |= map(if .tag == $in_tag then .streamSettings.realitySettings.target = $dest else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
    else
        echo "Error: Please enter a valid domain name or socket path"
        exit 1
    fi
}

function set_server_names() {
    local in_tag="${1}"
    local sns_str="${2}"
    local is_append="${3}"
    local sns_list=''
    for domain in $(printf '%s' "${sns_str}" | jq -R -s -c -r 'split(",") | map(select(length > 0)) | .[]'); do
        if [[ ${isNotValidate} -eq 1 ]]; then
            sns_list+="${domain},"
        else
            xray tls ping "${domain}" >/dev/null 2>&1 && sns_list+="${domain},"
        fi
    done
    sns_list=$(printf '%s' "${sns_list}" | jq -R -s -c 'split(",") | map(select(length > 0))')
    if [ "${sns_list}" != '[]' ]; then
        [ "${is_append}" -eq 0 ] && jq --arg in_tag "${in_tag}" '.inbounds |= map(if .tag == $in_tag then .streamSettings.realitySettings.serverNames = [] else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
        jq --arg in_tag "${in_tag}" --argjson sns "${sns_list}" '.inbounds |= map(if .tag == $in_tag then .streamSettings.realitySettings.serverNames += $sns else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
        [ "${is_append}" -eq 1 ] && jq --arg in_tag "${in_tag}" --argjson sns "${sns_list}" '.inbounds |= map(if .tag == $in_tag then .streamSettings.realitySettings.serverNames = (.streamSettings.realitySettings.serverNames | unique) else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
    else
        echo "Error: Please enter a valid domain name, e.g. xxx.com,www.xxx.com"
        exit 1
    fi
}

function reset_x25519() {
    local in_tag="${1}"
    local private_key="${2}"
    if [ "${private_key}" ]; then
        jq --arg in_tag "${in_tag}" --arg private_key "${private_key}" '.inbounds |= map(if .tag == $in_tag then .streamSettings.realitySettings.privateKey = $private_key else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
    else
        echo 'Error: x25519 private key not provided'
        exit 1
    fi
}

function set_sid() {
    local in_tag="${1}"
    local is_append="${2}"
    local sids_str="${3}"
    local sids_list=''
    for sid in $(printf '%s' "${sids_str}" | jq -R -s -c -r 'split(",") | .[]'); do
        [ $((${#sid} % 2)) -eq 0 ] && [ ${#sid} -le 16 ] && sids_list+="${sid},"
    done
    sids_list=$(printf '%s' "${sids_list}" | jq -R -s -c 'split(",")')
    if [ "${is_append}" -eq 0 ]; then
        jq --arg in_tag "${in_tag}" '.inbounds |= map(if .tag == $in_tag then .streamSettings.realitySettings.shortIds = [""] else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
    elif [ "${sids_list}" == '[]' ]; then
        echo "Error: Please enter a valid shortIds, e.g. 402a or fd,81d5,2d5ac952d7a7"
        exit 1
    fi
    jq --arg in_tag "${in_tag}" --argjson sids "${sids_list}" '.inbounds |= map(if .tag == $in_tag then .streamSettings.realitySettings.shortIds += $sids else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
    jq --arg in_tag "${in_tag}" --argjson sids "${sids_list}" '.inbounds |= map(if .tag == $in_tag then .streamSettings.realitySettings.shortIds = (.streamSettings.realitySettings.shortIds | unique) else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
    jq --arg in_tag "${in_tag}" --argjson sids "${sids_list}" '.inbounds |= map(if .tag == $in_tag then .streamSettings.realitySettings.shortIds = (.streamSettings.realitySettings.shortIds | sort_by(length)) else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
}

function reset_sid() {
    local in_tag="${1}"
    local sids_len=0
    local sid_len=0
    local sid=''
    sids_len=$(jq --arg in_tag "${in_tag}" '.inbounds[] | select(.tag == $in_tag) | .streamSettings.realitySettings.shortIds | length' "${configPath}")
    if [ "${sids_len}" -gt 0 ]; then
        for i in $(seq 1 "${sids_len}"); do
            sid_len=$(jq --arg in_tag "${in_tag}" --argjson i $((i - 1)) '.inbounds[] | select(.tag == $in_tag) | .streamSettings.realitySettings.shortIds[$i] | length' "${configPath}")
            sid_len=$(("${sid_len}" / 2))
            [ ${sid_len} -eq 0 ] && continue
            sid=$(openssl rand -hex ${sid_len})
            jq --arg in_tag "${in_tag}" --arg sid "${sid}" --argjson i $((i - 1)) '.inbounds |= map(if .tag == $in_tag then .streamSettings.realitySettings.shortIds[$i] = $sid else . end)' "${configPath}" >"${HOME}"/new.json && mv -f "${HOME}"/new.json "${configPath}"
        done
    else
        echo 'Error: shortIds is empty'
        exit 1
    fi
}

if ! _exists 'jq' || ! _exists 'xray'; then
    echo 'Error: jq or Xray not found, please install jq and Xray first'
    exit 1
fi

if ! is_config_path "${configPath}"; then
    echo 'Error: Please use a full Xray configuration file path'
    exit 1
fi

if [ ${isDownload} -eq 1 ]; then
    wget -O "${configPath}" https://raw.githubusercontent.com/faintx/public/main/configs/VLESS-XTLS-uTLS-REALITY/server.json
fi

if [ ${isSetListen} -eq 1 ]; then
    set_listen "${matchTag}" "${setListen}"
fi

if [ ${isSetPort} -eq 1 ]; then
    set_port "${matchTag}" "${setPort}"
fi

if [ ${isSetProto} -eq 1 ]; then
    select_proto "${matchTag}" "${setProto}"
fi

if [ ${isResetUUID} -eq 1 ]; then
    reset_uuid "${matchTag}" "${matchEmail}" "${resetUUID}"
fi

if [ ${isPickNetwork} -eq 1 ]; then
    select_network "${matchTag}" "${pickNetwork}"
fi

if [ "${setDest}" ]; then
    set_dest "${matchTag}" "${setDest}"
fi

if [ "${setServerNames}" ]; then
    set_server_names "${matchTag}" "${setServerNames}" 0
fi

if [ "${appendServerNames}" ]; then
    set_server_names "${matchTag}" "${appendServerNames}" 1
fi

if [ "${x25519PrivateKey}" ]; then
    reset_x25519 "${matchTag}" "${x25519PrivateKey}"
fi

if [ ${isSetShortIds} -eq 1 ]; then
    set_sid "${matchTag}" 0 "${setShortIds}"
fi

if [ ${isResetShortIds} -eq 1 ]; then
    reset_sid "${matchTag}"
fi

if [ "${appendShortIds}" ]; then
    set_sid "${matchTag}" 1 "${appendShortIds}"
fi
