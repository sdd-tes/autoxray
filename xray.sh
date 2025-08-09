#!/bin/bash
set -e

green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "$(uname -s)"
  fi
}

install_dependencies() {
  OS=$(detect_os)
  green "检测系统：$OS，安装依赖中..."
  case "$OS" in
    ubuntu|debian)
      sudo apt update
      sudo apt install -y curl wget xz-utils jq xxd openssl >/dev/null 2>&1
      ;;
    centos|rhel|rocky|alma)
      sudo yum install -y epel-release
      sudo yum install -y curl wget xz jq vim-common openssl >/dev/null 2>&1
      ;;
    alpine)
      sudo apk update
      sudo apk add --no-cache curl wget xz jq vim openssl
      ;;
    *)
      red "不支持的系统: $OS"
      exit 1
      ;;
  esac
}

check_and_install_xray() {
  if command -v xray >/dev/null 2>&1; then
    green "✅ Xray 已安装，跳过"
  else
    green "❗检测到 Xray 未安装，安装中..."
    bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
    XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
    if [ ! -x "$XRAY_BIN" ]; then
      red "❌ Xray 安装失败，请检查"
      exit 1
    fi
    green "✅ Xray 安装完成"
  fi
}

restart_xray_service() {
  if command -v systemctl >/dev/null 2>&1; then
    green "用 systemd 重启 xray"
    sudo systemctl daemon-reexec
    sudo systemctl restart xray
    sudo systemctl enable xray
  elif command -v rc-service >/dev/null 2>&1; then
    green "用 OpenRC 重启 xray"
    sudo rc-service xray restart
    sudo rc-update add xray default
  else
    yellow "⚠️ 找不到合适的服务管理命令，请手动启动 xray"
  fi
}

# 读取用户输入端口和备注
read_port_and_remark() {
  read -rp "请输入 $1 监听端口（默认 $2）: " port
  port=${port:-$2}
  read -rp "请输入 $1 节点备注（默认 $3）: " remark
  remark=${remark:-$3}
  echo "$port|$remark"
}

generate_reality_keys() {
  XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
  KEYS=$($XRAY_BIN x25519)
  PRIV_KEY=$(echo "$KEYS" | awk '/Private/ {print $3}')
  PUB_KEY=$(echo "$KEYS" | awk '/Public/ {print $3}')
  SHORT_ID=$(head -c 4 /dev/urandom | xxd -p)
  echo "$PRIV_KEY|$PUB_KEY|$SHORT_ID"
}

main() {
  install_dependencies
  check_and_install_xray

  # 取IP
  IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)

  # VLESS
  vless_input=$(read_port_and_remark "VLESS Reality" 443 "vlessNode")
  vless_port=${vless_input%%|*}
  vless_remark=${vless_input##*|}
  vless_keys=$(generate_reality_keys)
  vless_priv=${vless_keys%%|*}
  rest=${vless_keys#*|}
  vless_pub=${rest%%|*}
  vless_sid=${rest##*|}

  # Trojan
  trojan_input=$(read_port_and_remark "Trojan Reality" 8443 "trojanNode")
  trojan_port=${trojan_input%%|*}
  trojan_remark=${trojan_input##*|}
  trojan_password=$(openssl rand -hex 8)
  trojan_keys=$(generate_reality_keys)
  trojan_priv=${trojan_keys%%|*}
  rest=${trojan_keys#*|}
  trojan_pub=${rest%%|*}
  trojan_sid=${rest##*|}

  # Shadowsocks
  ss_input=$(read_port_and_remark "Shadowsocks Reality" 8388 "ssNode")
  ss_port=${ss_input%%|*}
  ss_remark=${ss_input##*|}
  ss_method="aes-128-gcm"
  ss_password=$(openssl rand -hex 8)
  ss_keys=$(generate_reality_keys)
  ss_priv=${ss_keys%%|*}
  rest=${ss_keys#*|}
  ss_pub=${rest%%|*}
  ss_sid=${rest##*|}

  SNI="www.cloudflare.com"

  mkdir -p /usr/local/etc/xray

  cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $vless_port,
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "$(cat /proc/sys/kernel/random/uuid)", "email": "$vless_remark" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$SNI:443",
          "xver": 0,
          "serverNames": ["$SNI"],
          "privateKey": "$vless_priv",
          "shortIds": ["$vless_sid"]
        }
      }
    },
    {
      "port": $trojan_port,
      "protocol": "trojan",
      "settings": {
        "clients": [ { "password": "$trojan_password", "email": "$trojan_remark" } ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$SNI:443",
          "xver": 0,
          "serverNames": ["$SNI"],
          "privateKey": "$trojan_priv",
          "shortIds": ["$trojan_sid"]
        }
      }
    },
    {
      "port": $ss_port,
      "protocol": "shadowsocks",
      "settings": {
        "method": "$ss_method",
        "password": "$ss_password",
        "network": "tcp,udp"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$SNI:443",
          "xver": 0,
          "serverNames": ["$SNI"],
          "privateKey": "$ss_priv",
          "shortIds": ["$ss_sid"]
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ]
}
EOF

  restart_xray_service

  green "✅ 节点配置完成，以下为链接信息："

  vless_uuid=$(jq -r '.inbounds[0].settings.clients[0].id' /usr/local/etc/xray/config.json)
  echo "VLESS Reality:"
  echo "vless://${vless_uuid}@${IP}:${vless_port}?type=tcp&security=reality&sni=${SNI}&fp=chrome&pbk=${vless_pub}&sid=${vless_sid}#${vless_remark}"
  echo

  echo "Trojan Reality:"
  echo "trojan://${trojan_password}@${IP}:${trojan_port}#${trojan_remark}"
  echo

  # Shadowsocks 链接格式带加密方式和密码 base64 编码
  ss_userpass=$(echo -n "${ss_method}:${ss_password}" | base64 -w 0)
  echo "Shadowsocks Reality:"
  echo "ss://${ss_userpass}@${IP}:${ss_port}#${ss_remark}"
  echo

  read -rp "按任意键退出..."
}

main