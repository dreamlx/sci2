# ActiveAdmin Configuration for WorkOrderProblemHistory

This document provides a template for implementing the ActiveAdmin configuration for the `WorkOrderProblemHistory` model.

## ActiveAdmin Registration File

```ruby
# app/admin/work_order_problem_histories.rb
ActiveAdmin.register WorkOrderProblemHistory do
  # Menu configuration
  menu false # Hide from main menu
  
  # Belongs to configuration
  belongs_to :work_order, optional: true
  
  # Actions configuration
  actions :index, :show # Read-only
  
  # Controller customization
  controller do
    def scoped_collection
      super.includes(:work_order, :problem_type, :fee_type, :admin_user)
    end
  end
  
  # Filters
  filter :work_order
  filter :problem_type
  filter :fee_type
  filter :admin_user
  filter :action_type, as: :select, collection: -> { 
    [
      ['添加', 'add'],
      ['修改', 'modify'],
      ['移除', 'remove']
    ]
  }
  filter :created_at
  
  # Index page
  index do
    selectable_column
    id_column
    column :work_order do |history|
      link_to "工单 ##{history.work_order.id}", admin_work_order_path(history.work_order)
    end
    column :action_type do |history|
      case history.action_type
      when 'add'
        status_tag '添加', class: 'green'
      when 'modify'
        status_tag '修改', class: 'orange'
      when 'remove'
        status_tag '移除', class: 'red'
      else
        status_tag history.action_type
      end
    end
    column :problem_type do |history|
      history.problem_type&.display_name
    end
    column :fee_type do |history|
      history.fee_type&.display_name
    end
    column :admin_user
    column :created_at
    actions
  end
  
  # Show page
  show do
    attributes_table do
      row :id
      row :work_order do |history|
        link_to "工单 ##{history.work_order.id}", admin_work_order_path(history.work_order)
      end
      row :action_type do |history|
        case history.action_type
        when 'add'
          status_tag '添加', class: 'green'
        when 'modify'
          status_tag '修改', class: 'orange'
        when 'remove'
          status_tag '移除', class: 'red'
        else
          status_tag history.action_type
        end
      end
      row :problem_type do |history|
        history.problem_type&.display_name
      end
      row :fee_type do |history|
        history.fee_type&.display_name
      end
      row :admin_user
      row :change_reason
      row :created_at
    end
    
    panel "内容变更" do
      tabs do
        tab '变更前' do
          div class: 'problem-content' do
            pre history.previous_content
          end
        end
        
        tab '变更后' do
          div class: 'problem-content' do
            pre history.new_content
          end
        end
        
        tab '差异对比' do
          if history.previous_content.present? && history.new_content.present?
            # This is a placeholder for a diff implementation
            # In a real implementation, you would use a diff library like Diffy
            # Example: raw Diffy::Diff.new(history.previous_content, history.new_content, context: 2).to_s(:html)
            div class: 'problem-diff' do
              para "差异对比功能需要实现"
            end
          else
            para "无法生成差异对比，变更前或变更后的内容为空。"
          end
        end
      end
    end
  end
  
  # Sidebar
  sidebar "相关信息", only: :show do
    attributes_table_for resource do
      row "工单类型" do |history|
        history.work_order.type
      end
      row "工单状态" do |history|
        status_tag history.work_order.status
      end
      row "报销单" do |history|
        link_to history.work_order.reimbursement.invoice_number, 
                admin_reimbursement_path(history.work_order.reimbursement)
      end
    end
  end
end
```

## CSS Styles for Diff Display

Add the following CSS to your ActiveAdmin stylesheets:

```scss
// app/assets/stylesheets/active_admin.scss

// Problem history styles
.problem-content {
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
}

.problem-diff {
  max-height: 400px;
  overflow-y: auto;
  background-color: #f5f5f5;
  padding: 10px;
  border-radius: 4px;
  
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
panel "问题历史记录" do
  if resource.problem_histories.exists?
    table_for resource.problem_histories.recent_first do
      column :id do |history|
        link_to history.id, admin_work_order_problem_history_path(history)
      end
      column :action_type do |history|
        case history.action_type
        when 'add'
          status_tag '添加', class: 'green'
        when 'modify'
          status_tag '修改', class: 'orange'
        when 'remove'
          status_tag '移除', class: 'red'
        else
          status_tag history.action_type
        end
      end
      column :problem_type do |history|
        history.problem_type&.display_name
      end
      column :admin_user
      column :created_at
    end
  else
    para "暂无问题历史记录"
  end
end
```

## Implementing Diff Functionality

To implement the diff functionality, you'll need to add a gem like `diffy` to your Gemfile:

```ruby
# Gemfile
gem 'diffy'
```

Then update the `content_diff` method in the `WorkOrderProblemHistory` model:

```ruby
# app/models/work_order_problem_history.rb
def content_diff
  return nil if previous_content.blank? || new_content.blank?
  
  Diffy::Diff.new(previous_content, new_content, context: 2).to_s(:html)
end
```

And update the show page to use this method:

```ruby
# app/admin/work_order_problem_histories.rb
# Replace the placeholder in the 'diff' tab
tab '差异对比' do
  if history.previous_content.present? && history.new_content.present?
    div class: 'problem-diff' do
      raw history.content_diff
    end
  else
    para "无法生成差异对比，变更前或变更后的内容为空。"
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
  
  can :read, WorkOrderProblemHistory
  
  # ...
end