# 费用明细重复记录修复部署计划

本文档提供了在生产环境中部署费用明细重复记录修复方案的步骤和注意事项。

## 前提条件

1. 已在开发/测试环境中完成所有测试，并确认修复方案有效
2. 已获得相关利益相关者的批准
3. 已安排维护窗口期间进行部署
4. 已准备好回滚计划

## 部署准备

### 1. 备份

在开始部署前，必须进行以下备份：

1. 完整的数据库备份
   ```bash
   # 使用适当的数据库备份命令，例如：
   pg_dump -U username -h hostname -d database_name > backup_before_fix_$(date +%Y%m%d_%H%M%S).sql
   ```

2. 关键表的单独备份
   ```bash
   # 导出 fee_details 表
   psql -U username -h hostname -d database_name -c "COPY (SELECT * FROM fee_details) TO STDOUT WITH CSV HEADER" > fee_details_backup_$(date +%Y%m%d_%H%M%S).csv
   
   # 导出 reimbursements 表
   psql -U username -h hostname -d database_name -c "COPY (SELECT * FROM reimbursements) TO STDOUT WITH CSV HEADER" > reimbursements_backup_$(date +%Y%m%d_%H%M%S).csv
   ```

### 2. 部署前检查

1. 检查生产环境中的重复记录情况
   ```bash
   # 连接到生产数据库
   rails runner -e production "puts FeeDetail.select(:external_fee_id).group(:external_fee_id).having('COUNT(*) > 1').count.size"
   ```

2. 检查 nil 值记录情况
   ```bash
   rails runner -e production "puts FeeDetail.where(external_fee_id: nil).count"
   ```

3. 估算迁移时间
   ```bash
   # 获取 fee_details 表的总记录数
   rails runner -e production "puts FeeDetail.count"
   ```

## 部署步骤

### 1. 通知用户

1. 在维护窗口开始前，通知所有用户系统将进入维护模式
2. 更新系统状态页面或发送系统维护通知

### 2. 启用维护模式

1. 如果系统支持维护模式，启用它以防止用户访问
   ```bash
   # 例如，在 Rails 应用中
   rails maintenance:start
   ```

### 3. 部署代码更改

1. 部署包含以下文件的代码更改：
   - `app/models/fee_detail.rb`（已有更改）
   - `app/services/fee_detail_import_service.rb`（已有更改）
   - `db/migrate/20250725080400_ensure_external_fee_id_presence.rb`
   - `db/migrate/20250725080500_fix_duplicate_external_fee_ids.rb`
   - `db/scripts/fix_duplicate_external_fee_ids.rb`
   - `db/scripts/README_FIX_DUPLICATE_EXTERNAL_FEE_IDS.md`

2. 使用适当的部署工具（如 Capistrano、Docker 或手动部署）

### 4. 运行数据库迁移

1. 运行第一个迁移，确保所有记录都有 `external_fee_id` 值
   ```bash
   RAILS_ENV=production rails db:migrate:up VERSION=20250725080400
   ```

2. 验证所有记录都有非空的 `external_fee_id` 值
   ```bash
   rails runner -e production "puts FeeDetail.where(external_fee_id: nil).count"
   ```

3. 运行第二个迁移，修复重复的 `external_fee_id` 值
   ```bash
   RAILS_ENV=production rails db:migrate:up VERSION=20250725080500
   ```

4. 验证没有重复的 `external_fee_id` 值
   ```bash
   rails runner -e production "puts FeeDetail.select(:external_fee_id).group(:external_fee_id).having('COUNT(*) > 1').count.size"
   ```

### 5. 运行清理脚本（如果需要）

如果迁移后仍有重复记录，运行清理脚本：

```bash
RAILS_ENV=production rails runner db/scripts/fix_duplicate_external_fee_ids.rb
```

### 6. 验证部署

1. 验证数据库状态
   ```bash
   # 检查 nil 值
   rails runner -e production "puts FeeDetail.where(external_fee_id: nil).count"
   
   # 检查重复值
   rails runner -e production "puts FeeDetail.select(:external_fee_id).group(:external_fee_id).having('COUNT(*) > 1').count.size"
   ```

2. 验证模型验证
   ```bash
   rails runner -e production "fee = FeeDetail.new(document_number: 'TEST001', fee_type: '测试', amount: 100); puts fee.valid?; puts fee.errors.full_messages"
   ```

3. 验证导入功能（可选，在测试环境中进行）

### 7. 禁用维护模式

1. 如果启用了维护模式，禁用它以恢复用户访问
   ```bash
   # 例如，在 Rails 应用中
   rails maintenance:end
   ```

### 8. 通知用户

1. 通知所有用户系统已恢复正常运行
2. 更新系统状态页面或发送系统恢复通知

## 监控和后续行动

### 1. 密切监控

1. 监控系统日志，查找任何与 `FeeDetail` 或 `external_fee_id` 相关的错误
2. 监控数据库性能，特别是与 `fee_details` 表相关的查询
3. 监控导入功能，确保它正常工作且没有创建重复记录

### 2. 用户反馈

1. 收集用户反馈，特别是关于导入功能的反馈
2. 解决用户报告的任何问题

### 3. 验证数据完整性

1. 定期检查是否有新的重复记录
   ```bash
   rails runner -e production "puts FeeDetail.select(:external_fee_id).group(:external_fee_id).having('COUNT(*) > 1').count.size"
   ```

2. 定期检查是否有新的 nil 值记录
   ```bash
   rails runner -e production "puts FeeDetail.where(external_fee_id: nil).count"
   ```

## 回滚计划

如果部署过程中出现严重问题，按以下步骤回滚：

### 1. 启用维护模式

```bash
rails maintenance:start
```

### 2. 恢复数据库

```bash
# 使用适当的数据库恢复命令，例如：
psql -U username -h hostname -d database_name < backup_before_fix_TIMESTAMP.sql
```

### 3. 回滚代码更改

使用适当的部署工具回滚到之前的版本

### 4. 禁用维护模式

```bash
rails maintenance:end
```

### 5. 通知用户

通知所有用户系统已回滚到之前的版本，并解释原因

## 联系人和责任

1. 部署负责人：[姓名]，[联系方式]
2. 数据库管理员：[姓名]，[联系方式]
3. 开发团队联系人：[姓名]，[联系方式]
4. 运维团队联系人：[姓名]，[联系方式]

## 时间表

1. 部署准备：[日期和时间]
2. 维护窗口开始：[日期和时间]
3. 预计完成时间：[日期和时间]
4. 维护窗口结束：[日期和时间]