#!/bin/bash
# Puma systemd 服务配置脚本
# 在服务器上以 root 运行此脚本

set -e

APP_NAME="sci2"
SERVICE_NAME="puma-${APP_NAME}"
DEPLOY_USER="deploy"
DEPLOY_PATH="/opt/${APP_NAME}"
RUBY_VERSION="3.4.2"

echo "=== Puma systemd 服务配置 ==="
echo "应用: ${APP_NAME}"
echo "服务: ${SERVICE_NAME}"
echo "用户: ${DEPLOY_USER}"
echo "路径: ${DEPLOY_PATH}"
echo ""

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本"
  echo "sudo bash $0"
  exit 1
fi

# 1. 创建 systemd 服务文件
echo "[1/4] 创建 systemd 服务文件..."
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Puma HTTP Server for ${APP_NAME}
After=network.target

[Service]
Type=simple
User=${DEPLOY_USER}
WorkingDirectory=${DEPLOY_PATH}/current
Environment=RAILS_ENV=production
Environment=PATH=/usr/local/rvm/gems/ruby-${RUBY_VERSION}/bin:/usr/local/rvm/gems/ruby-${RUBY_VERSION}@global/bin:/usr/local/rvm/rubies/ruby-${RUBY_VERSION}/bin:/usr/local/rvm/bin:/usr/bin:/bin
Environment=GEM_HOME=/usr/local/rvm/gems/ruby-${RUBY_VERSION}
Environment=GEM_PATH=/usr/local/rvm/gems/ruby-${RUBY_VERSION}:/usr/local/rvm/gems/ruby-${RUBY_VERSION}@global

ExecStart=/usr/local/rvm/bin/rvm ${RUBY_VERSION} do bundle exec puma -C ${DEPLOY_PATH}/shared/config/puma.rb
ExecReload=/bin/kill -USR1 \$MAINPID
PIDFile=${DEPLOY_PATH}/shared/tmp/pids/puma.pid

Restart=always
RestartSec=5
StandardOutput=append:${DEPLOY_PATH}/shared/log/puma.stdout.log
StandardError=append:${DEPLOY_PATH}/shared/log/puma.stderr.log

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/${SERVICE_NAME}.service
echo "✓ 服务文件已创建: /etc/systemd/system/${SERVICE_NAME}.service"

# 2. 配置 sudoers
echo ""
echo "[2/4] 配置 sudoers 权限..."
cat > /etc/sudoers.d/puma-deploy << EOF
# Sudoers for Capistrano Puma deployment
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl start ${SERVICE_NAME}
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl stop ${SERVICE_NAME}
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl restart ${SERVICE_NAME}
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl reload ${SERVICE_NAME}
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl status ${SERVICE_NAME}
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl is-active ${SERVICE_NAME}
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl daemon-reload
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl enable ${SERVICE_NAME}
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl list-unit-files ${SERVICE_NAME}.service
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/mv /tmp/${SERVICE_NAME}.service /etc/systemd/system/${SERVICE_NAME}.service
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/chmod 644 /etc/systemd/system/${SERVICE_NAME}.service
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/journalctl -u ${SERVICE_NAME} *
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
EOF

chmod 440 /etc/sudoers.d/puma-deploy
echo "✓ sudoers 配置已创建: /etc/sudoers.d/puma-deploy"

# 3. 重新加载 systemd
echo ""
echo "[3/4] 重新加载 systemd..."
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
echo "✓ systemd 已重新加载，服务已启用"

# 4. 停止旧的 puma 进程并启动服务
echo ""
echo "[4/4] 启动 Puma 服务..."

# 停止可能存在的旧进程
pkill -f "puma.*${APP_NAME}" 2>/dev/null || true
sleep 2

# 启动服务
systemctl start ${SERVICE_NAME}
sleep 3

# 检查状态
if systemctl is-active --quiet ${SERVICE_NAME}; then
  echo "✓ ${SERVICE_NAME} 服务启动成功"
  systemctl status ${SERVICE_NAME} --no-pager
else
  echo "✗ ${SERVICE_NAME} 服务启动失败"
  journalctl -u ${SERVICE_NAME} -n 20 --no-pager
  exit 1
fi

echo ""
echo "=== 配置完成 ==="
echo ""
echo "常用命令:"
echo "  查看状态: sudo systemctl status ${SERVICE_NAME}"
echo "  查看日志: sudo journalctl -u ${SERVICE_NAME} -f"
echo "  重启服务: sudo systemctl restart ${SERVICE_NAME}"
echo "  停止服务: sudo systemctl stop ${SERVICE_NAME}"
echo ""
echo "Capistrano 部署现在会自动使用 systemctl 管理 Puma"
