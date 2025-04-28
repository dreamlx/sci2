# SCI2 工单系统ActiveAdmin集成更新 (STI 版本)

## 1. 主要变更概述

根据新需求，需要对ActiveAdmin集成进行以下主要更新：

1. **单表继承模型**：确认使用单表继承(STI)模型实现工单类型
2. **工单关联关系**：移除工单之间的直接关联，所有工单类型直接关联到报销单
3. **共享表单字段**：审核工单和沟通工单表单结构基本相同
4. **工单状态流转**：更新状态流转逻辑
5. **费用明细验证**：统一验证状态流转

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

### 2.2 快递收单工单资源 (ExpressReceiptWorkOrder)

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
end
```

### 2.3 审核工单资源 (AuditWorkOrder)

```ruby
# app/admin/audit_work_orders.rb 更新要点
ActiveAdmin.register AuditWorkOrder do
  # 添加共享字段
  permit_params :reimbursement_id, ...,
                :problem_type, :problem_description, :remark, :processing_opinion,
                fee_detail_ids: []
  
  # 添加共享字段过滤器
  filter :problem_type, as: :select, collection: ProblemTypeOptions.all
  
  # 显示共享字段
  index do
    # ...
    column :problem_type
    column :problem_description
    # ...
  end
  
  # 详情页显示共享字段
  show do
    attributes_table do
      # ...
      row :problem_type
      row :problem_description
      row :remark
      row :processing_opinion
      # ...
    end
  end
  
  # 表单使用partial，包含共享字段
  form partial: 'form'
end
```

### 2.4 沟通工单资源 (CommunicationWorkOrder)

```ruby
# app/admin/communication_work_orders.rb 更新要点
ActiveAdmin.register CommunicationWorkOrder do
  # 移除与审核工单的关联
  permit_params :reimbursement_id, :status, ...,
                :problem_type, :problem_description, :remark, :processing_opinion,
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
  
  # 移除审核工单过滤器
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :problem_type, as: :select, collection: ProblemTypeOptions.all
  # 移除filter :audit_work_order_id
  
  # 更新索引页，移除审核工单列
  index do
    # ...
    # 移除column :audit_work_order
    column :problem_type
    column :problem_description
    # ...
  end
  
  # 更新详情页，移除审核工单关联
  show do
    attributes_table do
      # ...
      # 移除row :audit_work_order
      row :problem_type
      row :problem_description
      row :remark
      row :processing_opinion
      # ...
    end
  end
  
  # 表单使用partial，包含共享字段，移除审核工单选择
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
    
    <!-- 状态 -->
    <%= f.input :status, as: :select, collection: AuditWorkOrder.state_machines[:status].states.map(&:value), include_blank: false %>
    
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
    
    <!-- 移除审核工单关联 -->
    
    <!-- 状态 -->
    <%= f.input :status, as: :select, collection: CommunicationWorkOrder.state_machines[:status].states.map(&:value), include_blank: false %>
    
    <!-- 沟通工单特有字段 -->
    <%= f.input :communication_method, as: :select, collection: CommunicationMethodOptions.all %>
    <%= f.input :initiator_role, as: :select, collection: InitiatorRoleOptions.all %>
    
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
```

## 5. 实施建议

1. **数据库迁移**：
   - 确保WorkOrder表包含所有共享字段
   - 移除CommunicationWorkOrder表中的audit_work_order_id字段

2. **模型更新**：
   - 更新WorkOrder基类，添加共享字段
   - 移除CommunicationWorkOrder与AuditWorkOrder的关联

3. **服务层更新**：
   - 更新工单处理服务，处理共享字段
   - 更新状态流转逻辑

4. **UI更新**：
   - 更新表单模板，包含共享字段
   - 更新详情页，显示共享字段
   - 移除工单间关联的显示

5. **测试**：
   - 测试工单创建和编辑功能
   - 测试状态流转逻辑
   - 测试费用明细验证状态更新