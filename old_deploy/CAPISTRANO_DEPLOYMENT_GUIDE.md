# Capistrano 部署指南 / Capistrano Deployment Guide

[中文](#中文版) | [English](#english)

<a id="中文版"></a>
## 中文版

本指南说明如何使用 Capistrano 将 sci2 应用程序部署到远程服务器。

### 文件结构

- `Capfile`: Capistrano主配置文件，加载所需的插件
- `config/deploy.rb`: 通用部署配置
- `config/deploy/staging.rb`: 测试环境特定配置
- `config/deploy/production.rb`: 生产环境特定配置
- `lib/capistrano/tasks/docker.rake`: Docker相关任务
- `lib/capistrano/tasks/utils.rake`: 实用工具任务
- `deploy_with_capistrano.sh`: 便捷部署脚本

### 前提条件

在部署之前，请确保您具备：

1. 本地机器上安装了 Ruby 和 Bundler
2. 对远程服务器的 SSH 访问权限
3. 已设置包含代码的 Git 仓库

### 安全注意事项

为确保部署安全，请注意以下几点：

1. **不要提交敏感信息**：
   - 确保`config/master.key`不会被提交到仓库
   - 不要在代码中硬编码任何密码或密钥
   - 使用环境变量或配置文件存储敏感信息

2. **SSH密钥管理**：
   - 确保SSH密钥安全存储
   - 考虑为不同环境使用不同的部署密钥

3. **权限控制**：
   - 确保服务器上的文件权限正确设置
   - 敏感文件(如master.key)应设置为600权限

### 设置

#### 1. 安装 Capistrano 及其依赖项

Gemfile 已更新，包含 Capistrano 及其插件。通过运行以下命令安装它们：

```bash
bundle install
```

#### 2. 配置 SSH 访问

确保您可以使用 SSH 密钥无需密码登录远程服务器：

```bash
ssh-copy-id root@47.97.35.0
```

如果您使用的是不同的 SSH 密钥，请更新 `config/deploy/staging.rb` 中的 `ssh_options`。

#### 3. 更新仓库 URL

打开 `config/deploy.rb` 并使用您实际的 Git 仓库 URL 更新 `:repo_url` 设置：

```ruby
set :repo_url, "git@github.com:your-username/sci2.git"
```

### 部署命令

使用以下命令进行部署：

```bash
# 设置服务器
./deploy_with_capistrano.sh setup

# 部署应用
./deploy_with_capistrano.sh deploy

# 检查状态
./deploy_with_capistrano.sh status

# 查看日志
./deploy_with_capistrano.sh logs

# 重启应用
./deploy_with_capistrano.sh restart

# 回滚到上一个版本
./deploy_with_capistrano.sh rollback
```

### 环境配置

#### 测试环境 (47.97.35.0)

测试环境配置位于`config/deploy/staging.rb`文件中。主要配置包括：

- 服务器地址：47.97.35.0
- 部署用户：root
- 部署目录：/opt/sci2
- 分支：main

#### 生产环境

生产环境配置位于`config/deploy/production.rb`文件中。在部署到生产环境前，请确保更新此文件中的服务器信息。

### 部署工作流程

典型的部署工作流程是：

1. 对代码进行更改
2. 提交并推送到 Git 仓库
3. 使用 Capistrano 部署：
   ```bash
   ./deploy_with_capistrano.sh deploy
   ```
4. 验证部署：
   ```bash
   ./deploy_with_capistrano.sh status
   ```


### 故障排除

如果部署过程中遇到问题，请检查以下几点：

1. 确保服务器可以访问互联网，特别是在构建Docker镜像时
2. 检查服务器上的防火墙设置，确保必要的端口已开放
3. 检查日志文件以获取更详细的错误信息：
   - Capistrano日志：`log/capistrano.log`
   - 应用程序日志：`/opt/sci2/current/log/production.log`
   - Docker日志：使用`docker logs sci2-container`命令

如果应用程序无法访问：

1. 检查 Docker 容器是否正在运行：
   ```bash
   ./deploy_with_capistrano.sh status
   ```

2. 检查 Docker 日志：
   ```bash
   ./deploy_with_capistrano.sh logs
   ```

3. 重启 Docker 容器：
   ```bash
   ./deploy_with_capistrano.sh restart
   ```

如果部署失败：

1. 检查 Capistrano 日志输出中的错误
2. 验证您对服务器的 SSH 访问权限
3. 检查 Git 仓库是否可访问
4. 验证服务器上是否安装并运行了 Docker

### 资产预编译问题

如果遇到资产预编译问题，可以使用 `force_asset_precompile.sh` 脚本强制重新编译资产：

```bash
./force_asset_precompile.sh
```

<a id="english"></a>
## English

This guide explains how to deploy the sci2 application using Capistrano to remote servers.

### File Structure

- `Capfile`: Main Capistrano configuration file that loads required plugins
- `config/deploy.rb`: Common deployment configuration
- `config/deploy/staging.rb`: Staging environment-specific configuration
- `config/deploy/production.rb`: Production environment-specific configuration
- `lib/capistrano/tasks/docker.rake`: Docker-related tasks
- `lib/capistrano/tasks/utils.rake`: Utility tasks
- `deploy_with_capistrano.sh`: Convenient deployment script

### Prerequisites

Before deploying, make sure you have:

1. Ruby and Bundler installed on your local machine
2. SSH access to the remote server
3. Git repository set up with your code

### Security Considerations

To ensure deployment security, note the following:

1. **Don't commit sensitive information**:
   - Ensure `config/master.key` is not committed to the repository
   - Don't hardcode any passwords or keys in the code
   - Use environment variables or configuration files to store sensitive information

2. **SSH key management**:
   - Ensure SSH keys are securely stored
   - Consider using different deployment keys for different environments

3. **Permission control**:
   - Ensure file permissions are correctly set on the server
   - Sensitive files (like master.key) should have 600 permissions

### Setup

#### 1. Install Capistrano and its dependencies

The Gemfile has been updated to include Capistrano and its plugins. Install them by running:

```bash
bundle install
```

#### 2. Configure SSH access

Make sure you can SSH into the remote server without a password using SSH keys:

```bash
ssh-copy-id root@47.97.35.0
```

If you're using a different SSH key, update the `ssh_options` in `config/deploy/staging.rb`.

#### 3. Update repository URL

Open `config/deploy.rb` and update the `:repo_url` setting with your actual Git repository URL:

```ruby
set :repo_url, "git@github.com:your-username/sci2.git"
```

### Deployment Commands

Use the following commands for deployment:

```bash
# Set up the server
./deploy_with_capistrano.sh setup

# Deploy the application
./deploy_with_capistrano.sh deploy

# Check status
./deploy_with_capistrano.sh status

# View logs
./deploy_with_capistrano.sh logs

# Restart the application
./deploy_with_capistrano.sh restart

# Rollback to the previous version
./deploy_with_capistrano.sh rollback
```

### Environment Configuration

#### Staging Environment (47.97.35.0)

The staging environment configuration is in the `config/deploy/staging.rb` file. Main configurations include:

- Server address: 47.97.35.0
- Deployment user: root
- Deployment directory: /opt/sci2
- Branch: main

#### Production Environment

The production environment configuration is in the `config/deploy/production.rb` file. Before deploying to the production environment, make sure to update the server information in this file.

### Deployment Workflow

The typical deployment workflow is:

1. Make changes to your code
2. Commit and push to your Git repository
3. Deploy using Capistrano:
   ```bash
   ./deploy_with_capistrano.sh deploy
   ```
4. Verify the deployment:
   ```bash
   ./deploy_with_capistrano.sh status
   ```

### Custom Tasks

#### Docker Tasks

- `docker:check_installation`: Check if Docker is installed
- `docker:install`: Install Docker (if not installed)
- `docker:start_service`: Start Docker service
- `docker:build`: Build Docker image
- `docker:run`: Run Docker container
- `docker:status`: Check Docker container status
- `docker:logs`: View Docker container logs
- `docker:restart`: Restart Docker container

#### Utility Tasks

- `utils:check_server`: Check server status
- `utils:open_firewall_port`: Open firewall port
- `utils:check_application`: Check application status
- `utils:setup_directories`: Set up application directories
- `utils:upload_config`: Upload configuration files

### Troubleshooting

If you encounter issues during deployment, check the following:

1. Ensure the server can access the internet, especially when building Docker images
2. Check firewall settings on the server to ensure necessary ports are open
3. Check log files for more detailed error information:
   - Capistrano logs: `log/capistrano.log`
   - Application logs: `/opt/sci2/current/log/production.log`
   - Docker logs: Use the `docker logs sci2-container` command

If the application is not accessible:

1. Check if the Docker container is running:
   ```bash
   ./deploy_with_capistrano.sh status
   ```

2. Check the Docker logs:
   ```bash
   ./deploy_with_capistrano.sh logs
   ```

3. Restart the Docker container:
   ```bash
   ./deploy_with_capistrano.sh restart
   ```

If deployment fails:

1. Check the Capistrano log output for errors
2. Verify your SSH access to the server
3. Check if the Git repository is accessible
4. Verify that Docker is installed and running on the server

### Asset Precompilation Issues

If you encounter asset precompilation issues, you can use the `force_asset_precompile.sh` script to force recompilation of assets:

```bash
./force_asset_precompile.sh