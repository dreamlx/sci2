# SCI2 工单系统数据库结构调整（更新版）

本文档描述了SCI2工单系统数据库结构调整的实现方案，包括迁移脚本、模型更新和服务层实现。

## 1. 数据库结构变更概述

根据开发计划，我们对数据库结构进行了以下调整：

1. **简化问题代码库结构**：
   - 将原有的多层级结构简化为 `FeeType` -> `ProblemType` 两层结构
   - 移除了不必要的中间表和关联表

2. **优化字段设计**：
   - 为 `FeeType` 添加 `code`, `title`, `meeting_type`, `active` 字段
   - 为 `ProblemType` 添加 `code`, `title`, `sop_description`, `standard_handling` 字段
   - 建立 `ProblemType` 与 `FeeType` 的直接关联

3. **移除冗余表**：
   - 移除 `problem_type_fee_types` 关联表
   - 移除 `problem_descriptions` 表
   - 移除 `materials` 和 `problem_type_materials` 表
   - 移除 `document_categories` 表

4. **添加工单问题关联表**：
   - 创建 `work_order_problems` 表，支持工单与多个问题类型的关联
   - 添加唯一索引确保不重复添加同一问题

## 2. 迁移脚本说明

我们创建了以下迁移脚本来实现数据库结构调整：

1. `20250529100000_update_fee_types_table.rb`：更新 `fee_types` 表结构
2. `20250529100001_update_problem_types_table.rb`：更新 `problem_types` 表结构
3. `20250529100002_remove_document_category_from_problem_types.rb`：移除 `document_category_id` 字段
4. `20250529100003_remove_problem_type_fee_types_table.rb`：移除 `problem_type_fee_types` 表
5. `20250529100004_remove_problem_descriptions_table.rb`：移除 `problem_descriptions` 表
6. `20250529100005_remove_materials_related_tables.rb`：移除 `materials` 相关表
7. `20250529100006_remove_document_categories_table.rb`：移除 `document_categories` 表
8. `20250529100007_migrate_problem_code_data.rb`：数据迁移脚本
9. `20250605000001_create_work_order_problems.rb`：创建 `work_order_problems` 表
10. `20250605010001_drop_and_create_work_order_fee_details.rb`：重建工单费用明细关联表，移除多态关联

## 3. 模型更新

我们更新了以下模型以适应新的数据库结构：

1. `FeeType`：添加新字段和关联
2. `ProblemType`：添加新字段和关联
3. `WorkOrder`：更新关联和方法，添加多对多关联
4. `WorkOrderProblem`：新增模型，处理工单与问题类型的多对多关联
5. `FeeDetail`：更新关联和方法
6. `Reimbursement`：更新关联和方法

### 3.1 WorkOrder模型更新

```ruby
class WorkOrder < ApplicationRecord
  # 使用STI实现不同类型的工单
  self.inheritance_column = :type
  
  # 关联
  belongs_to :reimbursement
  # 保留向后兼容，计划在下一版本中移除
  # 新代码应使用 has_many :problem_types, through: :work_order_problems
  belongs_to :problem_type, optional: true
  
  # 新增多对多关联
  has_many :work_order_problems, dependent: :destroy
  has_many :problem_types, through: :work_order_problems
  
  # 修改关联定义，使用普通的has_many而不是多态关联
  has_many :work_order_fee_details, dependent: :destroy
  has_many :fee_details, through: :work_order_fee_details
  
  # 虚拟属性，用于表单处理
  attr_accessor :problem_type_ids
  
  # 回调处理多问题类型关联
  after_save :process_problem_types, if: -> { @problem_type_ids.present? }
  
  private
  
  def process_problem_types
    # 使用服务处理问题类型
    WorkOrderProblemService.new(self).add_problems(@problem_type_ids)
    @problem_type_ids = nil
  end
end
```

### 3.2 WorkOrderProblem模型

```ruby
class WorkOrderProblem < ApplicationRecord
  # 关联
  belongs_to :work_order
  belongs_to :problem_type

  # 验证
  validates :work_order_id, uniqueness: { scope: :problem_type_id, message: "已关联此问题类型" }

  # 回调
  after_create :log_problem_added
  after_destroy :log_problem_removed

  private

  # 记录问题添加操作
  def log_problem_added
    WorkOrderOperation.create!(
      work_order: work_order,
      operation_type: WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM,
      details: "添加问题: #{problem_type.display_name}",
      admin_user_id: Current.admin_user&.id
    ) if defined?(WorkOrderOperation)
  end

  # 记录问题移除操作
  def log_problem_removed
    WorkOrderOperation.create!(
      work_order: work_order,
      operation_type: WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM,
      details: "移除问题: #{problem_type.display_name}",
      admin_user_id: Current.admin_user&.id
    ) if defined?(WorkOrderOperation)
  end
end
```

## 4. 服务层实现

我们创建了以下服务类来支持新的业务逻辑：

1. `ProblemCodeMigrationService`：负责将旧结构数据迁移到新结构
2. `ProblemCodeImportService`：负责从CSV文件导入问题代码
3. `FeeDetailStatusService`：实现"最新工单决定原则"
4. `WorkOrderProblemService`：处理工单中的问题添加和格式化
5. `FeeDetailGroupService`：按费用类型分组费用明细

### 4.1 WorkOrderProblemService

```ruby
class WorkOrderProblemService
  def initialize(work_order)
    @work_order = work_order
  end
  
  # 添加多个问题类型
  def add_problems(problem_type_ids)
    return false if problem_type_ids.blank?
    
    # 转换为数组并确保是整数
    problem_type_ids = Array(problem_type_ids).map(&:to_i).uniq
    
    # 清除现有关联
    @work_order.work_order_problems.destroy_all
    
    # 创建新关联
    problem_type_ids.each do |problem_type_id|
      @work_order.work_order_problems.create(problem_type_id: problem_type_id)
    end
    
    true
  end
  
  # 添加单个问题类型
  def add_problem(problem_type_id)
    return false if problem_type_id.blank?
    
    # 创建关联
    @work_order.work_order_problems.create(problem_type_id: problem_type_id)
    
    true
  end
  
  # 移除问题类型
  def remove_problem(problem_type_id)
    return false if problem_type_id.blank?
    
    # 查找并删除关联
    problem = @work_order.work_order_problems.find_by(problem_type_id: problem_type_id)
    problem&.destroy
    
    true
  end
  
  # 清除所有问题
  def clear_problems
    @work_order.work_order_problems.destroy_all
    
    # 如果工单还有旧的单一问题类型关联，也清除它
    if @work_order.respond_to?(:problem_type_id) && @work_order.problem_type_id.present?
      @work_order.update(problem_type_id: nil)
    end
    
    # 清除审核意见
    if @work_order.respond_to?(:audit_comment) && @work_order.audit_comment.present?
      @work_order.update(audit_comment: nil)
    end
    
    true
  end
  
  # 获取当前关联的所有问题类型
  def get_problems
    @work_order.problem_types
  end
  
  # 获取问题类型的格式化文本
  def get_formatted_problems
    @work_order.problem_types.map do |problem_type|
      format_problem(problem_type)
    end
  end
  
  # 生成审核意见文本
  # @deprecated 此方法仅用于兼容旧版本，新版本中审核意见由用户手动输入，将在下一版本中移除
  def generate_audit_comment
    problems = get_formatted_problems
    
    if problems.empty?
      nil
    else
      problems.join("\n\n")
    end
  end
  
  private
  
  # 格式化单个问题类型
  def format_problem(problem_type)
    fee_type_info = problem_type.fee_type.present? ? "#{problem_type.fee_type.display_name}: " : ""
    [
      "#{fee_type_info}#{problem_type.display_name}",
      "    #{problem_type.sop_description}",
      "    #{problem_type.standard_handling}"
    ].join("\n")
  end
end
```

### 4.2 FeeDetailGroupService

```ruby
class FeeDetailGroupService
  def initialize(fee_detail_ids)
    @fee_detail_ids = Array(fee_detail_ids).map(&:to_i).uniq
    @fee_details = FeeDetail.where(id: @fee_detail_ids)
  end
  
  # 按费用类型分组
  def group_by_fee_type
    # 创建分组结果
    result = {}
    
    @fee_details.each do |fee_detail|
      fee_type = fee_detail.fee_type.to_s
      
      # 初始化分组
      result[fee_type] ||= {
        fee_type: fee_type,
        fee_type_id: get_fee_type_id(fee_type),
        details: []
      }
      
      # 添加到分组
      result[fee_type][:details] << {
        id: fee_detail.id,
        amount: fee_detail.amount,
        fee_date: fee_detail.fee_date,
        verification_status: fee_detail.verification_status
      }
    end
    
    result.values
  end
  
  # 获取所有相关的费用类型
  def fee_types
    @fee_details.pluck(:fee_type).compact.uniq
  end
  
  # 获取所有相关的费用类型ID
  def fee_type_ids
    # 从费用类型名称获取ID
    fee_types.map { |fee_type| get_fee_type_id(fee_type) }.compact
  end
  
  # 获取所有相关的问题类型
  def available_problem_types
    ProblemType.active.where(fee_type_id: fee_type_ids)
  end
  
  # 按费用类型分组的问题类型
  def problem_types_by_fee_type
    result = {}
    
    available_problem_types.each do |problem_type|
      fee_type_id = problem_type.fee_type_id
      
      # 初始化分组
      result[fee_type_id] ||= []
      
      # 添加到分组
      result[fee_type_id] << {
        id: problem_type.id,
        code: problem_type.code,
        title: problem_type.title,
        display_name: problem_type.display_name,
        fee_type_id: fee_type_id
      }
    end
    
    result
  end
  
  private
  
  # 从费用类型名称获取ID
  def get_fee_type_id(fee_type_name)
    # 查找费用类型
    fee_type = FeeType.find_by("title LIKE ? OR code LIKE ?", "%#{fee_type_name}%", "%#{fee_type_name}%")
    fee_type&.id
  end
end
```

### 4.3 FeeDetailStatusService

```ruby
class FeeDetailStatusService
  def initialize(fee_detail_ids = nil)
    @fee_detail_ids = Array(fee_detail_ids)
  end
  
  # 更新费用明细状态
  def update_status
    fee_details = @fee_detail_ids.present? ? 
      FeeDetail.where(id: @fee_detail_ids) : 
      FeeDetail.all
      
    fee_details.find_each do |fee_detail|
      update_fee_detail_status(fee_detail)
    end
  end
  
  private
  
  # 更新单个费用明细状态
  def update_fee_detail_status(fee_detail)
    # 获取最新工单
    latest_work_order = fee_detail.work_orders.order(updated_at: :desc).first
    
    if latest_work_order.nil?
      # 如果没有关联工单，保持pending状态
      fee_detail.update(verification_status: FeeDetail::VERIFICATION_STATUS_PENDING)
      return
    end
    
    # 最新工单决定原则：根据最新工单的状态决定费用明细状态
    case latest_work_order.status
    when 'approved'
      fee_detail.update(verification_status: FeeDetail::VERIFICATION_STATUS_VERIFIED)
    when 'rejected'
      fee_detail.update(verification_status: FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
    else
      # 其他状态（如pending），保持pending状态
      fee_detail.update(verification_status: FeeDetail::VERIFICATION_STATUS_PENDING)
    end
  end
end
```

## 5. 最新工单决定原则

**最新工单决定原则**：费用明细的验证状态由最新关联的工单状态决定。具体规则如下：
- 如果最新关联的工单状态为"approved"，则费用明细状态为"verified"
- 如果最新关联的工单状态为"rejected"，则费用明细状态为"problematic"
- 如果最新关联的工单状态为"pending"或没有关联工单，则费用明细状态为"pending"

这一原则由`FeeDetailStatusService`实现，确保费用明细状态始终反映最新工单的处理结果。

## 6. 界面交互与状态关系

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

## 7. 执行迁移步骤

按照以下步骤执行数据库迁移：

1. **备份数据库**：
   ```bash
   rails db:dump
   ```

2. **运行迁移脚本**：
   ```bash
   rails db:migrate
   ```

3. **导入问题代码**：
   ```bash
   rails problem_codes:import
   ```

4. **验证数据完整性**：
   ```bash
   rails problem_codes:validate
   ```

## 8. 注意事项

1. **数据备份**：执行迁移前务必备份数据库，以防数据丢失。
2. **迁移顺序**：迁移脚本必须按照编号顺序执行，不可跳过。
3. **数据验证**：迁移后应验证数据完整性，确保所有数据正确迁移。
4. **问题代码导入**：如果有新的问题代码CSV文件，可以使用 `rails problem_codes:import` 导入。
5. **多问题类型支持**：新的 `work_order_problems` 表支持工单关联多个问题类型，需要相应更新界面。

## 9. 回滚方案

如需回滚迁移，可执行以下命令：

```bash
rails db:rollback STEP=10
```

注意：回滚会丢失在新结构中创建的数据，请谨慎操作。

## 10. 后续工作

完成数据库结构调整后，需要进行以下工作：

1. 更新控制器和视图以适应新的数据结构
2. 实现费用类型标签显示
3. 实现问题类型多选功能
4. 更新测试用例以覆盖新的功能