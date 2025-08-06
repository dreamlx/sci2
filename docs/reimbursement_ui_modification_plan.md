# 报销单列表页面UI修改计划

## 📋 任务概述
删除报销单list页面中的指定菜单项和批量操作功能。

## 🎯 修改目标

### 需要删除的功能
1. **顶部菜单**: "批量分配报销单" 按钮
2. **批量操作**: "make as received" (mark_as_received)
3. **批量操作**: "start processing" (start_processing)

### 需要保留的功能
- **批量操作**: "assign to" (assign_to) - 下拉式批量分配功能

## 🔍 代码分析

### 文件位置
- 主要文件: `app/admin/reimbursements.rb`
- 视图文件: `app/views/admin/reimbursements/batch_assign.html.erb`
- 服务文件: `app/services/reimbursement_assignment_service.rb` (保留)

### 需要修改的代码段

#### 1. 删除 batch_action :mark_as_received (第104-109行)
```ruby
batch_action :mark_as_received do |ids|
   batch_action_collection.find(ids).each do |reimbursement|
      reimbursement.update(receipt_status: 'received', receipt_date: Time.current)
   end
   redirect_to collection_path, notice: "已将选中的报销单标记为已收单"
end
```

#### 2. 删除 batch_action :start_processing (第110-119行)
```ruby
batch_action :start_processing, if: proc { params[:scope] == 'pending' || params[:q].blank? } do |ids|
   batch_action_collection.find(ids).each do |reimbursement|
      begin
        reimbursement.start_processing!
      rescue StateMachines::InvalidTransition => e
        Rails.logger.warn "Batch action start_processing failed for Reimbursement #{reimbursement.id}: #{e.message}"
      end
   end
   redirect_to collection_path, notice: "已尝试将选中的报销单标记为处理中"
end
```

#### 3. 保留 batch_action :assign_to (第122-149行)
```ruby
# 这个功能需要保留 - 它是下拉式的批量分配功能
batch_action :assign_to,
             title: "批量分配报销单",
             # ... 其余代码保持不变
```

#### 4. 删除 action_item :batch_assign (第160-170行)
```ruby
action_item :batch_assign, only: :index, if: proc {
  true # 总是显示，但根据权限决定是否禁用
} do
  css_class = current_admin_user.super_admin? ? "button" : "button disabled_action"
  title = current_admin_user.super_admin? ? nil : '您没有权限执行分配操作，请联系超级管理员'
  
  link_to "批量分配报销单",
          collection_path(action: :batch_assign),
          class: css_class,
          title: title
end
```

#### 5. 删除 collection_action :batch_assign (第751-784行)
```ruby
collection_action :batch_assign, method: :get do
  # 获取未分配的报销单
  @reimbursements = Reimbursement.left_joins(:active_assignment)
                                .where(reimbursement_assignments: { id: nil })
                                .order(created_at: :desc)
  
  render "admin/reimbursements/batch_assign"
end

collection_action :batch_assign, method: :post do
  # ... 完整的POST处理逻辑
end
```

#### 6. 删除视图文件
- `app/views/admin/reimbursements/batch_assign.html.erb`

## 🔧 实施步骤

1. **删除批量操作**
   - 删除 `batch_action :mark_as_received`
   - 删除 `batch_action :start_processing`

2. **删除顶部菜单按钮**
   - 删除 `action_item :batch_assign`

3. **删除相关的collection_action**
   - 删除两个 `collection_action :batch_assign` 方法

4. **删除视图文件**
   - 删除 `batch_assign.html.erb`

5. **保留必要功能**
   - 确保 `batch_action :assign_to` 保持完整
   - 保留 `ReimbursementAssignmentService`

## ⚠️ 注意事项

1. **功能区别**:
   - `batch_action :assign_to` - 下拉式批量分配 (保留)
   - `action_item :batch_assign` - 独立页面批量分配 (删除)

2. **依赖关系**:
   - `ReimbursementAssignmentService.batch_assign` 方法被两个功能使用
   - 删除独立页面后，该服务仍被下拉式功能使用

3. **测试验证**:
   - 确保删除后 `assign_to` 批量操作正常工作
   - 验证页面不再显示已删除的按钮和操作

## 📝 修改后的预期效果

- ✅ 批量操作下拉菜单中只显示 "assign_to"
- ✅ 顶部不再显示 "批量分配报销单" 按钮
- ✅ 无法访问独立的批量分配页面
- ✅ 原有的 assign_to 功能正常工作