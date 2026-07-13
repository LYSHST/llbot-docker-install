#!/bin/bash

echo "=========================================="
echo "LLBot Docker 安装脚本"
echo "这是第三方的脚本，不负责任何责任。本脚本负责安装 LLBot"
echo "by LYSHST(薯条甜不辣!)"
echo "=========================================="
echo ""
# 强制固定模式2，跳过选择菜单
config_mode="2"
echo "已自动选择：2) 稍后配置（仅配置 WebUI，其他选项在 WebUI 中配置）"
echo ""

AUTO_LOGIN_QQ=""
while [ -z "$AUTO_LOGIN_QQ" ]; do
    read -p "请输入 QQ 号（必填）: " AUTO_LOGIN_QQ
    [[ "$AUTO_LOGIN_QQ" =~ ^[0-9]+$ ]] || { echo "错误：QQ 号必须是数字！"; AUTO_LOGIN_QQ=""; continue; }
done

# Auth Token: 模式2留空，WebUI录入
AUTH_TOKEN=""

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

# 模式2 跳过全部协议配置
protocol_choices=""

# 清空协议相关变量（原版逻辑保留）
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

# 创建配置目录
mkdir -p llbot_config

# 模式2不生成config_QQ.json，保留两个必要文件
echo "$WEBUI_TOKEN" > "llbot_config/webui_token.txt"
echo "WebUI 密码文件已生成: llbot_config/webui_token.txt"

echo "$AUTH_TOKEN" > "llbot_config/auth_token.txt"
echo "Auth Token 文件已生成: llbot_config/auth_token.txt"

# 权限
chmod -R 777 llbot_config

echo ""
read -p "是否使用 Docker 镜像源 (y/n): " use_docker_mirror

docker_mirror=""
# 固定latest标签，双容器镜像
PMHQ_IMG_TAG="latest"
LLBOT_IMG_TAG="latest"

# 替换为1ms镜像源，删除原版gh-proxy镜像检测逻辑
if [[ "$use_docker_mirror" =~ ^[yY]$ ]]; then
    docker_mirror="docker.1ms.run/"
fi

# 端口改为 [::] 同时监听IPv4/IPv6
PORTS_CONFIG=""
if [ ${#SERVICE_PORTS[@]} -gt 0 ]; then
    PORTS_CONFIG="    ports:"
    for port in "${!SERVICE_PORTS[@]}"; do
        PORTS_CONFIG="${PORTS_CONFIG}
      - \"[::]:${port}:${port}\""
    done
fi

# llbot健康检查（原版完全不变）
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

# 生成双容器 pmhq + llbot compose（替换原版单llbot）
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

# 原版printLogin完整输出不修改
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
    echo "请在 WebUI 中完成 QQ 登录、协议配置等所有设置"
    echo ""
    echo "启动命令: sudo docker compose up -d"
    echo "查看日志: sudo docker compose logs -f"
    echo "=========================================="
}

# root权限校验（原版原样）
if [ "$(id -u)" -ne 0 ]; then
    echo "没有 root 权限，请手动运行 sudo docker compose up -d"
    printLogin
    exit 1
fi

# 检测docker、compose，不自动安装docker（原版逻辑）
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
