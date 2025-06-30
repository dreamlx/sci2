# 工单系统添加创建时间列和时间排序功能计划

## 项目概述
为审核工单和沟通工单页面添加 `created_at` 列显示和基本时间排序功能。

## 当前状态分析

### 数据库层面
- ✅ `work_orders` 表已包含 `created_at` 和 `updated_at` 字段 (db/schema.rb:238-239)
- ✅ 数据库索引已存在，支持时间排序查询

### ActiveAdmin 配置现状
- ✅ **审核工单**: 已配置默认排序 `config.sort_order = 'created_at_desc'` (app/admin/audit_work_orders.rb:11)
- ✅ **沟通工单**: 已配置默认排序 `config.sort_order = 'created_at_desc'` (app/admin/communication_work_orders.rb:9)

### 列显示现状
- ❌ **审核工单**: 缺少 `created_at` 列显示 (app/admin/audit_work_orders.rb:319 只有创建人列)
- ✅ **沟通工单**: 已显示 `created_at` 列 (app/admin/communication_work_orders.rb:281)

## 实施计划

### 任务 1: 添加审核工单创建时间列
**目标**: 在审核工单列表页面添加 `created_at` 列显示

**具体实现**:
- 在 `app/admin/audit_work_orders.rb` 的 index 块中添加 `column :created_at`
- 位置: 在第319行 "创建人" 列之后添加

**代码修改**:
```ruby
# 在 app/admin/audit_work_orders.rb 第319行后添加
column "创建人", :creator
column "创建时间", :created_at  # 新增此行
column "操作" do |work_order|
```

### 任务 2: 确保时间排序功能正常
**目标**: 验证两个页面的时间排序功能正常工作

**验证点**:
- 确认默认按创建时间降序排列 (最新的在前)
- 确认列标题可点击进行升序/降序切换
- 确认排序状态在页面刷新后保持

### 任务 3: 统一时间显示格式
**目标**: 确保两个页面的时间显示格式一致

**实现方式**:
- 使用标准的 Rails 时间格式
- 显示格式: `YYYY-MM-DD HH:MM`
- 保持与现有沟通工单页面格式一致

## 技术实现细节

### 文件修改清单
1. `app/admin/audit_work_orders.rb` - 添加 created_at 列

### 预期效果
- 审核工单页面将显示创建时间列
- 两个工单页面的时间显示保持一致
- 默认按创建时间倒序排列 (最新的工单在最前面)
- 用户可以点击列标题进行时间排序

### 测试验证
1. 访问 http://127.0.0.1:3000/admin/audit_work_orders 确认显示创建时间列
2. 访问 http://127.0.0.1:3000/admin/communication_work_orders 确认时间列正常
3. 点击时间列标题测试排序功能
4. 验证最新创建的工单显示在列表顶部

## 实施优先级
**高优先级**: 添加审核工单创建时间列显示 - 这是用户明确要求的核心功能

**完成标准**: 
- 审核工单和沟通工单页面都显示创建时间列
- 时间排序功能正常工作
- 界面显示一致且用户友好