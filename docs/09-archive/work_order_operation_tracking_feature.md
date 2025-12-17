# 工单操作记录跟踪功能设计

## 1. 功能概述

工单操作记录跟踪功能旨在记录系统中所有工单相关的操作，包括创建、修改、状态变更等，以便追踪谁在什么时间做了什么操作。这对于多个审核人员协同工作的场景尤为重要，可以提供完整的审计跟踪，便于了解工单处理的时间线和责任归属。

## 2. 需求分析

### 2.1 核心需求

1. **操作记录**：记录所有工单相关操作，包括创建、修改、状态变更等
2. **操作人记录**：记录每次操作的执行人
3. **时间线视图**：提供操作的时间线视图
4. **操作内容记录**：记录操作前后的内容变化
5. **操作类型分类**：对不同类型的操作进行分类，便于查询和统计

### 2.2 扩展需求

1. **操作统计**：提供操作统计功能，如每个人的操作数量、各类操作的分布等
2. **操作搜索**：支持按操作人、操作类型、时间范围等搜索操作记录
3. **操作导出**：支持导出操作记录
4. **操作通知**：特定操作发生时通知相关人员

## 3. 数据模型设计

### 3.1 新增表：`work_order_operations`

```ruby
create_table :work_order_operations do |t|
  t.references :work_order, null: false, foreign_key: true
  t.references :admin_user, null: false, foreign_key: true
  t.string :operation_type, null: false # 'create', 'update', 'status_change', 'add_problem', 'remove_problem', etc.
  t.text :details # JSON格式，存储操作的详细信息
  t.text :previous_state # JSON格式，存储操作前的状态
  t.text :current_state # JSON格式，存储操作后的状态
  t.datetime :created_at, null: false
  
  t.index [:work_order_id, :created_at]
  t.index [:admin_user_id, :created_at]
  t.index [:operation_type, :created_at]
end
```

### 3.2 模型关系

```ruby
# app/models/work_order.rb
has_many :operations, class_name: 'WorkOrderOperation', dependent: :destroy

# app/models/admin_user.rb
has_many :work_order_operations, dependent: :nullify

# app/models/work_order_operation.rb
class WorkOrderOperation < ApplicationRecord
  belongs_to :work_order
  belongs_to :admin_user
  
  validates :operation_type, presence: true
  
  scope :by_work_order, ->(work_order_id) { where(work_order_id: work_order_id) }
  scope :by_admin_user, ->(admin_user_id) { where(admin_user_id: admin_user_id) }
  scope :by_operation_type, ->(operation_type) { where(operation_type: operation_type) }
  scope :recent_first, -> { order(created_at: :desc) }
  
  # 操作类型常量
  OPERATION_TYPE_CREATE = 'create'.freeze
  OPERATION_TYPE_UPDATE = 'update'.freeze
  OPERATION_TYPE_STATUS_CHANGE = 'status_change'.freeze
  OPERATION_TYPE_ADD_PROBLEM = 'add_problem'.freeze
  OPERATION_TYPE_REMOVE_PROBLEM = 'remove_problem'.freeze
  OPERATION_TYPE_MODIFY_PROBLEM = 'modify_problem'.freeze
  
  # 操作类型列表
  def self.operation_types
    [
      OPERATION_TYPE_CREATE,
      OPERATION_TYPE_UPDATE,
      OPERATION_TYPE_STATUS_CHANGE,
      OPERATION_TYPE_ADD_PROBLEM,
      OPERATION_TYPE_REMOVE_PROBLEM,
      OPERATION_TYPE_MODIFY_PROBLEM
    ]
  end
  
  # 获取操作类型的显示名称
  def operation_type_display
    case operation_type
    when OPERATION_TYPE_CREATE
      '创建工单'
    when OPERATION_TYPE_UPDATE
      '更新工单'
    when OPERATION_TYPE_STATUS_CHANGE
      '状态变更'
    when OPERATION_TYPE_ADD_PROBLEM
      '添加问题'
    when OPERATION_TYPE_REMOVE_PROBLEM
      '移除问题'
    when OPERATION_TYPE_MODIFY_PROBLEM
      '修改问题'
    else
      operation_type
    end
  end
  
  # 获取操作详情的哈希表示
  def details_hash
    return {} if details.blank?
    
    begin
      JSON.parse(details)
    rescue JSON::ParserError
      {}
    end
  end
  
  # 获取操作前状态的哈希表示
  def previous_state_hash
    return {} if previous_state.blank?
    
    begin
      JSON.parse(previous_state)
    rescue JSON::ParserError
      {}
    end
  end
  
  # 获取操作后状态的哈希表示
  def current_state_hash
    return {} if current_state.blank?
    
    begin
      JSON.parse(current_state)
    rescue JSON::ParserError
      {}
    end
  end
end
```

## 4. 服务层设计

### 4.1 工单操作记录服务

```ruby
# app/services/work_order_operation_service.rb
class WorkOrderOperationService
  def initialize(work_order, admin_user)
    @work_order = work_order
    @admin_user = admin_user
  end
  
  # 记录工单创建操作
  def record_create
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_CREATE,
      { message: "工单已创建" },
      nil,
      work_order_state
    )
  end
  
  # 记录工单更新操作
  def record_update(changed_attributes)
    return if changed_attributes.empty?
    
    previous = {}
    current = {}
    
    changed_attributes.each do |attr, old_value|
      previous[attr] = old_value
      current[attr] = @work_order.send(attr)
    end
    
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_UPDATE,
      { changed_attributes: changed_attributes.keys },
      previous,
      current
    )
  end
  
  # 记录工单状态变更操作
  def record_status_change(from_status, to_status)
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE,
      { from_status: from_status, to_status: to_status },
      { status: from_status },
      { status: to_status }
    )
  end
  
  # 记录添加问题操作
  def record_add_problem(problem_type_id, problem_text)
    problem_type = ProblemType.find_by(id: problem_type_id)
    
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM,
      {
        problem_type_id: problem_type_id,
        problem_type_code: problem_type&.code,
        problem_type_title: problem_type&.title
      },
      { audit_comment: @work_order.audit_comment_was },
      { audit_comment: @work_order.audit_comment }
    )
  end
  
  # 记录移除问题操作
  def record_remove_problem(problem_type_id, problem_text)
    problem_type = ProblemType.find_by(id: problem_type_id)
    
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM,
      {
        problem_type_id: problem_type_id,
        problem_type_code: problem_type&.code,
        problem_type_title: problem_type&.title
      },
      { audit_comment: @work_order.audit_comment_was },
      { audit_comment: @work_order.audit_comment }
    )
  end
  
  # 记录修改问题操作
  def record_modify_problem(problem_type_id, old_text, new_text)
    problem_type = ProblemType.find_by(id: problem_type_id)
    
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM,
      {
        problem_type_id: problem_type_id,
        problem_type_code: problem_type&.code,
        problem_type_title: problem_type&.title
      },
      { audit_comment: old_text },
      { audit_comment: new_text }
    )
  end
  
  private
  
  # 记录操作的通用方法
  def record_operation(operation_type, details, previous_state, current_state)
    WorkOrderOperation.create!(
      work_order: @work_order,
      admin_user: @admin_user,
      operation_type: operation_type,
      details: details.to_json,
      previous_state: previous_state.to_json,
      current_state: current_state.to_json,
      created_at: Time.current
    )
  end
  
  # 获取工单当前状态的哈希表示
  def work_order_state
    {
      id: @work_order.id,
      type: @work_order.type,
      status: @work_order.status,
      reimbursement_id: @work_order.reimbursement_id,
      audit_comment: @work_order.audit_comment,
      problem_type_id: @work_order.problem_type_id,
      created_by: @work_order.created_by
    }
  end
end
```

### 4.2 更新 WorkOrderService

```ruby
# app/services/work_order_service.rb
class WorkOrderService
  # 现有代码...
  
  def initialize(work_order, current_admin_user)
    # 现有代码...
    @operation_service = WorkOrderOperationService.new(work_order, current_admin_user)
  end
  
  def create(params = {})
    # 现有创建逻辑...
    
    if @work_order.save
      # 记录创建操作
      @operation_service.record_create
      true
    else
      false
    end
  end
  
  def update(params = {})
    # 保存更新前的属性
    changed_attributes = {}
    
    # 分配属性
    assign_shared_attributes(params)
    
    # 检查哪些属性发生了变化
    @work_order.changed.each do |attr|
      changed_attributes[attr] = @work_order.send("#{attr}_was")
    end
    
    if @work_order.save
      # 记录更新操作
      @operation_service.record_update(changed_attributes)
      true
    else
      false
    end
  end
  
  def approve(params = {})
    # 保存状态变更前的状态
    old_status = @work_order.status
    
    # 现有审批逻辑...
    
    if @work_order.save
      # 记录状态变更操作
      @operation_service.record_status_change(old_status, @work_order.status)
      true
    else
      false
    end
  end
  
  def reject(params = {})
    # 保存状态变更前的状态
    old_status = @work_order.status
    
    # 现有拒绝逻辑...
    
    if @work_order.save
      # 记录状态变更操作
      @operation_service.record_status_change(old_status, @work_order.status)
      true
    else
      false
    end
  end
  
  # 现有代码...
end
```

### 4.3 更新 WorkOrderProblemService

```ruby
# app/services/work_order_problem_service.rb
class WorkOrderProblemService
  def initialize(work_order, admin_user = nil)
    @work_order = work_order
    @admin_user = admin_user || Current.admin_user
    @operation_service = WorkOrderOperationService.new(work_order, @admin_user)
  end
  
  def add_problem(problem_type_id)
    problem_type = ProblemType.find(problem_type_id)
    
    # 格式化问题信息
    new_problem_text = format_problem(problem_type)
    
    # 更新工单的审核意见
    current_comment = @work_order.audit_comment.to_s.strip
    
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
      # 记录添加问题操作
      @operation_service.record_add_problem(problem_type_id, new_problem_text)
      true
    else
      false
    end
  end
  
  def modify_problem(problem_type_id, new_content)
    problem_type = ProblemType.find(problem_type_id)
    old_content = @work_order.audit_comment.dup
    
    # 更新工单的审核意见
    @work_order.audit_comment = new_content
    
    # 保存工单
    if @work_order.save
      # 记录修改问题操作
      @operation_service.record_modify_problem(problem_type_id, old_content, new_content)
      true
    else
      false
    end
  end
  
  def remove_problem(problem_type_id)
    problem_type = ProblemType.find(problem_type_id)
    old_content = @work_order.audit_comment.dup
    
    # 从审核意见中移除问题
    new_content = remove_problem_from_text(@work_order.audit_comment, problem_type)
    @work_order.audit_comment = new_content
    
    # 保存工单
    if @work_order.save
      # 记录移除问题操作
      @operation_service.record_remove_problem(problem_type_id, old_content)
      true
    else
      false
    end
  end
  
  # 现有代码...
end
```

## 5. 控制器和视图设计

### 5.1 ActiveAdmin 配置

```ruby
# app/admin/work_order_operations.rb
ActiveAdmin.register WorkOrderOperation do
  belongs_to :work_order, optional: true
  
  menu false # 不在主菜单中显示
  
  # 权限控制
  actions :index, :show
  
  # 过滤器
  filter :work_order
  filter :admin_user
  filter :operation_type, as: :select, collection: -> { 
    WorkOrderOperation.operation_types.map { |type| 
      [WorkOrderOperation.new(operation_type: type).operation_type_display, type] 
    }
  }
  filter :created_at
  
  # 列表页
  index do
    selectable_column
    id_column
    column :work_order do |operation|
      link_to "工单 ##{operation.work_order.id}", admin_work_order_path(operation.work_order)
    end
    column :operation_type do |operation|
      status_tag operation.operation_type_display
    end
    column :admin_user
    column :created_at
    actions
  end
  
  # 详情页
  show do
    attributes_table do
      row :id
      row :work_order do |operation|
        link_to "工单 ##{operation.work_order.id}", admin_work_order_path(operation.work_order)
      end
      row :operation_type do |operation|
        status_tag operation.operation_type_display
      end
      row :admin_user
      row :created_at
    end
    
    panel "操作详情" do
      attributes_table_for resource do
        row :details do |operation|
          pre code JSON.pretty_generate(operation.details_hash)
        end
      end
    end
    
    panel "状态变化" do
      tabs do
        tab '操作前' do
          attributes_table_for resource do
            row :previous_state do |operation|
              pre code JSON.pretty_generate(operation.previous_state_hash)
            end
          end
        end
        
        tab '操作后' do
          attributes_table_for resource do
            row :current_state do |operation|
              pre code JSON.pretty_generate(operation.current_state_hash)
            end
          end
        end
      end
    end
  end
end
```

### 5.2 工单详情页集成

```ruby
# app/admin/audit_work_orders.rb (和其他工单类型)
# 在 show 块中添加
panel "操作记录" do
  if resource.operations.exists?
    table_for resource.operations.recent_first do
      column :id do |operation|
        link_to operation.id, admin_work_order_operation_path(operation)
      end
      column :operation_type do |operation|
        status_tag operation.operation_type_display
      end
      column :admin_user
      column :created_at
    end
  else
    para "暂无操作记录"
  end
end
```

### 5.3 操作统计页面

```ruby
# app/admin/operation_statistics.rb
ActiveAdmin.register_page "Operation Statistics" do
  menu label: "操作统计", priority: 10
  
  content title: "操作统计" do
    columns do
      column do
        panel "按操作类型统计" do
          pie_chart WorkOrderOperation.group(:operation_type).count.transform_keys { |k| 
            WorkOrderOperation.new(operation_type: k).operation_type_display 
          }
        end
      end
      
      column do
        panel "按操作人统计" do
          pie_chart WorkOrderOperation.joins(:admin_user).group('admin_users.email').count
        end
      end
    end
    
    columns do
      column do
        panel "最近30天操作趋势" do
          line_chart WorkOrderOperation.where('created_at >= ?', 30.days.ago)
                                      .group_by_day(:created_at)
                                      .count
        end
      end
    end
    
    panel "操作排行榜" do
      table_for AdminUser.joins(:work_order_operations)
                        .select('admin_users.*, COUNT(work_order_operations.id) as operations_count')
                        .group('admin_users.id')
                        .order('operations_count DESC')
                        .limit(10) do
        column :email
        column "操作数量" do |admin_user|
          admin_user.operations_count
        end
      end
    end
  end
end
```

## 6. 实现计划

### 6.1 阶段一：数据库结构调整（1天）

1. **创建迁移脚本**（0.5天）
   - 创建 `work_order_operations` 表
   - 添加必要的字段和索引

2. **执行迁移**（0.5天）
   - 运行迁移脚本
   - 验证表结构正确性

### 6.2 阶段二：模型和服务实现（2天）

1. **实现 `WorkOrderOperation` 模型**（0.5天）
   - 添加关联、验证和作用域
   - 实现辅助方法

2. **实现 `WorkOrderOperationService`**（1天）
   - 实现记录各类操作的方法
   - 实现操作详情的格式化

3. **更新现有服务**（0.5天）
   - 更新 `WorkOrderService`
   - 更新 `WorkOrderProblemService`

### 6.3 阶段三：UI实现（2天）

1. **ActiveAdmin 配置**（1天）
   - 创建 `work_order_operations.rb` 文件
   - 配置索引页和详情页

2. **工单详情页集成**（0.5天）
   - 在工单详情页添加操作记录面板

3. **操作统计页面**（0.5天）
   - 创建操作统计页面
   - 实现各类统计图表

### 6.4 阶段四：测试与优化（1天）

1. **单元测试**（0.5天）
   - 为 `WorkOrderOperation` 模型编写测试
   - 为 `WorkOrderOperationService` 编写测试

2. **集成测试**（0.5天）
   - 编写端到端测试，验证完整功能
   - 测试边缘情况和错误处理

## 7. 总结

工单操作记录跟踪功能将提供完整的工单操作审计跟踪，记录谁在什么时间做了什么操作，便于多个审核人员协同工作。该功能不需要修改现有的问题处理逻辑（保持文本存储方式），而是通过添加新的操作记录表和服务来实现。

实现这一功能将增强系统的审计能力，提高工作透明度，并为问题处理提供更好的可追溯性。同时，操作统计功能将帮助管理者了解工作量分布和效率，为资源调配提供依据。