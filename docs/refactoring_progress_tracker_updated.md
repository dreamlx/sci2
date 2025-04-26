# SCI2 重构项目进展跟踪

**最后更新时间:** 2025-04-26 17:42

## 目录

- [1. 项目目标与范围](#1-项目目标与范围)
- [2. 核心架构设计 (重构后)](#2-核心架构设计-重构后)
  - [2.1 数据模型 (ERD)](#21-数据模型-erd)
  - [2.2 核心业务规则](#22-核心业务规则)
- [3. 相关文档链接](#3-相关文档链接)
- [4. 开发计划与状态](#4-开发计划与状态)
  - [阶段一：基础搭建与数据导入](#阶段一基础搭建与数据导入)
  - [阶段二：核心工单逻辑 (STI & 状态机)](#阶段二核心工单逻辑-sti--状态机)
  - [阶段三：ActiveAdmin界面与交互](#阶段三activeadmin界面与交互)
  - [阶段四：沟通与费用明细集成](#阶段四沟通与费用明细集成)
  - [阶段五：测试与优化](#阶段五测试与优化)
- [5. 技术债务与风险](#5-技术债务与风险)
- [6. 当前问题与解决方案](#6-当前问题与解决方案)

## 1. 项目目标与范围

*   **目标**: 基于新的设计方案（特别是WorkOrder模型的STI实现）完全重构SCI2系统，解决原有MVP版本的局限性，提高系统的可维护性和清晰度。
*   **范围**:
    *   后端重构：实现STI工单模型、状态机、服务对象等。
    *   前端界面：使用ActiveAdmin构建内部管理界面。
    *   核心功能：数据导入（CSV）、工单处理（审核、沟通、快递收单）、费用明细选择与验证、多轮沟通记录、基于操作历史的状态同步。
*   **用户**: 主要为内部财务/管理人员。

## 2. 核心架构设计 (重构后)

### 2.1 数据模型 (ERD)

*参考 `docs/1-900SCI2工单系统重构设计方案.md` 中的数据模型设计，核心是 `work_orders` 表采用STI。*

```mermaid
 classDiagram
     class WorkOrder {
         +String type # STI
         +String status
         +Integer parent_work_order_id
         +Integer reimbursement_id
         # ... 其他通用字段
     }

     class AuditWorkOrder {
         +String audit_result
         +DateTime audit_date
         # ... 审核特定字段
     }

     class CommunicationWorkOrder {
         +String resolution_summary
         # ... 沟通特定字段
     }

     class ExpressReceiptWorkOrder {
         +String tracking_number
         # ... 快递特定字段
     }

     class Reimbursement {
         +String invoice_number PK
         # ...
     }

     class FeeDetail {
         +Integer id PK
         +String document_number FK
         # ...
     }

     class FeeDetailSelection {
         +Integer selectable_id # Polymorphic FK
         +String selectable_type # Polymorphic FK
         +Integer fee_detail_id FK
         +String verification_result
     }

     class CommunicationRecord {
         +Integer work_order_id FK # Links to CommunicationWorkOrder
         # ...
     }

     class WorkOrderStatusChange {
        +Integer work_order_id FK
        +String from_status
        +String to_status
        # ...
     }

     WorkOrder <|-- AuditWorkOrder
     WorkOrder <|-- CommunicationWorkOrder
     WorkOrder <|-- ExpressReceiptWorkOrder
     WorkOrder --> Reimbursement
     WorkOrder "1" -- "*" WorkOrderStatusChange
     WorkOrder "1" -- "*" FeeDetailSelection : selectable
     WorkOrder "0..1" -- "*" WorkOrder : parent_work_order / child_work_orders
     FeeDetailSelection "*" -- "1" FeeDetail
     CommunicationWorkOrder "1" -- "*" CommunicationRecord

     # 其他关联: Reimbursement, ExpressReceipt, OperationHistory 等
     Reimbursement "1" -- "*" FeeDetail
```

### 2.2 核心业务规则

1.  **工单核心**: 使用 `WorkOrder` STI 模型管理不同类型的工单 (`AuditWorkOrder`, `CommunicationWorkOrder`, `ExpressReceiptWorkOrder`)。
2.  **状态管理**: 每种工单子类拥有独立的状态机 (`state_machines-activerecord`)，状态变更记录在 `WorkOrderStatusChange`。
3.  **数据导入**: 严格按照 报销单 -> 快递收单 -> 费用明细 -> 操作历史 的顺序导入CSV。
4.  **自动化工单**:
    *   `ExpressReceiptWorkOrder` 在快递收单导入匹配成功时自动创建。
    *   `AuditWorkOrder` 在非电子发票报销单导入时自动创建，或在 `ExpressReceiptWorkOrder` 完成后创建。
    *   `CommunicationWorkOrder` 在 `AuditWorkOrder` 审核过程中需要沟通时创建。
5.  **关联**:
    *   工单通过 `parent_work_order_id` 建立父子关系。
    *   工单通过 `FeeDetailSelection` (多态) 关联 `FeeDetail`。
    *   `CommunicationRecord` 关联到 `CommunicationWorkOrder`。
6.  **报销单关闭**: 依赖于导入的 `OperationHistory` 中的 "审批通过" 记录。

## 3. 相关文档链接

*   **重构设计方案**: `docs/1-900SCI2工单系统重构设计方案.md`
*   **TDD计划**: `docs/1-1工单系统TDD测试驱动开发计划.md`
*   **测试计划**: `docs/1-2SCI2工单系统测试计划_v2.md`
*   **任务分解**: `docs/1-3工单系统LLM开发任务分解.md`
*   **高阶计划**: `docs/refactoring_plan.md`
*   **原MVP设计**: `docs/2.工单系统MVP设计方案整合-更新版.md`
*   **数据导入格式**: `docs/3.数据导入格式参考.md`
*   **原SCI理解**: `docs/SCI项目重构理解说明.md`
*   **测试环境修复计划**: `docs/test_environment_fix_plan.md` (新增)
*   **技术债务分析**: `docs/technical_debt_analysis.md` (新增)

## 4. 开发计划与状态

*基于 `docs/refactoring_plan.md`*

### 阶段一：基础搭建与数据导入
*   [x] **A1**: 设置Rails项目/清理现有 (已检查相关迁移)
*   [x] **A2**: 实现核心模型: Reimbursement, ExpressReceipt, FeeDetail, OperationHistory (已检查并清理模型回调)
*   [x] **A3**: 实现数据导入服务 (CSV) (已创建/检查/重构服务类，将逻辑移出模型和AA控制器)
*   [x] **A4**: 为核心模型创建基础ActiveAdmin资源 (已确认资源文件存在)
*   [x] **A5**: 在ActiveAdmin中实现导入界面 (已确认导入视图存在)

### 阶段二：核心工单逻辑 (STI & 状态机)
*   [x] **B1**: 实现WorkOrder基类 + STI子类 (已创建子类文件)
*   [x] **B2**: 为每种WorkOrder类型实现状态机 (已实现基础状态机逻辑)
*   [x] **B3**: 实现WorkOrderStatusChange状态变更记录 (已确认基类回调存在)
*   [x] **B4**: 实现父/子工单关系 (已确认基类关联存在)
*   [x] **B5**: 模型和状态机的单元测试 (已添加/清理基础测试，修正集成测试，修复fixture错误，待完善)

### 阶段三：ActiveAdmin界面与交互
*   [x] **C1**: WorkOrder的ActiveAdmin资源 (Index/Show) (已清理，移除导入逻辑和通用表单)
*   [x] **C2**: 在AA中显示类型特定信息 (已确认show块使用is_a?渲染不同视图)
*   [x] **C3**: 在AA中实现状态转换操作/按钮 (已添加通用trigger_event action，更新show视图按钮)
*   [x] **C4**: 在AA中显示父/子关系 (已添加到STI show视图)
*   [x] **C5**: 在AA中显示状态历史 (已添加到STI show视图)

### 阶段四：沟通与费用明细集成
*   [x] **D1**: 实现CommunicationRecord模型 (已检查模型和测试)
*   [x] **D2**: 实现FeeDetailSelection模型 (已检查模型和测试)
*   [x] **D3**: 在AA中集成费用明细选择界面 (工单创建/编辑) (已恢复UI并检查action)
*   [x] **D4**: 在AA中集成沟通记录界面 (工单详情) (已检查局部视图并恢复action)
*   [x] **D5**: 实现创建CommunicationWorkOrder的逻辑 (已检查模型和服务中的实现)

### 阶段五：测试与优化
*   [ ] **E1**: 集成测试 (完整工作流) (**进行中 - 已分析 `users.email` UNIQUE constraint 错误，见 `docs/test_environment_fix_plan.md`**)
*   [ ] **E2**: 根据反馈优化ActiveAdmin界面 (可能包含少量定制UI)
*   [ ] **E3**: 解决Bug和性能问题
*   [ ] **E4**: 用户验收测试 (UAT)

## 5. 技术债务与风险

*详细分析见 `docs/technical_debt_analysis.md`*

*   [ ] **STI性能**: 单表继承在大数据量下可能存在查询性能问题，需关注索引优化和未来可能的归档策略。
*   [ ] **ActiveAdmin定制**: 复杂的定制UI需求可能增加ActiveAdmin的开发和维护成本。
*   [ ] **测试覆盖率**: 确保重构过程中有足够的测试覆盖，特别是状态机和核心业务逻辑。
*   [ ] **数据迁移**: (如果需要从旧MVP迁移数据) 需要制定详细的数据迁移计划。
*   [ ] **依赖管理**: 保持Gemfile依赖更新。
*   [ ] **测试环境设置**: 集成测试中反复出现 `users.email` UNIQUE constraint 错误，需要排查测试环境的 `setup` 和 fixture 加载逻辑。

## 6. 当前问题与解决方案

### 6.1 测试环境中的 `users.email` UNIQUE constraint 错误

**问题描述**:
在集成测试阶段遇到 `users.email` UNIQUE constraint 错误，导致测试失败。这个问题出现在 `CompleteWorkflowTest` 中，阻碍了项目的进展。

**原因分析**:
1. 测试并行执行导致的冲突
2. 不一致的用户创建方法
3. 测试数据清理不完整
4. ExpressReceipt 与 User 邮箱关联

**解决方案**:
详细的修复步骤见 `docs/test_environment_fix_plan.md`，主要包括：
1. 修复 CompleteWorkflowTest 的 setup 方法，添加 User 和 AdminUser 表的清理
2. 统一 sign_in_admin 方法，确保使用动态生成的邮箱
3. 修改 create_test_express_receipt 方法，使用动态生成的收件人
4. 如有必要，禁用测试并行执行或使用数据库事务隔离测试

### 6.2 下一步计划

1. 实施测试环境修复计划
2. 完成集成测试
3. 根据技术债务分析文档，制定长期改进计划
4. 继续推进阶段五的其他任务