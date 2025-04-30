# SCI2 工单系统ActiveAdmin集成更新 (STI 版本 - v3.0)

## 1. 主要变更概述

根据新需求，需要对ActiveAdmin集成进行以下主要更新：

1. **单表继承模型**：确认使用单表继承(STI)模型实现工单类型
2. **工单关联关系**：移除工单之间的直接关联，所有工单类型直接关联到报销单
3. **共享表单字段**：审核工单和沟通工单表单结构基本相同
4. **工单状态流转**：更新状态流转逻辑，状态由系统自动管理，不允许用户直接编辑
5. **费用明细验证**：统一验证状态流转
6. **沟通工单需要沟通标志**：实现为布尔字段，而非状态值
7. **处理意见与状态关系**：明确定义处理意见如何影响工单状态
8. **操作历史只读**：操作历史记录只能通过导入获取，不能在UI中添加、编辑或删除

## 2. 资源注册更新

### 2.1 报销单资源 (Reimbursement)

```ruby
# app/admin/reimbursements.rb 更新要点
ActiveAdmin.register Reimbursement do
  # 添加电子发票标志字段
  permit_params :invoice_number, ..., :is_electronic, ...
  
  # 添加电子发票过滤器
  filter :is_electronic, as: :boolean
  
  # 更新状态显示，包含"等待完成"状态
  filter :status, label: "内部状态", as: :select, 
         collection: Reimbursement.state_machines[:status].states.map(&:value)
  
  # 显示电子发票标志
  index do
    # ...
    column :is_electronic
    # ...
  end
  
  # 表单中添加电子发票选项
  form do |f|
    f.inputs "报销单信息" do
      # ...
      f.input :is_electronic
      # ...
    end
  end
end
```

### 2.2 操作历史资源 (OperationHistory)

```ruby
# app/admin/operation_histories.rb 更新要点
ActiveAdmin.register OperationHistory do
  # 设置为只读资源，只允许查看和导入，不允许创建、编辑和删除
  actions :index, :show
  
  # 添加导入功能
  action_item :import, only: :index do
    link_to '导入操作历史', new_admin_operation_history_import_path
  end
  
  # 过滤器
  filter :document_number
  filter :operation_type
  filter :operator
  filter :operation_time
  
  # 列表页
  index do
    column :document_number
    column :operation_type
    column :operation_time
    column :operator
    column :notes
    actions defaults: false do |operation_history|
      item "查看", admin_operation_history_path(operation_history)
    end
  end
  
  # 详情页
  show do
    attributes_table do
      row :document_number
      row :operation_type
      row :operation_time
      row :operator
      row :notes
      row :created_at
      row :updated_at
    end
  end
end
```

### 2.3 快递收单工单资源 (ExpressReceiptWorkOrder)

```ruby
# app/admin/express_receipt_work_orders.rb 更新要点
ActiveAdmin.register ExpressReceiptWorkOrder do
  # 状态固定为completed，无需状态流转操作
  # 表单中无需显示状态选择
  form do |f|
    f.inputs "快递收单工单信息" do
      # ...
      # 无需状态字段，导入时自动设为completed
    end
  end
  
  # 显示状态但不允许编辑
  show do
    attributes_table do
      row :reimbursement
      row :status
      row :tracking_number
      row :received_at
      row :courier_name
      row :created_by
      row :created_at
      row :updated_at
    end
  end
end
```

### 2.4 审核工单资源 (AuditWorkOrder)

```ruby
# app/admin/audit_work_orders.rb 更新要点
ActiveAdmin.register AuditWorkOrder do
  # 添加共享字段，移除status从permit_params中
  permit_params :reimbursement_id, 
                :problem_type, :problem_description, :remark, :processing_opinion,
                :audit_comment, :vat_verified,
                fee_detail_ids: []
  
  # 添加共享字段过滤器
  filter :problem_type, as: :select, collection: ProblemTypeOptions.all
  
  # 显示共享字段
  index do
    # ...
    column :status # 只显示，不允许编辑
    column :problem_type
    column :problem_description
    # ...
  end
  
  # 详情页显示共享字段和状态操作按钮
  show do
    attributes_table do
      # ...
      row :status # 只显示，不允许编辑
      row :problem_type
      row :problem_description
      row :remark
      row :processing_opinion
      # ...
    end
    
    # 根据当前状态显示可用的操作按钮
    panel "操作" do
      if resource.pending?
        span do
          button_to "开始处理", start_processing_admin_audit_work_order_path(resource), method: :post, class: "button"
          button_to "审核通过", approve_admin_audit_work_order_path(resource), method: :post, class: "button"
        end
      elsif resource.processing?
        span do
          button_to "审核通过", approve_admin_audit_work_order_path(resource), method: :post, class: "button"
          button_to "审核拒绝", reject_admin_audit_work_order_path(resource), method: :post, class: "button"
        end
      end
    end
  end
  
  # 表单使用partial，包含共享字段，但不包含状态选择
  form partial: 'form'
  
  # 添加状态操作的成员操作
  member_action :start_processing, method: :post do
    @work_order = AuditWorkOrder.find(params[:id])
    service = AuditWorkOrderService.new(@work_order, current_admin_user)
    
    if service.start_processing
      redirect_to admin_audit_work_order_path(@work_order), notice: "已开始处理"
    else
      redirect_to admin_audit_work_order_path(@work_order), alert: "无法开始处理: #{@work_order.errors.full_messages.join(', ')}"
    end
  end
  
  member_action :approve, method: :post do
    @work_order = AuditWorkOrder.find(params[:id])
    service = AuditWorkOrderService.new(@work_order, current_admin_user)
    
    if service.approve
      redirect_to admin_audit_work_order_path(@work_order), notice: "审核已通过"
    else
      redirect_to admin_audit_work_order_path(@work_order), alert: "无法批准: #{@work_order.errors.full_messages.join(', ')}"
    end
  end
  
  member_action :reject, method: :post do
    @work_order = AuditWorkOrder.find(params[:id])
    service = AuditWorkOrderService.new(@work_order, current_admin_user)
    
    if service.reject
      redirect_to admin_audit_work_order_path(@work_order), notice: "审核已拒绝"
    else
      redirect_to admin_audit_work_order_path(@work_order), alert: "无法拒绝: #{@work_order.errors.full_messages.join(', ')}"
    end
  end
end
```

### 2.5 沟通工单资源 (CommunicationWorkOrder)

```ruby
# app/admin/communication_work_orders.rb 更新要点
ActiveAdmin.register CommunicationWorkOrder do
  # 移除与审核工单的关联，添加needs_communication布尔字段，移除status从permit_params中
  permit_params :reimbursement_id,
                :problem_type, :problem_description, :remark, :processing_opinion,
                :needs_communication, :communication_method, :initiator_role, :resolution_summary,
                fee_detail_ids: []
  
  # 移除审核工单关联的控制器代码
  controller do
    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      # 移除设置audit_work_order_id的代码
      resource
    end
  end
  
  # 移除审核工单过滤器，添加needs_communication过滤器
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :problem_type, as: :select, collection: ProblemTypeOptions.all
  filter :needs_communication, as: :boolean, label: '需要沟通'
  # 移除filter :audit_work_order_id
  
  # 更新索引页，移除审核工单列，添加needs_communication列
  index do
    # ...
    column :status # 只显示，不允许编辑
    # 移除column :audit_work_order
    column :problem_type
    column :problem_description
    column :needs_communication
    # ...
  end
  
  # 更新详情页，移除审核工单关联，添加needs_communication显示和切换按钮，添加状态操作按钮
  show do
    attributes_table do
      # ...
      row :status # 只显示，不允许编辑
      # 移除row :audit_work_order
      row :problem_type
      row :problem_description
      row :remark
      row :processing_opinion
      row :needs_communication
      # ...
    end
    
    panel "操作" do
      # 需要沟通标志切换按钮
      if resource.needs_communication
        button_to "取消需要沟通标记", toggle_needs_communication_admin_communication_work_order_path, method: :post, class: "button"
      else
        button_to "标记为需要沟通", toggle_needs_communication_admin_communication_work_order_path, method: :post, class: "button"
      end
      
      # 状态操作按钮
      if resource.pending?
        span do
          button_to "开始处理", start_processing_admin_communication_work_order_path(resource), method: :post, class: "button"
          button_to "沟通后通过", approve_admin_communication_work_order_path(resource), method: :post, class: "button"
        end
      elsif resource.processing?
        span do
          button_to "沟通后通过", approve_admin_communication_work_order_path(resource), method: :post, class: "button"
          button_to "沟通后拒绝", reject_admin_communication_work_order_path(resource), method: :post, class: "button"
        end
      end
    end
  end
  
  # 添加切换needs_communication的成员操作
  member_action :toggle_needs_communication, method: :post do
    @work_order = CommunicationWorkOrder.find(params[:id])
    service = CommunicationWorkOrderService.new(@work_order, current_admin_user)
    
    if service.toggle_needs_communication
      redirect_to admin_communication_work_order_path(@work_order), 
        notice: @work_order.needs_communication? ? "已标记为需要沟通" : "已取消需要沟通标记"
    else
      redirect_to admin_communication_work_order_path(@work_order), 
        alert: "无法更新沟通标志: #{@work_order.errors.full_messages.join(', ')}"
    end
  end
  
  # 添加状态操作的成员操作
  member_action :start_processing, method: :post do
    @work_order = CommunicationWorkOrder.find(params[:id])
    service = CommunicationWorkOrderService.new(@work_order, current_admin_user)
    
    if service.start_processing
      redirect_to admin_communication_work_order_path(@work_order), notice: "已开始处理"
    else
      redirect_to admin_communication_work_order_path(@work_order), alert: "无法开始处理: #{@work_order.errors.full_messages.join(', ')}"
    end
  end
  
  member_action :approve, method: :post do
    @work_order = CommunicationWorkOrder.find(params[:id])
    service = CommunicationWorkOrderService.new(@work_order, current_admin_user)
    
    if service.approve
      redirect_to admin_communication_work_order_path(@work_order), notice: "沟通后已通过"
    else
      redirect_to admin_communication_work_order_path(@work_order), alert: "无法批准: #{@work_order.errors.full_messages.join(', ')}"
    end
  end
  
  member_action :reject, method: :post do
    @work_order = CommunicationWorkOrder.find(params[:id])
    service = CommunicationWorkOrderService.new(@work_order, current_admin_user)
    
    if service.reject
      redirect_to admin_communication_work_order_path(@work_order), notice: "沟通后已拒绝"
    else
      redirect_to admin_communication_work_order_path(@work_order), alert: "无法拒绝: #{@work_order.errors.full_messages.join(', ')}"
    end
  end
  
  # 表单使用partial，包含共享字段，移除审核工单选择，添加needs_communication复选框，但不包含状态选择
  form partial: 'form'
end
```

## 3. 自定义视图更新

### 3.1 审核工单表单模板

```erb
<!-- app/views/admin/audit_work_orders/_form.html.erb -->
<%= semantic_form_for [:admin, @audit_work_order] do |f| %>
  <%= f.inputs "基本信息" do %>
    <!-- 报销单选择 -->
    <% if f.object.new_record? && params[:reimbursement_id] %>
      <%= f.input :reimbursement_id, as: :hidden, input_html: { value: params[:reimbursement_id] } %>
      <li class="string input optional">
        <label class="label">报销单</label>
        <%= link_to f.object.reimbursement&.invoice_number, admin_reimbursement_path(f.object.reimbursement) %>
      </li>
    <% else %>
      <%= f.input :reimbursement_id, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }, input_html: { disabled: !f.object.new_record? } %>
    <% end %>
    
    <!-- 状态只显示，不允许编辑 -->
    <% unless f.object.new_record? %>
      <li class="string input optional">
        <label class="label">状态</label>
        <span><%= f.object.status %></span>
      </li>
    <% end %>
    
    <!-- 共享字段 -->
    <%= f.input :problem_type, as: :select, collection: ProblemTypeOptions.all, include_blank: '无' %>
    <%= f.input :problem_description, as: :select, collection: ProblemDescriptionOptions.all, include_blank: '无' %>
    <%= f.input :remark, as: :text, input_html: { rows: 3 } %>
    <%= f.input :processing_opinion, as: :select, collection: ProcessingOpinionOptions.all, include_blank: '无' %>
    
    <!-- 审核工单特有字段 -->
    <%= f.input :audit_comment, as: :text, input_html: { rows: 3 } %>
    <%= f.input :vat_verified %>
  <% end %>
  
  <!-- 费用明细选择 -->
  <%= f.inputs "选择费用明细" do %>
    <%= f.input :fee_detail_ids, as: :check_boxes, collection: f.object.reimbursement&.fee_details&.map { |fd| ["##{fd.id} #{fd.fee_type} (#{number_to_currency(fd.amount)}) - #{fd.verification_status}", fd.id] } || [], label: false %>
  <% end %>
  
  <%= f.actions %>
<% end %>
```

### 3.2 沟通工单表单模板

```erb
<!-- app/views/admin/communication_work_orders/_form.html.erb -->
<%= semantic_form_for [:admin, @communication_work_order] do |f| %>
  <%= f.inputs "基本信息" do %>
    <!-- 报销单选择 -->
    <% if f.object.new_record? && params[:reimbursement_id] %>
      <%= f.input :reimbursement_id, as: :hidden, input_html: { value: params[:reimbursement_id] } %>
      <li class="string input optional">
        <label class="label">报销单</label>
        <%= link_to f.object.reimbursement&.invoice_number, admin_reimbursement_path(f.object.reimbursement) %>
      </li>
    <% else %>
      <%= f.input :reimbursement_id, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }, input_html: { disabled: !f.object.new_record? } %>
    <% end %>
    
    <!-- 状态只显示，不允许编辑 -->
    <% unless f.object.new_record? %>
      <li class="string input optional">
        <label class="label">状态</label>
        <span><%= f.object.status %></span>
      </li>
    <% end %>
    
    <!-- 沟通工单特有字段 -->
    <%= f.input :communication_method, as: :select, collection: CommunicationMethodOptions.all %>
    <%= f.input :initiator_role, as: :select, collection: InitiatorRoleOptions.all %>
    <%= f.input :needs_communication, as: :boolean, label: '需要沟通' %>
    
    <!-- 共享字段 -->
    <%= f.input :problem_type, as: :select, collection: ProblemTypeOptions.all, include_blank: '无' %>
    <%= f.input :problem_description, as: :select, collection: ProblemDescriptionOptions.all, include_blank: '无' %>
    <%= f.input :remark, as: :text, input_html: { rows: 3 } %>
    <%= f.input :processing_opinion, as: :select, collection: ProcessingOpinionOptions.all, include_blank: '无' %>
    
    <%= f.input :resolution_summary, as: :text, input_html: { rows: 3 } %>
  <% end %>
  
  <!-- 费用明细选择 -->
  <%= f.inputs "选择费用明细" do %>
    <%= f.input :fee_detail_ids, as: :check_boxes, collection: f.object.reimbursement&.fee_details&.map { |fd| ["##{fd.id} #{fd.fee_type} (#{number_to_currency(fd.amount)}) - #{fd.verification_status}", fd.id] } || [], label: false %>
  <% end %>
  
  <%= f.actions %>
<% end %>
```

### 3.3 操作历史导入页面

```erb
<!-- app/views/admin/operation_history_imports/new.html.erb -->
<h2>导入操作历史</h2>

<%= semantic_form_for :import, url: admin_operation_history_imports_path, html: { multipart: true } do |f| %>
  <%= f.inputs "导入选项" do %>
    <%= f.input :file, as: :file, label: "CSV文件", hint: "请选择CSV格式的操作历史文件" %>
  <% end %>
  
  <%= f.actions do %>
    <%= f.action :submit, label: "导入" %>
    <%= f.action :cancel, label: "取消", as: :link, url: admin_operation_histories_path %>
  <% end %>
<% end %>
```

## 4. 下拉列表选项配置

为支持共享字段的下拉列表选项，需要创建以下配置类：

```ruby
# app/models/problem_type_options.rb
class ProblemTypeOptions
  def self.all
    [
      "发票问题",
      "金额错误",
      "费用类型错误",
      "缺少附件",
      "其他问题"
    ]
  end
end

# app/models/problem_description_options.rb
class ProblemDescriptionOptions
  def self.all
    [
      "发票信息不完整",
      "发票金额与申报金额不符",
      "费用类型选择错误",
      "缺少必要证明材料",
      "其他问题说明"
    ]
  end
end

# app/models/processing_opinion_options.rb
class ProcessingOpinionOptions
  def self.all
    [
      "需要补充材料",
      "需要修改申报信息",
      "需要重新提交",
      "可以通过",
      "无法通过"
    ]
  end
end

# app/models/communication_method_options.rb
class CommunicationMethodOptions
  def self.all
    [
      "电话",
      "邮件",
      "微信",
      "当面沟通",
      "其他方式"
    ]
  end
end

# app/models/initiator_role_options.rb
class InitiatorRoleOptions
  def self.all
    [
      "财务人员",
      "审核人员",
      "申请人",
      "部门主管",
      "其他角色"
    ]
  end
end
```

## 5. 实施建议

1. **数据库迁移**：
   - 确保WorkOrder表包含所有共享字段
   - 移除CommunicationWorkOrder表中的audit_work_order_id字段
   - 添加needs_communication布尔字段，默认为false

2. **模型更新**：
   - 更新WorkOrder基类，添加共享字段
   - 移除CommunicationWorkOrder与AuditWorkOrder的关联
   - 在CommunicationWorkOrder中添加needs_communication布尔字段的处理方法

3. **服务层更新**：
   - 更新工单处理服务，处理共享字段
   - 更新状态流转逻辑，支持直接通过路径
   - 添加toggle_needs_communication方法，处理布尔标志

4. **UI更新**：
   - 更新表单模板，包含共享字段，但不允许直接编辑状态
   - 更新详情页，显示共享字段和状态操作按钮
   - 移除工单间关联的显示
   - 添加needs_communication布尔标志的UI控件
   - 设置操作历史为只读资源，只允许导入

5. **测试**：
   - 测试工单创建和编辑功能
   - 测试状态流转逻辑，特别是直接通过路径
   - 测试费用明细验证状态更新
   - 测试needs_communication布尔标志的设置和取消
   - 测试操作历史的只读性和导入功能

## 6. 主要更新内容

1. **沟通工单的needs_communication实现**:
   - 将needs_communication实现为布尔字段，而非状态值
   - 添加toggle_needs_communication成员操作
   - 在表单中添加needs_communication复选框
   - 在详情页添加切换按钮

2. **处理意见与状态关系**:
   - 移除表单中的状态直接编辑
   - 添加状态操作按钮（开始处理、审核通过、审核拒绝等）
   - 在控制器中添加处理逻辑，确保状态正确设置

3. **直接通过路径**:
   - 确保表单和控制器支持从pending直接到approved的转换
   - 通过状态操作按钮实现直接通过

4. **工单关联关系**:
   - 移除沟通工单与审核工单的关联
   - 确保所有工单类型直接关联到报销单

5. **操作历史只读**:
   - 设置操作历史资源为只读，只允许查看和导入
   - 移除创建、编辑和删除操作
   - 添加专门的导入页面和功能