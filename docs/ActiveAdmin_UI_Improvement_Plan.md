# ActiveAdmin 用户界面改进实施计划

本文档提供了详细的实施步骤和代码修改建议，按照优先级排序。

## 1. 集中化数据导入功能到Dashboard

### 步骤 1.1: 修改 Dashboard 页面

文件路径: `app/admin/dashboard.rb`

```ruby
# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "数据导入中心" do
          div class: 'import-center' do
            ul class: 'import-list' do
              li link_to "导入报销单", new_import_admin_reimbursements_path, class: 'import-button'
              li link_to "导入快递收单", new_import_admin_express_receipts_path, class: 'import-button'
              li link_to "导入费用明细", new_import_admin_fee_details_path, class: 'import-button'
              li link_to "导入操作历史", new_import_admin_operation_histories_path, class: 'import-button'
              li link_to "导入工单", new_import_admin_work_orders_path, class: 'import-button'
            end
          end
        end
      end
      
      column do
        panel "系统概览" do
          div class: 'stats-container' do
            div class: 'stat-box' do
              h3 Reimbursement.count
              p "报销单总数"
            end
            div class: 'stat-box' do
              h3 WorkOrder.count
              p "工单总数"
            end
            div class: 'stat-box' do
              h3 WorkOrder.where(status: WorkOrder::STATUS_PENDING).count
              p "待处理工单"
            end
            div class: 'stat-box' do
              h3 ExpressReceipt.count
              p "快递收单总数"
            end
          end
        end
      end
    end

    columns do
      column do
        panel "最近工单" do
          table_for WorkOrder.order(created_at: :desc).limit(5) do
            column("工单号") { |order| link_to(order.order_number, admin_work_order_path(order)) }
            column("类型") { |order| order.order_type }
            column("状态") { |order| status_tag(order.status) }
            column("创建时间") { |order| order.creation_time }
          end
          div do
            link_to "查看所有工单", admin_work_orders_path, class: 'view-all'
          end
        end
      end

      column do
        panel "最近报销单" do
          table_for Reimbursement.order(created_at: :desc).limit(5) do
            column("单号") { |r| link_to(r.invoice_number, admin_reimbursement_path(r)) }
            column("申请人") { |r| r.applicant }
            column("状态") { |r| status_tag(r.status) }
            column("金额") { |r| r.amount }
          end
          div do
            link_to "查看所有报销单", admin_reimbursements_path, class: 'view-all'
          end
        end
      end
    end
  end
end
```

## 2. 改进工单处理界面

### 步骤 2.1: 修改报销单详情页中的费用明细标签页

文件路径: `app/admin/reimbursements.rb`

找到 `tab '费用明细'` 部分，替换为以下代码:

```ruby
tab '费用明细' do
  panel "关联的费用明细" do
    div class: 'panel_contents' do
      if resource.fee_details.any?
        div do
          link_to "查看全部费用明细", admin_fee_details_path(q: { document_number_eq: resource.invoice_number }), class: 'button'
        end
        
        # 添加费用明细多选功能
        form_for :work_order, url: create_work_order_admin_reimbursement_path(resource), method: :post, html: { class: 'fee-detail-form' } do |f|
          div class: 'fee-details-container' do
            table_for resource.fee_details do
              column do |fee_detail|
                check_box_tag "fee_detail_ids[]", fee_detail.id, false, class: 'fee-detail-checkbox'
              end
              column :fee_type
              column :amount
              column :verification_status do |fee_detail|
                status_tag fee_detail.verification_status
              end
              column do |fee_detail|
                link_to "查看", admin_fee_detail_path(fee_detail)
              end
            end
          end
          
          div class: 'work-order-form-container' do
            div class: 'filter_form_field' do
              f.label :order_type, '工单类型', class: 'form-label'
              f.select :order_type, WorkOrder::ORDER_TYPES, {}, class: 'select-input'
            end
            
            div class: 'filter_form_field' do
              f.label :description, '描述', class: 'form-label'
              f.text_area :description, rows: 3, class: 'text-area-input'
            end
            
            div class: 'actions' do
              f.submit "创建工单", class: 'button primary-button'
              button_tag "全选", type: 'button', class: 'button secondary-button', onclick: 'selectAllFeeDetails()'
              button_tag "取消全选", type: 'button', class: 'button secondary-button', onclick: 'deselectAllFeeDetails()'
            end
          end
        end
      else
        div class: 'blank_slate' do
          span "暂无关联的费用明细"
        end
      end
    end
  end
end
```

### 步骤 2.2: 修改 create_work_order 方法

文件路径: `app/admin/reimbursements.rb`

找到 `member_action :create_work_order, method: :post do` 部分，确保其实现如下:

```ruby
member_action :create_work_order, method: :post do
  @reimbursement = Reimbursement.find(params[:id])
  
  # 验证是否选择了费用明细
  if params[:fee_detail_ids].blank?
    flash[:alert] = "请至少选择一个费用明细"
    redirect_to admin_reimbursement_path(@reimbursement)
    return
  end
  
  # 创建工单
  @work_order = WorkOrder.new(
    order_number: "WO-#{Time.now.to_i}",
    document_number: @reimbursement.invoice_number,
    order_type: params[:work_order][:order_type],
    status: WorkOrder::STATUS_PENDING,
    creation_time: Time.now,
    operator: current_admin_user.email,
    description: params[:work_order][:description]
  )
  
  if @work_order.save
    # 关联选中的费用明细
    params[:fee_detail_ids].each do |fee_detail_id|
      FeeDetailSelection.create!(
        work_order_id: @work_order.id,
        fee_detail_id: fee_detail_id,
        verification_status: FeeDetailSelection::VERIFICATION_STATUS_PENDING
      )
    end
    
    redirect_to admin_work_order_path(@work_order), notice: '工单创建成功'
  else
    flash[:alert] = "工单创建失败: #{@work_order.errors.full_messages.join(', ')}"
    redirect_to admin_reimbursement_path(@reimbursement)
  end
end
```

## 3. 改进工单表单

### 步骤 3.1: 修改工单统一表单

文件路径: `app/views/admin/work_orders/_unified_form.html.erb`

```erb
<% 
  # 确定表单的URL和方法
  if form_mode == 'create'
    form_url = create_work_order_admin_reimbursement_path(reimbursement)
    form_method = :post
    form_id = 'new_work_order_form'
    submit_text = '创建工单'
    form_title = '创建新工单'
  else
    form_url = update_work_order_admin_reimbursement_path(reimbursement, work_order_id: work_order.id)
    form_method = :patch
    form_id = "edit_work_order_#{work_order.id}"
    submit_text = '更新工单'
    form_title = '编辑工单'
  end
%>

<div class="unified-work-order-form card" data-reimbursement-id="<%= reimbursement.id %>">
  <div class="card-header">
    <h3><%= form_title %></h3>
  </div>
  
  <div class="card-body">
    <%= form_for [:admin, work_order], url: form_url, html: { id: form_id, class: 'formtastic work_order' }, remote: true, method: form_method do |f| %>
      <div class="form-grid">
        <div class="form-group">
          <%= f.label :order_number, '工单号', class: 'form-label' %>
          <%= f.text_field :order_number, required: true, class: 'form-control' %>
        </div>
        
        <div class="form-group">
          <%= f.label :order_type, '类型', class: 'form-label' %>
          <%= f.select :order_type, WorkOrder::ORDER_TYPES, {}, class: 'form-control select' %>
        </div>
        
        <div class="form-group">
          <%= f.label :operator, '操作人', class: 'form-label' %>
          <%= f.text_field :operator, required: true, class: 'form-control' %>
        </div>
        
        <div class="form-group">
          <%= f.label :creation_time, '创建时间', class: 'form-label' %>
          <% if form_mode == 'create' %>
            <%= f.datetime_field :creation_time, value: Time.current.strftime('%Y-%m-%dT%H:%M'), class: 'form-control' %>
          <% else %>
            <%= f.datetime_field :creation_time, value: work_order.creation_time&.strftime('%Y-%m-%dT%H:%M'), class: 'form-control' %>
          <% end %>
        </div>
        
        <div class="form-group full-width">
          <%= f.label :result, '处理结果', class: 'form-label' %>
          <%= f.text_area :result, rows: 3, class: 'form-control' %>
        </div>
      </div>
      
      <div class="form-actions">
        <%= f.submit submit_text, class: 'button primary-button' %>
        <% if form_mode == 'edit' %>
          <%= link_to '取消', '#', onclick: "resetWorkOrderForm(); return false;", class: 'button secondary-button' %>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

## 4. 改进工单列表显示

### 步骤 4.1: 修改工单列表模板

文件路径: `app/views/admin/reimbursements/_work_orders_table.html.erb`

```erb
<div class="work-orders-container">
  <div class="work-orders-header">
    <% if resource.work_orders.any? %>
      <%= link_to "查看全部工单", admin_work_orders_path(q: { document_number_eq: resource.invoice_number }), class: 'button view-all-button' %>
    <% end %>
  </div>

  <% if resource.work_orders.any? %>
    <div class="work-orders-grid">
      <% resource.work_orders.order(created_at: :desc).each do |work_order| %>
        <div class="work-order-card <%= work_order.status %>">
          <div class="work-order-header">
            <span class="work-order-id"><%= link_to "##{work_order.id}", admin_work_order_path(work_order) %></span>
            <span class="work-order-status"><%= status_tag work_order.status %></span>
          </div>
          
          <div class="work-order-body">
            <div class="work-order-info">
              <div class="info-item">
                <span class="label">工单号:</span>
                <span class="value"><%= work_order.order_number %></span>
              </div>
              <div class="info-item">
                <span class="label">类型:</span>
                <span class="value"><%= work_order.order_type %></span>
              </div>
              <div class="info-item">
                <span class="label">操作人:</span>
                <span class="value"><%= work_order.operator %></span>
              </div>
              <div class="info-item">
                <span class="label">创建时间:</span>
                <span class="value"><%= work_order.creation_time&.strftime('%Y-%m-%d %H:%M') %></span>
              </div>
            </div>
            
            <% if work_order.result.present? %>
              <div class="work-order-result">
                <span class="label">处理结果:</span>
                <p><%= work_order.result %></p>
              </div>
            <% end %>
          </div>
          
          <div class="work-order-actions">
            <%= link_to "编辑", "#",
                class: "edit-work-order-link button",
                data: {
                  id: work_order.id,
                  order_number: work_order.order_number,
                  creation_time: work_order.creation_time&.strftime('%Y-%m-%dT%H:%M'),
                  order_type: work_order.order_type,
                  operator: work_order.operator,
                  result: work_order.result
                },
                onclick: "editWorkOrder(this); return false;" %>
                
            <% if work_order.status == WorkOrder::STATUS_PENDING %>
              <%= link_to "开始处理", start_processing_admin_work_order_path(work_order), method: :put, class: "button action-button" %>
            <% elsif work_order.status == WorkOrder::STATUS_PROCESSING %>
              <%= link_to "标记完成", mark_as_completed_admin_work_order_path(work_order), class: "button action-button" %>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
  <% else %>
    <div class="blank_slate">
      <span>暂无关联的工单</span>
    </div>
  <% end %>
</div>
```

## 5. 添加自定义CSS样式

### 步骤 5.1: 创建自定义样式文件

文件路径: `app/assets/stylesheets/active_admin_custom.scss`

```scss
// 导入中心样式
.import-center {
  padding: 20px;
  background: #f9f9f9;
  border-radius: 5px;
}

.import-list {
  display: flex;
  flex-wrap: wrap;
  gap: 15px;
  list-style: none;
  padding: 0;
}

.import-button {
  display: inline-block;
  padding: 12px 20px;
  background: #5E6469;
  color: white;
  border-radius: 4px;
  text-decoration: none;
  transition: background 0.3s;
  
  &:hover {
    background: #7B8389;
    color: white;
  }
}

// 统计盒子样式
.stats-container {
  display: flex;
  flex-wrap: wrap;
  gap: 15px;
}

.stat-box {
  flex: 1;
  min-width: 120px;
  padding: 15px;
  background: white;
  border-radius: 5px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.1);
  text-align: center;
  
  h3 {
    font-size: 24px;
    margin: 0;
    color: #5E6469;
  }
  
  p {
    margin: 5px 0 0;
    color: #8a8a8a;
  }
}

// 工单卡片样式
.work-orders-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
  margin-top: 20px;
}

.work-order-card {
  background: white;
  border-radius: 5px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.1);
  overflow: hidden;
  
  &.pending {
    border-left: 4px solid #FF9800;
  }
  
  &.processing {
    border-left: 4px solid #2196F3;
  }
  
  &.completed {
    border-left: 4px solid #4CAF50;
  }
  
  &.communication_needed {
    border-left: 4px solid #F44336;
  }
}

.work-order-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 15px;
  background: #f5f5f5;
  border-bottom: 1px solid #e0e0e0;
}

.work-order-body {
  padding: 15px;
}

.work-order-info {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.info-item {
  .label {
    font-weight: bold;
    color: #666;
  }
}

.work-order-result {
  margin-top: 15px;
  padding-top: 15px;
  border-top: 1px solid #eee;
  
  .label {
    font-weight: bold;
    color: #666;
  }
}

.work-order-actions {
  padding: 15px;
  background: #f9f9f9;
  display: flex;
  gap: 10px;
}

// 表单样式改进
.unified-work-order-form.card {
  background: white;
  border-radius: 5px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.1);
  margin-bottom: 20px;
}

.card-header {
  padding: 15px;
  background: #f5f5f5;
  border-bottom: 1px solid #e0e0e0;
  
  h3 {
    margin: 0;
    color: #5E6469;
  }
}

.card-body {
  padding: 20px;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 15px;
  
  .full-width {
    grid-column: 1 / -1;
  }
}

.form-group {
  margin-bottom: 15px;
}

.form-label {
  display: block;
  margin-bottom: 5px;
  font-weight: bold;
  color: #5E6469;
}

.form-control {
  width: 100%;
  padding: 8px 12px;
  border: 1px solid #ddd;
  border-radius: 4px;
  
  &:focus {
    border-color: #5E6469;
    outline: none;
  }
}

.form-actions {
  margin-top: 20px;
  display: flex;
  gap: 10px;
}

.button {
  padding: 8px 16px;
  border-radius: 4px;
  border: none;
  cursor: pointer;
  text-decoration: none;
  
  &.primary-button {
    background: #5E6469;
    color: white;
    
    &:hover {
      background: #7B8389;
    }
  }
  
  &.secondary-button {
    background: #e0e0e0;
    color: #333;
    
    &:hover {
      background: #d0d0d0;
    }
  }
  
  &.action-button {
    background: #4CAF50;
    color: white;
    
    &:hover {
      background: #3d8b40;
    }
  }
}

// 费用明细多选表单
.fee-details-container {
  margin-bottom: 20px;
  max-height: 300px;
  overflow-y: auto;
  border: 1px solid #eee;
  border-radius: 4px;
}

.fee-detail-checkbox {
  width: 18px;
  height: 18px;
}

.work-order-form-container {
  background: #f9f9f9;
  padding: 15px;
  border-radius: 4px;
}
```

### 步骤 5.2: 在 ActiveAdmin 中引入自定义样式

文件路径: `app/assets/stylesheets/active_admin.scss`

在文件末尾添加:

```scss
// 引入自定义样式
@import "active_admin_custom";
```

## 6. 添加JavaScript功能

### 步骤 6.1: 创建自定义JavaScript文件

文件路径: `app/assets/javascripts/active_admin_custom.js`

```javascript
// 费用明细全选/取消全选功能
function selectAllFeeDetails() {
  document.querySelectorAll('.fee-detail-checkbox').forEach(checkbox => {
    checkbox.checked = true;
  });
}

function deselectAllFeeDetails() {
  document.querySelectorAll('.fee-detail-checkbox').forEach(checkbox => {
    checkbox.checked = false;
  });
}

// 工单编辑功能增强
function editWorkOrder(element) {
  const data = element.dataset;
  const formContainer = document.getElementById('work_order_form_container');
  
  // 显示加载状态
  formContainer.innerHTML = '<div class="loading">加载中...</div>';
  
  // 获取编辑表单
  fetch(`/admin/reimbursements/${formContainer.dataset.reimbursementPath}/get_work_order_form?form_mode=edit&work_order_id=${data.id}`, {
    headers: {
      'Accept': 'text/javascript'
    }
  })
  .then(response => response.text())
  .then(html => {
    formContainer.innerHTML = html;
    
    // 滚动到表单位置
    formContainer.scrollIntoView({ behavior: 'smooth' });
    
    // 高亮表单
    formContainer.classList.add('highlight');
    setTimeout(() => {
      formContainer.classList.remove('highlight');
    }, 1500);
  })
  .catch(error => {
    console.error('Error fetching form:', error);
    formContainer.innerHTML = '<div class="error">加载表单失败</div>';
  });
}

// 重置工单表单
function resetWorkOrderForm() {
  const formContainer = document.getElementById('work_order_form_container');
  const reimbursementId = formContainer.dataset.reimbursementId;
  
  fetch(`/admin/reimbursements/${reimbursementId}/get_work_order_form?form_mode=create`, {
    headers: {
      'Accept': 'text/javascript'
    }
  })
  .then(response => response.text())
  .then(html => {
    formContainer.innerHTML = html;
  })
  .catch(error => {
    console.error('Error resetting form:', error);
  });
}

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
  // 初始化提示框
  const notices = document.querySelectorAll('.flash_notice, .flash_alert');
  notices.forEach(notice => {
    setTimeout(() => {
      notice.style.opacity = '0';
      setTimeout(() => {
        notice.style.display = 'none';
      }, 500);
    }, 5000);
  });
  
  // 初始化表格排序和过滤功能
  const tables = document.querySelectorAll('.index_table');
  tables.forEach(table => {
    // 实现简单的表格排序
    const headers = table.querySelectorAll('th');
    headers.forEach(header => {
      if (!header.classList.contains('sortable')) return;
      
      header.addEventListener('click', function() {
        const isAsc = this.classList.contains('sorted-asc');
        
        // 移除所有排序类
        headers.forEach(h => {
          h.classList.remove('sorted-asc', 'sorted-desc');
        });
        
        // 添加新的排序类
        this.classList.add(isAsc ? 'sorted-desc' : 'sorted-asc');
        
        // 这里可以添加实际的排序逻辑
      });
    });
  });
});
```

### 步骤 6.2: 在 ActiveAdmin 中引入自定义JavaScript

文件路径: `app/assets/javascripts/active_admin.js`

在文件末尾添加:

```javascript
//= require active_admin_custom
```

## 7. 修复费用明细访问问题

### 步骤 7.1: 检查路由配置

文件路径: `config/routes.rb`

确保路由配置正确:

```ruby
Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  
  # 确保费用明细路由正确
  resources :fee_details, only: [:index, :show]
  
  root to: 'admin/dashboard#index'
end
```

### 步骤 7.2: 检查 FeeDetailsController

文件路径: `app/controllers/fee_details_controller.rb`

如果不存在，创建该控制器:

```ruby
class FeeDetailsController < ApplicationController
  def index
    @fee_details = FeeDetail.all
    render json: @fee_details
  end
  
  def show
    @fee_detail = FeeDetail.find(params[:id])
    render json: @fee_detail
  end
end
```

## 8. 实施步骤

1. **备份当前代码**：在进行任何修改前，确保备份当前代码。
2. **按顺序实施修改**：按照上述步骤顺序实施修改，每次修改后测试功能。
3. **测试**：每个修改完成后，测试相应功能是否正常工作。
4. **部署**：所有修改完成并测试通过后，部署到生产环境。

## 9. 注意事项

1. **数据库迁移**：本计划不涉及数据库结构变更，因此不需要数据库迁移。
2. **兼容性**：确保修改后的代码与现有系统兼容。
3. **性能**：监控修改后的系统性能，特别是在数据量大的情况下。
4. **用户培训**：为用户提供新界面的使用指南。

## 10. 流程图

```mermaid
flowchart TD
    A[Dashboard] --> B[集中数据导入]
    A --> C[系统概览]
    A --> D[最近工单]
    A --> E[最近报销单]
    
    F[报销单详情页] --> G[基本信息]
    F --> H[费用明细]
    F --> I[快递单]
    F --> J[工单]
    F --> K[操作记录]
    
    H --> L[多选费用明细]
    L --> M[创建工单]
    
    J --> N[工单表单]
    J --> O[工单列表]
    
    N --> P[创建/编辑工单]
    O --> Q[查看工单详情]
    O --> R[工单状态管理]
    
    R --> S[开始处理]
    R --> T[标记完成]
    R --> U[创建沟通工单]