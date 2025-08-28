#!/bin/bash

# SCI2 测试环境部署脚本
# 此脚本确保使用正确的 Ruby 版本进行部署

echo "开始部署 SCI2 到测试环境..."

# 设置 Ruby 版本
export RBENV_VERSION=3.4.2

# 检查 rbenv 是否可用
if ! command -v rbenv &> /dev/null; then
    echo "错误: rbenv 未安装或不在 PATH 中"
    exit 1
fi

# 检查指定的 Ruby 版本是否可用
if ! rbenv versions | grep -q "3.4.2"; then
    echo "错误: Ruby 3.4.2 未安装。请先安装: rbenv install 3.4.2"
    exit 1
fi

# 显示当前 Ruby 版本信息
echo "使用 Ruby 版本: $(ruby -v)"
echo "使用 Bundler 版本: $(bundle -v)"

# 执行部署
echo "执行 Capistrano 部署到测试环境..."
bundle exec cap staging deploy

# 检查部署结果
if [ $? -eq 0 ]; then
    echo "测试环境部署成功完成！"
else
    echo "测试环境部署失败，请检查错误信息。"
    exit 1
fi