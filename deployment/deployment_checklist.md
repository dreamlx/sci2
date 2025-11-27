# SCI2生产部署检查清单

## 部署前检查 (Pre-Deployment Checklist)

### 1. 服务器准备
- [ ] 新服务器 `ssh root@tickmytime.com` 可访问
- [ ] 域名 `tickmytime.com` DNS解析正确
- [ ] SSH密钥已配置到deploy用户
- [ ] 服务器防火墙已配置 (端口22, 80, 443)

### 2. 代码准备
- [ ] 代码已推送到main分支
- [ ] 部署配置已更新 (Capistrano, 数据库配置)
- [ ] 环境变量文件已准备
- [ ] 依赖Gem已锁定 (bundle install成功)

### 3. 数据库准备
- [ ] PostgreSQL 15已安装
- [ ] 数据库用户 `sci2_prod` 已创建
- [ ] 数据库 `sci2_production` 已创建
- [ ] 数据库连接权限已配置

### 4. SSL证书准备
- [ ] Let's Encrypt账户已准备
- [ ] 域名所有权验证准备就绪

## 部署执行步骤 (Deployment Steps)

### 阶段1: 服务器环境准备
```bash
# 在新服务器上执行
ssh root@tickmytime.com "bash -s" < deployment/server_setup.sh
```

### 阶段2: 应用部署
```bash
# 在本地开发机器上执行
cap production deploy:check
cap production deploy
cap production deploy:migrate
cap production deploy:assets:precompile
```

### 阶段3: Nginx和SSL配置
```bash
# 在服务器上执行
sudo cp deployment/nginx_sci2.conf /etc/nginx/sites-available/sci2
sudo ln -s /etc/nginx/sites-available/sci2 /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 获取SSL证书
sudo certbot --nginx -d tickmytime.com
```

### 阶段4: 服务启动
```bash
# 重启应用服务
cap production puma:restart
sudo systemctl restart nginx
```

## 部署后验证 (Post-Deployment Verification)

### 1. 应用访问测试
- [ ] `https://tickmytime.com` 可正常访问
- [ ] 主页加载正常
- [ ] 登录功能正常
- [ ] 核心功能测试通过

### 2. 数据库连接测试
- [ ] 数据库连接正常
- [ ] 数据迁移成功
- [ ] 查询性能正常

### 3. 性能测试
- [ ] 页面响应时间 < 2秒
- [ ] 并发用户测试通过
- [ ] 内存使用正常

### 4. 安全检查
- [ ] SSL证书有效
- [ ] HTTPS重定向正常
- [ ] 安全头配置正确
- [ ] 敏感文件无法访问

## 监控和维护设置

### 1. 日志配置
- [ ] 应用日志轮转配置
- [ ] Nginx日志轮转配置
- [ ] PostgreSQL日志配置

### 2. 备份设置
- [ ] 数据库自动备份脚本
- [ ] 文件备份脚本
- [ ] 备份恢复测试

### 3. 监控脚本
- [ ] 系统健康检查脚本
- [ ] 应用状态监控
- [ ] 磁盘空间监控

## 回滚计划 (Rollback Plan)

如果部署失败，可以执行以下回滚步骤：

```bash
# 回滚到上一个版本
cap production deploy:rollback

# 如果需要回滚数据库
# (需要手动执行数据库回滚脚本)

# 重启服务
cap production puma:restart
```

## 紧急联系信息

- **服务器IP**: tickmytime.com
- **部署用户**: deploy
- **应用目录**: /opt/sci2
- **数据库**: sci2_production
- **日志目录**: /opt/sci2/current/log

## 部署完成确认

部署完成后，请确认以下项目：

- [ ] 所有功能正常工作
- [ ] 性能指标达标
- [ ] 安全配置正确
- [ ] 监控和备份已设置
- [ ] 团队成员已通知
- [ ] 文档已更新