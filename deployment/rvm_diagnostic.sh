#!/bin/bash

echo "=== RVM诊断脚本 ==="
echo "当前用户: $(whoami)"
echo "当前shell: $SHELL"
echo "当前PATH: $PATH"
echo

echo "=== RVM安装检查 ==="
if [ -f "/usr/local/rvm/scripts/rvm" ]; then
    echo "✓ RVM脚本存在: /usr/local/rvm/scripts/rvm"
else
    echo "✗ RVM脚本不存在"
fi

if [ -d "/usr/local/rvm" ]; then
    echo "✓ RVM目录存在: /usr/local/rvm"
    ls -la /usr/local/rvm/
else
    echo "✗ RVM目录不存在"
fi

echo
echo "=== RVM版本检查 ==="
/usr/local/rvm/bin/rvm version 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ 直接调用rvm版本成功"
else
    echo "✗ 直接调用rvm版本失败"
fi

echo
echo "=== Ruby版本检查 ==="
/usr/local/rvm/bin/rvm current 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ 直接调用rvm current成功"
else
    echo "✗ 直接调用rvm current失败"
fi

echo
echo "=== 加载RVM环境后测试 ==="
source /usr/local/rvm/scripts/rvm
echo "加载后PATH: $PATH"

echo "测试rvm version:"
timeout 10 rvm version
if [ $? -eq 124 ]; then
    echo "✗ rvm version命令超时"
else
    echo "✓ rvm version命令成功"
fi

echo
echo "测试rvm current:"
timeout 10 rvm current
if [ $? -eq 124 ]; then
    echo "✗ rvm current命令超时"
else
    echo "✓ rvm current命令成功"
fi

echo
echo "测试ruby --version:"
timeout 10 ruby --version
if [ $? -eq 124 ]; then
    echo "✗ ruby --version命令超时"
else
    echo "✓ ruby --version命令成功"
fi

echo
echo "=== 完整RVM路径测试 ==="
timeout 10 /usr/local/rvm/bin/rvm ruby-3.4.2 do ruby --version
if [ $? -eq 124 ]; then
    echo "✗ 完整路径命令超时"
else
    echo "✓ 完整路径命令成功"
fi

echo
echo "=== 进程监控 ==="
echo "检查是否有卡住的RVM进程:"
ps aux | grep rvm | grep -v grep

echo
echo "=== 系统资源检查 ==="
echo "内存使用:"
free -h
echo
echo "磁盘使用:"
df -h /usr/local/rvm

echo
echo "=== 权限检查 ==="
ls -la /usr/local/rvm/bin/rvm
ls -la /usr/local/rvm/rubies/ruby-3.4.2/bin/ruby