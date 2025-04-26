# SCI功能迁移任务拆分

## 目录

- [概述](#概述)
- [审核流程任务](#审核流程任务)
- [问题管理任务](#问题管理任务)
- [测试任务](#测试任务)
- [任务优先级和依赖关系](#任务优先级和依赖关系)
- [任务分配建议](#任务分配建议)

## 概述

本文档将SCI审核流程和问题管理迁移计划拆分为具体的开发任务，以便团队进入编码阶段。每个任务都包含明确的目标、具体步骤和预计完成时间。

## 审核流程任务

### 任务A1：工单模型审核字段扩展

**目标**：扩展WorkOrder模型，添加审核相关字段

**步骤**：
1. 创建数据库迁移文件，添加以下字段：
   - `audit_result` (string)：审核结果
   - `audit_date` (datetime)：审核日期
   - `audit_comment` (text)：审核意见
   - `vat_verified` (boolean)：VAT验证状态

**预计时间**：0.5天

**技术要点**：
```ruby
# 创建迁移文件
rails generate migration AddAuditFieldsToWorkOrders audit_result:string audit_date:datetime audit_comment:text vat_verified:boolean

# 编辑迁移文件，添加默认值
def change
  add_column :work_orders, :audit_result, :string
  add_column :work_orders, :audit_date, :datetime
  add_column :work_orders, :audit_comment, :text
  add_column :work_orders, :vat_verified, :boolean, default: false
end
```

### 任务A2：费用明细VAT字段扩展

**目标**：扩展FeeDetail模型，添加VAT相关字段

**步骤**：
1. 创建数据库迁移文件，添加以下字段：
   - `tax_code` (string)：税码
   - `tax_amount` (decimal)：税额
   - `deduct_tax_amount` (decimal)：可抵扣税额

**预计时间**：0.5天

**技术要点**：
```ruby
# 创建迁移文件
rails generate migration AddVatFieldsToFeeDetails tax_code:string tax_amount:decimal deduct_tax_amount:decimal

# 编辑迁移文件，设置精度
def change
  add_column :fee_details, :tax_code, :string
  add_column :fee_details, :tax_amount, :decimal, precision: 10, scale: 2
  add_column :fee_details, :deduct_tax_amount, :decimal, precision: 10, scale: 2
end
```

### 任务A3：工单状态机扩展

**目标**：扩展WorkOrder模型的状态机，添加审核相关状态和转换

**步骤**：
1. 更新WorkOrder模型中的状态机定义
2. 添加审核相关状态：auditing, approved, rejected
3. 添加状态转换方法

**预计时间**：1天

**技术要点**：
```ruby
# 在WorkOrder模型中
state_machine :status, initial: :pending do
  # 现有状态转换...
  
  # 添加审核相关状态转换
  event :start_audit do
    transition processing: :auditing
  end
  
  event :approve_audit do
    transition auditing: :approved
  end
  
  event :reject_audit do
    transition auditing: :rejected
  end
  
  event :revert_audit do
    transition [:approved, :rejected] => :auditing
  end
end
```

### 任务A4：工单审核控制器方法

**目标**：在WorkOrdersController中添加审核相关方法

**步骤**：
1. 添加audit方法，显示审核表单
2. 添加update_audit方法，处理审核表单提交
3. 添加revert_audit方法，处理审核撤销

**预计时间**：1天

**技术要点**：
```ruby
# 在WorkOrdersController中
def audit
  @work_order = WorkOrder.find(params[:id])
end

def update_audit
  @work_order = WorkOrder.find(params[:id])
  
  if @work_order.update(audit_params)
    # 根据审核结果更新状态
    if params[:work_order][:audit_result] == 'approved'
      @work_order.approve_audit
    elsif params[:work_order][:audit_result] == 'rejected'
      @work_order.reject_audit
    end
    
    redirect_to @work_order, notice: '审核已完成'
  else
    render :audit
  end
end

def revert_audit
  @work_order = WorkOrder.find(params[:id])
  @work_order.update(audit_result: nil, audit_date: nil)
  @work_order.revert_audit
  
  redirect_to @work_order, notice: '审核已撤销'
end

private

def audit_params
  params.require(:work_order).permit(:audit_result, :audit_date, :audit_comment, :vat_verified)
end
```

### 任务A5：工单审核视图

**目标**：创建工单审核相关视图

**步骤**：
1. 创建audit.html.erb视图，显示审核表单
2. 更新工单详情页面，显示审核信息
3. 添加审核和撤销审核按钮

**预计时间**：1天

**技术要点**：
```erb
<!-- app/views/work_orders/audit.html.erb -->
<h1>审核工单 #<%= @work_order.order_number %></h1>

<%= form_with(model: @work_order, url: update_audit_work_order_path(@work_order), method: :patch) do |form| %>
  <div class="field">
    <%= form.label :audit_result, "审核结果" %>
    <%= form.select :audit_result, [["通过", "approved"], ["不通过", "rejected"]] %>
  </div>

  <div class="field">
    <%= form.label :audit_date, "审核日期" %>
    <%= form.date_field :audit_date, value: Date.today %>
  </div>

  <div class="field">
    <%= form.label :audit_comment, "审核意见" %>
    <%= form.text_area :audit_comment %>
  </div>

  <div class="field">
    <%= form.label :vat_verified, "VAT已验证" %>
    <%= form.check_box :vat_verified %>
  </div>

  <div class="actions">
    <%= form.submit "提交审核" %>
  </div>
<% end %>
```

### 任务A6：路由更新

**目标**：更新路由配置，添加审核相关路由

**步骤**：
1. 在routes.rb中添加审核相关路由

**预计时间**：0.5天

**技术要点**：
```ruby
# 在config/routes.rb中
resources :work_orders do
  member do
    get :audit
    patch :update_audit
    get :revert_audit
  end
end
```

### 任务A7：工单模型单表继承实现

**目标**：实现工单模型的单表继承(STI)，优化不同类型工单的处理

**步骤**：
1. 添加type列到work_orders表
2. 创建工单子类（AuditWorkOrder, CommunicationWorkOrder, ExpressReceiptWorkOrder）
3. 将类型特定的行为和验证移至相应的子类
4. 更新控制器和视图以使用子类

**预计时间**：2天

**技术要点**：
```ruby
# 创建迁移文件
class AddTypeToWorkOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :work_orders, :type, :string
    # 更新现有记录
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE work_orders
          SET type =
            CASE order_type
              WHEN 'audit' THEN 'AuditWorkOrder'
              WHEN 'communication' THEN 'CommunicationWorkOrder'
              WHEN 'express_receipt' THEN 'ExpressReceiptWorkOrder'
            END
        SQL
      end
    end
    add_index :work_orders, :type
  end
end

# 创建工单子类
# app/models/audit_work_order.rb
class AuditWorkOrder < WorkOrder
  # 审核特定验证和方法
  def order_type
    'audit'
  end
end

# 更新控制器
def new
  @work_order = case params[:order_type]
                when 'audit'
                  AuditWorkOrder.new
                when 'communication'
                  CommunicationWorkOrder.new
                when 'express_receipt'
                  ExpressReceiptWorkOrder.new
                else
                  WorkOrder.new
                end
end
```

## 问题管理任务

### 任务B1：沟通记录模型扩展

**目标**：扩展CommunicationRecord模型，添加问题管理相关字段

**步骤**：
1. 创建数据库迁移文件，添加以下字段：
   - `category` (string)：问题类别
   - `question` (text)：问题描述
   - `material` (text)：材料要求
   - `problem_status` (string)：问题状态
   - `fee_detail_id` (reference)：关联的费用明细

**预计时间**：0.5天

**技术要点**：
```ruby
# 创建迁移文件
rails generate migration AddProblemFieldsToCommunicationRecords category:string question:text material:text problem_status:string fee_detail:references

# 编辑迁移文件
def change
  add_column :communication_records, :category, :string
  add_column :communication_records, :question, :text
  add_column :communication_records, :material, :text
  add_column :communication_records, :problem_status, :string, default: 'pending'
  add_reference :communication_records, :fee_detail, foreign_key: true
end
```

### 任务B2：沟通记录状态机实现

**目标**：在CommunicationRecord模型中实现问题状态机

**步骤**：
1. 添加state_machine gem（如果尚未添加）
2. 实现问题状态机，包括pending, approved, rejected状态
3. 添加状态转换方法

**预计时间**：1天

**技术要点**：
```ruby
# 在CommunicationRecord模型中
state_machine :problem_status, initial: :pending do
  event :approve do
    transition pending: :approved
  end
  
  event :reject do
    transition pending: :rejected
  end
  
  event :reset do
    transition [:approved, :rejected] => :pending
  end
end
```

### 任务B3：沟通记录控制器扩展

**目标**：扩展CommunicationRecordsController，添加问题管理相关方法

**步骤**：
1. 更新create和update方法，处理问题相关字段
2. 添加update_status方法，处理问题状态更新
3. 添加duplicate方法，实现问题复制功能

**预计时间**：1天

**技术要点**：
```ruby
# 在CommunicationRecordsController中
def create
  @work_order = WorkOrder.find(params[:work_order_id])
  @communication_record = @work_order.communication_records.build(communication_record_params)
  
  if @communication_record.save
    redirect_to @work_order, notice: '沟通记录已创建'
  else
    render :new
  end
end

def update_status
  @communication_record = CommunicationRecord.find(params[:id])
  
  case params[:status]
  when 'approve'
    @communication_record.approve
  when 'reject'
    @communication_record.reject
  when 'reset'
    @communication_record.reset
  end
  
  redirect_to @communication_record.work_order, notice: '状态已更新'
end

def duplicate
  @original_record = CommunicationRecord.find(params[:id])
  @work_order = @original_record.work_order
  
  @new_record = @original_record.dup
  @new_record.created_at = nil
  @new_record.updated_at = nil
  @new_record.communication_time = Time.now
  
  if @new_record.save
    redirect_to @work_order, notice: '沟通记录已复制'
  else
    redirect_to @work_order, alert: '复制失败'
  end
end

private

def communication_record_params
  params.require(:communication_record).permit(
    :communicator_role, :communicator_name, :content,
    :communication_method, :status, :category,
    :question, :material, :fee_detail_id
  )
end
```

### 任务B4：沟通记录表单更新

**目标**：更新沟通记录表单，添加问题管理相关字段

**步骤**：
1. 更新new.html.erb和edit.html.erb视图
2. 添加问题类别、问题描述、材料要求等字段
3. 添加费用明细选择功能

**预计时间**：1天

**技术要点**：
```erb
<!-- app/views/communication_records/_form.html.erb -->
<%= form_with(model: [@work_order, @communication_record]) do |form| %>
  <!-- 现有字段... -->

  <div class="field">
    <%= form.label :category, "问题类别" %>
    <%= form.select :category, ["发票问题", "金额问题", "材料不全", "其他"], include_blank: true %>
  </div>

  <div class="field">
    <%= form.label :question, "问题描述" %>
    <%= form.text_area :question %>
  </div>

  <div class="field">
    <%= form.label :material, "材料要求" %>
    <%= form.text_area :material %>
  </div>

  <div class="field">
    <%= form.label :fee_detail_id, "关联费用明细" %>
    <%= form.collection_select :fee_detail_id, @work_order.reimbursement.fee_details, :id, :description, include_blank: true %>
  </div>

  <div class="actions">
    <%= form.submit %>
  </div>
<% end %>
```

### 任务B5：沟通记录显示更新

**目标**：更新工单详情页面，显示沟通记录的问题信息

**步骤**：
1. 更新工单详情页面中的沟通记录部分
2. 显示问题类别、问题描述、材料要求等信息
3. 添加状态管理和复制按钮

**预计时间**：1天

**技术要点**：
```erb
<!-- 在工单详情页面中 -->
<h3>沟通记录</h3>
<table>
  <thead>
    <tr>
      <th>时间</th>
      <th>角色</th>
      <th>内容</th>
      <th>问题类别</th>
      <th>问题状态</th>
      <th>操作</th>
    </tr>
  </thead>
  <tbody>
    <% @work_order.communication_records.each do |record| %>
      <tr>
        <td><%= record.communication_time %></td>
        <td><%= record.communicator_role %></td>
        <td><%= record.content %></td>
        <td><%= record.category %></td>
        <td><%= record.problem_status %></td>
        <td>
          <%= link_to '查看详情', '#', data: { toggle: 'modal', target: "#record-#{record.id}" } %>
          <%= link_to '通过', update_status_communication_record_path(record, status: 'approve'), method: :patch %>
          <%= link_to '拒绝', update_status_communication_record_path(record, status: 'reject'), method: :patch %>
          <%= link_to '复制', duplicate_communication_record_path(record), method: :post %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

### 任务B6：沟通记录路由更新

**目标**：更新路由配置，添加沟通记录相关路由

**步骤**：
1. 在routes.rb中添加沟通记录相关路由

**预计时间**：0.5天

**技术要点**：
```ruby
# 在config/routes.rb中
resources :work_orders do
  resources :communication_records
end

resources :communication_records, only: [] do
  member do
    patch :update_status
    post :duplicate
  end
end
```

## 测试任务

### 任务C1：审核流程单元测试

**目标**：为工单审核功能编写单元测试

**步骤**：
1. 测试工单状态流转
2. 测试审核结果验证
3. 测试VAT验证功能

**预计时间**：1天

**技术要点**：
```ruby
# test/models/work_order_test.rb
require 'test_helper'

class WorkOrderTest < ActiveSupport::TestCase
  setup do
    @work_order = work_orders(:processing)
  end
  
  test "should transition to auditing state" do
    assert @work_order.start_audit
    assert_equal "auditing", @work_order.status
  end
  
  test "should transition to approved state" do
    @work_order.start_audit
    assert @work_order.approve_audit
    assert_equal "approved", @work_order.status
  end
  
  # 更多测试...
end
```

### 任务C2：问题管理单元测试

**目标**：为沟通记录问题管理功能编写单元测试

**步骤**：
1. 测试问题状态流转
2. 测试问题复制功能
3. 测试与费用明细的关联

**预计时间**：1天

**技术要点**：
```ruby
# test/models/communication_record_test.rb
require 'test_helper'

class CommunicationRecordTest < ActiveSupport::TestCase
  setup do
    @record = communication_records(:pending)
  end
  
  test "should transition to approved state" do
    assert @record.approve
    assert_equal "approved", @record.problem_status
  end
  
  test "should transition to rejected state" do
    assert @record.reject
    assert_equal "rejected", @record.problem_status
  end
  
  # 更多测试...
end
```

### 任务C3：集成测试

**目标**：编写集成测试，测试完整的审核和问题处理流程

**步骤**：
1. 测试工单审核流程
2. 测试问题创建和状态更新
3. 测试完整的用户交互流程

**预计时间**：1天

**技术要点**：
```ruby
# test/system/work_order_flows_test.rb
require "application_system_test_case"

class WorkOrderFlowsTest < ApplicationSystemTestCase
  setup do
    @work_order = work_orders(:processing)
    login_as(users(:admin))
  end
  
  test "audit work order" do
    visit work_order_path(@work_order)
    click_on "审核"
    
    select "通过", from: "审核结果"
    fill_in "审核意见", with: "审核通过，无问题"
    check "VAT已验证"
    click_on "提交审核"
    
    assert_text "审核已完成"
    assert_text "approved"
  end
  
  # 更多测试...
end
```

## 任务优先级和依赖关系

| 任务ID | 任务名称 | 优先级 | 依赖任务 |
|--------|---------|--------|---------|
| A1 | 工单模型审核字段扩展 | 高 | 无 |
| A2 | 费用明细VAT字段扩展 | 高 | 无 |
| A3 | 工单状态机扩展 | 高 | A1 |
| A4 | 工单审核控制器方法 | 中 | A1, A3 |
| A5 | 工单审核视图 | 中 | A1, A3, A4 |
| A6 | 路由更新 | 中 | A4 |
| B1 | 沟通记录模型扩展 | 高 | 无 |
| B2 | 沟通记录状态机实现 | 高 | B1 |
| B3 | 沟通记录控制器扩展 | 中 | B1, B2 |
| B4 | 沟通记录表单更新 | 中 | B1, B3 |
| B5 | 沟通记录显示更新 | 中 | B1, B3, B4 |
| B6 | 沟通记录路由更新 | 中 | B3 |
| C1 | 审核流程单元测试 | 低 | A1-A6 |
| C2 | 问题管理单元测试 | 低 | B1-B6 |
| C3 | 集成测试 | 低 | A1-A6, B1-B6 |

## 任务分配建议

根据任务的依赖关系和优先级，建议按以下顺序进行开发：

**第一阶段（数据模型更新）**：
- 任务A1：工单模型审核字段扩展
- 任务A2：费用明细VAT字段扩展
- 任务B1：沟通记录模型扩展

**第二阶段（状态机实现）**：
- 任务A3：工单状态机扩展
- 任务B2：沟通记录状态机实现

**第三阶段（控制器和路由更新）**：
- 任务A4：工单审核控制器方法
- 任务A6：路由更新
- 任务B3：沟通记录控制器扩展
- 任务B6：沟通记录路由更新

**第四阶段（视图更新）**：
- 任务A5：工单审核视图
- 任务B4：沟通记录表单更新
- 任务B5：沟通记录显示更新

**第五阶段（测试）**：
- 任务C1：审核流程单元测试
- 任务C2：问题管理单元测试
- 任务C3：集成测试