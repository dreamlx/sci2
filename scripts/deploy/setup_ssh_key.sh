#!/bin/bash
# 脚本：将SSH公钥添加到测试服务器

set -e

# 服务器配置
SERVER_IP="8.136.10.88"
SERVER_USER="root"
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDmiG5+bDL5ZmIoH9Z4tmMvdwtwkf9g2uzk7nB2Gsa6Bdg9adIpKrI0UQg/xV3sdMmct1icLqyOrI8oJVJSYgvQmJ7VKhXMKLrFdYoZ0LKzZc8Z6rEDfsfUaXD5MS16NA52K09k+MNqf3WAzRn3ygW4HoZbNTsSpiXqLHNjIivri563zavKAhFHMVcneDtygzD7YMG52TVhbEnL6PSwJyAZfP4ptIy5+cq9lR3Rh01pXVqgMJ9w5/H6O/hLidYNpwC0qPOL09DhAX/19ZHwx8KPtilH60keofOo1fD8jaB5jYtingiHq+jyedXA47r5IozjmMs78ej9Q9XNJHEIm9jhMw0Fphu3Ox//Y24URLRKs/hnP7zxmWOO1bPNv01/01LWhaInYoxGraNENsSRgGA1r57OH9n0gb7reSpb7xsqMCe2Ifha/U+l4hNwrVSxlXrRJ0/3w8tmLoR4IeyF1NZG0zD2v1nJ9LdSyAAxcoUhQ6XYIBHqyGCYwmnw3KlnsTzdm8zenzWFbYtpVoM6aVi8LfmswbUhk2bxP4OrP4tB1fN+LNymc96FzsbQTRXQoZPDMb3T7D9/iGcDCEIYWsYZu8GF/ASkUNaVTqI0FAYMVfk60aiVk/041Ru2LJ5Al6SvEvxq6VvzweFkv0Msv0WP0V6T9o+7lvW7h30P4WX6Dw== your_email@example.com"

echo "=== 设置SSH密钥到服务器 $SERVER_IP ==="

# 创建临时脚本文件
cat > /tmp/setup_remote_ssh.sh << 'EOF'
#!/bin/bash
set -e

# 创建.ssh目录
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 添加公钥到authorized_keys
echo "$SSH_KEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo "SSH密钥已添加到服务器"
EOF

# 使用sshpass自动输入密码
echo "正在将SSH公钥添加到服务器..."
sshpass -p "Aliyun2025!" ssh -o StrictHostKeyChecking=no $SERVER_USER@$SERVER_IP "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$SSH_KEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

echo "=== SSH密钥设置完成 ==="
echo "现在您可以测试SSH连接：ssh $SERVER_USER@$SERVER_IP"