# 费用明细监控脚本使用说明

本文档提供了费用明细监控脚本的使用说明，这些脚本用于持续监控系统中的费用明细记录，确保没有重复或缺失的 `external_fee_id` 值。

## 脚本概述

我们提供了两个监控脚本：

1. `monitor_duplicate_external_fee_ids.rb` - 监控重复的 `external_fee_id` 值
2. `monitor_nil_external_fee_ids.rb` - 监控 `nil` 值的 `external_fee_id`

这些脚本设计用于定期运行（如每日），以检测系统中可能出现的数据问题，并在发现问题时发出警报。

## 运行脚本

### 手动运行

您可以使用以下命令手动运行脚本：

```bash
# 监控重复的 external_fee_id 值
RAILS_ENV=production rails runner db/scripts/monitor_duplicate_external_fee_ids.rb

# 监控 nil 值的 external_fee_id
RAILS_ENV=production rails runner db/scripts/monitor_nil_external_fee_ids.rb
```

### 设置定时任务

建议将这些脚本设置为定时任务，以便定期自动运行。您可以使用 cron 或其他任务调度工具来实现这一点。

#### 使用 cron

将以下行添加到您的 crontab 中：

```
# 每天凌晨 2:30 运行重复值监控脚本
30 2 * * * cd /path/to/your/app && RAILS_ENV=production rails runner db/scripts/monitor_duplicate_external_fee_ids.rb >> log/monitor_duplicate_external_fee_ids.log 2>&1

# 每天凌晨 3:00 运行 nil 值监控脚本
0 3 * * * cd /path/to/your/app && RAILS_ENV=production rails runner db/scripts/monitor_nil_external_fee_ids.rb >> log/monitor_nil_external_fee_ids.log 2>&1
```

#### 使用 whenever gem

如果您的项目使用 [whenever gem](https://github.com/javan/whenever)，您可以将以下内容添加到 `config/schedule.rb` 文件中：

```ruby
every 1.day, at: '2:30 am' do
  runner "load 'db/scripts/monitor_duplicate_external_fee_ids.rb'"
end

every 1.day, at: '3:00 am' do
  runner "load 'db/scripts/monitor_nil_external_fee_ids.rb'"
end
```

然后运行 `whenever --update-crontab` 来更新您的 crontab。

## 配置选项

这些脚本支持通过环境变量进行配置：

### monitor_duplicate_external_fee_ids.rb

| 环境变量 | 描述 | 默认值 |
|---------|------|--------|
| `LOG_FILE` | 日志文件路径 | `log/monitor_duplicate_external_fee_ids_YYYYMMDD.log` |
| `ALERT_THRESHOLD` | 触发警报的重复值数量阈值 | `0` (任何重复都会触发警报) |

### monitor_nil_external_fee_ids.rb

| 环境变量 | 描述 | 默认值 |
|---------|------|--------|
| `LOG_FILE` | 日志文件路径 | `log/monitor_nil_external_fee_ids_YYYYMMDD.log` |
| `ALERT_THRESHOLD` | 触发警报的 nil 值数量阈值 | `0` (任何 nil 值都会触发警报) |
| `RECENT_PERIOD` | 检查最近记录的时间段（天） | `1` (1 天) |

示例：

```bash
# 设置警报阈值为 5，只有当发现 5 个以上的重复值时才触发警报
ALERT_THRESHOLD=5 RAILS_ENV=production rails runner db/scripts/monitor_duplicate_external_fee_ids.rb

# 检查最近 7 天内创建的记录
RECENT_PERIOD=7 RAILS_ENV=production rails runner db/scripts/monitor_nil_external_fee_ids.rb
```

## 警报集成

目前，这些脚本会将警报信息输出到日志文件和标准输出。要集成到您的警报系统中，您需要取消注释并修改脚本中的 `AlertService.send_alert` 调用，或者添加您自己的警报逻辑。

您可以集成的警报系统示例：

1. 电子邮件通知
2. Slack 或其他聊天工具通知
3. 监控系统如 Nagios、Prometheus 等
4. 短信通知

## 日志文件

脚本会生成详细的日志文件，包含以下信息：

1. 脚本运行的时间和结果
2. 发现的问题详情（如有）
3. 样本记录信息
4. 错误和警告信息

日志文件默认保存在 `log/` 目录下，文件名包含日期信息。

## 故障排除

如果脚本运行失败，请检查：

1. 日志文件中的错误信息
2. 确保脚本有足够的权限访问数据库
3. 确保 Rails 环境正确设置
4. 确保数据库连接正常

## 最佳实践

1. 定期检查日志文件，了解系统状态
2. 设置适当的警报阈值，避免过多的误报
3. 将脚本集成到您的监控系统中
4. 定期审查和更新监控策略
5. 在发现问题时及时处理，避免问题积累