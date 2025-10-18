# 部署脚本目录

这个目录包含了项目的部署相关脚本和配置。

## 文件说明

### 主要脚本

- `deploy.sh` - **统一部署脚本** (推荐使用)
- `deploy_to_server.sh` - 原始部署脚本
- `deploy_with_capistrano.sh` - Capistrano 部署脚本
- `deploy_fix.sh` - 部署修复脚本
- `deploy_port_fix.sh` - 端口修复脚本
- `emergency_port_fix.sh` - 紧急端口修复脚本

### 其他文件

- `fetch_from_server.sh` - 从服务器获取文件
- `fix_production_database.sh` - 生产数据库修复
- `install_dependencies.sh` - 依赖安装脚本

## 使用方法

### 推荐的部署方式

```bash
# 生产环境基本部署
./deployment/deploy.sh production

# 测试环境部署（包含数据库迁移）
./deployment/deploy.sh staging --migrate

# 生产环境部署（包含迁移和端口修复）
./deployment/deploy.sh production --migrate --fix-port

# 查看帮助
./deployment/deploy.sh --help
```

### 传统部署方式

```bash
# 使用 Capistrano
./deployment/deploy_with_capistrano.sh

# 修复端口问题
./deployment/emergency_port_fix.sh
```

## 注意事项

1. **统一部署脚本** `deploy.sh` 是推荐的使用方式，它集成了所有部署功能
2. 部署前请确保：
   - SSH 密钥已配置
   - 服务器网络连接正常
   - 代码已提交到 Git
3. 生产环境部署建议先在测试环境验证
4. 部署日志会自动保存在 `deployment/` 目录下

## 配置要求

- SSH 访问权限
- Capistrano 配置文件 (`config/deploy.rb`)
- 服务器环境配置
- 数据库备份脚本