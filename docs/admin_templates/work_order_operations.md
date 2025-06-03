# ActiveAdmin Configuration for WorkOrderOperation

This document provides a template for implementing the ActiveAdmin configuration for the `WorkOrderOperation` model.

## ActiveAdmin Registration File

```ruby
# app/admin/work_order_operations.rb
ActiveAdmin.register WorkOrderOperation do
  # Menu configuration
  menu false # Hide from main menu
  
  # Belongs to configuration
  belongs_to :work_order, optional: true
  
  # Actions configuration
  actions :index, :show # Read-only
  
  # Controller customization
  controller do
    def scoped_collection
      super.includes(:work_order, :admin_user)
    end
  end
  
  # Filters
  filter :work_order
  filter :admin_user
  filter :operation_type, as: :select, collection: -> { 
    WorkOrderOperation.operation_types.map { |type| 
      [WorkOrderOperation.new(operation_type: type).operation_type_display, type] 
    }
  }
  filter :created_at
  
  # Index page
  index do
    selectable_column
    id_column
    column :work_order do |operation|
      link_to "工单 ##{operation.work_order.id}", admin_work_order_path(operation.work_order)
    end
    column :operation_type do |operation|
      case operation.operation_type
      when WorkOrderOperation::OPERATION_TYPE_CREATE
        status_tag operation.operation_type_display, class: 'green'
      when WorkOrderOperation::OPERATION_TYPE_UPDATE
        status_tag operation.operation_type_display, class: 'orange'
      when WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE
        status_tag operation.operation_type_display, class: 'blue'
      when WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM
        status_tag operation.operation_type_display, class: 'green'
      when WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM
        status_tag operation.operation_type_display, class: 'red'
      when WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM
        status_tag operation.operation_type_display, class: 'orange'
      else
        status_tag operation.operation_type_display
      end
    end
    column :admin_user
    column :created_at
    actions
  end
  
  # Show page
  show do
    attributes_table do
      row :id
      row :work_order do |operation|
        link_to "工单 ##{operation.work_order.id}", admin_work_order_path(operation.work_order)
      end
      row :operation_type do |operation|
        case operation.operation_type
        when WorkOrderOperation::OPERATION_TYPE_CREATE
          status_tag operation.operation_type_display, class: 'green'
        when WorkOrderOperation::OPERATION_TYPE_UPDATE
          status_tag operation.operation_type_display, class: 'orange'
        when WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE
          status_tag operation.operation_type_display, class: 'blue'
        when WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM
          status_tag operation.operation_type_display, class: 'green'
        when WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM
          status_tag operation.operation_type_display, class: 'red'
        when WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM
          status_tag operation.operation_type_display, class: 'orange'
        else
          status_tag operation.operation_type_display
        end
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
        
        tab '差异对比' do
          if resource.previous_state.present? && resource.current_state.present?
            div class: 'state-diff' do
              # This is a placeholder for a diff implementation
              # In a real implementation, you would use a diff library or custom implementation
              para "差异对比功能需要实现"
            end
          else
            para "无法生成差异对比，操作前或操作后的状态为空。"
          end
        end
      end
    end
  end
  
  # Sidebar
  sidebar "相关信息", only: :show do
    attributes_table_for resource do
      row "工单类型" do |operation|
        operation.work_order.type
      end
      row "工单状态" do |operation|
        status_tag operation.work_order.status
      end
      row "报销单" do |operation|
        link_to operation.work_order.reimbursement.invoice_number, 
                admin_reimbursement_path(operation.work_order.reimbursement)
      end
    end
  end
end
```

## CSS Styles for Operation Display

Add the following CSS to your ActiveAdmin stylesheets:

```scss
// app/assets/stylesheets/active_admin.scss

// Operation styles
.state-diff {
  max-height: 400px;
  overflow-y: auto;
  background-color: #f5f5f5;
  padding: 10px;
  border-radius: 4px;
  
  pre {
    white-space: pre-wrap;
    word-wrap: break-word;
    font-family: monospace;
    margin: 0;
  }
  
  .diff {
    font-family: monospace;
    
    .del {
      background-color: #ffecec;
      color: #bd2c00;
      text-decoration: line-through;
    }
    
    .ins {
      background-color: #eaffea;
      color: #55a532;
    }
  }
}
```

## Integration with Work Order Show Page

Add the following to your work order show page:

```ruby
# app/admin/audit_work_orders.rb (and other work order types)
# Inside the show block
panel "操作记录" do
  if resource.operations.exists?
    table_for resource.operations.recent_first do
      column :id do |operation|
        link_to operation.id, admin_work_order_operation_path(operation)
      end
      column :operation_type do |operation|
        case operation.operation_type
        when WorkOrderOperation::OPERATION_TYPE_CREATE
          status_tag operation.operation_type_display, class: 'green'
        when WorkOrderOperation::OPERATION_TYPE_UPDATE
          status_tag operation.operation_type_display, class: 'orange'
        when WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE
          status_tag operation.operation_type_display, class: 'blue'
        when WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM
          status_tag operation.operation_type_display, class: 'green'
        when WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM
          status_tag operation.operation_type_display, class: 'red'
        when WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM
          status_tag operation.operation_type_display, class: 'orange'
        else
          status_tag operation.operation_type_display
        end
      end
      column :admin_user
      column :created_at
    end
  else
    para "暂无操作记录"
  end
end
```

## Operation Statistics Page

Create a new page for operation statistics:

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

## Implementing State Diff Functionality

To implement the state diff functionality, you can use a custom helper method:

```ruby
# app/helpers/admin/work_order_operations_helper.rb
module Admin
  module WorkOrderOperationsHelper
    def state_diff(previous_state, current_state)
      return nil if previous_state.blank? || current_state.blank?
      
      begin
        prev_hash = JSON.parse(previous_state)
        curr_hash = JSON.parse(current_state)
        
        # Get all keys from both hashes
        all_keys = (prev_hash.keys + curr_hash.keys).uniq
        
        # Build HTML diff
        html = '<div class="diff">'
        
        all_keys.each do |key|
          if !prev_hash.key?(key)
            # Key only in current state (added)
            html += "<div class='ins'>+ #{key}: #{curr_hash[key].inspect}</div>"
          elsif !curr_hash.key?(key)
            # Key only in previous state (removed)
            html += "<div class='del'>- #{key}: #{prev_hash[key].inspect}</div>"
          elsif prev_hash[key] != curr_hash[key]
            # Key in both but value changed
            html += "<div class='del'>- #{key}: #{prev_hash[key].inspect}</div>"
            html += "<div class='ins'>+ #{key}: #{curr_hash[key].inspect}</div>"
          end
        end
        
        html += '</div>'
        html.html_safe
      rescue JSON::ParserError
        "无法解析JSON数据"
      end
    end
  end
end
```

Then update the show page to use this helper:

```ruby
# app/admin/work_order_operations.rb
# Replace the placeholder in the 'diff' tab
tab '差异对比' do
  if resource.previous_state.present? && resource.current_state.present?
    div class: 'state-diff' do
      state_diff(resource.previous_state, resource.current_state)
    end
  else
    para "无法生成差异对比，操作前或操作后的状态为空。"
  end
end
```

## Routes Configuration

Ensure your routes are properly configured:

```ruby
# config/routes.rb
ActiveAdmin.routes(self)
```

## Permissions Configuration

If you're using CanCanCan for authorization, update your ability class:

```ruby
# app/models/ability.rb
def initialize(user)
  # ...
  
  can :read, WorkOrderOperation
  
  # ...
end
```

## Required Gems for Charts

To use the charts in the operation statistics page, you need to add the following gems to your Gemfile:

```ruby
# Gemfile
gem 'chartkick'
gem 'groupdate'
```

And include the JavaScript libraries in your ActiveAdmin JavaScript manifest:

```javascript
// app/assets/javascripts/active_admin.js
//= require chartkick
//= require Chart.bundle