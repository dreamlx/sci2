# 用户故事与数据库结构对齐调整计划

## 调整目标

基于用户反馈，保持测试计划v4.3的三级问题代码库设计，调整数据库结构和用户故事以实现完全对齐。

## 1. 数据库结构调整

### 1.1 新增三级问题代码库表

```sql
-- 第一级：会议类型/文档类别
CREATE TABLE problem_meeting_types (
  id INTEGER PRIMARY KEY,
  code VARCHAR(10) NOT NULL UNIQUE,
  title VARCHAR(100) NOT NULL,
  active BOOLEAN DEFAULT true,
  created_at DATETIME,
  updated_at DATETIME
);

-- 第二级：问题大类
CREATE TABLE problem_major_categories (
  id INTEGER PRIMARY KEY,
  code VARCHAR(10) NOT NULL,
  title VARCHAR(100) NOT NULL,
  meeting_type_id INTEGER NOT NULL,
  active BOOLEAN DEFAULT true,
  created_at DATETIME,
  updated_at DATETIME,
  FOREIGN KEY (meeting_type_id) REFERENCES problem_meeting_types(id),
  UNIQUE(code, meeting_type_id)
);

-- 第三级：具体问题类型
CREATE TABLE problem_specific_types (
  id INTEGER PRIMARY KEY,
  code VARCHAR(10) NOT NULL,
  title VARCHAR(100) NOT NULL,
  sop_description TEXT,
  standard_handling TEXT,
  major_category_id INTEGER NOT NULL,
  active BOOLEAN DEFAULT true,
  created_at DATETIME,
  updated_at DATETIME,
  FOREIGN KEY (major_category_id) REFERENCES problem_major_categories(id),
  UNIQUE(code, major_category_id)
);
```

### 1.2 工单表字段调整

```sql
-- 添加三级问题选择字段
ALTER TABLE work_orders ADD COLUMN problem_meeting_type_id INTEGER;
ALTER TABLE work_orders ADD COLUMN problem_major_category_id INTEGER;
ALTER TABLE work_orders ADD COLUMN problem_specific_type_id INTEGER;
ALTER TABLE work_orders ADD COLUMN custom_description TEXT;

-- 添加外键约束
ALTER TABLE work_orders ADD FOREIGN KEY (problem_meeting_type_id) REFERENCES problem_meeting_types(id);
ALTER TABLE work_orders ADD FOREIGN KEY (problem_major_category_id) REFERENCES problem_major_categories(id);
ALTER TABLE work_orders ADD FOREIGN KEY (problem_specific_type_id) REFERENCES problem_specific_types(id);
```

### 1.3 数据迁移策略

1. **保留现有数据**：将当前的 `problem_types` 映射到新的 `problem_major_categories`
2. **创建默认会议类型**：为个人和学术类别创建顶级会议类型
3. **映射现有问题描述**：将 `problem_descriptions` 映射到 `problem_specific_types`

## 2. 用户故事字段命名调整

### 2.1 需要更新的字段命名

| 原用户故事命名 | 调整后命名 | 数据库字段 |
|---------------|-----------|-----------|
| `is_electronic_invoice` | `is_electronic` | `is_electronic` |
| `pending_receipt` | `pending` | `status = 'pending'` |
| `WorkOrderProblems` | `WorkOrderProblemSelections` | 三级字段组合 |

### 2.2 状态值统一

- 报销单状态：`pending`, `processing`, `closed`
- 费用明细状态：`pending`, `problematic`, `verified`
- 工单状态：`pending`, `approved`, `rejected`, `completed`

## 3. 模型关系调整

### 3.1 新增模型

```ruby
class ProblemMeetingType < ApplicationRecord
  has_many :problem_major_categories, dependent: :destroy
  validates :code, presence: true, uniqueness: true
  validates :title, presence: true
end

class ProblemMajorCategory < ApplicationRecord
  belongs_to :problem_meeting_type
  has_many :problem_specific_types, dependent: :destroy
  validates :code, presence: true, uniqueness: { scope: :meeting_type_id }
  validates :title, presence: true
end

class ProblemSpecificType < ApplicationRecord
  belongs_to :problem_major_category
  validates :code, presence: true, uniqueness: { scope: :major_category_id }
  validates :title, presence: true
end
```

### 3.2 工单模型调整

```ruby
class WorkOrder < ApplicationRecord
  belongs_to :problem_meeting_type, optional: true
  belongs_to :problem_major_category, optional: true
  belongs_to :problem_specific_type, optional: true
  
  # 验证：如果选择了具体问题，必须选择完整的三级
  validates :problem_major_category_id, presence: true, 
    if: :problem_specific_type_id?
  validates :problem_meeting_type_id, presence: true, 
    if: :problem_major_category_id?
end
```

## 4. 用户故事更新要点

### 4.1 问题选择流程更新

将用户故事第80-108行的问题选择逻辑更新为：

1. **第一级**：根据报销单类型自动确定或选择会议类型
2. **第二级**：根据第一级选择动态加载问题大类
3. **第三级**：根据第二级选择动态加载具体问题类型

### 4.2 数据结构影响更新

更新用户故事第105-108行，明确说明新的三级数据库结构。

## 5. 实施步骤

1. **创建数据库迁移文件**
2. **实现新的模型类**
3. **更新工单模型关联**
4. **创建数据迁移脚本**
5. **更新用户故事文档**
6. **验证测试计划对齐**

## 6. 风险评估

### 6.1 低风险
- 新增表结构不影响现有功能
- 字段命名调整影响范围小

### 6.2 中等风险
- 数据迁移需要仔细测试
- 前端三级联动需要重新实现

### 6.3 缓解措施
- 分步实施，先创建新结构再迁移数据
- 保留旧字段作为备份，确认无误后删除
- 充分测试数据迁移脚本

## 7. 验收标准

1. ✅ 数据库支持完整的三级问题代码库
2. ✅ 用户故事与数据库结构完全对齐
3. ✅ 测试计划v4.3无需修改即可执行
4. ✅ 现有数据完整迁移到新结构
5. ✅ 前端支持三级级联选择