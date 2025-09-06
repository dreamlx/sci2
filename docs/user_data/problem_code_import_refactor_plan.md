# 问题代码导入功能改造方案 (v5 - 最终生产版)

## 1. 背景

当前系统的问题代码导入功能无法满足新的业务需求。核心挑战在于客户提供的数据编码体系复杂且存在歧义，而现有系统未能准确捕捉其背后的业务规则，特别是在前端问题选择的交互场景上。

## 2. 核心业务规则 (最终确认)

1.  **报销单类型 (EN/MN)**: 这是一个**派生值**，需根据报销单名称（如“个人日常”、“学术会议”）在业务逻辑中动态判断。
2.  **费用类型字符串不可靠**: 费用明细 (`FeeDetail`) 中的 `fee_type` 字段是用户手填的字符串，不规范且不可作为精确匹配的唯一依据。
3.  **最终查询逻辑**: 在前端为某个费用明细选择问题时，系统需要展示一个由两部分组成的列表：
    - **尽力精确匹配**: 尝试使用 `fee_detail` 的上下文（报销单类型, 会议类型）和 `fee_type` 字符串，去 `FeeType` 字典表中查找一个精确匹配的记录。如果找到，则返回该费用类型对应的所有问题。
    - **必定通用匹配**: **无论是否精确匹配成功**，总是返回该上下文（报销单类型, 会议类型）下，费用类型为**通用 (`expense_type_code: '00'`)** 的所有问题。

## 3. 最终改造方案

本方案旨在提供一个从数据标准、后端存储到前端消费的完整、健壮的端到端解决方案。

### 3.1 Step 1: 标准化数据输入

所有新数据都应按此格式提供，这将作为开发与业务之间的“技术合同”。

**CSV模板 (`problem_code_import_template.csv`):**
```csv
reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,legacy_problem_code,problem_title,sop_description,standard_handling
EN,00,个人,01,月度交通费,01,EN000101,"燃油费行程问题","根据SOP规定...","请根据要求..."
EN,00,个人,02,交通费-市内,01,EN000201,"出租车行程问题","根据SOP规定...","请根据要求..."
MN,01,学术论坛,01,会议讲课费,01,MN010101,"非讲者库讲者","根据SOP规定...","不符合要求..."
MN,01,学术论坛,00,通用,01,MN010001,"会议权限_学术论坛","根据SOP规定...","请提供..."
```

### 3.2 Step 2: 改造数据模型 (已完成)

1.  **修改 `ProblemType` 表**:
    - **Migration**: [`db/migrate/20251726000016_refactor_problem_types_v3.rb`](db/migrate/20251726000016_refactor_problem_types_v3.rb)
    - **内容**: 增加 `reimbursement_type_code`, `meeting_type_code`, `expense_type_code`, `legacy_problem_code` 字段；移除 `fee_type_id`；添加复合唯一索引。

2.  **修改 `ProblemType` 模型**:
    - **文件**: [`app/models/problem_type.rb`](app/models/problem_type.rb)
    - **内容**: 移除 `belongs_to :fee_type`；更新 `uniqueness` 验证以匹配新的复合索引。

### 3.3 Step 3: 重构服务层 (已完成)

1.  **重构 `ProblemCodeImportService`**:
    - **文件**: [`app/services/problem_code_import_service.rb`](app/services/problem_code_import_service.rb)
    - **职责**: 读取标准CSV，分别查找或创建 `FeeType` (作为字典) 和 `ProblemType` (包含完整上下文) 记录。

2.  **创建并实现 `ProblemFinderService`**:
    - **文件**: [`app/services/problem_finder_service.rb`](app/services/problem_finder_service.rb)
    - **职责**: 封装最终的“尽力精确匹配 + 必定通用匹配”查询逻辑，作为系统中查找问题的唯一入口。

### 3.4 Step 4: 对接前端 (待办)

- **修改 `AuditWorkOrdersController`**: 调用 `ProblemFinderService.find_for`，并将结果以 `JSON` 格式返回给前端。

## 4. 单元测试 (当前步骤)

- **目标**: 为 `ProblemCodeImportService` 和 `ProblemFinderService` 编写全面的单元测试。
- **具体任务**:
    1.  探查 `spec/services/` 目录，寻找现有测试。
    2.  创建/修改 `problem_code_import_service_spec.rb`。
    3.  创建/修改 `problem_finder_service_spec.rb`。

## 5. 实施计划

1.  **完成单元测试编写**。
2.  运行所有测试，确保新旧功能均正常。
3.  交付后端代码，供前端开发人员对接。