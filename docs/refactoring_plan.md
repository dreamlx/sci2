# SCI2 重构高阶计划

基于对现有文档的分析和讨论，我们确定采用ActiveAdmin作为前端界面，结合重构后的后端逻辑（基于STI的WorkOrder模型）进行开发。以下是高阶实施计划：

```mermaid
graph TD
    A[阶段一：基础搭建与数据导入] --> B[阶段二：核心工单逻辑 (STI & 状态机)];
    B --> C[阶段三：ActiveAdmin界面与交互];
    C --> D[阶段四：沟通与费用明细集成];
    D --> E[阶段五：测试与优化];

    subgraph A [阶段一：基础搭建与数据导入]
        A1[设置Rails项目/清理现有];
        A2[实现核心模型: Reimbursement, ExpressReceipt, FeeDetail, OperationHistory];
        A3[实现数据导入服务 (CSV)];
        A4[为核心模型创建基础ActiveAdmin资源];
        A5[在ActiveAdmin中实现导入界面];
    end

    subgraph B [阶段二：核心工单逻辑 (STI & 状态机)]
        B1[实现WorkOrder基类 + STI子类];
        B2[为每种WorkOrder类型实现状态机];
        B3[实现WorkOrderStatusChange状态变更记录];
        B4[实现父/子工单关系];
        B5[模型和状态机的单元测试];
    end

    subgraph C [阶段三：ActiveAdmin界面与交互]
        C1[WorkOrder的ActiveAdmin资源 (Index/Show)];
        C2[在AA中显示类型特定信息];
        C3[在AA中实现状态转换操作/按钮];
        C4[在AA中显示父/子关系];
        C5[在AA中显示状态历史];
    end

    subgraph D [阶段四：沟通与费用明细集成]
        D1[实现CommunicationRecord模型];
        D2[实现FeeDetailSelection模型];
        D3[在AA中集成费用明细选择界面 (工单创建/编辑)];
        D4[在AA中集成沟通记录界面 (工单详情)];
        D5[实现创建CommunicationWorkOrder的逻辑];
    end

     subgraph E [阶段五：测试与优化]
        E1[集成测试 (完整工作流)];
        E2[根据反馈优化ActiveAdmin界面];
        E3[解决Bug和性能问题];
        E4[用户验收测试 (UAT)];
     end

```

此计划旨在指导后续的开发实施工作。