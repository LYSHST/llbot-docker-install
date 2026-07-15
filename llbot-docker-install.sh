#!/bin/bash

echo "=========================================="
echo "LLBot Docker 安装脚本"
echo "这是第三方的脚本，不负责任何责任。本脚本负责安装 LLBot"
echo "by LYSHST(薯条甜不辣!)"
echo "=========================================="
echo ""
config_mode="2"
echo "仅配置 WebUI，其他选项在 WebUI 中配置"
echo ""

AUTH_TOKEN=""
declare -A SERVICE_PORTS
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

mkdir -p llbot_config
echo "$WEBUI_TOKEN" > "llbot_config/webui_token.txt"
echo "WebUI 密码文件已生成: llbot_config/webui_token.txt"
echo "$AUTH_TOKEN" > "llbot_config/auth_token.txt"
echo "Auth Token 文件已生成: llbot_config/auth_token.txt"
chmod -R 777 llbot_config

echo ""
read -p "是否使用 Docker 镜像源 (y/n): " use_docker_mirror
docker_mirror=""
LLBOT_TAG="7.12.14"
PMHQ_TAG="latest"

if [[ "$use_docker_mirror" =~ ^[yY]$ ]]; then
    docker_mirror="docker.1ms.run/"
fi

# 新增IPv6选择
echo ""
read -p "是否需要监听 IPv6 (y/n): " enable_ipv6

PORTS_CONFIG=""
if [ ${#SERVICE_PORTS[@]} -gt 0 ]; then
    PORTS_CONFIG="    ports:"
    for port in "${!SERVICE_PORTS[@]}"; do
        if [[ "$enable_ipv6" =~ ^[yY]$ ]]; then
            PORTS_CONFIG="${PORTS_CONFIG}
      - \"[::]:${port}:${port}\""
        else
            PORTS_CONFIG="${PORTS_CONFIG}
      - \"${port}:${port}\""
        fi
    done
fi

cat << EOF > docker-compose.yml
version: "3.8"
services:
  pmhq:
    image: ${docker_mirror}linyuchen/pmhq:latest
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
    image: ${docker_mirror}linyuchen/llbot:8.0.8
${PORTS_CONFIG}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - PMHQ_HOST=pmhq
      - WEBUI_PORT=${WEBUI_PORT}
    networks:
      - app_network
    volumes:
      - qq_volume:/root/.config/QQ
      - ./llbot_config:/app/llbot/data:rw
    depends_on:
      - pmhq
    restart: unless-stopped
    healthcheck:
      test:
        - CMD-SHELL
        - node -e "fetch('http://127.0.0.1:'+(process.env.WEBUI_PORT||3080)).then(()=>process.exit(0),()=>process.exit(1))"
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

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
}

if [ "$(id -u)" -ne 0 ]; then
    echo "没有 root 权限，请手动运行 sudo docker compose up -d"
    printLogin
    exit 1
fi

if ! command -v docker &> /dev/null; then
  echo "未检测到 Docker，请先自行安装 Docker 后再执行启动命令"
  printLogin
  exit 1
fi
if ! docker compose version &> /dev/null; then
  echo "未检测到 docker compose，请升级 Docker 版本后重试"
  printLogin
  exit 1
fi

echo ""
read -p "是否立即启动 Docker 容器 (y/n): " start_docker
if [[ "$start_docker" =~ ^[yY]$ ]]; then
    docker compose up -d
fi

printLogin
