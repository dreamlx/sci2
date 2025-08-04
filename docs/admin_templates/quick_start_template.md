# ActiveAdmin CSV导出和列表优化 - 快速启动模板

## 任务信息收集表

### 基本信息
- **目标模块：** _________________ (如：报销单、沟通工单等)
- **ActiveAdmin文件路径：** `app/admin/_____________.rb`
- **数据模型路径：** `app/models/_____________.rb`
- **任务类型：** □ CSV导出配置 □ 列表页优化 □ 两者都需要

### 字段需求清单
请客户提供字段列表，按以下格式填写：

| 序号 | 中文字段名 | 数据库字段名 | 数据类型 | 格式要求 | 空值处理 |
|------|------------|--------------|----------|----------|----------|
| 1    |            |              |          |          |          |
| 2    |            |              |          |          |          |
| 3    |            |              |          |          |          |

### 格式化需求
- **日期格式：** □ YYYY-MM-DD □ YYYY-MM-DD HH:MM:SS □ 中文格式
- **空值显示：** □ '0' □ '空' □ '未设置' □ 其他：_______
- **状态翻译：** □ 需要中文翻译 □ 大写显示 □ 保持原样
- **数字格式：** □ 原始数字 □ 货币格式 □ 其他：_______

## 快速检查清单

### 代码检查 (5分钟)
- [ ] 检查现有ActiveAdmin配置
- [ ] 确认数据模型字段存在
- [ ] 检查关联关系定义
- [ ] 查看现有导入/导出逻辑

### 实现步骤 (15-30分钟)
- [ ] 添加CSV导出配置
- [ ] 更新列表页字段配置
- [ ] 应用数据格式化
- [ ] 测试功能

### 验证测试 (10分钟)
- [ ] 启动服务器测试
- [ ] 检查列表页显示
- [ ] 测试CSV导出
- [ ] 验证数据格式

### 提交代码 (5分钟)
- [ ] git add 相关文件
- [ ] git commit 规范化提交信息
- [ ] 更新文档

## 常用代码片段

### CSV导出模板
```ruby
# CSV 导出配置
csv do
  column("字段名") { |resource| resource.field_name }
  column("日期字段") { |resource| resource.date_field&.strftime('%Y-%m-%d %H:%M:%S') || '0' }
  column("状态字段") { |resource| resource.status == 'value' ? '中文' : '其他' }
  column("关联字段") { |resource| resource.association&.email || "未分配" }
end
```

### 列表页模板
```ruby
# 列表页
index do
  selectable_column
  column :field_name, label: "中文标签"
  column :date_field, label: "日期字段" do |resource|
    resource.date_field&.strftime('%Y-%m-%d %H:%M:%S') || '0'
  end
  column :status, label: "状态" do |resource|
    status_tag resource.status.upcase
  end
  actions defaults: false do |resource|
    item "查看", admin_resource_path(resource), class: "member_link"
  end
end
```

## 预计时间
- **简单配置（10个字段以内）：** 30-45分钟
- **复杂配置（20个字段以上）：** 60-90分钟
- **包含复杂关联和格式化：** 90-120分钟

## 下次任务准备
1. 复制此模板到新的任务文档
2. 填写基本信息和字段需求
3. 按照检查清单逐步执行
4. 参考操作指南处理复杂情况

---
*使用此模板可以将任务启动时间从30分钟缩短到5分钟*