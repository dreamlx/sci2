# SCI2 工单系统 UI 实现变更总结

## 变更背景

根据最新的需求讨论和测试计划，需要对SCI2工单系统的UI实现进行两项重要调整：

1. **操作历史记录只读化**：操作历史记录(OperationHistory)应该只能通过导入从ERP系统获取，不能在UI中直接添加、编辑或删除。

2. **工单状态管理优化**：工单状态不应该由用户直接编辑，而应该通过状态机逻辑和明确的操作按钮（如"开始处理"、"审核通过"等）来管理。

## 主要变更内容

### 1. 操作历史记录只读化

#### 变更前
- 操作历史可能在UI中被创建、编辑或删除
- 没有明确限制操作历史的来源

#### 变更后
- 操作历史设置为只读资源，只允许查看和导入
- 移除了创建、编辑和删除操作
- 添加了专门的导入页面和功能
- 在ActiveAdmin中明确限制了actions为`:index, :show`

```ruby
# app/admin/operation_histories.rb
ActiveAdmin.register OperationHistory do
  actions :index, :show
  
  # 添加导入功能
  action_item :import, only: :index do
    link_to '导入操作历史', new_admin_operation_history_import_path
  end
  
  # 列表页操作仅保留"查看"
  index do
    # ...
    actions defaults: false do |operation_history|
      item "查看", admin_operation_history_path(operation_history)
    end
  end
end
```

### 2. 工单状态管理优化

#### 变更前
- 工单状态可能在表单中被直接编辑
- 状态字段包含在`permit_params`中，允许通过表单提交更改
- 状态变更逻辑分散在控制器和JavaScript中

#### 变更后
- 移除了表单中的状态直接编辑功能
- 从`permit_params`中移除了`status`字段
- 在表单中只显示状态，不允许编辑
- 添加了明确的状态操作按钮（开始处理、审核通过、审核拒绝等）
- 通过成员操作(member_action)实现状态变更，确保调用状态机方法
- 状态变更逻辑集中在服务层和状态机中

```ruby
# 表单中状态只显示，不允许编辑
<% unless f.object.new_record? %>
  <li class="string input optional">
    <label class="label">状态</label>
    <span><%= f.object.status %></span>
  </li>
<% end %>

# 添加状态操作按钮
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
```

## 实施建议

### 1. 操作历史只读化实施步骤

1. 更新`app/admin/operation_histories.rb`，限制actions为`:index, :show`
2. 添加导入功能和导入页面
3. 确保导入服务(`OperationHistoryImportService`)正常工作
4. 更新测试，确保操作历史只能通过导入添加

### 2. 工单状态管理优化实施步骤

1. 更新工单资源文件，从`permit_params`中移除`status`
2. 更新表单模板，将状态字段改为只读显示
3. 添加状态操作按钮和对应的成员操作
4. 确保服务层方法正确调用状态机事件
5. 更新测试，验证状态只能通过操作按钮变更

## 预期效果

### 1. 操作历史只读化

- 确保操作历史数据的完整性和一致性
- 明确操作历史的来源为ERP系统导入
- 防止手动创建或修改操作历史导致的数据不一致

### 2. 工单状态管理优化

- 确保工单状态变更符合业务流程规则
- 提高用户界面的直观性，通过明确的操作按钮引导用户
- 减少用户错误操作的可能性
- 集中状态变更逻辑，便于维护和扩展

## 结论

这些变更将使SCI2工单系统的UI实现更加符合业务需求，提高系统的可用性和数据一致性。通过限制操作历史的编辑和优化工单状态管理，系统将更加稳定和可靠，同时提供更好的用户体验。