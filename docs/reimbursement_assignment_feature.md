# 报销单分配功能设计

## 1. 功能概述

报销单分配功能旨在支持多个财务审核人员协同工作，允许管理员将报销单分配给不同的员工，每个员工可以查看和处理自己分配到的报销单，同时也能查看和处理全部报销单。这将提高工作效率，明确责任归属，并支持团队协作。

## 2. 需求分析

### 2.1 核心需求

1. **报销单分配**：管理员可以将报销单分配给特定的审核人员
2. **个人工作区**：审核人员可以查看分配给自己的报销单列表
3. **全局视图**：审核人员可以查看所有报销单列表
4. **灵活处理**：审核人员可以处理分配给自己的报销单，也可以处理分配给其他人的报销单
5. **分配记录**：记录报销单分配历史，包括分配人、被分配人、分配时间等

### 2.2 扩展需求

1. **批量分配**：支持批量选择报销单并分配给特定审核人员
2. **自动分配**：根据预设规则自动分配新导入的报销单
3. **工作量平衡**：提供工作量统计，帮助管理员平衡分配
4. **分配通知**：当报销单被分配时通知相关审核人员
5. **转移分配**：允许将已分配的报销单转移给其他审核人员

## 3. 数据模型设计

### 3.1 新增表：`reimbursement_assignments`

```ruby
create_table :reimbursement_assignments do |t|
  t.references :reimbursement, null: false, foreign_key: true
  t.references :assignee, null: false, foreign_key: { to_table: :admin_users }
  t.references :assigner, null: false, foreign_key: { to_table: :admin_users }
  t.boolean :is_active, default: true
  t.text :notes
  t.datetime :created_at, null: false
  t.datetime :updated_at, null: false
  
  t.index [:reimbursement_id, :is_active]
  t.index [:assignee_id, :is_active]
end
```

### 3.2 模型关系

```ruby
# app/models/reimbursement.rb
has_many :assignments, class_name: 'ReimbursementAssignment', dependent: :destroy
has_many :assignees, through: :assignments, source: :assignee
has_one :active_assignment, -> { where(is_active: true) }, class_name: 'ReimbursementAssignment'
has_one :current_assignee, through: :active_assignment, source: :assignee

# app/models/admin_user.rb
has_many :assigned_reimbursements, class_name: 'ReimbursementAssignment', foreign_key: 'assignee_id'
has_many :active_assigned_reimbursements, -> { where(is_active: true) }, class_name: 'ReimbursementAssignment', foreign_key: 'assignee_id'
has_many :reimbursements_to_process, through: :active_assigned_reimbursements, source: :reimbursement
has_many :reimbursement_assignments_made, class_name: 'ReimbursementAssignment', foreign_key: 'assigner_id'

# app/models/reimbursement_assignment.rb
class ReimbursementAssignment < ApplicationRecord
  belongs_to :reimbursement
  belongs_to :assignee, class_name: 'AdminUser'
  belongs_to :assigner, class_name: 'AdminUser'
  
  validates :reimbursement_id, uniqueness: { scope: :is_active, message: "已经有一个活跃的分配" }, if: :is_active?
  
  scope :active, -> { where(is_active: true) }
  scope :by_assignee, ->(assignee_id) { where(assignee_id: assignee_id) }
  scope :by_assigner, ->(assigner_id) { where(assigner_id: assigner_id) }
  scope :recent_first, -> { order(created_at: :desc) }
  
  before_create :deactivate_previous_assignments
  
  private
  
  def deactivate_previous_assignments
    if is_active?
      ReimbursementAssignment.where(reimbursement_id: reimbursement_id, is_active: true)
                            .update_all(is_active: false)
    end
  end
end
```

## 4. 服务层设计

### 4.1 报销单分配服务

```ruby
# app/services/reimbursement_assignment_service.rb
class ReimbursementAssignmentService
  def initialize(current_admin_user)
    @current_admin_user = current_admin_user
  end
  
  # 分配单个报销单
  # @param reimbursement_id [Integer] 报销单ID
  # @param assignee_id [Integer] 被分配人ID
  # @param notes [String] 分配备注
  # @return [ReimbursementAssignment] 创建的分配记录
  def assign(reimbursement_id, assignee_id, notes = nil)
    reimbursement = Reimbursement.find(reimbursement_id)
    assignee = AdminUser.find(assignee_id)
    
    assignment = ReimbursementAssignment.new(
      reimbursement: reimbursement,
      assignee: assignee,
      assigner: @current_admin_user,
      is_active: true,
      notes: notes
    )
    
    if assignment.save
      # 记录操作
      record_assignment_operation(reimbursement, assignee)
      assignment
    else
      nil
    end
  end
  
  # 批量分配报销单
  # @param reimbursement_ids [Array<Integer>] 报销单ID数组
  # @param assignee_id [Integer] 被分配人ID
  # @param notes [String] 分配备注
  # @return [Array<ReimbursementAssignment>] 创建的分配记录数组
  def batch_assign(reimbursement_ids, assignee_id, notes = nil)
    assignee = AdminUser.find(assignee_id)
    assignments = []
    
    Reimbursement.where(id: reimbursement_ids).find_each do |reimbursement|
      assignment = ReimbursementAssignment.new(
        reimbursement: reimbursement,
        assignee: assignee,
        assigner: @current_admin_user,
        is_active: true,
        notes: notes
      )
      
      if assignment.save
        # 记录操作
        record_assignment_operation(reimbursement, assignee)
        assignments << assignment
      end
    end
    
    assignments
  end
  
  # 取消分配
  # @param assignment_id [Integer] 分配记录ID
  # @return [Boolean] 是否成功取消分配
  def unassign(assignment_id)
    assignment = ReimbursementAssignment.find(assignment_id)
    
    if assignment.update(is_active: false)
      # 记录操作
      record_unassignment_operation(assignment.reimbursement, assignment.assignee)
      true
    else
      false
    end
  end
  
  # 转移分配
  # @param reimbursement_id [Integer] 报销单ID
  # @param new_assignee_id [Integer] 新被分配人ID
  # @param notes [String] 分配备注
  # @return [ReimbursementAssignment] 创建的分配记录
  def transfer(reimbursement_id, new_assignee_id, notes = nil)
    reimbursement = Reimbursement.find(reimbursement_id)
    new_assignee = AdminUser.find(new_assignee_id)
    
    # 获取当前分配
    current_assignment = reimbursement.active_assignment
    
    # 创建新分配
    assignment = ReimbursementAssignment.new(
      reimbursement: reimbursement,
      assignee: new_assignee,
      assigner: @current_admin_user,
      is_active: true,
      notes: notes
    )
    
    if assignment.save
      # 记录操作
      record_transfer_operation(reimbursement, current_assignment&.assignee, new_assignee)
      assignment
    else
      nil
    end
  end
  
  private
  
  # 记录分配操作
  def record_assignment_operation(reimbursement, assignee)
    # 如果有工单操作记录服务，可以在这里记录操作
    # 例如：
    # operation_service = WorkOrderOperationService.new(nil, @current_admin_user)
    # operation_service.record_reimbursement_assignment(reimbursement, assignee)
  end
  
  # 记录取消分配操作
  def record_unassignment_operation(reimbursement, assignee)
    # 如果有工单操作记录服务，可以在这里记录操作
  end
  
  # 记录转移分配操作
  def record_transfer_operation(reimbursement, old_assignee, new_assignee)
    # 如果有工单操作记录服务，可以在这里记录操作
  end
end
```

### 4.2 报销单查询服务

```ruby
# app/services/reimbursement_query_service.rb
class ReimbursementQueryService
  def initialize(current_admin_user)
    @current_admin_user = current_admin_user
  end
  
  # 获取分配给当前用户的报销单
  # @param params [Hash] 查询参数
  # @return [ActiveRecord::Relation] 报销单查询结果
  def assigned_to_me(params = {})
    query = Reimbursement.joins(:active_assignment)
                        .where(reimbursement_assignments: { assignee_id: @current_admin_user.id })
    
    apply_filters(query, params)
  end
  
  # 获取所有报销单
  # @param params [Hash] 查询参数
  # @return [ActiveRecord::Relation] 报销单查询结果
  def all_reimbursements(params = {})
    query = Reimbursement.all
    
    apply_filters(query, params)
  end
  
  # 获取未分配的报销单
  # @param params [Hash] 查询参数
  # @return [ActiveRecord::Relation] 报销单查询结果
  def unassigned(params = {})
    query = Reimbursement.left_joins(:active_assignment)
                        .where(reimbursement_assignments: { id: nil })
    
    apply_filters(query, params)
  end
  
  # 获取分配给特定用户的报销单
  # @param assignee_id [Integer] 被分配人ID
  # @param params [Hash] 查询参数
  # @return [ActiveRecord::Relation] 报销单查询结果
  def assigned_to_user(assignee_id, params = {})
    query = Reimbursement.joins(:active_assignment)
                        .where(reimbursement_assignments: { assignee_id: assignee_id })
    
    apply_filters(query, params)
  end
  
  private
  
  # 应用过滤条件
  # @param query [ActiveRecord::Relation] 初始查询
  # @param params [Hash] 查询参数
  # @return [ActiveRecord::Relation] 应用过滤条件后的查询
  def apply_filters(query, params)
    # 状态过滤
    if params[:status].present?
      query = query.where(status: params[:status])
    end
    
    # 发票号过滤
    if params[:invoice_number].present?
      query = query.where('invoice_number LIKE ?', "%#{params[:invoice_number]}%")
    end
    
    # 日期范围过滤
    if params[:start_date].present? && params[:end_date].present?
      query = query.where(created_at: params[:start_date]..params[:end_date])
    end
    
    # 排序
    if params[:sort_by].present?
      direction = params[:sort_direction] == 'desc' ? 'desc' : 'asc'
      query = query.order("#{params[:sort_by]} #{direction}")
    else
      query = query.order(created_at: :desc)
    end
    
    query
  end
end
```

## 5. 控制器和视图设计

### 5.1 ActiveAdmin 配置

```ruby
# app/admin/reimbursement_assignments.rb
ActiveAdmin.register ReimbursementAssignment do
  menu label: "报销单分配", priority: 5
  
  # 权限控制
  actions :index, :show, :new, :create, :update
  
  # 过滤器
  filter :reimbursement_invoice_number, as: :string, label: "发票号"
  filter :assignee, label: "被分配人"
  filter :assigner, label: "分配人"
  filter :is_active, as: :boolean, label: "是否活跃"
  filter :created_at, label: "分配时间"
  
  # 列表页
  index do
    selectable_column
    id_column
    column :reimbursement do |assignment|
      link_to assignment.reimbursement.invoice_number, admin_reimbursement_path(assignment.reimbursement)
    end
    column :assignee
    column :assigner
    column :is_active do |assignment|
      status_tag assignment.is_active? ? "活跃" : "已取消", class: assignment.is_active? ? "green" : "red"
    end
    column :created_at
    actions
  end
  
  # 详情页
  show do
    attributes_table do
      row :id
      row :reimbursement do |assignment|
        link_to assignment.reimbursement.invoice_number, admin_reimbursement_path(assignment.reimbursement)
      end
      row :assignee
      row :assigner
      row :is_active do |assignment|
        status_tag assignment.is_active? ? "活跃" : "已取消", class: assignment.is_active? ? "green" : "red"
      end
      row :notes
      row :created_at
      row :updated_at
    end
  end
  
  # 表单
  form do |f|
    f.inputs "报销单分配" do
      f.input :reimbursement, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }
      f.input :assignee, collection: AdminUser.all
      f.input :is_active
      f.input :notes
    end
    f.actions
  end
  
  # 批量操作
  batch_action :assign_to, form: -> {
    {
      assignee: AdminUser.all.map { |u| [u.email, u.id] },
      notes: :text
    }
  } do |ids, inputs|
    service = ReimbursementAssignmentService.new(current_admin_user)
    reimbursement_ids = ReimbursementAssignment.where(id: ids).pluck(:reimbursement_id)
    
    results = service.batch_assign(reimbursement_ids, inputs[:assignee], inputs[:notes])
    
    redirect_to collection_path, notice: "成功分配 #{results.size} 个报销单"
  end
  
  # 控制器自定义
  controller do
    def create
      service = ReimbursementAssignmentService.new(current_admin_user)
      @reimbursement_assignment = service.assign(
        params[:reimbursement_assignment][:reimbursement_id],
        params[:reimbursement_assignment][:assignee_id],
        params[:reimbursement_assignment][:notes]
      )
      
      if @reimbursement_assignment.persisted?
        redirect_to admin_reimbursement_assignment_path(@reimbursement_assignment), notice: "报销单分配成功"
      else
        render :new
      end
    end
    
    def update
      @reimbursement_assignment = ReimbursementAssignment.find(params[:id])
      
      if @reimbursement_assignment.update(permitted_params[:reimbursement_assignment])
        redirect_to admin_reimbursement_assignment_path(@reimbursement_assignment), notice: "报销单分配更新成功"
      else
        render :edit
      end
    end
  end
end
```

### 5.2 报销单列表页更新

```ruby
# app/admin/reimbursements.rb
ActiveAdmin.register Reimbursement do
  # 现有代码...
  
  # 添加分配相关的列
  index do
    # 现有列...
    column :current_assignee do |reimbursement|
      reimbursement.current_assignee&.email || "未分配"
    end
    # 其他列...
  end
  
  # 添加分配相关的过滤器
  filter :current_assignee_id, as: :select, collection: -> { AdminUser.all.map { |u| [u.email, u.id] } }, label: "当前处理人"
  
  # 添加分配相关的批量操作
  batch_action :assign_to, form: -> {
    {
      assignee: AdminUser.all.map { |u| [u.email, u.id] },
      notes: :text
    }
  } do |ids, inputs|
    service = ReimbursementAssignmentService.new(current_admin_user)
    results = service.batch_assign(ids, inputs[:assignee], inputs[:notes])
    
    redirect_to collection_path, notice: "成功分配 #{results.size} 个报销单"
  end
  
  # 添加分配相关的成员操作
  member_action :assign, method: :post do
    service = ReimbursementAssignmentService.new(current_admin_user)
    assignment = service.assign(resource.id, params[:assignee_id], params[:notes])
    
    if assignment
      redirect_to admin_reimbursement_path(resource), notice: "报销单已分配给 #{assignment.assignee.email}"
    else
      redirect_to admin_reimbursement_path(resource), alert: "报销单分配失败"
    end
  end
  
  # 添加分配相关的详情页面板
  show do
    # 现有面板...
    
    panel "分配历史" do
      table_for resource.assignments.recent_first do
        column :id do |assignment|
          link_to assignment.id, admin_reimbursement_assignment_path(assignment)
        end
        column :assignee
        column :assigner
        column :is_active do |assignment|
          status_tag assignment.is_active? ? "活跃" : "已取消", class: assignment.is_active? ? "green" : "red"
        end
        column :created_at
        column :notes
      end
      
      if resource.current_assignee.nil?
        div class: 'panel_contents' do
          render partial: 'assign_form', locals: { reimbursement: resource }
        end
      else
        div class: 'panel_contents' do
          para "当前处理人: #{resource.current_assignee.email}"
          render partial: 'transfer_form', locals: { reimbursement: resource }
        end
      end
    end
  end
  
  # 自定义控制器
  controller do
    # 添加我的报销单和所有报销单视图
    def scoped_collection
      if params[:scope] == 'my_assignments'
        Reimbursement.joins(:active_assignment)
                    .where(reimbursement_assignments: { assignee_id: current_admin_user.id })
      else
        super
      end
    end
  end
  
  # 添加自定义范围
  scope :all, default: true
  scope :my_assignments, label: "分配给我的"
  scope :unassigned, label: "未分配的" do |reimbursements|
    reimbursements.left_joins(:active_assignment)
                 .where(reimbursement_assignments: { id: nil })
  end
end
```

### 5.3 分配表单模板

```erb
<!-- app/views/admin/reimbursements/_assign_form.html.erb -->
<%= form_tag assign_admin_reimbursement_path(reimbursement), method: :post do %>
  <div class="field">
    <%= label_tag :assignee_id, "分配给" %>
    <%= select_tag :assignee_id, options_from_collection_for_select(AdminUser.all, :id, :email) %>
  </div>
  
  <div class="field">
    <%= label_tag :notes, "备注" %>
    <%= text_area_tag :notes, nil, rows: 3 %>
  </div>
  
  <div class="actions">
    <%= submit_tag "分配", class: "button" %>
  </div>
<% end %>
```

```erb
<!-- app/views/admin/reimbursements/_transfer_form.html.erb -->
<%= form_tag assign_admin_reimbursement_path(reimbursement), method: :post do %>
  <div class="field">
    <%= label_tag :assignee_id, "转移给" %>
    <%= select_tag :assignee_id, options_from_collection_for_select(AdminUser.where.not(id: reimbursement.current_assignee.id), :id, :email) %>
  </div>
  
  <div class="field">
    <%= label_tag :notes, "备注" %>
    <%= text_area_tag :notes, nil, rows: 3 %>
  </div>
  
  <div class="actions">
    <%= submit_tag "转移", class: "button" %>
  </div>
<% end %>
```

### 5.4 仪表盘更新

```ruby
# app/admin/dashboard.rb
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "我的报销单" do
          table_for Reimbursement.joins(:active_assignment)
                              .where(reimbursement_assignments: { assignee_id: current_admin_user.id })
                              .order(created_at: :desc)
                              .limit(10) do
            column :invoice_number do |reimbursement|
              link_to reimbursement.invoice_number, admin_reimbursement_path(reimbursement)
            end
            column :status do |reimbursement|
              status_tag reimbursement.status
            end
            column :created_at
          end
          div do
            link_to "查看所有我的报销单", admin_reimbursements_path(scope: 'my_assignments')
          end
        end
      end
      
      column do
        panel "未分配的报销单" do
          table_for Reimbursement.left_joins(:active_assignment)
                              .where(reimbursement_assignments: { id: nil })
                              .order(created_at: :desc)
                              .limit(10) do
            column :invoice_number do |reimbursement|
              link_to reimbursement.invoice_number, admin_reimbursement_path(reimbursement)
            end
            column :status do |reimbursement|
              status_tag reimbursement.status
            end
            column :created_at
          end
          div do
            link_to "查看所有未分配的报销单", admin_reimbursements_path(scope: 'unassigned')
          end
        end
      end
    end
    
    columns do
      column do
        panel "工作量统计" do
          table_for AdminUser.all do
            column :email
            column "分配的报销单数量" do |admin_user|
              ReimbursementAssignment.active.where(assignee_id: admin_user.id).count
            end
            column "已处理的报销单数量" do |admin_user|
              Reimbursement.joins(:active_assignment)
                          .where(reimbursement_assignments: { assignee_id: admin_user.id })
                          .where(status: 'closed')
                          .count
            end
          end
        end
      end
    end
  end
end
```

## 6. 实现计划

### 6.1 阶段一：数据库结构调整（1天）

1. **创建迁移脚本**（0.5天）
   - 创建 `reimbursement_assignments` 表
   - 添加必要的字段和索引

2. **执行迁移**（0.5天）
   - 运行迁移脚本
   - 验证表结构正确性

### 6.2 阶段二：模型和服务实现（2天）

1. **实现 `ReimbursementAssignment` 模型**（0.5天）
   - 添加关联、验证和作用域
   - 实现回调方法

2. **实现 `ReimbursementAssignmentService`**（1天）
   - 实现分配、取消分配、转移分配等方法
   - 实现批量分配功能

3. **实现 `ReimbursementQueryService`**（0.5天）
   - 实现各种查询方法
   - 实现过滤和排序功能

### 6.3 阶段三：UI实现（2天）

1. **ActiveAdmin 配置**（1天）
   - 创建 `reimbursement_assignments.rb` 文件
   - 更新 `reimbursements.rb` 文件
   - 更新 `dashboard.rb` 文件

2. **表单和视图模板**（0.5天）
   - 创建分配表单模板
   - 创建转移表单模板

3. **批量操作和范围**（0.5天）
   - 实现批量分配功能
   - 实现自定义范围（我的报销单、未分配的报销单）

### 6.4 阶段四：测试与优化（1天）

1. **单元测试**（0.5天）
   - 为 `ReimbursementAssignment` 模型编写测试
   - 为 `ReimbursementAssignmentService` 编写测试
   - 为 `ReimbursementQueryService` 编写测试

2. **集成测试**（0.5天）
   - 编写端到端测试，验证完整功能
   - 测试边缘情况和错误处理

## 7. 总结

报销单分配功能将支持多个财务审核人员协同工作，允许管理员将报销单分配给不同的员工，每个员工可以查看和处理自己分配到的报销单，同时也能查看和处理全部报销单。这将提高工作效率，明确责任归属，并支持团队协作。

实现这一功能需要添加新的数据模型、服务和UI组件，但不需要修改现有的核心业务逻辑。建议按照实施计划分阶段实施，优先实现核心功能，并注意性能和用户体验。