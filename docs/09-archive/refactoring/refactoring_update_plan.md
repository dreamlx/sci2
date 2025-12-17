# SCI2 工单系统重构更新计划

## 1. 背景

根据最新的需求讨论和测试计划分析，我们需要对 SCI2 工单系统进行一些重要更新，以确保系统设计与实现与业务需求保持一致。主要更新包括：

1. 沟通工单的 `needs_communication` 实现为布尔字段而非状态值
2. 费用明细状态简化，移除 `FeeDetailSelection` 中的 `verification_status` 字段
3. 处理意见与工单状态关系的明确定义和实现

本文档重点关注这些更新的实施计划。

## 2. 更新内容

### 2.1 沟通工单的 needs_communication 实现

**当前问题**：沟通工单的"需要沟通"标记在设计上存在混淆，既被视为状态值又被视为标志。

**解决方案**：将 `needs_communication` 实现为布尔字段，而非状态值，使其可以在任何状态下设置或取消。

**实施步骤**：

1. 确认 `work_orders` 表中已有 `needs_communication` 布尔字段（默认为 false）
2. 在 `CommunicationWorkOrder` 模型中添加便捷方法：
   ```ruby
   def needs_communication?
     self.needs_communication == true
   end
   
   def mark_needs_communication!
     update(needs_communication: true)
   end
   
   def unmark_needs_communication!
     update(needs_communication: false)
   end
   ```
3. 在 `CommunicationWorkOrderService` 中添加 `toggle_needs_communication` 方法：
   ```ruby
   def toggle_needs_communication(value = nil)
     value = !@communication_work_order.needs_communication if value.nil?
     @communication_work_order.update(needs_communication: value)
   end
   ```
4. 在 ActiveAdmin 中添加切换此标志的 UI 控件

### 2.2 费用明细状态简化

**当前问题**：费用明细存在"全局状态"（`FeeDetail.verification_status`）和"工单内状态"（`FeeDetailSelection.verification_status`）两个状态，设计和实现上存在混淆，导致在更新工单处理意见时，费用明细状态未能正确更新。

**解决方案**：移除 `FeeDetailSelection` 中的 `verification_status` 字段，使 `FeeDetail` 模型完全负责状态管理。

**实施步骤**：

1. 创建迁移脚本 `20250501051827_remove_verification_status_from_fee_detail_selections.rb`：
   ```ruby
   class RemoveVerificationStatusFromFeeDetailSelections < ActiveRecord::Migration[7.0]
     def change
       remove_column :fee_detail_selections, :verification_status, :string
     end
   end
   ```

2. 创建 Rake 任务 `fix_fee_detail_selections.rake` 确保数据一致性：
   ```ruby
   namespace :sci2 do
     desc "Fix fee_detail_selections by removing verification_status values"
     task fix_fee_detail_selections: :environment do
       # 收集所有 FeeDetailSelection 中的状态信息
       # 根据优先级（verified > problematic > pending）更新对应的 FeeDetail 记录
     end
   end
   ```

3. 更新 `FeeDetailSelection` 模型，移除与 `verification_status` 相关的验证和方法

4. 更新 `WorkOrder` 基类中的 `update_associated_fee_details_status` 方法，直接更新 `FeeDetail` 的状态

5. 更新 `AuditWorkOrder` 和 `CommunicationWorkOrder` 中的 `select_fee_detail` 方法，移除状态同步逻辑

6. 简化 `FeeDetailVerificationService`，直接更新 `FeeDetail.verification_status`

7. 更新 ActiveAdmin 表单和显示逻辑，移除对 `FeeDetailSelection.verification_status` 的引用

### 2.3 处理意见与状态关系

**当前问题**：处理意见与工单状态的关系不够明确，导致状态更新不一致。

**解决方案**：在 `WorkOrder` 基类中添加 `set_status_based_on_processing_opinion` 回调方法，明确定义处理意见与状态的关系。

**实施步骤**：

1. 在 `WorkOrder` 基类中添加回调：
   ```ruby
   before_save :set_status_based_on_processing_opinion, if: :processing_opinion_changed?
   ```

2. 实现 `set_status_based_on_processing_opinion` 方法：
   ```ruby
   def set_status_based_on_processing_opinion
     return unless self.is_a?(AuditWorkOrder) || self.is_a?(CommunicationWorkOrder)
     
     case processing_opinion
     when nil, ""
       # 保持当前状态
     when "审核通过"
       self.status = "approved" unless status == "approved"
     when "无法通过"
       self.status = "rejected" unless status == "rejected"
     else
       self.status = "processing" if status == "pending"
     end
   end
   ```

3. 在服务层方法中添加注释，明确说明处理意见与状态的关系由模型层处理

## 3. 测试计划

### 3.1 单元测试

1. 测试 `CommunicationWorkOrder` 的 `needs_communication` 布尔字段功能
2. 测试 `WorkOrder` 的 `set_status_based_on_processing_opinion` 方法
3. 测试 `FeeDetail` 状态更新逻辑
4. 测试 `FeeDetailVerificationService` 的简化版本

### 3.2 集成测试

1. 测试工单状态流转与费用明细状态的联动
2. 测试处理意见变更对工单状态的影响
3. 测试沟通工单的 `needs_communication` 标志在不同状态下的行为
4. 测试费用明细关联多个工单时的状态更新逻辑

### 3.3 系统测试

1. 测试完整的报销流程，包括快递收单、审核和沟通
2. 测试 UI 中的 `needs_communication` 切换功能
3. 测试费用明细状态在 UI 中的正确显示

## 4. 实施路线图

1. **准备阶段**（5月1日）
   - 创建迁移脚本和 Rake 任务
   - 更新模型实现
   - 更新服务层实现

2. **测试阶段**（5月2日 - 5月3日）
   - 运行单元测试和集成测试
   - 修复发现的问题
   - 运行系统测试

3. **部署阶段**（5月4日）
   - 运行 Rake 任务确保数据一致性
   - 应用数据库迁移
   - 部署更新后的代码
   - 监控系统运行情况

## 5. 风险与缓解措施

1. **数据丢失风险**：
   - 缓解：在应用迁移前运行 Rake 任务，确保数据一致性
   - 缓解：备份数据库

2. **功能回归风险**：
   - 缓解：全面的测试覆盖
   - 缓解：分阶段部署，先在测试环境验证

3. **性能风险**：
   - 缓解：监控系统性能指标
   - 缓解：优化数据库查询

## 6. 结论

通过实施这些更新，我们将使 SCI2 工单系统的设计与实现与最新的业务需求保持一致，同时简化系统逻辑，提高代码质量和可维护性。这些更新将解决当前存在的问题，并为未来的功能扩展奠定更坚实的基础。