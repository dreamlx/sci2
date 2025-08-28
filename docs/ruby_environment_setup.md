# Ruby 环境设置

## 概述

本项目使用 rbenv 来管理 Ruby 版本。本文档记录了 Ruby 环境的设置和使用方法。

## 当前 Ruby 版本

- **项目所需 Ruby 版本**: 3.4.2
- **本地系统 Ruby 版本**: 2.6.10
- **版本管理工具**: rbenv

## rbenv 安装和配置

### 检查 rbenv 安装

```bash
rbenv --version
```

### 查看可用的 Ruby 版本

```bash
rbenv versions
```

输出示例：
```
  system
* 2.6.10 (set by RBENV_VERSION environment variable)
  3.2.2
  3.4.2
```

### 切换 Ruby 版本

#### 临时切换（当前会话）

```bash
RBENV_VERSION=3.4.2 bundle exec cap production deploy
```

#### 全局切换

```bash
rbenv global 3.4.2
```

#### 本地项目切换

```bash
rbenv local 3.4.2
```

这会在项目根目录创建一个 `.ruby-version` 文件，自动设置项目的 Ruby 版本。

## Capistrano 部署中的 Ruby 版本管理

### 服务器端配置

在 `config/deploy.rb` 中已经配置了 RVM：

```ruby
# RVM Configuration
set :rvm_type, :system
set :rvm_ruby_version, '3.4.2'
```

### 本地执行部署命令

由于本地系统 Ruby 版本与项目要求不同，执行部署命令时需要指定 Ruby 版本：

```bash
# 使用 rbenv 指定 Ruby 版本
RBENV_VERSION=3.4.2 bundle exec cap production deploy

# 或者使用 rbenv exec
rbenv exec 3.4.2 bundle exec cap production deploy
```

## 常见问题解决

### 1. "cap: command not found" 错误

确保使用正确的 Ruby 版本：

```bash
RBENV_VERSION=3.4.2 bundle exec cap --version
```

### 2. "Your RubyGems version has a bug" 警告

这个警告不影响功能，但可以通过升级 RubyGems 来解决：

```bash
gem update --system 3.2.3
```

### 3. Bundle 安装问题

确保在正确的 Ruby 版本下安装 gems：

```bash
RBENV_VERSION=3.4.2 bundle install
```

## 开发环境设置

### 1. 安装项目依赖

```bash
# 设置本地 Ruby 版本
rbenv local 3.4.2

# 安装 gems
bundle install
```

### 2. 运行 Rails 应用

```bash
# 启动开发服务器
bundle exec rails server

# 或者使用 rbenv
rbenv exec bundle exec rails server
```

### 3. 运行测试

```bash
# 运行所有测试
bundle exec rake test

# 运行特定测试
bundle exec rspec spec/path/to/test.rb
```

## 部署脚本

为了简化部署过程，可以创建一个部署脚本：

```bash
#!/bin/bash
# deploy.sh

# 设置 Ruby 版本
export RBENV_VERSION=3.4.2

# 执行部署
bundle exec cap production deploy
```

然后给脚本添加执行权限：

```bash
chmod +x deploy.sh
```

## 总结

使用 rbenv 管理 Ruby 版本可以确保项目在不同环境中使用一致的 Ruby 版本。在执行部署命令时，记得使用 `RBENV_VERSION=3.4.2` 来指定正确的 Ruby 版本。