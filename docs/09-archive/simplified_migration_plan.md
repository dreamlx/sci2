# 简化的迁移计划

根据项目需求，我们可以采用更简单的方式来重构工单系统中的多态关联为单表继承（STI）。由于不需要保留现有数据，我们可以直接删除旧表并创建新表，这大大简化了迁移过程。

## 1. 迁移文件修正

### 1.1 修正版本号冲突

首先，我们需要修正迁移文件的版本号冲突。目前有多个迁移文件使用了相同的版本号`20250605000001`，这会导致迁移冲突。我们应该确保每个迁移文件都有唯一的版本号：

```
20250605000001_create_work_order_problems.rb
20250605010001_drop_and_create_work_order_fee_details.rb
```

### 1.2 简化迁移文件

由于不需要保留数据，我们可以将之前的三个迁移文件（创建临时表、迁移数据、重命名表）合并为一个简单的迁移文件：

```ruby
# 20250605010001_drop_and_create_work_order_fee_details.rb
class DropAndCreateWorkOrderFeeDetails < ActiveRecord::Migration[6.1]
  def up
    # 删除旧表
    drop_table :work_order_fee_details if table_exists?(:work_order_fee_details)
    
    # 创建新表
    create_table :work_order_fee_details do |t|
      t.references :work_order, null: false, foreign_key: true
      t.references :fee_detail, null: false, foreign_key: true
      
      # 添加唯一索引确保不会有重复关联
      t.index [:work_order_id, :fee_detail_id], unique: true, name: 'index_work_order_fee_details_on_wo_and_fd'
      
      t.timestamps
    end
  end
  
  def down
    drop_table :work_order_fee_details if table_exists?(:work_order_fee_details)
  end
end
```

## 2. 模型修改

### 2.1 修改`WorkOrder`模型

```ruby
# app/models/work_order.rb
class WorkOrder < ApplicationRecord
  # 使用STI实现不同类型的工单
  self.inheritance_column = :type
  
  # 关联
  belongs_to :reimbursement
  belongs_to :problem_type, optional: true
  belongs_to :creator, class_name: 'AdminUser', foreign_key: 'created_by', optional: true
  
  # 新增多对多关联
  has_many :work_order_problems, dependent: :destroy
  has_many :problem_types, through: :work_order_problems
  
  # 修改关联定义，使用普通的has_many而不是多态关联
  has_many :work_order_fee_details, dependent: :destroy
  has_many :fee_details, through: :work_order_fee_details
  
  has_many :operations, class_name: 'WorkOrderOperation', dependent: :destroy
  
  # 其余代码保持不变...
  
  # 同步费用明细验证状态 - 简化版本
  def sync_fee_details_verification_status
    # 直接使用关联获取费用明细ID
    fee_detail_ids = fee_details.pluck(:id)
    
    # 使用服务更新费用明细状态
    FeeDetailStatusService.new(fee_detail_ids).update_status if fee_detail_ids.any?
  end
  
  # 其余代码保持不变...
end
```

### 2.2 修改`WorkOrderFeeDetail`模型

```ruby
# app/models/work_order_fee_detail.rb
class WorkOrderFeeDetail < ApplicationRecord
  belongs_to :fee_detail
  belongs_to :work_order
  
  # 校验确保唯一性
  validates :fee_detail_id, uniqueness: { scope: :work_order_id, message: "已经与此工单关联" }
  validates :fee_detail_id, presence: true
  validates :work_order_id, presence: true
  
  # 添加按工单类型筛选的scope
  scope :by_work_order_type, ->(type) { joins(:work_order).where(work_orders: { type: type }) }
  
  # 添加按费用明细ID筛选的scope
  scope :by_fee_detail, ->(fee_detail_id) { where(fee_detail_id: fee_detail_id) }
  
  # 添加按工单ID筛选的scope
  scope :by_work_order, ->(work_order_id) { where(work_order_id: work_order_id) }
  
  # 回调：创建或更新关联后，更新费用明细的验证状态
  after_commit :update_fee_detail_status, on: [:create, :update]
  
  # 回调：删除关联后，更新费用明细的验证状态
  after_commit :update_fee_detail_status, on: :destroy
  
  private
  
  # 更新费用明细的验证状态
  def update_fee_detail_status
    # 使用 FeeDetailStatusService 更新费用明细状态
    service = FeeDetailStatusService.new([fee_detail_id])
    service.update_status
    
    # 更新报销单状态
    if fee_detail&.reimbursement&.persisted?
      fee_detail.reimbursement.update_status_based_on_fee_details!
    end
  end
end
```

### 2.3 修改`FeeDetail`模型

```ruby
# app/models/fee_detail.rb
class FeeDetail < ApplicationRecord
  # Constants
  VERIFICATION_STATUS_PENDING = 'pending'.freeze
  VERIFICATION_STATUS_PROBLEMATIC = 'problematic'.freeze
  VERIFICATION_STATUS_VERIFIED = 'verified'.freeze
  
  VERIFICATION_STATUSES = [
    VERIFICATION_STATUS_PENDING,
    VERIFICATION_STATUS_PROBLEMATIC,
    VERIFICATION_STATUS_VERIFIED
  ].freeze
  
  # Associations
  belongs_to :reimbursement, foreign_key: 'document_number', primary_key: 'invoice_number'
  has_many :work_order_fee_details, dependent: :destroy
  has_many :work_orders, through: :work_order_fee_details
  
  # 其余代码保持不变...
  
  # 获取最新工单 - 简化版本
  def latest_work_order
    work_orders.order(updated_at: :desc).first
  end
  
  # 其余代码保持不变...
end
```

## 3. 服务层修改

### 3.1 修改`FeeDetailStatusService`

```ruby
# app/services/fee_detail_status_service.rb
class FeeDetailStatusService
  def initialize(fee_detail_ids = nil)
    @fee_detail_ids = Array(fee_detail_ids)
  end
  
  # 其余代码保持不变...
  
  def get_latest_work_order(fee_detail)
    # 简化版本 - 直接使用关联获取最新工单
    fee_detail.work_orders.order(updated_at: :desc).first
  end
  
  # 其余代码保持不变...
end
```

## 4. 数据重建

由于我们采用了删除旧表并创建新表的方式，我们需要在迁移后重新创建数据。这可以通过以下方式实现：

1. 使用种子数据（seeds.rb）重新创建基础数据
2. 使用导入服务重新导入数据
3. 手动创建关键数据

## 5. 测试计划

尽管我们不保留现有数据，但仍然需要确保系统功能正常：

1. 单元测试：确保模型、服务和控制器正常工作
2. 集成测试：确保工单创建、状态变更和费用明细状态更新等流程正常
3. UI测试：确保界面正常显示和操作

## 6. 部署计划

1. 备份数据库（即使不需要迁移数据，也应该备份以防万一）
2. 运行迁移
3. 重新创建必要的数据
4. 验证系统功能