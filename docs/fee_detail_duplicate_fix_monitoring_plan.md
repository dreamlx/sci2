# 费用明细重复记录修复监控计划

本文档提供了在部署费用明细重复记录修复方案后的监控计划，以确保系统正常运行且不再产生重复记录。

## 监控目标

1. 确保没有新的重复 `external_fee_id` 记录产生
2. 确保没有新的 `nil` 值 `external_fee_id` 记录产生
3. 确保导入功能正常工作且正确处理重复记录
4. 确保系统性能没有受到负面影响
5. 及时发现并解决任何相关问题

## 监控指标

### 1. 数据完整性指标

| 指标 | 描述 | 目标值 | 监控频率 | 警报阈值 |
|------|------|--------|----------|----------|
| 重复 external_fee_id 数量 | 具有相同 external_fee_id 值的记录数量 | 0 | 每日 | > 0 |
| Nil external_fee_id 数量 | external_fee_id 为 nil 的记录数量 | 0 | 每日 | > 0 |
| 验证失败次数 | 因 external_fee_id 验证失败的记录创建/更新尝试次数 | 最小化 | 每日 | 显著增加 |

### 2. 功能性能指标

| 指标 | 描述 | 目标值 | 监控频率 | 警报阈值 |
|------|------|--------|----------|----------|
| 导入成功率 | 成功导入的记录百分比 | > 99% | 每次导入 | < 95% |
| 导入处理时间 | 处理每条记录的平均时间 | < 基准值 | 每次导入 | > 基准值的 150% |
| 导入错误率 | 导入过程中报告的错误百分比 | < 1% | 每次导入 | > 5% |

### 3. 系统性能指标

| 指标 | 描述 | 目标值 | 监控频率 | 警报阈值 |
|------|------|--------|----------|----------|
| 数据库查询时间 | 与 fee_details 表相关的查询平均响应时间 | < 基准值 | 每小时 | > 基准值的 200% |
| 数据库锁定时间 | 与 fee_details 表相关的锁定时间 | 最小化 | 每小时 | 显著增加 |
| 应用响应时间 | 与费用明细相关的页面加载时间 | < 基准值 | 每小时 | > 基准值的 150% |

## 监控实施

### 1. 自动化监控脚本

创建以下自动化监控脚本，并设置为定期运行：

1. 检查重复 external_fee_id 的脚本：

```ruby
# db/scripts/monitor_duplicate_external_fee_ids.rb
duplicates = FeeDetail.select(:external_fee_id)
                      .group(:external_fee_id)
                      .having("COUNT(*) > 1")
                      .count

if duplicates.any?
  puts "警告：发现 #{duplicates.size} 个重复的 external_fee_id 值"
  duplicates.each do |external_id, count|
    puts "  - #{external_id}: #{count} 条记录"
  end
  
  # 发送警报（邮件、Slack 等）
  # AlertService.send_alert("发现重复的 external_fee_id 值", duplicates.to_json)
else
  puts "检查通过：没有发现重复的 external_fee_id 值"
end
```

2. 检查 nil external_fee_id 的脚本：

```ruby
# db/scripts/monitor_nil_external_fee_ids.rb
nil_count = FeeDetail.where(external_fee_id: nil).count

if nil_count > 0
  puts "警告：发现 #{nil_count} 条 external_fee_id 为 nil 的记录"
  
  # 发送警报（邮件、Slack 等）
  # AlertService.send_alert("发现 external_fee_id 为 nil 的记录", { count: nil_count }.to_json)
else
  puts "检查通过：没有发现 external_fee_id 为 nil 的记录"
end
```

3. 设置定时任务：

```ruby
# config/schedule.rb (使用 whenever gem)
every 1.day, at: '2:30 am' do
  runner "load 'db/scripts/monitor_duplicate_external_fee_ids.rb'"
  runner "load 'db/scripts/monitor_nil_external_fee_ids.rb'"
end
```

### 2. 日志监控

配置日志监控系统（如 ELK Stack、Datadog、New Relic 等）以捕获和分析以下日志：

1. 与 `external_fee_id` 相关的错误和警告
2. 导入过程中的错误和警告
3. 与 `fee_details` 表相关的数据库查询性能

### 3. 性能监控

使用 APM 工具（如 New Relic、Datadog、Skylight 等）监控：

1. 与费用明细相关的控制器和服务的性能
2. 与 `fee_details` 表相关的数据库查询性能
3. 导入功能的性能

### 4. 用户反馈监控

1. 设置专门的反馈渠道，收集用户关于费用明细功能的反馈
2. 定期审查用户反馈，识别潜在问题
3. 跟踪与费用明细相关的支持请求和问题报告

## 报告和审查

### 1. 每日报告

创建每日自动报告，包含：

1. 重复和 nil external_fee_id 检查结果
2. 导入功能性能统计
3. 系统性能指标
4. 任何警报或异常情况

### 2. 每周审查

每周进行一次审查会议，讨论：

1. 监控结果和趋势
2. 任何发现的问题及其解决方案
3. 用户反馈和支持请求
4. 需要改进的地方

### 3. 每月报告

生成每月综合报告，包含：

1. 监控指标的月度趋势
2. 发现的问题及其解决方案
3. 系统稳定性和性能评估
4. 建议的改进措施

## 问题响应流程

### 1. 警报触发

当监控系统触发警报时：

1. 通知相关团队成员（开发、运维、DBA 等）
2. 记录警报详情和时间戳
3. 开始初步调查

### 2. 问题分类

根据问题的严重性和影响范围，将问题分类为：

1. **紧急**：系统无法正常工作，用户无法使用关键功能
2. **高优先级**：系统部分功能受影响，但有临时解决方案
3. **中优先级**：系统功能正常，但有潜在风险
4. **低优先级**：小问题，不影响系统功能

### 3. 问题解决

根据问题类型，采取相应的解决措施：

1. **数据完整性问题**：
   - 运行修复脚本
   - 审查和修复导入逻辑
   - 加强验证

2. **性能问题**：
   - 优化数据库查询
   - 调整索引
   - 增加缓存

3. **功能问题**：
   - 修复代码错误
   - 更新业务逻辑
   - 改进用户界面

### 4. 问题复盘

问题解决后：

1. 记录问题详情、原因和解决方案
2. 分析根本原因，防止类似问题再次发生
3. 更新监控和警报系统
4. 分享经验教训

## 长期监控策略

### 1. 持续改进

1. 定期审查监控计划和指标
2. 根据系统变化和用户需求调整监控策略
3. 优化监控工具和流程

### 2. 知识库建设

1. 记录所有与费用明细重复记录相关的问题和解决方案
2. 创建常见问题解答和故障排除指南
3. 培训团队成员了解监控系统和问题解决流程

### 3. 预防措施

1. 定期进行数据完整性检查
2. 在测试环境中模拟各种边缘情况
3. 进行代码审查，确保新功能不会引入重复记录问题