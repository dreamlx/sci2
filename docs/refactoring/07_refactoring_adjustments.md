# SCI2 工单系统重构调整方案

根据对数据导入格式参考文档和测试计划的深入分析，以及与用户的沟通确认，我们需要对重构计划进行一些调整，以确保系统满足实际业务需求。本文档总结了需要调整的关键点和具体实施方案。

## 1. 数据导入顺序调整

### 1.1 原计划

原计划中没有明确规定数据导入的顺序，只是在数据迁移策略中提到按照"报销单 -> 快递收单 -> 费用明细 -> 操作历史"的顺序导入数据。

### 1.2 调整方案

根据数据导入格式参考文档，我们需要明确规定数据导入的顺序：

1. **必须先导入报销单**：报销单的invoice number是关键字段，其他数据导入都依赖于此
2. **其他三种数据可灵活导入**：快递收单、费用明细和操作历史可以按任意顺序导入，但都必须在报销单导入之后

### 1.3 实施调整

1. 在`ReimbursementImportService`中添加导入成功标志，供其他导入服务检查
2. 在`ExpressReceiptImportService`、`FeeDetailImportService`和`OperationHistoryImportService`中添加对报销单存在性的检查
3. 如果报销单不存在，提供明确的错误信息，并允许用户下载未匹配成功的记录

```ruby
# 在其他导入服务中添加检查
def validate_reimbursement_exists(document_number)
  reimbursement = Reimbursement.find_by(invoice_number: document_number)
  
  unless reimbursement
    @unmatched_count += 1
    @unmatched_records << {
      original_data: row.to_h,
      document_number: document_number,
      error: "报销单不存在"
    }
    return false
  end
  
  true
end
```

## 2. 工单创建逻辑调整

### 2.1 原计划

原计划中对工单创建逻辑的描述不够明确，特别是关于审核工单的两种创建路径和沟通工单关联费用明细的数量。

### 2.2 调整方案

1. **快递收单工单**：
   - 在导入快递收单数据时自动创建
   - 初始状态为"received"

2. **审核工单**：有两种创建路径
   - 导入非电子发票报销单时自动创建
   - 快递收单工单完成后自动创建
   - 初始状态为"pending"

3. **沟通工单**：
   - 只能由审核工单创建
   - 可以关联0到多个费用明细（原计划中没有明确说明可以关联0个）
   - 初始状态为"open"

### 2.3 实施调整

1. 修改`ReimbursementImportService`，实现非电子发票报销单的审核工单自动创建：

```ruby
def create_reimbursement(row)
  # 创建报销单代码...
  
  if reimbursement.save
    @created_count += 1
    
    # 如果是非电子发票且未收单，创建审核工单
    if !reimbursement.is_electronic
      create_audit_work_order(reimbursement)
    end
  end
end
```

2. 修改`ExpressReceiptWorkOrder`模型，实现完成后自动创建审核工单：

```ruby
# 在状态机中添加回调
event :complete do
  transitions from: :processed, to: :completed
  after do
    create_audit_work_order
  end
end

def create_audit_work_order
  AuditWorkOrder.create!(
    reimbursement: reimbursement,
    express_receipt_work_order: self,
    status: 'pending',
    created_by: created_by
  )
end
```

3. 修改`AuditWorkOrder`模型，实现创建沟通工单时可以关联0到多个费用明细：

```ruby
def create_communication_work_order(params = {})
  comm_order = CommunicationWorkOrder.new(
    reimbursement: reimbursement,
    audit_work_order: self,
    status: 'open',
    created_by: created_by,
    **params
  )
  
  if comm_order.save
    # 如果指定了费用明细ID，则关联这些费用明细
    if params[:fee_detail_ids].present?
      params[:fee_detail_ids].each do |id|
        fee_detail = FeeDetail.find_by(id: id)
        if fee_detail
          # 创建费用明细选择记录
          comm_order.fee_detail_selections.create(
            fee_detail: fee_detail,
            verification_status: 'problematic'
          )
          
          # 更新费用明细状态
          fee_detail.mark_as_problematic
        end
      end
    end
    
    # 更新自身状态
    need_communication unless status == 'needs_communication'
  end
  
  comm_order
end
```

## 3. 费用明细验证状态流转调整

### 3.1 原计划

原计划中对费用明细验证状态流转的描述不够明确，特别是关于沟通工单解决后费用明细状态的处理。

### 3.2 调整方案

明确费用明细验证状态流转如下：

1. **导入时**：初始状态为"待验证"(pending)
2. **审核过程中**：
   - 审核人员可以将费用明细标记为"已验证"(verified)
   - 或标记为"有问题"(problematic)并创建沟通工单
3. **沟通工单解决后**：
   - 费用明细状态保持为"有问题"(problematic)
   - 需要审核人员手动将其更改为"已验证"(verified)或"已拒绝"(rejected)
4. **审核工单完成时**：
   - 审核通过的费用明细最终状态为"已验证"(verified)
   - 审核拒绝的费用明细最终状态为"已拒绝"(rejected)

### 3.3 实施调整

1. 修改`CommunicationWorkOrder`模型，确保解决后不自动更新费用明细状态：

```ruby
def resolve
  result = super
  
  # 不自动更新费用明细状态，只通知审核工单
  if result && audit_work_order.present? && audit_work_order.status == 'needs_communication'
    audit_work_order.resume_audit
  end
  
  result
end
```

2. 在`FeeDetailVerificationService`中添加方法，让审核人员手动更新费用明细状态：

```ruby
def update_fee_detail_after_communication(fee_detail_id, verification_status, comment = nil)
  fee_detail = FeeDetail.find(fee_detail_id)
  
  case verification_status
  when 'verified'
    fee_detail.mark_as_verified
  when 'rejected'
    fee_detail.mark_as_rejected
  else
    return false
  end
  
  # 更新所有关联的费用明细选择记录
  fee_detail.fee_detail_selections.each do |selection|
    selection.update(
      verification_status: verification_status,
      verification_comment: comment,
      verified_by: @current_admin_user.id,
      verified_at: Time.current
    )
  end
  
  true
end
```

3. 在`AuditWorkOrderService`中添加方法，在审核工单完成时更新所有费用明细状态：

```ruby
def complete
  result = @audit_work_order.complete
  
  if result
    # 根据审核结果更新所有费用明细状态
    status = @audit_work_order.audit_result == 'approved' ? 'verified' : 'rejected'
    
    @audit_work_order.fee_details.each do |fee_detail|
      if fee_detail.verification_status == 'problematic'
        @audit_work_order.verify_fee_detail(fee_detail, status)
      end
    end
    
    # 如果所有审核工单都已完成，更新报销单状态
    reimbursement = @audit_work_order.reimbursement
    pending_audit_work_orders = reimbursement.audit_work_orders.where.not(status: 'completed')
    
    if pending_audit_work_orders.empty?
      reimbursement.mark_as_complete
    end
  end
  
  result
end
```

## 4. ActiveAdmin界面调整

### 4.1 原计划

原计划中的ActiveAdmin界面设计没有充分考虑费用明细验证状态的手动更新需求。

### 4.2 调整方案

1. 在审核工单详情页添加费用明细验证界面，允许审核人员手动更新费用明细状态
2. 在沟通工单详情页添加费用明细问题解决界面，但不自动更新费用明细状态
3. 添加费用明细批量操作功能，方便审核人员批量处理费用明细

### 4.3 实施调整

1. 在审核工单资源中添加费用明细验证操作：

```ruby
# app/admin/audit_work_orders.rb
ActiveAdmin.register AuditWorkOrder do
  # 其他代码...
  
  member_action :verify_fee_detail, method: :get do
    @fee_detail = FeeDetail.find(params[:fee_detail_id])
    render "admin/audit_work_orders/verify_fee_detail"
  end
  
  member_action :do_verify_fee_detail, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    if service.verify_fee_detail(params[:fee_detail_id], params[:verification_status], params[:comment])
      redirect_to admin_audit_work_order_path(resource), notice: "费用明细已更新"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败"
    end
  end
  
  # 在详情页添加费用明细验证界面
  show do
    # 其他代码...
    
    tab "费用明细" do
      panel "费用明细信息" do
        table_for resource.fee_details do
          column :id
          column :fee_type
          column :amount do |fee_detail|
            number_to_currency(fee_detail.amount, unit: "¥")
          end
          column :verification_status do |fee_detail|
            status_tag fee_detail.verification_status
          end
          column "操作" do |fee_detail|
            links = []
            links << link_to("查看", admin_fee_detail_path(fee_detail))
            links << link_to("验证", verify_fee_detail_admin_audit_work_order_path(resource, fee_detail_id: fee_detail.id))
            links << link_to("标记问题", mark_problematic_admin_fee_detail_path(fee_detail, work_order_id: resource.id))
            links.join(" | ").html_safe
          end
        end
      end
    end
  end
end
```

2. 添加费用明细验证视图：

```erb
<!-- app/views/admin/audit_work_orders/verify_fee_detail.html.erb -->
<h2>验证费用明细</h2>

<%= form_tag do_verify_fee_detail_admin_audit_work_order_path(@audit_work_order), method: :post do %>
  <%= hidden_field_tag :fee_detail_id, @fee_detail.id %>
  
  <div class="panel">
    <div class="panel_contents">
      <div class="attributes_table">
        <table>
          <tr>
            <th>费用类型</th>
            <td><%= @fee_detail.fee_type %></td>
          </tr>
          <tr>
            <th>金额</th>
            <td><%= number_to_currency(@fee_detail.amount, unit: "¥") %></td>
          </tr>
          <tr>
            <th>当前状态</th>
            <td><%= status_tag @fee_detail.verification_status %></td>
          </tr>
          <tr>
            <th>验证状态</th>
            <td>
              <%= select_tag :verification_status, options_for_select([
                ["已验证", "verified"],
                ["已拒绝", "rejected"],
                ["有问题", "problematic"]
              ], @fee_detail.verification_status), required: true %>
            </td>
          </tr>
          <tr>
            <th>验证意见</th>
            <td><%= text_area_tag :comment, nil, rows: 3, cols: 40 %></td>
          </tr>
        </table>
      </div>
    </div>
  </div>
  
  <div class="actions">
    <%= submit_tag "提交", class: "button" %>
    <%= link_to "取消", admin_audit_work_order_path(@audit_work_order), class: "button" %>
  </div>
<% end %>
```

## 5. 测试策略调整

### 5.1 原计划

原计划中的测试策略没有充分覆盖数据导入顺序、工单创建逻辑和费用明细验证状态流转的测试。

### 5.2 调整方案

1. 添加测试用例验证数据导入顺序的强制要求
2. 测试非电子发票报销单导入时自动创建审核工单
3. 测试快递收单工单完成后自动创建审核工单
4. 测试沟通工单可以关联0到多个费用明细
5. 测试费用明细验证状态流转的完整流程，特别是沟通解决后状态不自动更新的情况

### 5.3 实施调整

1. 添加数据导入顺序测试：

```ruby
# test/integration/data_import_order_test.rb
require 'test_helper'

class DataImportOrderTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = admin_users(:admin)
    sign_in @admin_user
  end
  
  test "should not import express receipts without reimbursements" do
    # 尝试导入快递收单，但没有先导入报销单
    express_receipt_file = fixture_file_upload('test_express_receipts.csv', 'text/csv')
    
    post import_admin_express_receipts_path, params: { file: express_receipt_file }
    
    # 验证导入失败，并提示报销单不存在
    assert_match /报销单不存在/, flash[:alert]
  end
  
  test "should not import fee details without reimbursements" do
    # 尝试导入费用明细，但没有先导入报销单
    fee_detail_file = fixture_file_upload('test_fee_details.csv', 'text/csv')
    
    post import_admin_fee_details_path, params: { file: fee_detail_file }
    
    # 验证导入失败，并提示报销单不存在
    assert_match /报销单不存在/, flash[:alert]
  end
  
  test "should not import operation histories without reimbursements" do
    # 尝试导入操作历史，但没有先导入报销单
    operation_history_file = fixture_file_upload('test_operation_histories.csv', 'text/csv')
    
    post import_admin_operation_histories_path, params: { file: operation_history_file }
    
    # 验证导入失败，并提示报销单不存在
    assert_match /报销单不存在/, flash[:alert]
  end
end
```

2. 添加工单创建逻辑测试：

```ruby
# test/models/reimbursement_test.rb
test "should create audit work order for non-electronic reimbursement" do
  reimbursement = Reimbursement.new(
    invoice_number: "R20250101003",
    document_name: "测试报销单",
    applicant: "张三",
    applicant_id: "EMP001",
    company: "测试公司",
    department: "测试部门",
    amount: 1000.00,
    is_electronic: false
  )
  
  assert_difference 'AuditWorkOrder.count' do
    reimbursement.save
  end
  
  audit_work_order = AuditWorkOrder.last
  assert_equal reimbursement.id, audit_work_order.reimbursement_id
  assert_equal "pending", audit_work_order.status
end

test "should not create audit work order for electronic reimbursement" do
  reimbursement = Reimbursement.new(
    invoice_number: "R20250101004",
    document_name: "电子发票报销单",
    applicant: "李四",
    applicant_id: "EMP002",
    company: "测试公司",
    department: "财务部",
    amount: 2000.00,
    is_electronic: true
  )
  
  assert_no_difference 'AuditWorkOrder.count' do
    reimbursement.save
  end
end
```

3. 添加费用明细验证状态流转测试：

```ruby
# test/integration/fee_detail_verification_flow_test.rb
require 'test_helper'

class FeeDetailVerificationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = admin_users(:admin)
    sign_in @admin_user
    
    @reimbursement = reimbursements(:valid_reimbursement)
    @audit_work_order = audit_work_orders(:auditing)
    @audit_work_order.update(reimbursement: @reimbursement)
    
    @fee_detail = fee_details(:pending)
    @fee_detail.update(document_number: @reimbursement.invoice_number)
    
    @audit_work_order.select_fee_detail(@fee_detail)
  end
  
  test "fee detail status should not change after communication work order resolved" do
    # 标记费用明细有问题
    post mark_problematic_admin_fee_detail_path(@fee_detail), params: {
      work_order_id: @audit_work_order.id,
      issue_description: "金额有问题"
    }
    
    communication_work_order = CommunicationWorkOrder.last
    assert_equal "problematic", @fee_detail.reload.verification_status
    
    # 解决沟通工单
    post do_resolve_admin_communication_work_order_path(communication_work_order), params: {
      resolution_summary: "问题已解决"
    }
    
    # 验证费用明细状态没有变化
    assert_equal "problematic", @fee_detail.reload.verification_status
    
    # 手动更新费用明细状态
    post do_verify_fee_detail_admin_audit_work_order_path(@audit_work_order), params: {
      fee_detail_id: @fee_detail.id,
      verification_status: "verified",
      comment: "问题已解决，验证通过"
    }
    
    # 验证费用明细状态已更新
    assert_equal "verified", @fee_detail.reload.verification_status
  end
end
```

## 6. 总结

通过以上调整，我们可以确保重构后的系统满足实际业务需求，特别是在数据导入顺序、工单创建逻辑和费用明细验证状态流转方面。这些调整将使系统更加符合用户的期望，提高系统的可用性和用户体验。

在实施过程中，我们需要特别注意以下几点：

1. 确保数据导入服务严格检查报销单的存在性
2. 确保审核工单的两种创建路径都能正常工作
3. 确保沟通工单可以关联0到多个费用明细
4. 确保费用明细验证状态流转符合业务需求，特别是沟通解决后状态不自动更新
5. 提供清晰的界面，让用户能够方便地手动更新费用明细状态

通过这些调整，我们将实现一个更加符合业务需求的工单系统，提高系统的可用性和用户体验。