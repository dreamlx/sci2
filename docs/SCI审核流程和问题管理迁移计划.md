# SCI审核流程和问题管理迁移计划

## 目录

- [概述](#概述)
- [审核流程迁移](#审核流程迁移)
  - [SCI审核流程分析](#sci审核流程分析)
  - [SCI2工单审核功能增强](#sci2工单审核功能增强)
  - [实施步骤](#实施步骤)
- [问题管理迁移](#问题管理迁移)
  - [SCI问题管理分析](#sci问题管理分析)
  - [SCI2沟通记录功能增强](#sci2沟通记录功能增强)
  - [实施步骤](#实施步骤-1)
- [迁移时间表](#迁移时间表)
- [测试计划](#测试计划)

## 概述

本文档提供了将SCI项目中的审核流程和问题管理功能迁移到SCI2 MVP的详细计划。由于是MVP阶段，我们将优先实现核心功能，暂不考虑多人分配功能。

## 审核流程迁移

### SCI审核流程分析

SCI项目中的审核流程主要包括以下步骤：

1. **分派**：将报销单分派给审核人员（在MVP中暂不考虑多人分配）
2. **审核**：审核人员审核报销单并记录审核结果
3. **审核结果处理**：根据审核结果进行后续处理
   - 如果审核通过，报销单状态变为"已审核"
   - 如果审核不通过，可能需要创建问题或退回到前一状态

关键功能点：
- 审核结果记录（通过/暂缓）
- 审核日期记录
- VAT（增值税）相关信息处理
- 审核撤销功能

### SCI2工单审核功能增强

在SCI2中，我们将通过以下方式增强工单的审核功能：

1. **工单状态扩展**：
   - 添加"审核中"状态
   - 添加"审核通过"和"审核不通过"状态

2. **审核结果记录**：
   - 添加审核结果字段（通过/暂缓/不通过）
   - 添加审核日期字段
   - 添加审核意见字段

3. **VAT信息处理**：
   - 在费用明细中添加VAT相关字段
   - 实现VAT信息的验证和处理功能

4. **审核撤销功能**：
   - 实现审核结果撤销功能
   - 记录撤销原因和时间

### 实施步骤

1. **数据模型更新**：
   ```ruby
   # 在WorkOrder模型中添加审核相关字段
   add_column :work_orders, :audit_result, :string
   add_column :work_orders, :audit_date, :datetime
   add_column :work_orders, :audit_comment, :text
   add_column :work_orders, :vat_verified, :boolean, default: false
   
   # 在FeeDetail模型中添加VAT相关字段
   add_column :fee_details, :tax_code, :string
   add_column :fee_details, :tax_amount, :decimal, precision: 10, scale: 2
   add_column :fee_details, :deduct_tax_amount, :decimal, precision: 10, scale: 2
   ```

2. **工单状态流转更新**：
   ```ruby
   # 在WorkOrder模型中更新状态机定义
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

3. **控制器更新**：
   ```ruby
   # 在WorkOrdersController中添加审核相关方法
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

4. **视图更新**：
   - 创建审核表单视图
   - 更新工单详情页面，显示审核信息
   - 添加审核撤销按钮

## 问题管理迁移

### SCI问题管理分析

SCI项目中的问题管理主要包括以下功能：

1. **问题创建**：为报销单创建问题记录
2. **问题分类**：对问题进行分类（类别、问题、材料等）
3. **问题状态管理**：管理问题状态（待定、通过、拒绝）
4. **问题复制**：复制现有问题

关键功能点：
- 问题与报销单的关联
- 问题状态流转
- 问题详细信息记录（类别、问题描述、材料等）

### SCI2沟通记录功能增强

在SCI2中，我们将通过以下方式增强沟通记录功能：

1. **沟通记录扩展**：
   - 添加问题类别字段
   - 添加问题描述字段
   - 添加材料要求字段
   - 添加问题状态字段（待定、通过、拒绝）

2. **沟通记录管理**：
   - 实现沟通记录的创建、编辑和删除
   - 实现沟通记录的状态管理
   - 实现沟通记录的复制功能

3. **沟通记录与费用明细关联**：
   - 建立沟通记录与费用明细的关联
   - 在沟通记录中显示相关费用明细信息

### 实施步骤

1. **数据模型更新**：
   ```ruby
   # 在CommunicationRecord模型中添加问题管理相关字段
   add_column :communication_records, :category, :string
   add_column :communication_records, :question, :text
   add_column :communication_records, :material, :text
   add_column :communication_records, :problem_status, :string, default: 'pending'
   add_reference :communication_records, :fee_detail, foreign_key: true
   ```

2. **沟通记录状态流转更新**：
   ```ruby
   # 在CommunicationRecord模型中添加状态机
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

3. **控制器更新**：
   ```ruby
   # 在CommunicationRecordsController中添加问题管理相关方法
   def new
     @work_order = WorkOrder.find(params[:work_order_id])
     @communication_record = @work_order.communication_records.build
   end
   
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

4. **视图更新**：
   - 更新沟通记录表单，添加问题管理相关字段
   - 更新工单详情页面，显示沟通记录的问题信息
   - 添加沟通记录状态管理按钮
   - 添加沟通记录复制按钮

## 迁移时间表

| 阶段 | 任务 | 时间估计 |
|------|------|----------|
| 1 | 数据模型更新 | 2天 |
| 2 | 工单审核功能实现 | 3天 |
| 3 | 沟通记录功能增强 | 3天 |
| 4 | 用户界面更新 | 2天 |
| 5 | 测试和修复 | 2天 |
| 总计 | | 12天 |

## 测试计划

1. **单元测试**：
   - 测试工单状态流转
   - 测试沟通记录状态流转
   - 测试数据验证

2. **功能测试**：
   - 测试工单审核流程
   - 测试问题管理功能
   - 测试沟通记录创建和管理

3. **集成测试**：
   - 测试工单与沟通记录的交互
   - 测试费用明细与沟通记录的关联
   - 测试完整的审核和问题处理流程