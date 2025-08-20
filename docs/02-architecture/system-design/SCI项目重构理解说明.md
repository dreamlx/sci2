# SCI项目重构理解说明

## 目录

- [SCI项目概述](#sci项目概述)
- [SCI项目的工作流程](#sci项目的工作流程)
- [SCI项目的关键功能模块](#sci项目的关键功能模块)
- [SCI2 MVP与SCI的对比](#sci2-mvp与sci的对比)
- [工单与审核流程的关系](#工单与审核流程的关系)
- [建议的实施方向](#建议的实施方向)
- [结论](#结论)

## SCI项目概述

SCI是一个财务报销管理系统，主要用于处理报销单的收单、验真、分派、审核和追踪等流程。系统的核心实体是"报告"(Report)，它代表一个报销单，并通过状态机管理其生命周期。

## SCI项目的工作流程

SCI项目的工作流程是通过Report模型的状态机实现的，主要包括以下状态转换：

1. **未收单** → **已完成收单**：当快递收到报销单后，进行登记
2. **已完成收单** → **已完成验真**：对报销单进行验真
3. **已完成验真** → **已完成分派**：将报销单分派给审核人员
4. **已完成分派** → **已审核**：审核人员完成审核
5. **已审核** → **已追踪**：开始追踪报销单
6. **已追踪** → **追踪完成**：完成追踪

每个状态转换都有对应的反向操作，允许在必要时回退到前一个状态。

## SCI项目的关键功能模块

1. **报销单管理**：
   - 创建和更新报销单
   - 导入报销单数据
   - 冻结/解冻报销单
   - 查看报销单详情

2. **收单登记**：
   - 记录快递信息（快递公司、单号、收件日期）
   - 分配唯一的filing_id

3. **验真流程**：
   - 单个验真和批量验真
   - 记录验真人员和验真日期

4. **分派流程**：
   - 单个分派和批量分派
   - 分派给特定审核人员

5. **审核流程**：
   - 记录审核结果和审核日期
   - 处理VAT（增值税）相关信息

6. **追踪流程**：
   - 记录追踪结果和完成日期
   - 创建追踪日志

7. **问题管理**：
   - 创建与报销单关联的问题
   - 问题状态管理（待定、通过、拒绝）

8. **借阅管理**：
   - 记录报销单的借阅信息
   - 跟踪借阅和归还状态

## SCI2 MVP与SCI的对比

SCI2 MVP已经实现了一些基本功能，但与原SCI项目相比有一些差异：

1. **数据模型差异**：
   - SCI2使用了更现代化的数据模型，包括Reimbursement（报销单）、ExpressReceipt（快递收单）、WorkOrder（工单）等
   - SCI2引入了CommunicationRecord（沟通记录）和FeeDetailSelection（费用明细选择）等新模型

2. **工作流程差异**：
   - SCI2采用了工单（WorkOrder）作为核心工作单元，而不是直接操作报销单
   - SCI2支持多轮沟通流程，更适合复杂的审核场景
   - SCI2简化了一些流程，如MVP中不包含工单分配功能和多级审核流程

## 工单与审核流程的关系

在SCI2中，工单是处理报销单的主要方式，工单的状态流转如下：

1. **待处理** → **处理中**：开始处理工单
2. **处理中** → **需沟通**：发现问题需要与申请人沟通
3. **需沟通** → **等待回复**：已发送沟通信息
4. **等待回复** → **已回复**：收到申请人回复
5. **已回复** → **需沟通**（如问题未解决）或 **处理中**（如问题已解决）
6. **处理中** → **已完成**：工单处理完成

这个流程与SCI的审核流程有相似之处，但更加灵活，特别是在处理需要多轮沟通的情况时。

## 建议的实施方向

基于对SCI项目的分析和SCI2 MVP的现状，我建议在SCI2中实现以下功能：

1. **完善工单处理流程**：
   - 参考SCI的状态流转，完善工单的状态管理
   - 实现工单分派功能，允许将工单分派给不同的审核人员
   - 添加批量处理功能，提高效率

2. **增强审核功能**：
   - 实现多级审核流程，参考SCI的审核和复核机制
   - 添加审核结果记录和统计功能
   - 实现VAT相关的审核功能

3. **完善沟通记录功能**：
   - 增强多轮沟通的跟踪和管理
   - 添加沟通提醒和超时提醒功能
   - 实现沟通历史的完整记录和查询

4. **集成操作历史功能**：
   - 参考SCI的操作历史导入和处理机制
   - 实现基于操作历史的状态自动更新
   - 添加操作历史的查询和统计功能

5. **工单模型单表继承优化**：
   - 实现工单模型的单表继承(STI)，创建专门的子类处理不同类型的工单
   - 将类型特定的行为和验证移至相应的子类，提高代码组织性
   - 保持与现有代码的兼容性，同时提供更清晰的领域模型

## 工单单表继承实现方案

为了更好地支持不同类型的工单（审核工单、沟通工单、快递收单工单），建议采用单表继承(Single Table Inheritance, STI)模式重构工单模型。这种方法可以保持数据库结构简单的同时，提供更清晰的领域模型和更好的代码组织。

### 实现步骤

1. **添加type列**：
   ```ruby
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
   ```

2. **创建工单子类**：
   ```ruby
   # 基类
   class WorkOrder < ApplicationRecord
     # 共同属性和行为
   end

   # 审核工单
   class AuditWorkOrder < WorkOrder
     # 审核特定验证和方法
     def order_type
       'audit'
     end
   end

   # 沟通工单
   class CommunicationWorkOrder < WorkOrder
     # 沟通特定验证和方法
     def order_type
       'communication'
     end
   end

   # 快递收单工单
   class ExpressReceiptWorkOrder < WorkOrder
     # 快递收单特定验证和方法
     def order_type
       'express_receipt'
     end
   end
   ```

3. **更新控制器**：
   ```ruby
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

### 优势

1. **代码组织更清晰**：每种工单类型都有自己的类，包含特定的行为和验证
2. **更好的领域模型**：类结构更符合业务领域，提高代码可读性
3. **更容易扩展**：添加新的工单类型只需创建新的子类
4. **向后兼容**：通过重写order_type方法保持与现有代码的兼容性

### 与问题管理的集成

SCI的问题管理功能将通过CommunicationRecord模型实现，而不是直接在工单模型中实现。这样可以保持模型的职责清晰，同时提供更灵活的问题管理功能。

## 结论

SCI项目提供了一个完整的报销单处理流程，包括收单、验真、分派、审核和追踪等环节。SCI2 MVP已经实现了基本功能，但需要参考SCI的工作流程和审核流程，进一步完善工单处理和多轮沟通功能。

通过将SCI的成熟流程与SCI2的现代化架构相结合，并采用单表继承等优化技术，可以构建一个更加高效、灵活、可维护的报销管理系统，更好地满足财务部门的需求。