# SCI2工单系统文档更新计划

基于文档一致性分析的结果，本计划提供了具体的文档更新建议，以确保所有文档完全一致，并准确反映最新的需求和开发变更。

## 1. 需要更新的文档

- `docs/database_structure_adjustment_updated.md`
- `docs/SCI2工单系统开发计划_updated.md`
- `docs/SCI2工单系统界面调整方案_补充.md`

## 2. 具体更新内容

### 2.1 WorkOrderFeeDetail表结构更新

**在`docs/SCI2工单系统开发计划_updated.md`中：**

将ER图中的`WorkOrderFeeDetail`表结构从：
```
WorkOrderFeeDetail {
    integer id PK
    integer work_order_id FK
    integer fee_detail_id FK
    string work_order_type
}
```

更新为：
```
WorkOrderFeeDetail {
    integer id PK
    integer work_order_id FK
    integer fee_detail_id FK
}
```

同时更新相关描述文本，明确说明我们已经从多态关联转变为普通的外键关联。

### 2.2 WorkOrder模型的problem_type关联说明

**在所有文档中：**

在`WorkOrder`模型代码示例中，为`belongs_to :problem_type, optional: true`添加更明确的注释：

```ruby
# 保留向后兼容，计划在下一版本中移除
# 新代码应使用 has_many :problem_types, through: :work_order_problems
belongs_to :problem_type, optional: true
```

并在相关说明文本中添加：

> 注意：`WorkOrder`模型中的`belongs_to :problem_type`关联仅为向后兼容保留，新代码应使用`has_many :problem_types, through: :work_order_problems`多对多关联。此单一关联将在未来版本中移除。

### 2.3 审核意见生成方式更新

**在`docs/database_structure_adjustment_updated.md`中：**

修改`WorkOrderProblemService`中的`generate_audit_comment`方法：

```ruby
# 生成审核意见文本（仅用于兼容旧版本，新版本中审核意见由用户手动输入）
# @deprecated 此方法将在下一版本中移除
def generate_audit_comment
  problems = get_formatted_problems
  
  if problems.empty?
    nil
  else
    problems.join("\n\n")
  end
end
```

并在服务层实现部分添加说明：

> 注意：根据最新的界面需求变更，审核意见不再自动生成，而是完全由用户手动输入。`WorkOrderProblemService`中的`generate_audit_comment`方法仅为向后兼容保留，将在未来版本中移除。

### 2.4 费用明细状态更新逻辑补充

**在`docs/database_structure_adjustment_updated.md`中：**

在"服务层实现"部分添加对"最新工单决定原则"的明确说明：

> **最新工单决定原则**：费用明细的验证状态由最新关联的工单状态决定。具体规则如下：
> - 如果最新关联的工单状态为"approved"，则费用明细状态为"verified"
> - 如果最新关联的工单状态为"rejected"，则费用明细状态为"problematic"
> - 如果最新关联的工单状态为"pending"或没有关联工单，则费用明细状态为"pending"
>
> 这一原则由`FeeDetailStatusService`实现，确保费用明细状态始终反映最新工单的处理结果。

### 2.5 界面交互与状态关系补充

**在`docs/database_structure_adjustment_updated.md`中：**

添加新的章节"界面交互与状态关系"：

```markdown
## 5. 界面交互与状态关系

根据最新的界面需求变更，工单创建和编辑界面的交互方式有以下调整：

1. **费用明细选择**：
   - 用户选择费用明细后，系统自动按费用类型分组显示标签
   - 费用明细选择不直接影响工单状态

2. **问题类型选择**：
   - 用户可以选择多个问题类型（使用复选框）
   - 问题类型选择不直接影响工单状态

3. **处理意见设置**：
   - 用户选择"可以通过"时，工单状态自动变更为"approved"
   - 用户选择"无法通过"时，工单状态自动变更为"rejected"
   - 处理意见是决定工单状态的关键因素

4. **审核意见输入**：
   - 用户手动输入审核意见
   - 审核意见不直接影响工单状态
```

## 3. 新增文档

### 3.1 创建统一的需求变更历史文档

创建新文档`docs/requirement_change_history.md`，记录所有需求变更的历史：

```markdown
# SCI2工单系统需求变更历史

本文档记录SCI2工单系统开发过程中的需求变更历史，帮助团队成员了解系统需求的演变过程。

## 1. 初始需求（2025年5月）

1. **问题代码库结构**：
   - 多层级结构：DocumentCategory -> ProblemType -> ProblemDescription
   - 复杂的关联关系，包括ProblemTypeFeeTye, Material等表

2. **工单与费用明细关系**：
   - 工单可以关联多个费用明细
   - 费用明细状态更新逻辑不明确

3. **工单问题添加**：
   - 工单只能关联单个问题类型
   - 审核意见自动生成

## 2. 第一次需求变更（2025年5月底）

1. **问题代码库结构简化**：
   - 简化为两级结构：FeeType -> ProblemType
   - 移除DocumentCategory, ProblemDescription, Material等表
   - 为FeeType和ProblemType添加更多字段

2. **工单与费用明细关系明确化**：
   - 引入"最新工单决定原则"
   - 明确费用明细状态更新规则

3. **工单问题添加增强**：
   - 支持工单关联多个问题类型
   - 创建work_order_problems表

## 3. 最新需求变更（2025年6月初）

1. **费用类型显示方式变更**：
   - 原设计：通过下拉列表选择费用类型
   - 新需求：根据选择的费用明细自动分组显示费用类型标签

2. **问题类型选择方式变更**：
   - 原设计：单选下拉列表
   - 新需求：多选复选框，允许选择多个问题类型

3. **审核意见生成方式变更**：
   - 原设计：根据选择的问题类型自动填充审核意见
   - 新需求：完全由用户手动输入，不再自动填充
```

## 4. 实施计划

1. **文档更新**：在一周内完成所有文档的更新
2. **代码同步**：确保代码实现与更新后的文档保持一致
3. **团队沟通**：在下次团队会议上介绍文档更新内容，确保所有团队成员了解最新需求
4. **版本控制**：使用Git版本控制系统跟踪文档变更
5. **持续维护**：建立文档维护机制，确保未来的需求变更及时反映在文档中

## 5. 责任分工

1. **文档更新**：系统架构师负责
2. **代码同步**：开发团队负责
3. **团队沟通**：项目经理负责
4. **版本控制**：所有团队成员共同负责
5. **持续维护**：系统架构师和项目经理共同负责