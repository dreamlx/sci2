# 工单问题历史记录功能设计

## 1. 功能概述

工单问题历史记录功能旨在跟踪工单中问题的添加、修改和删除历史，提供完整的审计跟踪，便于了解问题处理的时间线和变更原因。

## 2. 需求分析

### 2.1 核心需求

1. **问题变更记录**：记录工单中问题的添加、修改和删除操作
2. **时间线视图**：提供问题变更的时间线视图
3. **操作人记录**：记录每次变更的操作人
4. **变更内容比较**：支持查看问题变更前后的内容差异
5. **问题状态跟踪**：记录问题状态的变化（如"已添加"、"已修改"、"已解决"等）

### 2.2 扩展需求

1. **变更原因记录**：允许操作人添加变更原因说明
2. **通知机制**：问题变更时通知相关人员
3. **统计分析**：提供问题变更的统计分析功能
4. **导出功能**：支持导出问题历史记录

## 3. 数据模型设计

### 3.1 新增表：`work_order_problem_histories`

```ruby
create_table :work_order_problem_histories do |t|
  t.references :work_order, null: false, foreign_key: true
  t.references :problem_type, null: true, foreign_key: true
  t.references :fee_type, null: true, foreign_key: true
  t.references :admin_user, null: false, foreign_key: true
  t.string :action_type, null: false # 'add', 'modify', 'remove'
  t.text :previous_content
  t.text :new_content
  t.text :change_reason
  t.datetime :created_at, null: false
  
  t.index [:work_order_id, :created_at]
end
```

### 3.2 模型关系

```ruby
# app/models/work_order.rb
has_many :problem_histories, class_name: 'WorkOrderProblemHistory', dependent: :destroy

# app/models/work_order_problem_history.rb
class WorkOrderProblemHistory < ApplicationRecord
  belongs_to :work_order
  belongs_to :problem_type, optional: true
  belongs_to :fee_type, optional: true
  belongs_to :admin_user
  
  validates :action_type, presence: true, inclusion: { in: ['add', 'modify', 'remove'] }
  
  scope :by_work_order, ->(work_order_id) { where(work_order_id: work_order_id) }
  scope :by_admin_user, ->(admin_user_id) { where(admin_user_id: admin_user_id) }
  scope :by_action_type, ->(action_type) { where(action_type: action_type) }
  scope :recent_first, -> { order(created_at: :desc) }
end
```

## 4. 服务层设计

### 4.1 更新 `WorkOrderProblemService`

```ruby
# app/services/work_order_problem_service.rb
def add_problem(problem_type_id, admin_user_id = nil)
  problem_type = ProblemType.find(problem_type_id)
  
  # 格式化问题信息
  new_problem_text = format_problem(problem_type)
  
  # 更新工单的审核意见
  current_comment = @work_order.audit_comment.to_s.strip
  previous_content = current_comment.dup
  
  if current_comment.present?
    # 在问题之间添加空行
    @work_order.audit_comment = "#{current_comment}\n\n#{new_problem_text}"
  else
    @work_order.audit_comment = new_problem_text
  end
  
  # 更新problem_type_id字段（用于参考）
  @work_order.problem_type_id = problem_type_id
  
  # 保存工单
  if @work_order.save
    # 记录问题历史
    record_problem_history(
      'add',
      problem_type_id,
      problem_type.fee_type_id,
      admin_user_id,
      previous_content,
      @work_order.audit_comment
    )
    true
  else
    false
  end
end

def modify_problem(problem_type_id, new_content, admin_user_id = nil)
  problem_type = ProblemType.find(problem_type_id)
  previous_content = @work_order.audit_comment.dup
  
  # 更新工单的审核意见
  @work_order.audit_comment = new_content
  
  # 保存工单
  if @work_order.save
    # 记录问题历史
    record_problem_history(
      'modify',
      problem_type_id,
      problem_type.fee_type_id,
      admin_user_id,
      previous_content,
      new_content
    )
    true
  else
    false
  end
end

def remove_problem(problem_type_id, admin_user_id = nil)
  problem_type = ProblemType.find(problem_type_id)
  previous_content = @work_order.audit_comment.dup
  
  # 从审核意见中移除问题
  # 这里需要实现一个方法来从文本中识别并移除特定问题
  new_content = remove_problem_from_text(@work_order.audit_comment, problem_type)
  @work_order.audit_comment = new_content
  
  # 保存工单
  if @work_order.save
    # 记录问题历史
    record_problem_history(
      'remove',
      problem_type_id,
      problem_type.fee_type_id,
      admin_user_id,
      previous_content,
      new_content
    )
    true
  else
    false
  end
end

private

def record_problem_history(action_type, problem_type_id, fee_type_id, admin_user_id, previous_content, new_content, change_reason = nil)
  WorkOrderProblemHistory.create!(
    work_order: @work_order,
    problem_type_id: problem_type_id,
    fee_type_id: fee_type_id,
    admin_user_id: admin_user_id || Current.admin_user&.id,
    action_type: action_type,
    previous_content: previous_content,
    new_content: new_content,
    change_reason: change_reason
  )
end

def remove_problem_from_text(text, problem_type)
  # 实现从文本中识别并移除特定问题的逻辑
  # 这需要一个相对复杂的文本处理算法
  # 可能需要使用正则表达式或其他文本处理技术
  # 返回移除问题后的文本
end
```

## 5. 控制器和视图设计

### 5.1 ActiveAdmin 配置

```ruby
# app/admin/work_order_problem_histories.rb
ActiveAdmin.register WorkOrderProblemHistory do
  belongs_to :work_order, optional: true
  
  menu false # 不在主菜单中显示
  
  # 权限控制
  actions :index, :show
  
  # 过滤器
  filter :work_order
  filter :admin_user
  filter :action_type, as: :select, collection: ['add', 'modify', 'remove']
  filter :created_at
  
  # 列表页
  index do
    column :id
    column :work_order
    column :action_type
    column :problem_type
    column :admin_user
    column :created_at
    actions
  end
  
  # 详情页
  show do
    attributes_table do
      row :id
      row :work_order
      row :problem_type
      row :fee_type
      row :admin_user
      row :action_type
      row :previous_content
      row :new_content
      row :change_reason
      row :created_at
    end
  end
end
```

### 5.2 工单详情页添加问题历史标签页

```ruby
# app/admin/audit_work_orders.rb (在 show 块中添加)
panel "问题历史记录" do
  table_for resource.problem_histories.recent_first do
    column :id
    column :action_type do |history|
      case history.action_type
      when 'add'
        status_tag '添加', class: 'green'
      when 'modify'
        status_tag '修改', class: 'orange'
      when 'remove'
        status_tag '移除', class: 'red'
      end
    end
    column :problem_type
    column :admin_user
    column :created_at
    column :actions do |history|
      link_to '查看', admin_work_order_problem_history_path(history)
    end
  end
end
```

## 6. 实现计划

### 6.1 阶段一：基础功能实现

1. 创建 `work_order_problem_histories` 表的迁移脚本
2. 实现 `WorkOrderProblemHistory` 模型
3. 更新 `WorkOrderProblemService` 添加历史记录功能
4. 实现 ActiveAdmin 配置

### 6.2 阶段二：高级功能实现

1. 实现问题内容差异比较功能
2. 添加问题变更原因记录功能
3. 实现问题历史时间线视图
4. 添加问题变更通知功能

### 6.3 阶段三：优化和扩展

1. 实现问题历史统计分析功能
2. 添加问题历史导出功能
3. 优化用户界面和交互体验
4. 实现问题历史搜索和筛选功能

## 7. 测试计划

### 7.1 单元测试

1. `WorkOrderProblemHistory` 模型测试
2. `WorkOrderProblemService` 服务测试

### 7.2 集成测试

1. 问题添加、修改、删除功能测试
2. 问题历史记录功能测试
3. 问题历史查看功能测试

### 7.3 系统测试

1. 完整工作流测试
2. 用户界面测试
3. 性能测试

## 8. 总结

工单问题历史记录功能将提供完整的问题变更跟踪，增强系统的审计能力，便于了解问题处理的时间线和变更原因。该功能将分三个阶段实现，从基础功能到高级功能，最后进行优化和扩展。