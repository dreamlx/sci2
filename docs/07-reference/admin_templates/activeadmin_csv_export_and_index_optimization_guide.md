# ActiveAdmin CSV导出和列表页优化操作指南

## 任务概述
本指南记录了如何为ActiveAdmin资源配置自定义CSV导出功能和优化列表页显示字段的标准化流程。

## 适用场景
- 需要自定义CSV导出字段和格式
- 需要重新配置列表页显示字段
- 需要优化数据显示格式（日期、状态翻译等）
- 适用于报销单、工单等业务模块

## 操作流程

### 1. 需求分析阶段
**目标：** 明确客户对导出和显示字段的具体要求

**操作步骤：**
1. 收集客户提供的字段列表和示例数据
2. 分析字段映射关系（中文字段名 → 数据库字段）
3. 确认数据格式要求（日期格式、空值处理、状态翻译等）
4. 区分CSV导出字段和列表页显示字段的差异

**关键信息收集：**
- 字段中文名称和对应的数据库字段
- 日期字段的显示格式
- 空值的处理方式（如显示'0'）
- 状态字段的翻译需求
- 字段显示顺序

### 2. 代码检查阶段
**目标：** 了解现有实现和数据模型

**操作步骤：**
1. 检查ActiveAdmin资源文件（如 `app/admin/reimbursements.rb`）
2. 检查数据模型文件（如 `app/models/reimbursement.rb`）
3. 检查相关迁移文件，确认字段存在
4. 检查导入服务（如存在），了解字段处理逻辑

**关键检查点：**
- 现有的index配置
- 是否已有csv配置
- 模型中的字段定义
- 关联关系（如current_assignee）

### 3. CSV导出配置
**目标：** 添加自定义CSV导出功能

**代码模板：**
```ruby
# CSV 导出配置
csv do
  column("中文字段名") { |resource| resource.database_field }
  column("日期字段") { |resource| resource.date_field&.strftime('%Y-%m-%d %H:%M:%S') || '0' }
  column("状态字段") { |resource| resource.status_field == 'value' ? '中文状态' : '其他状态' }
  column("关联字段") { |resource| resource.association&.display_field || "默认值" }
end
```

**常用格式化模式：**
- 日期时间：`&.strftime('%Y-%m-%d %H:%M:%S') || '0'`
- 日期：`&.strftime('%Y-%m-%d') || '0'`
- 状态翻译：`field == 'received' ? '已收单' : '未收单'`
- 空值处理：`field || '0'`
- 大写状态：`field.upcase`
- 中文日期：`&.strftime('%Y年%m月%d日 %H:%M')`

### 4. 列表页配置优化
**目标：** 重新配置index页面的显示字段

**代码模板：**
```ruby
# 列表页
index do
  # 保留必要的系统列
  selectable_column
  
  # 业务字段配置
  column :field_name, label: "中文标签" do |resource|
    # 自定义显示逻辑
  end
  
  # 保留操作列
  actions defaults: false do |resource|
    item "查看", admin_resource_path(resource), class: "member_link"
  end
end
```

**常用显示模式：**
- 简单字段：`column :field_name, label: "中文标签"`
- 格式化数字：`number_to_currency(resource.amount, unit: "¥")`
- 日期格式化：`resource.date_field&.strftime('%Y-%m-%d %H:%M:%S') || '0'`
- 状态标签：`status_tag resource.status.upcase`
- 条件显示：`resource.field.present? ? resource.field : "默认值"`

### 5. 数据格式化标准
**目标：** 统一数据显示格式

**格式化规则：**
- **日期时间字段：** `YYYY-MM-DD HH:MM:SS`
- **日期字段：** `YYYY-MM-DD`
- **空值处理：** 显示 `'0'`
- **状态字段：** 翻译为中文或大写显示
- **关联字段：** 显示关联对象的标识字段（如email）
- **未分配状态：** 显示 `"未分配"`

### 6. 测试验证
**目标：** 确保功能正常工作

**验证步骤：**
1. 启动Rails服务器
2. 访问资源列表页面，检查字段显示
3. 测试CSV导出功能
4. 验证数据格式是否符合要求
5. 检查空值和特殊情况的处理

### 7. 代码提交
**目标：** 规范化提交更改

**提交模板：**
```bash
git add app/admin/[resource_name].rb
git commit -m "更新[资源名称]管理页面：添加CSV导出配置和优化列表显示字段

- 添加完整的CSV导出配置，包含所有[N]个必需字段
- 更新列表页显示字段，按客户要求重新排序和格式化
- 优化日期字段显示格式，空值显示为'0'
- [其他具体优化点]
- 保持[保留的功能]"
```

## 常见问题和解决方案

### 1. 字段不存在错误
**问题：** NoMethodError: undefined method for model
**解决：** 检查数据库迁移，确认字段已添加到数据库

### 2. 关联字段显示问题
**问题：** 关联对象为nil导致错误
**解决：** 使用安全导航操作符 `&.` 和默认值

### 3. 日期格式化错误
**问题：** 日期字段格式不正确
**解决：** 使用 `&.strftime()` 和空值处理

### 4. CSV导出中文乱码
**问题：** CSV文件中文显示乱码
**解决：** 检查ActiveAdmin CSV配置和编码设置

## 文件位置参考
- ActiveAdmin资源文件：`app/admin/[resource_name].rb`
- 数据模型文件：`app/models/[model_name].rb`
- 迁移文件：`db/migrate/`
- 服务文件：`app/services/`

## 下次任务准备清单
1. [ ] 收集字段需求列表
2. [ ] 确认数据格式要求
3. [ ] 检查现有代码结构
4. [ ] 准备测试数据
5. [ ] 确认提交信息模板

---
*最后更新：2025-08-04*
*适用版本：Rails 7.1 + ActiveAdmin*