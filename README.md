# LLBot Docker 安装脚本
## 修改内容
1. 优化安装流程
2. 使用1ms镜像站安装
3. 修复镜像站无法使用
4. 修复镜像拉取失败
5. 去掉了Auth Token
6. 新增 IPv6 监听
## Docker Compose 版本
使用 Docker Compose 一键部署，支持 Linux 和 macOS
### 特性
- [x] 容器化部署
- [x] 环境隔离
- [x] 一键安装
- [x] 易于管理
- [x] 自动化配置
### 系统要求
- 如果是 macOS 请安装 OrbStack 不要使用 Docker Desktop !!!
## 安装步骤
1. 安装 Docker 环境
> Linux 用户：确保已安装 Docker 和 Docker Compose  
macOS 用户：必须使用 OrbStack，不要使用 Docker Desktop  
前往 OrbStack 官网 下载并安装，或使用 Homebrew：
```bash
brew install orbstack
```
>> 提示：OrbStack 比 Docker Desktop 更快、更轻量，且完全兼容 Docker 命令
2. 运行一键脚本
```bash
curl -fsSL https://raw.githubusercontent.com/LYSHST/llbot-docker-install/refs/heads/main/llbot-docker-install.sh -o llbot-docker.sh && chmod u+x ./llbot-docker.sh && ./llbot-docker.sh
```
>> 提示：脚本会自动配置生成 docker-compose.yaml
3. 启动容器
```bash
docker-compose up -d
```
4. 查看日志
```bash
docker-compose logs -f
```
5.扫码登录
> 按照日志中的提示扫码登录 QQ 或者打开 WebUI http://localhost:3080 进行登录
  
> 安装完成后，请查看 [配置指南](https://www.llonebot.com/guide/config) 了解如何配置 LLBot 对接你的机器人框架。
