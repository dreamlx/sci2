# 简化费用明细状态设计和实现

## 问题描述

当前费用明细存在“全局状态”（`FeeDetail.verification_status`）和“工单内状态”（`FeeDetailSelection.verification_status`）两个状态，设计和实现上存在混淆，导致在更新工单处理意见时，费用明细状态未能正确更新。

原始设计需求：
- 费用明细导入后默认为 pending。
- 创建工单选择费用明细后，根据处理意见更新费用明细状态（审核通过 -> verified，其他 -> problematic）。
- 费用明细可关联到多个工单。

## 简化的设计方案

为了简化逻辑并解决当前 bug，我们采纳以下简化的设计：

*   **数据库层面**：
    *   `fee_details` 表保留 `verification_status` 字段作为费用明细的唯一状态。
    *   `fee_detail_selections` 表保留 `fee_detail_id` 和 `work_order_id` 字段，用于记录关联关系。**移除 `verification_status` 字段**。
*   **模型层面**：
    *   `FeeDetail` 模型：负责管理费用明细的唯一状态。
    *   `FeeDetailSelection` 模型：仅用于建立 `FeeDetail` 和 `WorkOrder` 之间的关联。
    *   `WorkOrder` 模型：在状态更新后，触发更新关联费用明细状态的逻辑。
*   **状态更新逻辑**：当 `WorkOrder` 的状态更新为 `approved` 或 `rejected` 时，遍历所有**与该工单关联**的 `FeeDetail`，并将其 `verification_status` 更新为 `verified` 或 `problematic`。费用明细的最终状态由**最后一个**更新状态的关联工单决定。

## 实施计划

1.  创建数据库迁移，移除 `fee_detail_selections` 表中的 `verification_status` 字段。
2.  修改 `WorkOrder` 模型中的 `set_status_based_on_processing_opinion` 方法，调整更新费用明细状态的逻辑，使其根据工单的最终状态来更新关联的 `FeeDetail.verification_status`。
3.  修改 `FeeDetailVerificationService`，简化其逻辑，使其只负责更新 `FeeDetail.verification_status`。
4.  检查并更新 `FeeDetail` 模型中的 `mark_as_verified` 和 `mark_as_problematic` 方法，确保它们与新的服务逻辑兼容。
5.  检查 ActiveAdmin 中与 `FeeDetailSelection.verification_status` 相关的表单和显示逻辑，进行相应的移除或修改。
6.  修改测试用例，进行全面的测试，确保费用明细状态根据工单状态正确更新，并且多工单关联功能正常。