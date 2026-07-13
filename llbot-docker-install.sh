#!/bin/bash

echo "=========================================="
echo "LLBot Docker 安装脚本"
echo "这是第三方的脚本，不负责任何责任。本脚本负责安装 LLBot"
echo "by LYSHST(薯条甜不辣!)"
echo "=========================================="
echo ""
config_mode="2"
echo "已自动选择：2) 稍后配置（仅配置 WebUI，其他选项在 WebUI 中配置）"
echo ""

# 原版mode2固定空，全程无读取输入逻辑
AUTH_TOKEN=""

AUTO_LOGIN_QQ=""
while [ -z "$AUTO_LOGIN_QQ" ]; do
    read -p "请输入 QQ 号（必填）: " AUTO_LOGIN_QQ
    [[ "$AUTO_LOGIN_QQ" =~ ^[0-9]+$ ]] || { echo "错误：QQ 号必须是数字！"; AUTO_LOGIN_QQ=""; continue; }
done

declare -A SERVICE_PORTS
ENABLE_WEBUI="true"
WEBUI_HOST=""
WEBUI_PORT="3080"
WEBUI_TOKEN=""

echo ""
echo "WebUI 配置："
while [ -z "$WEBUI_TOKEN" ]; do
    read -p "WebUI 密码（必填，仅支持英文和数字）: " WEBUI_TOKEN
done

while true; do
    read -p "WebUI 端口 (默认 3080): " port
    port=${port:-3080}
    [[ "$port" =~ ^[0-9]+$ ]] || { echo "错误：端口必须是数字！"; continue; }
    WEBUI_PORT=$port
    SERVICE_PORTS["$WEBUI_PORT"]=1
    break
done

# mode2直接跳过所有协议配置
protocol_choices=""
ENABLE_OB11="false"
declare -a OB11_CONNECTS
ENABLE_MILKY="false"
MILKY_HTTP_HOST=""
MILKY_HTTP_PORT="3000"
MILKY_HTTP_PREFIX="/milky"
MILKY_HTTP_TOKEN=""
MILKY_WEBHOOK_URLS="[]"
MILKY_WEBHOOK_TOKEN=""
ENABLE_SATORI="false"
SATORI_HOST=""
SATORI_PORT="5500"
SATORI_TOKEN=""
OB11_CONNECT_JSON="[]"

mkdir -p llbot_config
# 仅生成两个文件，auth_token.txt为空，网页填写
echo "$WEBUI_TOKEN" > "llbot_config/webui_token.txt"
echo "WebUI 密码文件已生成: llbot_config/webui_token.txt"
echo "$AUTH_TOKEN" > "llbot_config/auth_token.txt"
echo "Auth Token 文件已生成: llbot_config/auth_token.txt"
chmod -R 777 llbot_config

echo ""
read -p "是否使用 Docker 镜像源 (y/n): " use_docker_mirror
docker_mirror=""
PMHQ_IMG_TAG="latest"
LLBOT_IMG_TAG="latest"

if [[ "$use_docker_mirror" =~ ^[yY]$ ]]; then
    docker_mirror="docker.1ms.run/"
fi

# 端口兼容IPv4+IPv6
PORTS_CONFIG=""
if [ ${#SERVICE_PORTS[@]} -gt 0 ]; then
    PORTS_CONFIG="    ports:"
    for port in "${!SERVICE_PORTS[@]}"; do
        PORTS_CONFIG="${PORTS_CONFIG}
      - \"[::]:${port}:${port}\""
    done
fi

LLBOT_HEALTHCHECK="    healthcheck:
      test:
        - CMD-SHELL
        - node -e \"fetch('http://127.0.0.1:'+(process.env.WEBUI_PORT||3080)).then(()=>process.exit(0),()=>process.exit(1))\"
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s"

LLBOT_ENV="      - WEBUI_PORT=${WEBUI_PORT}
      - QQ=${AUTO_LOGIN_QQ}"

# 双容器 compose
cat << EOF > docker-compose.yml
version: "3.8"
services:
  pmhq:
    image: ${docker_mirror}linyuchen/pmhq:${PMHQ_IMG_TAG}
    privileged: true
    environment:
      - ENABLE_HEADLESS=false
    networks:
      - app_network
    volumes:
      - qq_volume:/root/.config/QQ
      - ./llbot_config:/app/llbot/data:rw
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:13000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  llbot:
    image: ${docker_mirror}linyuchen/llbot:${LLBOT_IMG_TAG}
${PORTS_CONFIG}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
${LLBOT_ENV}
      - PMHQ_HOST=pmhq
    networks:
      - app_network
    volumes:
      - qq_volume:/root/.config/QQ
      - ./llbot_config:/app/llbot/data:rw
    depends_on:
      - pmhq
    restart: unless-stopped
${LLBOT_HEALTHCHECK}

volumes:
  qq_volume:
networks:
  app_network:
    driver: bridge
EOF

echo ""
echo "Docker Compose 配置已生成: docker-compose.yml"

printLogin(){
    echo ""
    echo "=========================================="
    echo "配置完成！"
    echo "=========================================="
    echo ""
    echo "生成的文件："
    echo "  - llbot_config/webui_token.txt"
    echo "  - llbot_config/auth_token.txt"
    echo "  - docker-compose.yml"
    echo ""
    echo "WebUI 访问地址: http://localhost:${WEBUI_PORT}"
    echo "WebUI 密码: ${WEBUI_TOKEN}"
    echo ""
    echo "登录方式: 启动后打开 WebUI 扫码登录，"
    echo "          或运行 sudo docker compose logs -f llbot 在日志中查看二维码"
    echo ""
    echo "提示: 您选择了稍后配置模式"
    echo "请在 WebUI 中完成 AuthToken、协议配置等所有设置"
    echo "Auth Token 获取地址: https://auth.luckylillia.com"
    echo ""
    echo "启动命令: sudo docker compose up -d"
    echo "查看日志: sudo docker compose logs -f"
    echo "=========================================="
}

# Root校验
if [ "$(id -u)" -ne 0 ]; then
    echo "没有 root 权限，请手动运行 sudo docker compose up -d"
    printLogin
    exit 1
fi

# 仅检测Docker不安装
if ! command -v docker &> /dev/null; then
  echo "没有安装 Docker！安装后运行 sudo docker compose up -d"
  printLogin
  exit 1
fi
if ! docker compose version &> /dev/null; then
  echo "未检测到 docker compose，请升级Docker"
  printLogin
  exit 1
fi

echo ""
read -p "是否立即启动 Docker 容器 (y/n): " start_docker
if [[ "$start_docker" =~ ^[yY]$ ]]; then
    docker compose up -d
fi

printLogin
