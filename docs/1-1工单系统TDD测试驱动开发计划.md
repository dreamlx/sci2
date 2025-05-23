# 工单系统TDD测试驱动开发计划

## 目录

- [1. 项目概述](#1-项目概述)
- [2. TDD开发方法论](#2-tdd开发方法论)
- [3. 测试结构设计](#3-测试结构设计)
- [4. 测试用例规划](#4-测试用例规划)
- [5. 实现计划](#5-实现计划)
- [6. 重构策略](#6-重构策略)
- [7. 开发迭代计划](#7-开发迭代计划)
- [8. 质量保证措施](#8-质量保证措施)
- [9. 风险管理](#9-风险管理)

## 1. 项目概述

### 1.1 背景

当前系统是一个使用Rails和ActiveAdmin快速开发的MVP，已经实现了基本的数据导入功能和工单系统。根据测试计划，需要对系统进行重构，确保其符合测试用例中定义的所有功能和业务逻辑。

### 1.2 目标

1. 基于测试计划中的测试用例，实施测试驱动开发
2. 重构现有系统，确保其满足所有测试用例
3. 保持使用ActiveAdmin作为管理界面
4. 确保系统的可维护性和可扩展性
5. 提高代码质量和测试覆盖率

### 1.3 范围

本TDD计划涵盖以下功能模块的测试和实现：

1. 数据导入模块（报销单、快递收单、操作历史、费用明细）
2. 工单处理模块（快递收单工单、审核工单、沟通工单）
3. 工单状态流转模块
4. 工单关联关系模块
5. 费用明细验证模块
6. 集成测试场景

**第一阶段简化说明**：
- 仅实现CSV数据导入，不处理Excel文件
- 简化用户权限，假设只有一个admin用户可以操作所有环节
- 电子发票状态需要另外操作，仅确认字段存在

## 2. TDD开发方法论

### 2.1 TDD基本流程

我们将采用经典的TDD"红-绿-重构"循环：

```mermaid
graph LR
    A[编写失败的测试] --> B[运行测试确认失败]
    B --> C[编写最小实现代码]
    C --> D[运行测试确认通过]
    D --> E[重构代码]
    E --> A
```

### 2.2 TDD应用策略

1. **自顶向下与自底向上结合**：
   - 自顶向下：从高层业务需求开始，编写集成测试
   - 自底向上：为基础组件编写单元测试

2. **测试粒度**：
   - 单元测试：测试单个模型、方法的功能
   - 集成测试：测试多个组件之间的交互
   - 系统测试：测试完整的业务流程

3. **测试优先级**：
   - 优先测试核心业务逻辑
   - 优先测试高风险区域
   - 优先测试频繁变化的部分

### 2.3 TDD在Rails项目中的应用

在Rails项目中，我们将使用Minitest作为测试框架，并结合Rails提供的测试工具：

1. **模型测试**：使用`ActiveSupport::TestCase`
2. **控制器测试**：使用`ActionDispatch::IntegrationTest`
3. **系统测试**：使用`ActionDispatch::SystemTestCase`

## 3. 测试结构设计

### 3.1 测试目录结构

```
test/
├── models/                  # 模型单元测试
│   ├── reimbursement_test.rb
│   ├── express_receipt_test.rb
│   ├── operation_history_test.rb
│   ├── fee_detail_test.rb
│   ├── work_order_test.rb
│   └── fee_detail_selection_test.rb
├── services/                # 服务对象测试
│   ├── import_service_test.rb
│   ├── work_order_service_test.rb
│   └── fee_verification_service_test.rb
├── controllers/             # 控制器测试
│   ├── admin/
│   │   ├── reimbursements_controller_test.rb
│   │   ├── express_receipts_controller_test.rb
│   │   ├── work_orders_controller_test.rb
│   │   └── ...
├── integration/             # 集成测试
│   ├── data_import_test.rb
│   ├── work_order_flow_test.rb
│   └── fee_verification_test.rb
├── system/                  # 系统测试
│   ├── complete_workflow_test.rb
│   └── ui_interaction_test.rb
└── fixtures/                # 测试数据
    ├── files/
    │   ├── reimbursements.csv
    │   ├── express_receipts.csv
    │   ├── operation_histories.csv
    │   └── fee_details.csv
    ├── reimbursements.yml
    ├── express_receipts.yml
    ├── work_orders.yml
    └── ...
```

### 3.2 测试辅助工具

为了支持测试，我们将创建以下辅助模块：

1. **ImportTestHelper**：用于测试数据导入功能
   - 提供CSV测试文件加载方法
   - 提供导入成功/失败断言方法

2. **WorkOrderTestHelper**：用于测试工单状态流转
   - 提供创建特定状态工单的方法
   - 提供状态变更断言方法

3. **测试数据准备**：
   - 创建各类型测试数据的固定装置(fixtures)
   - 准备CSV测试文件

## 4. 测试用例规划

### 4.1 数据导入测试

#### 4.1.1 报销单导入测试

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| IMP-R-001 | 导入标准CSV格式报销单 | 验证成功导入、数据正确性、状态设置 | 高 |
| IMP-R-005 | 导入格式错误的报销单文件 | 验证错误处理、错误消息显示 | 中 |
| IMP-R-006 | 导入重复的报销单 | 验证重复检测、更新已存在记录 | 高 |

**注意**：第一阶段不测试Excel导入和电子发票特定处理，但需确保电子发票字段存在。

#### 4.1.2 快递收单导入测试

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| IMP-E-001 | 导入匹配已有报销单的快递收单 | 验证关联、工单创建、状态更新 | 高 |
| IMP-E-002 | 导入未匹配报销单的快递收单 | 验证未匹配处理、警告显示 | 高 |
| IMP-E-004 | 导入多次收单的情况 | 验证多收单处理、多工单创建 | 中 |
| IMP-E-005 | 导入格式错误的快递收单文件 | 验证错误处理、错误消息显示 | 中 |

**注意**：第一阶段不测试Excel导入。

#### 4.1.3 费用明细导入测试

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| IMP-F-001 | 导入匹配已有报销单的费用明细 | 验证关联、验证状态设置 | 高 |
| IMP-F-002 | 导入未匹配报销单的费用明细 | 验证未匹配处理、警告显示 | 中 |
| IMP-F-004 | 导入多种费用类型的明细 | 验证费用类型识别 | 中 |
| IMP-F-005 | 导入格式错误的费用明细文件 | 验证错误处理、错误消息显示 | 中 |
| IMP-F-006 | 导入重复的费用明细 | 验证重复检测、跳过处理 | 高 |

**注意**：第一阶段不测试Excel导入。

#### 4.1.4 操作历史导入测试

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| IMP-O-001 | 导入匹配已有报销单的操作历史 | 验证关联 | 高 |
| IMP-O-002 | 导入审批通过类型的操作历史 | 验证报销单状态更新 | 高 |
| IMP-O-004 | 导入未匹配报销单的操作历史 | 验证未匹配处理、警告显示 | 中 |
| IMP-O-005 | 导入格式错误的操作历史文件 | 验证错误处理、错误消息显示 | 中 |
| IMP-O-006 | 导入重复的操作历史 | 验证重复检测、跳过处理 | 高 |

**注意**：第一阶段不测试Excel导入。

#### 4.1.5 导入顺序测试

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| IMP-S-001 | 按正确顺序导入所有数据 | 验证关联关系、状态更新 | 高 |
| IMP-S-002 | 颠倒顺序导入数据 | 验证系统处理能力、最终一致性 | 中 |
| IMP-S-003 | 混合顺序多次导入 | 验证系统处理能力、最终一致性 | 中 |

### 4.2 工单状态流转测试

#### 4.2.1 快递收单工单状态流转测试

快递收单工单在导入时自动创建并设置为已完成状态，无需状态流转。

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| WF-E-001 | 快递收单工单自动创建 | 验证自动创建、状态设置 | 高 |
| WF-E-002 | 快递收单工单关联报销单 | 验证关联、报销单状态更新 | 高 |
| WF-E-003 | 快递收单工单状态变更记录 | 验证状态记录、操作人记录 | 中 |

#### 4.2.2 审核工单状态流转测试

审核工单状态流转图：

```
[创建] --> pending --> processing --> rejected/approved
```

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| WF-A-001 | 审核工单基础状态流转-通过路径 | 验证状态流转、费用明细状态更新 | 高 |
| WF-A-002 | 审核工单基础状态流转-不通过路径 | 验证状态流转、费用明细状态更新 | 高 |
| WF-A-003 | 审核工单处理中保存 | 验证状态保存、费用明细状态更新 | 中 |
| WF-A-004 | 审核工单必填字段验证 | 验证必填字段检查 | 高 |
| WF-A-005 | 审核工单问题类型必填验证 | 验证问题类型必填检查 | 高 |
| WF-A-006 | 审核工单状态变更记录 | 验证状态变更记录 | 中 |
| WF-A-007 | 审核工单非法状态转换 | 验证非法状态转换拒绝 | 中 |
| WF-A-008 | 审核工单备注字段添加 | 验证备注字段可添加和保存 | 高 |

**注意**：审核工单需要支持备注(text)字段的添加。

#### 4.2.3 沟通工单状态流转测试

沟通工单状态流转图：

```
[创建] --> pending --> processing/needs_communication --> rejected/approved
```

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| WF-C-001 | 沟通工单通过流程 | 验证状态流转、费用明细状态更新 | 高 |
| WF-C-002 | 沟通工单不通过流程 | 验证状态流转、费用明细状态更新 | 高 |
| WF-C-003 | 沟通工单需要沟通状态 | 验证状态流转、费用明细状态更新 | 高 |
| WF-C-004 | 沟通工单必填字段验证 | 验证必填字段检查 | 高 |
| WF-C-005 | 沟通工单添加沟通记录 | 验证沟通记录添加 | 中 |
| WF-C-006 | 沟通工单状态变更记录 | 验证状态变更记录 | 中 |
| WF-C-007 | 沟通工单非法状态转换 | 验证非法状态转换拒绝 | 中 |
| WF-C-008 | 沟通工单备注字段添加 | 验证备注字段可添加和保存 | 高 |
| WF-C-009 | 沟通工单沟通记录字段添加 | 验证沟通记录字段可添加和保存 | 高 |

**注意**：沟通工单需要支持备注(text)字段和沟通记录(text)字段的添加。

### 4.3 工单关联关系测试

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| REL-001 | 工单与报销单关联 | 验证关联关系建立 | 高 |
| REL-002 | 一个报销单多个工单 | 验证多工单关联 | 高 |
| REL-003 | 工单与费用明细关联 | 验证工单与费用明细关联 | 高 |
| REL-004 | 报销单状态与费用明细状态联动 | 验证状态联动逻辑 | 高 |
| REL-005 | 删除报销单对工单的影响 | 验证级联删除处理 | 低 |
| REL-006 | 工单创建入口限制 | 验证创建入口限制 | 中 |

**注意**：第一阶段不考虑多用户权限，默认一个人可以操作所有环节。

### 4.4 费用明细验证测试

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| FEE-001 | 选择费用明细关联到工单 | 验证关联、状态设置 | 高 |
| FEE-002 | 批量全选关联费用明细 | 验证批量关联 | 中 |
| FEE-003 | 工单状态变更影响费用明细状态 | 验证状态联动 | 高 |
| FEE-004 | 费用明细关联多个工单 | 验证多工单关联、状态更新 | 高 |
| FEE-005 | 费用明细查看关联工单 | 验证关联工单显示 | 高 |
| FEE-006 | 费用明细状态影响报销单状态 | 验证状态联动 | 高 |
| FEE-007 | 费用明细验证结果记录 | 验证结果记录 | 中 |
| FEE-008 | 费用明细问题标记 | 验证问题标记、记录 | 高 |

### 4.5 集成测试场景

| 测试ID | 测试场景 | 测试要点 | 优先级 |
|--------|----------|----------|--------|
| INT-001 | 完整报销流程-快递收单到审核完成 | 验证完整流程、状态变更 | 高 |
| INT-002 | 完整报销流程-包含沟通处理 | 验证完整流程、状态变更 | 高 |
| INT-004 | 费用明细多工单关联测试 | 验证多工单关联、状态更新 | 高 |
| INT-005 | 操作历史影响报销单状态 | 验证状态联动 | 中 |
| INT-006 | 电子发票标志测试 | 验证电子发票标志设置和显示 | 中 |
| INT-007 | 多个报销单并行处理 | 验证并行处理能力 | 低 |

**注意**：第一阶段假设只有一个admin用户，简化权限测试。

## 5. 实现计划

### 5.1 模型实现

1. **工单基类实现**：
   - 实现工单基类(WorkOrder)
   - 实现状态变更记录机制
   - 实现父子工单关联关系

2. **审核工单实现**：
   - 实现审核工单(AuditWorkOrder)模型
   - 实现状态流转逻辑
   - 实现备注字段

3. **沟通工单实现**：
   - 实现沟通工单(CommunicationWorkOrder)模型
   - 实现状态流转逻辑
   - 实现备注字段和沟通记录字段

4. **快递收单工单实现**：
   - 实现快递收单工单(ExpressReceiptWorkOrder)模型
   - 实现状态设置逻辑

5. **费用明细选择实现**：
   - 实现费用明细选择(FeeDetailSelection)模型
   - 实现多态关联

### 5.2 服务对象实现

1. **导入服务实现**：
   - 实现报销单导入服务
   - 实现快递收单导入服务
   - 实现费用明细导入服务
   - 实现操作历史导入服务

2. **工单处理服务实现**：
   - 实现审核工单处理服务
   - 实现沟通工单处理服务
   - 实现快递收单工单处理服务

3. **费用明细验证服务实现**：
   - 实现费用明细验证服务
   - 实现状态联动逻辑

### 5.3 控制器与视图实现

1. **工单控制器实现**：
   - 实现工单基础控制器
   - 实现审核工单控制器
   - 实现沟通工单控制器
   - 实现快递收单工单控制器

2. **ActiveAdmin资源配置**：
   - 配置工单资源
   - 配置报销单资源
   - 配置费用明细资源

3. **自定义表单与视图**：
   - 实现工单创建表单
   - 实现工单处理表单
   - 实现费用明细选择界面

## 6. 重构策略

### 6.1 现有代码重构

1. **数据结构调整**：
   - 实施数据库迁移，调整工单表结构以支持STI
   - 创建状态变更记录表
   - 添加备注和沟通记录字段

2. **模型实现**：
   - 实现工单基类和子类
   - 为各工单类型实现独立的状态机
   - 添加工单之间的父子关联关系
   - 实现沟通记录和费用明细选择关联模型

3. **服务对象实现**：
   - 重构导入服务，确保正确处理各种导入场景并自动创建工单
   - 实现工单处理服务

4. **控制器与视图**：
   - 实现工单基础控制器和类型特定的控制器逻辑
   - 优化ActiveAdmin界面，支持不同工单类型的显示、编辑和状态转换
   - 添加费用明细选择和沟通记录显示界面

### 6.2 重构步骤

实施计划分为四个主要阶段：

1. **数据结构调整**
   - 数据库迁移设计
   - 执行数据库迁移

2. **模型实现**
   - 工单基类实现
   - 审核工单模型
   - 沟通工单模型
   - 快递收单工单模型

3. **控制器与视图**
   - 工单基础控制器
   - 审核工单控制器与视图
   - 沟通工单控制器与视图
   - 快递收单工单控制器与视图

4. **测试与部署**
   - 单元测试
   - 集成测试
   - 用户验收测试
   - 生产环境部署

## 7. 开发迭代计划

实施计划分为四个主要阶段，时间安排如下：

### 7.1 数据结构调整（5月1日 - 5月4日）

- 数据库迁移设计（2天）
- 执行数据库迁移（1天）

### 7.2 模型实现（5月5日 - 5月12日）

- 工单基类实现（2天）
- 审核工单模型（2天）
- 沟通工单模型（2天）
- 快递收单工单模型（1天）

### 7.3 控制器与视图（5月13日 - 5月23日）

- 工单基础控制器（2天）
- 审核工单控制器与视图（3天）
- 沟通工单控制器与视图（3天）
- 快递收单工单控制器与视图（2天）

### 7.4 测试与部署（5月24日 - 6月1日）

- 单元测试（3天）
- 集成测试（3天）
- 用户验收测试（2天）
- 生产环境部署（1天）

## 8. 质量保证措施

### 8.1 代码审查

- 每个功能模块完成后进行代码审查
- 使用Pull Request流程，确保至少一名团队成员审查代码
- 关注点：代码质量、测试覆盖率、设计模式应用

### 8.2 持续集成

- 配置CI/CD流水线，确保每次提交都运行测试
- 设置代码质量门禁，不允许测试覆盖率下降
- 自动化部署流程，减少人为错误

### 8.3 测试覆盖率目标

- 模型层：90%以上
- 服务层：85%以上
- 控制器层：80%以上
- 整体覆盖率：85%以上

## 9. 风险管理

### 9.1 潜在风险

1. **表膨胀风险**：
   - 随着工单数量增加，单表可能变得庞大
   - 应对：定期归档历史数据，优化索引，考虑分区表

2. **查询性能**：
   - 不同类型工单的查询可能需要额外的过滤条件
   - 应对：添加复合索引，优化查询语句，使用缓存

3. **代码维护**：
   - STI模式下子类特有字段在基类中也存在，可能造成混淆
   - 应对：良好的代码注释和文档，明确字段用途

### 9.2 应对措施

1. **性能监控**：
   - 设置性能基准
   - 定期进行性能测试
   - 监控生产环境查询性能

2. **代码质量保证**：
   - 严格的代码审查流程
   - 持续重构，消除技术债务
   - 完善的文档和注释

3. **灵活的设计**：
   - 保持设计的灵活性，便于后续调整
   - 避免过度设计，专注于满足当前需求
   - 预留扩展点，便于未来功能扩展
