# 工单系统多态关联重构为单表继承（STI）计划

本文档详细说明将SCI2工单系统中的多态关联重构为单表继承（Single Table Inheritance, STI）的计划。这项重构旨在解决当前多态关联设计中存在的问题，提高系统性能、可维护性和可靠性。

## 1. 背景与问题

当前系统中，`WorkOrderFeeDetail`模型使用多态关联（`belongs_to :work_order, polymorphic: true`）连接不同类型的工单（如`AuditWorkOrder`、`CommunicationWorkOrder`等）。这种设计存在以下问题：

1. **查询复杂性**：需要同时考虑`work_order_id`和`work_order_type`，导致查询变得复杂
2. **性能隐患**：多态关联无法充分利用数据库索引，可能导致性能问题
3. **关联完整性难以保证**：数据库层面难以为多态关联设置外键约束
4. **代码复杂度增加**：多态关联使得代码更难理解和维护

## 2. 重构目标

1. 将多态关联改为单表继承（STI）
2. 简化关联查询，提高性能
3. 在数据库层面保证关联完整性
4. 减少代码复杂度，提高可维护性
5. 保持现有功能不变，确保系统正常运行

## 3. 实施计划

### 3.1 数据库迁移

#### 3.1.1 创建新的工单关联表

```ruby
# 创建新的工单关联表迁移文件
class CreateWorkOrderFeeDetailsV2 < ActiveRecord::Migration[6.1]
  def change
    create_table :work_order_fee_details_v2 do |t|
      t.references :work_order, null: false, foreign_key: true
      t.references :fee_detail, null: false, foreign_key: true
      
      # 添加唯一索引确保不会有重复关联
      t.index [:work_order_id, :fee_detail_id], unique: true
      
      t.timestamps
    end
  end
end
```

#### 3.1.2 数据迁移

```ruby
# 数据迁移文件
class MigrateWorkOrderFeeDetailsToV2 < ActiveRecord::Migration[6.1]
  def up
    # 创建临时表存储映射关系
    create_table :work_order_id_mapping, temporary: true do |t|
      t.integer :old_id
      t.string :old_type
      t.integer :new_id
    end
    
    # 迁移数据
    execute <<-SQL
      INSERT INTO work_order_id_mapping (old_id, old_type, new_id)
      SELECT id, type, id FROM work_orders
    SQL
    
    # 迁移关联数据
    execute <<-SQL
      INSERT INTO work_order_fee_details_v2 (work_order_id, fee_detail_id, created_at, updated_at)
      SELECT m.new_id, wofd.fee_detail_id, wofd.created_at, wofd.updated_at
      FROM work_order_fee_details wofd
      JOIN work_order_id_mapping m ON wofd.work_order_id = m.old_id AND wofd.work_order_type = m.old_type
    SQL
    
    # 删除临时表
    drop_table :work_order_id_mapping
  end
  
  def down
    # 回滚数据迁移
    execute <<-SQL
      DELETE FROM work_order_fee_details_v2
    SQL
  end
end
```

#### 3.1.3 重命名表

```ruby
# 重命名表迁移文件
class RenameWorkOrderFeeDetailsTables < ActiveRecord::Migration[6.1]
  def change
    rename_table :work_order_fee_details, :work_order_fee_details_old
    rename_table :work_order_fee_details_v2, :work_order_fee_details
  end
end
```

### 3.2 模型修改

#### 3.2.1 修改`WorkOrder`模型

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

#### 3.2.2 修改`WorkOrderFeeDetail`模型

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

#### 3.2.3 修改`FeeDetail`模型

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

### 3.3 服务层修改

#### 3.3.1 修改`FeeDetailStatusService`

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

### 3.4 控制器修改

#### 3.4.1 修改`AuditWorkOrdersController`

```ruby
# app/controllers/admin/audit_work_orders_controller.rb
ActiveAdmin.register AuditWorkOrder do
  # 其余代码保持不变...
  
  controller do
    # 其余代码保持不变...
    
    # 创建时设置报销单ID
    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      # 如果是从表单提交的，设置 submitted_fee_detail_ids
      if params[:audit_work_order] && params[:audit_work_order][:submitted_fee_detail_ids]
        resource.submitted_fee_detail_ids = params[:audit_work_order][:submitted_fee_detail_ids]
      end
      resource
    end
    
    # 其余代码保持不变...
  end
  
  # 其余代码保持不变...
end
```

### 3.5 视图修改

#### 3.5.1 修改`_fee_details_selection.html.erb`

```erb
<%# app/views/admin/shared/_fee_details_selection.html.erb %>
<%# 参数: work_order, reimbursement %>

<div class="panel">
  <h3>选择关联的费用明细</h3>
  <% if work_order.persisted? %>
    <%# 编辑模式：显示只读列表 %>
    <table class="index_table">
      <thead>
        <tr>
          <th>ID</th>
          <th>费用类型</th>
          <th>金额</th>
          <th>费用日期</th>
          <th>验证状态</th>
          <th>备注</th>
          <th>创建时间</th>
          <th>更新时间</th>
        </tr>
      </thead>
      <tbody>
        <% work_order.fee_details.each do |fee_detail| %>
          <tr>
            <td><%= link_to fee_detail.id, admin_fee_detail_path(fee_detail) %></td>
            <td><%= fee_detail.fee_type %></td>
            <td><%= number_to_currency(fee_detail.amount, unit: "¥") %></td>
            <td><%= fee_detail.fee_date %></td>
            <td>
              <% arbre_context = Arbre::Context.new %>
              <%= arbre_context.status_tag(fee_detail.verification_status, class: case fee_detail.verification_status
                                                                           when FeeDetail::VERIFICATION_STATUS_VERIFIED
                                                                             'ok' # green
                                                                           when FeeDetail::VERIFICATION_STATUS_PROBLEMATIC
                                                                             'error' # red
                                                                           else
                                                                             'warning' # orange
                                                                           end).to_s %>
            </td>
            <td><%= fee_detail.notes %></td>
            <td><%= fee_detail.created_at %></td>
            <td><%= fee_detail.updated_at %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  <% else %>
    <%# 新建模式：显示复选框 %>
    <div class="fee-details-selection">
      <% reimbursement.fee_details.each do |fee_detail| %>
        <div class="fee-detail-item">
          <label for="fee_detail_<%= fee_detail.id %>">
            <div class="checkbox-container">
              <%
                # For new work orders, determine the type from the controller name
                if work_order.type.present?
                  param_name = work_order.type.underscore.gsub('/', '_')
                else
                  # Extract from current path, e.g., /admin/audit_work_orders/new -> audit_work_order
                  controller_path = request.path.split('/')[2]
                  param_name = controller_path.present? ? controller_path.singularize : 'work_order'
                end
              %>
              <%= check_box_tag "#{param_name}[submitted_fee_detail_ids][]",
                              fee_detail.id,
                              work_order.submitted_fee_detail_ids&.include?(fee_detail.id.to_s),
                              id: "fee_detail_#{fee_detail.id}",
                              class: "fee-detail-checkbox",
                              data: { fee_type: fee_detail.fee_type } %>
            </div>
            <span class="fee-detail-id">#<%= fee_detail.id %></span>
            <span class="fee-detail-type"><%= fee_detail.fee_type %></span>
            <span class="fee-detail-amount"><%= number_to_currency(fee_detail.amount, unit: "¥") %></span>
            <span class="fee-detail-date"><%= fee_detail.fee_date %></span>
            <span class="fee-detail-status">
              <% arbre_context = Arbre::Context.new %>
              <%= arbre_context.status_tag(fee_detail.verification_status, class: case fee_detail.verification_status
                                                                            when FeeDetail::VERIFICATION_STATUS_VERIFIED
                                                                              'ok' # green
                                                                            when FeeDetail::VERIFICATION_STATUS_PROBLEMATIC
                                                                              'error' # red
                                                                            else
                                                                              'warning' # orange
                                                                            end).to_s %>
            </span>
          </label>
        </div>
      <% end %>
    </div>
    
    <%# 费用类型分组标签 %>
    <div class="fee-type-tags" id="fee-type-tags">
      <h4>已选费用类型</h4>
      <div class="fee-type-tags-container"></div>
    </div>
    
    <%# 问题类型选择区域 %>
    <div class="problem-types-container" id="problem-types-container" style="display:none;">
      <h4>选择问题类型</h4>
      <div class="problem-types-wrapper"></div>
    </div>
  <% end %>
</div>

<%# JavaScript代码保持不变 %>
<script>
  document.addEventListener('DOMContentLoaded', function() {
    // JavaScript代码保持不变...
  });
</script>
```

## 4. 测试计划

### 4.1 单元测试

1. 修改`WorkOrder`模型测试
2. 修改`WorkOrderFeeDetail`模型测试
3. 修改`FeeDetail`模型测试
4. 修改`FeeDetailStatusService`测试

### 4.2 集成测试

1. 测试工单创建流程
2. 测试工单状态变更流程
3. 测试费用明细状态更新流程
4. 测试最新工单决定原则

### 4.3 UI测试

1. 测试费用明细选择界面
2. 测试问题类型选择界面
3. 测试审核意见填写界面

## 5. 部署计划

### 5.1 准备工作

1. 备份数据库
2. 准备回滚计划

### 5.2 部署步骤

1. 部署数据库迁移
2. 部署模型修改
3. 部署服务层修改
4. 部署控制器修改
5. 部署视图修改

### 5.3 部署后验证

1. 验证数据迁移是否成功
2. 验证系统功能是否正常
3. 验证性能是否有提升

## 6. 风险与缓解措施

### 6.1 数据迁移风险

**风险**：数据迁移过程中可能丢失数据或数据不一致
**缓解措施**：
- 在迁移前进行完整备份
- 编写详细的数据验证脚本
- 准备回滚计划

### 6.2 功能变更风险

**风险**：重构可能导致现有功能失效
**缓解措施**：
- 编写全面的测试用例
- 进行充分的测试
- 分阶段部署，先在测试环境验证

### 6.3 性能风险

**风险**：重构可能导致性能下降
**缓解措施**：
- 进行性能测试
- 监控系统性能
- 准备性能优化方案

## 7. 时间线

1. **准备阶段**（1周）：
   - 详细设计
   - 编写测试用例
   - 准备数据迁移脚本

2. **开发阶段**（2周）：
   - 实施数据库迁移
   - 修改模型
   - 修改服务层
   - 修改控制器
   - 修改视图

3. **测试阶段**（1周）：
   - 单元测试
   - 集成测试
   - UI测试
   - 性能测试

4. **部署阶段**（1天）：
   - 备份数据库
   - 部署代码
   - 验证部署

5. **监控阶段**（1周）：
   - 监控系统性能
   - 修复发现的问题
   - 优化性能

## 8. 结论

将多态关联重构为单表继承是一项重要的优化，可以显著提高系统的性能、可维护性和可靠性。通过本文档提供的计划，可以有序地实施这项重构，确保系统在重构过程中保持稳定运行。