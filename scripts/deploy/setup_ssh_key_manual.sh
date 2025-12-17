#!/bin/bash
# 脚本：手动设置SSH密钥到测试服务器

set -e

# 服务器配置
SERVER_IP="8.136.10.88"
SERVER_USER="root"
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDmiG5+bDL5ZmIoH9Z4tmMvdwtwkf9g2uzk7nB2Gsa6Bdg9adIpKrI0UQg/xV3sdMmct1icLqyOrI8oJVJSYgvQmJ7VKhXMKLrFdYoZ0LKzZc8Z6rEDfsfUaXD5MS16NA52K09k+MNqf3WAzRn3ygW4HoZbNTsSpiXqLHNjIivri563zavKAhFHMVcneDtygzD7YMG52TVhbEnL6PSwJyAZfP4ptIy5+cq9lR3Rh01pXVqgMJ9w5/H6O/hLidYNpwC0qPOL09DhAX/19ZHwx8KPtilH60keofOo1fD8jaB5jYtingiHq+jyedXA47r5IozjmMs78ej9Q9XNJHEIm9jhMw0Fphu3Ox//Y24URLRKs/hnP7zxmWOO1bPNv01/01LWhaInYoxGraNENsSRgGA1r57OH9n0gb7reSpb7xsqMCe2Ifha/U+l4hNwrVSxlXrRJ0/3w8tmLoR4IeyF1NZG0zD2v1nJ9LdSyAAxcoUhQ6XYIBHqyGCYwmnw3KlnsTzdm8zenzWFbYtpVoM6aVi8LfmswbUhk2bxP4OrP4tB1fN+LNymc96FzsbQTRXQoZPDMb3T7D9/iGcDCEIYWsYZu8GF/ASkUNaVTqI0FAYMVfk60aiVk/041Ru2LJ5Al6SvEvxq6VvzweFkv0Msv0WP0V6T9o+7lvW7h30P4WX6Dw== your_email@example.com"

echo "=== 手动设置SSH密钥到服务器 $SERVER_IP ==="
echo "请按照以下步骤操作："
echo ""
echo "1. 连接到服务器："
echo "   ssh $SERVER_USER@$SERVER_IP"
echo ""
echo "2. 输入密码：Aliyun2025！"
echo ""
echo "3. 在服务器上执行以下命令："
echo "   mkdir -p ~/.ssh"
echo "   chmod 700 ~/.ssh"
echo "   echo '$SSH_KEY' >> ~/.ssh/authorized_keys"
echo "   chmod 600 ~/.ssh/authorized_keys"
echo ""
echo "4. 退出服务器："
echo "   exit"
echo ""
echo "5. 测试SSH连接："
echo "   ssh $SERVER_USER@$SERVER_IP"
echo ""
echo "=== 按Enter键继续，或Ctrl+C取消 ==="
read