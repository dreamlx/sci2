# SCI2工单系统界面调整方案补充

## 1. 工单状态处理逻辑优化

在实现新的界面交互方式后，我们发现工单状态没有根据处理意见自动更新的问题。为解决这个问题，我们对系统进行了以下优化：

### 1.1 WorkOrder模型优化

在WorkOrder模型中添加了`set_status_based_on_processing_opinion`回调函数，用于根据处理意见自动更新工单状态：

```ruby
# 回调
after_save :set_status_based_on_processing_opinion, if: -> { processing_opinion_changed? && persisted? }

# 根据处理意见设置状态
def set_status_based_on_processing_opinion
  return unless respond_to?(:processing_opinion)
  
  case processing_opinion
  when '可以通过'
    approve if can_approve?
  when '无法通过'
    reject if can_reject?
  end
end
```

### 1.2 AuditWorkOrder模型优化

在AuditWorkOrder模型中添加了`sync_audit_result_with_status`回调函数，用于在状态变更时同步更新审核结果和审核日期：

```ruby
# 回调
after_save :sync_audit_result_with_status, if: -> { status_changed? && persisted? }

# 同步状态和审核结果
def sync_audit_result_with_status
  case status
  when 'approved'
    self.audit_result = 'approved'
    self.audit_date = Time.current
  when 'rejected'
    self.audit_result = 'rejected'
    self.audit_date = Time.current
  end
  
  # 避免触发无限循环
  self.class.skip_callback(:save, :after, :sync_audit_result_with_status)
  save
  self.class.set_callback(:save, :after, :sync_audit_result_with_status, if: -> { status_changed? && persisted? })
end
```

### 1.3 WorkOrderService优化

修改了WorkOrderService的`update`方法，确保在处理意见变更时自动调用相应的`approve`或`reject`方法：

```ruby
# General update method - now handles status changes based on processing_opinion
def update(params = {})
  # 保存原始处理意见
  original_processing_opinion = @work_order.processing_opinion
  
  # 分配属性
  assign_shared_attributes(params)
  
  # 检查处理意见是否变更
  processing_opinion_changed = @work_order.processing_opinion != original_processing_opinion
  
  # 如果处理意见变更为"可以通过"或"无法通过"，则调用相应的方法
  if processing_opinion_changed
    case @work_order.processing_opinion
    when '可以通过'
      return approve(params)
    when '无法通过'
      return reject(params)
    end
  end
  
  # 其他情况正常保存
  save_work_order("更新")
end
```

## 2. 状态流转逻辑说明

### 2.1 工单状态流转

工单状态流转遵循以下规则：

1. 新建工单初始状态为"pending"
2. 当处理意见设置为"可以通过"时，状态变更为"approved"
3. 当处理意见设置为"无法通过"时，状态变更为"rejected"
4. 状态为"approved"或"rejected"的工单可以标记为"completed"

### 2.2 费用明细状态流转

费用明细状态流转遵循"最新工单决定"原则：

1. 如果最新关联的工单状态为"approved"，则费用明细状态为"verified"
2. 如果最新关联的工单状态为"rejected"，则费用明细状态为"problematic"
3. 如果最新关联的工单状态为"pending"，则费用明细状态为"pending"

### 2.3 报销单状态流转

报销单状态根据其关联的费用明细状态自动更新：

1. 如果所有费用明细状态为"verified"，则报销单状态为"closed"
2. 如果存在状态为"problematic"的费用明细，则报销单状态为"processing"
3. 如果存在状态为"pending"的费用明细，则报销单状态为"processing"

## 3. 界面交互与状态关系

在新的界面交互方式下，状态处理逻辑与用户操作的关系如下：

1. **费用明细选择**：
   - 用户选择费用明细后，系统自动按费用类型分组显示标签
   - 费用明细选择不直接影响工单状态

2. **问题类型选择**：
   - 用户可以选择多个问题类型
   - 问题类型选择不直接影响工单状态

3. **处理意见设置**：
   - 用户选择"可以通过"时，工单状态自动变更为"approved"
   - 用户选择"无法通过"时，工单状态自动变更为"rejected"
   - 处理意见是决定工单状态的关键因素

4. **审核意见输入**：
   - 用户手动输入审核意见
   - 审核意见不直接影响工单状态

## 4. 测试要点

在测试新的界面交互和状态处理逻辑时，需要重点关注以下方面：

1. **处理意见与状态关系**：
   - 验证设置处理意见为"可以通过"时，工单状态是否正确变更为"approved"
   - 验证设置处理意见为"无法通过"时，工单状态是否正确变更为"rejected"

2. **费用明细状态更新**：
   - 验证工单状态变更后，关联的费用明细状态是否正确更新
   - 验证"最新工单决定"原则是否正确实现

3. **报销单状态更新**：
   - 验证费用明细状态变更后，报销单状态是否正确更新

4. **界面交互一致性**：
   - 验证费用类型标签显示是否正确
   - 验证问题类型多选是否正常工作
   - 验证审核意见输入是否正常工作

## 5. 后续优化建议

1. **状态显示优化**：
   - 在界面上更明确地显示工单状态和处理意见的关系
   - 添加状态变更历史记录查看功能

2. **批量操作优化**：
   - 支持批量设置处理意见和状态
   - 支持批量关联费用明细

3. **用户体验优化**：
   - 添加状态变更提示和确认机制
   - 优化状态变更的视觉反馈