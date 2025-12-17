# 代码重构与文档更新详细计划

本文档提供了SCI2工单系统多态关联重构为单表继承（STI）后的进一步代码重构和文档更新的详细计划。

## 1. 代码重构详细计划

### 1.1 查询优化

#### 1.1.1 添加索引

为提高查询性能，需要在关键表上添加适当的索引：

```ruby
# 创建索引迁移文件
class AddIndexesToWorkOrderRelatedTables < ActiveRecord::Migration[6.1]
  def change
    # 为工单表添加索引
    add_index :work_orders, :type, name: 'index_work_orders_on_type'
    add_index :work_orders, :status, name: 'index_work_orders_on_status'
    add_index :work_orders, [:reimbursement_id, :type], name: 'index_work_orders_on_reimbursement_id_and_type'
    
    # 为工单费用明细关联表添加复合索引
    add_index :work_order_fee_details, [:work_order_id, :fee_detail_id], name: 'index_wofd_on_work_order_id_and_fee_detail_id'
    
    # 为费用明细表添加索引
    add_index :fee_details, :verification_status, name: 'index_fee_details_on_verification_status'
  end
end
```

#### 1.1.2 优化N+1查询

修改控制器中的`includes`方法，确保预加载所有必要的关联：

```ruby
# 在AuditWorkOrdersController中
def scoped_collection
  AuditWorkOrder.includes(:reimbursement, :creator, :fee_details, :problem_types)
end

# 在CommunicationWorkOrdersController中
### 1.2 服务层重构

#### 1.2.1 创建统一的工单操作服务

创建一个统一的工单操作服务，处理所有类型工单的共同操作：

```ruby
# app/services/unified_work_order_service.rb
class UnifiedWorkOrderService
  def initialize(work_order, admin_user)
    @work_order = work_order
    @admin_user = admin_user
    @operation_service = WorkOrderOperationService.new(work_order, admin_user)
  end
  
  # 通用的状态变更方法
  def change_status(new_status, params = {})
    # 记录原始状态
    original_status = @work_order.status
    
    # 更新工单属性
    @work_order.assign_attributes(params)
    
    # 设置状态
    @work_order.status = new_status
    
    # 保存工单
    if @work_order.save
      # 记录状态变更
      @operation_service.record_status_change(original_status, new_status)
      
      # 更新费用明细状态
      @work_order.sync_fee_details_verification_status
      
      return true
    end
    
    false
  end
  
  # 其他通用方法...
end
```

#### 1.2.2 重构现有服务以使用统一服务

修改现有的`WorkOrderService`、`AuditWorkOrderService`和`CommunicationWorkOrderService`，使其继承自统一服务：

```ruby
# app/services/work_order_service.rb
class WorkOrderService < UnifiedWorkOrderService
  # 特定于WorkOrder的方法...
end

# app/services/audit_work_order_service.rb
class AuditWorkOrderService < WorkOrderService
  # 特定于AuditWorkOrder的方法...
end

# app/services/communication_work_order_service.rb
class CommunicationWorkOrderService < WorkOrderService
  # 特定于CommunicationWorkOrder的方法...
end
```

### 1.3 模型层重构

#### 1.3.1 添加验证和回调

在`WorkOrder`模型中添加更严格的验证和回调：

```ruby
# app/models/work_order.rb
class WorkOrder < ApplicationRecord
  # 现有代码...
  
  # 添加验证
  validates :status, inclusion: { in: [STATUS_PENDING, STATUS_APPROVED, STATUS_REJECTED, STATUS_COMPLETED] }
  validates :processing_opinion, inclusion: { in: ProcessingOpinionOptions.all }, allow_blank: true
  
  # 添加回调
  before_validation :normalize_attributes
  after_save :update_reimbursement_status, if: -> { saved_change_to_status? }
  
  private
  
  # 规范化属性
  def normalize_attributes
    self.processing_opinion = processing_opinion.strip if processing_opinion.present?
    self.audit_comment = audit_comment.strip if audit_comment.present?
    self.remark = remark.strip if remark.present?
  end
  
  # 更新报销单状态
  def update_reimbursement_status
    reimbursement.update_status_based_on_work_orders! if reimbursement.present?
  end
end
```

### 1.4 控制器层重构

#### 1.4.1 添加批量操作

在`AuditWorkOrdersController`中添加批量操作：

```ruby
# app/admin/audit_work_orders.rb
ActiveAdmin.register AuditWorkOrder do
  # 现有代码...
  
  # 批量审核通过
  batch_action :approve, if: proc { params[:scope] == 'pending' || params[:q].blank? } do |ids|
    batch_action_collection.find(ids).each do |work_order|
      begin
        service = WorkOrderService.new(work_order, current_admin_user)
        service.approve(processing_opinion: '可以通过', audit_comment: '批量审核通过')
      rescue => e
        Rails.logger.warn "Batch action approve failed for AuditWorkOrder #{work_order.id}: #{e.message}"
      end
    end
    redirect_to collection_path, notice: "已尝试批量审核通过选中的工单"
  end
  
  # 批量拒绝
  batch_action :reject, if: proc { params[:scope] == 'pending' || params[:q].blank? } do |ids|
    batch_action_collection.find(ids).each do |work_order|
      begin
        service = WorkOrderService.new(work_order, current_admin_user)
        service.reject(processing_opinion: '无法通过', audit_comment: '批量审核拒绝')
      rescue => e
        Rails.logger.warn "Batch action reject failed for AuditWorkOrder #{work_order.id}: #{e.message}"
      end
    end
    redirect_to collection_path, notice: "已尝试批量审核拒绝选中的工单"
  end
end
```

#### 1.4.2 添加高级过滤器

在`AuditWorkOrdersController`中添加高级过滤器：

```ruby
# app/admin/audit_work_orders.rb
ActiveAdmin.register AuditWorkOrder do
  # 现有代码...
  
  # 启用过滤器
  config.filters = true
  
  # 添加过滤器
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :status, as: :select, collection: -> { AuditWorkOrder.state_machine(:status).states.map(&:value) }
  filter :creator, as: :select, collection: -> { AdminUser.all }
  filter :created_at, as: :date_range
  filter :problem_types, as: :select, collection: -> { ProblemType.active.order(:code) }
  filter :fee_details_fee_type, as: :select, collection: -> { FeeDetail.distinct.pluck(:fee_type) }, label: '费用类型'
end
```

### 1.5 视图层重构

#### 1.5.1 添加批量操作按钮

在`_fee_details_selection.html.erb`中添加批量操作按钮：

```erb
<%# app/views/admin/shared/_fee_details_selection.html.erb %>
<%# 在费用明细选择区域添加批量操作按钮 %>

<div class="batch-actions">
  <button type="button" class="select-all-button">全选</button>
  <button type="button" class="deselect-all-button">取消全选</button>
</div>

<script>
  document.addEventListener('DOMContentLoaded', function() {
    // 现有代码...
    
    // 全选按钮
    const selectAllButton = document.querySelector('.select-all-button');
    if (selectAllButton) {
      selectAllButton.addEventListener('click', function() {
        feeDetailCheckboxes.forEach(checkbox => {
          checkbox.checked = true;
        });
        updateSelectedFeeDetails();
        updateFeeTypeTags();
        loadProblemTypes();
      });
    }
    
    // 取消全选按钮
    const deselectAllButton = document.querySelector('.deselect-all-button');
    if (deselectAllButton) {
      deselectAllButton.addEventListener('click', function() {
        feeDetailCheckboxes.forEach(checkbox => {
          checkbox.checked = false;
        });
## 2. 文档更新详细计划

### 2.1 数据库结构文档

#### 2.1.1 创建数据库结构图

创建一个新的数据库结构图，反映单表继承（STI）架构：

```markdown
# 数据库结构图

## 核心表

### work_orders
- id: integer (主键)
- type: string (单表继承类型: AuditWorkOrder, CommunicationWorkOrder, etc.)
- reimbursement_id: integer (外键 -> reimbursements.id)
- status: string (状态: pending, approved, rejected, completed)
- processing_opinion: string (处理意见)
- audit_comment: text (审核意见)
- audit_date: date (审核日期)
- created_by: integer (外键 -> admin_users.id)
- created_at: datetime
- updated_at: datetime

### work_order_fee_details
- id: integer (主键)
- work_order_id: integer (外键 -> work_orders.id)
- fee_detail_id: integer (外键 -> fee_details.id)
- created_at: datetime
- updated_at: datetime

### fee_details
- id: integer (主键)
- document_number: string (外键 -> reimbursements.invoice_number)
- fee_type: string (费用类型)
- amount: decimal (金额)
- fee_date: date (费用日期)
- verification_status: string (验证状态: pending, verified, problematic)
- notes: text (备注)
- created_at: datetime
- updated_at: datetime

## 关系图

```
+----------------+       +----------------------+       +----------------+
| work_orders    |       | work_order_fee_details |       | fee_details    |
+----------------+       +----------------------+       +----------------+
| id             |<----->| work_order_id        |<----->| id             |
| type           |       | fee_detail_id        |       | document_number|
| reimbursement_id|       | created_at           |       | fee_type       |
| status         |       | updated_at           |       | amount         |
| ...            |       |                      |       | ...            |
+----------------+       +----------------------+       +----------------+
       ^                                                       ^
       |                                                       |
       |                                                       |
       |                                                       |
       v                                                       v
+----------------+                                    +----------------+
| reimbursements |                                    | admin_users    |
+----------------+                                    +----------------+
| id             |                                    | id             |
| invoice_number |                                    | email          |
| ...            |                                    | ...            |
+----------------+                                    +----------------+
```

#### 2.1.2 更新数据库迁移说明

创建一个新的数据库迁移说明文档，详细说明从多态关联到单表继承的迁移过程：

```markdown
# 数据库迁移说明

## 从多态关联到单表继承的迁移

### 1. 迁移前的数据库结构

在迁移前，系统使用多态关联来连接不同类型的工单和费用明细：

- `work_order_fee_details`表使用`work_order_id`和`work_order_type`字段实现多态关联
- 不同类型的工单（如`AuditWorkOrder`、`CommunicationWorkOrder`）通过多态关联与费用明细关联

### 2. 迁移步骤

1. 创建新的`work_order_fee_details_v2`表，使用普通外键关联
2. 将数据从旧表迁移到新表
3. 重命名表，将新表设为主表

### 3. 迁移后的数据库结构

在迁移后，系统使用单表继承（STI）和普通关联：

- `work_orders`表使用`type`字段实现单表继承
- `work_order_fee_details`表使用普通外键`work_order_id`关联到`work_orders`表
- 不同类型的工单都存储在`work_orders`表中，通过`type`字段区分

### 4. 索引优化

为提高查询性能，添加了以下索引：

- `work_orders`表的`type`字段
- `work_orders`表的`status`字段
- `work_orders`表的`reimbursement_id`和`type`字段组合
- `work_order_fee_details`表的`work_order_id`和`fee_detail_id`字段组合
- `fee_details`表的`verification_status`字段
```

### 2.2 代码组织文档

#### 2.2.1 创建类图

创建一个类图，展示系统的类层次结构：

```markdown
# 类图

## 模型层

```
+-------------------+
|    ApplicationRecord    |
+-------------------+
         ^
         |
+-------------------+
|     WorkOrder     |
+-------------------+
| +type: string     |
| +status: string   |
| +sync_fee_details_verification_status() |
+-------------------+
         ^
         |
         |
+------------------+------------------+
|                  |                  |
+------------------+  +---------------+
| AuditWorkOrder   |  | CommunicationWorkOrder |
+------------------+  +---------------+
| (特定属性和方法)  |  | (特定属性和方法) |
+------------------+  +---------------+


+-------------------+       +-------------------+       +-------------------+
|     FeeDetail     |<----->| WorkOrderFeeDetail |<----->|     WorkOrder     |
+-------------------+       +-------------------+       +-------------------+
```
#### 2.2.2 创建代码组织说明

创建一个代码组织说明文档，详细说明系统的代码组织结构：

```markdown
# 代码组织说明

## 1. 模型层

### 1.1 单表继承（STI）

系统使用单表继承（STI）来组织不同类型的工单：

- `WorkOrder`：基类，包含所有工单共有的属性和方法
- `AuditWorkOrder`：审核工单，继承自`WorkOrder`
- `CommunicationWorkOrder`：沟通工单，继承自`WorkOrder`

### 1.2 关联关系

- `WorkOrder`与`FeeDetail`通过`WorkOrderFeeDetail`关联表建立多对多关联
- `WorkOrder`与`ProblemType`通过`WorkOrderProblem`关联表建立多对多关联
- `WorkOrder`与`Reimbursement`建立多对一关联
- `WorkOrder`与`AdminUser`建立多对一关联（创建者）

## 2. 服务层

### 2.1 服务层继承结构

服务层也采用继承结构：

- `UnifiedWorkOrderService`：统一服务，包含所有工单共有的操作
- `WorkOrderService`：工单服务，继承自`UnifiedWorkOrderService`
- `AuditWorkOrderService`：审核工单服务，继承自`WorkOrderService`
- `CommunicationWorkOrderService`：沟通工单服务，继承自`WorkOrderService`

### 2.2 服务职责

- `FeeDetailStatusService`：负责更新费用明细的验证状态
- `WorkOrderProblemService`：负责管理工单的问题类型
- `WorkOrderOperationService`：负责记录工单的操作历史

## 3. 控制器层

系统使用ActiveAdmin作为管理界面，控制器集成在ActiveAdmin的DSL中：

- `app/admin/audit_work_orders.rb`：审核工单控制器
- `app/admin/communication_work_orders.rb`：沟通工单控制器
- `app/admin/fee_details.rb`：费用明细控制器
- `app/admin/reimbursements.rb`：报销单控制器

## 4. 视图层

系统使用ActiveAdmin的DSL和自定义视图：

- `app/views/admin/shared/_fee_details_selection.html.erb`：费用明细选择视图
- `app/views/admin/shared/_work_order_approve_or_reject.html.erb`：工单审核/拒绝视图
- `app/views/admin/audit_work_orders/approve.html.erb`：审核工单审核视图
- `app/views/admin/audit_work_orders/reject.html.erb`：审核工单拒绝视图
```

### 2.3 API文档

#### 2.3.1 创建服务API文档

创建一个服务API文档，详细说明系统的服务API：

```markdown
# 服务API文档

## WorkOrderService

### approve(params = {})

审核通过工单。

**参数**：
- `params`：包含以下可选参数：
  - `audit_comment`：审核意见
  - `remark`：备注
  - `problem_type_ids`：问题类型ID数组（仅在拒绝时使用）

**返回值**：
- `true`：操作成功
- `false`：操作失败

**示例**：
```ruby
service = WorkOrderService.new(work_order, current_admin_user)
result = service.approve(audit_comment: '审核通过', remark: '无问题')
```

### reject(params = {})

审核拒绝工单。

**参数**：
- `params`：包含以下可选参数：
  - `audit_comment`：审核意见
  - `remark`：备注
  - `problem_type_ids`：问题类型ID数组

**返回值**：
- `true`：操作成功
- `false`：操作失败

**示例**：
```ruby
service = WorkOrderService.new(work_order, current_admin_user)
result = service.reject(audit_comment: '审核拒绝', remark: '有问题', problem_type_ids: [1, 2])
```

## FeeDetailStatusService

### update_status()

更新费用明细的验证状态。

**参数**：无

**返回值**：无

**示例**：
```ruby
service = FeeDetailStatusService.new([1, 2, 3])
service.update_status
```

### update_status_for_work_order(work_order)

更新与指定工单关联的费用明细的验证状态。

**参数**：
- `work_order`：工单对象

**返回值**：无

**示例**：
```ruby
service = FeeDetailStatusService.new
service.update_status_for_work_order(work_order)
```

## WorkOrderProblemService

### add_problems(problem_type_ids)

添加多个问题类型到工单。

**参数**：
- `problem_type_ids`：问题类型ID数组

**返回值**：
- `true`：操作成功
- `false`：操作失败

**示例**：
```ruby
service = WorkOrderProblemService.new(work_order)
result = service.add_problems([1, 2, 3])
```
```

### 2.4 用户指南

#### 2.4.1 创建管理员用户指南

创建一个管理员用户指南，详细说明系统的使用方法：

```markdown
# 管理员用户指南

## 1. 工单管理

### 1.1 创建审核工单

1. 进入报销单详情页
2. 点击"新建审核工单"按钮
3. 选择需要审核的费用明细
4. 选择处理意见
5. 填写审核意见
6. 点击"创建审核工单"按钮

### 1.2 审核工单

1. 进入审核工单详情页
2. 点击"审核通过"或"审核拒绝"按钮
3. 填写审核意见
4. 如果选择"审核拒绝"，还需要选择问题类型
5. 点击"确认通过"或"确认拒绝"按钮

### 1.3 批量审核工单

1. 进入审核工单列表页
2. 选择需要批量审核的工单
3. 点击"批量操作"下拉菜单
4. 选择"批量审核通过"或"批量审核拒绝"
5. 确认操作

## 2. 费用明细管理

### 2.1 查看费用明细

1. 进入费用明细列表页
2. 使用过滤器筛选费用明细
3. 点击费用明细ID查看详情

### 2.2 更新费用明细验证状态

1. 进入费用明细详情页
2. 点击"更新验证状态"按钮
3. 选择新的验证状态
4. 填写备注
5. 点击"确认更新"按钮

## 3. 报销单管理

### 3.1 查看报销单

1. 进入报销单列表页
2. 使用过滤器筛选报销单
3. 点击报销单号查看详情

### 3.2 关闭报销单

1. 进入报销单详情页
2. 点击"关闭报销单"按钮
3. 确认操作
```

#### 2.4.2 创建开发者指南

创建一个开发者指南，详细说明系统的开发方法：

```markdown
# 开发者指南

## 1. 系统架构

### 1.1 技术栈

- Ruby on Rails：Web框架
- ActiveAdmin：管理界面
- SQLite/MySQL/PostgreSQL：数据库
- RSpec：测试框架

### 1.2 架构概述

系统采用MVC架构，并添加了服务层：

- 模型层（Model）：使用ActiveRecord实现，包括单表继承（STI）
- 视图层（View）：使用ActiveAdmin DSL和ERB模板
- 控制器层（Controller）：集成在ActiveAdmin DSL中
- 服务层（Service）：包含业务逻辑

## 2. 开发环境设置

### 2.1 安装依赖

```bash
bundle install
```

### 2.2 数据库设置

```bash
rails db:create
rails db:migrate
rails db:seed
```

### 2.3 启动服务器

```bash
rails server
```

## 3. 开发指南

### 3.1 添加新的工单类型

1. 创建新的工单类：

```ruby
# app/models/new_work_order.rb
class NewWorkOrder < WorkOrder
  # 特定属性和方法
end
```

2. 创建ActiveAdmin资源：

```ruby
# app/admin/new_work_orders.rb
ActiveAdmin.register NewWorkOrder do
  # 配置
end
```

3. 创建服务类：

```ruby
# app/services/new_work_order_service.rb
class NewWorkOrderService < WorkOrderService
  # 特定方法
end
```

### 3.2 添加新的功能

1. 创建迁移文件：

```bash
rails generate migration AddNewFeature
```

2. 修改模型：

```ruby
# app/models/work_order.rb
class WorkOrder < ApplicationRecord
  # 添加新属性和方法
end
```

3. 修改服务：

```ruby
# app/services/work_order_service.rb
class WorkOrderService
  # 添加新方法
end
```

4. 修改视图：

```erb
<%# app/views/admin/shared/_new_feature.html.erb %>
<div class="new-feature">
  <!-- 新功能的HTML -->
</div>
```

5. 修改控制器：

```ruby
# app/admin/work_orders.rb
ActiveAdmin.register WorkOrder do
  # 添加新操作
end
```

## 4. 测试指南

### 4.1 运行测试

```bash
bundle exec rspec
```

### 4.2 添加模型测试

```ruby
# spec/models/work_order_spec.rb
RSpec.describe WorkOrder, type: :model do
  # 测试用例
end
```

### 4.3 添加服务测试

```ruby
# spec/services/work_order_service_spec.rb
RSpec.describe WorkOrderService, type: :service do
  # 测试用例
end
```

### 4.4 添加集成测试

```ruby
# spec/features/work_order_spec.rb
RSpec.describe "WorkOrder", type: :feature do
  # 测试用例
end
```
```

## 服务层

```
+-------------------+
| UnifiedWorkOrderService |
+-------------------+
| +change_status()  |
+-------------------+
         ^
         |
+-------------------+
|  WorkOrderService  |
+-------------------+
| +approve()        |
| +reject()         |
+-------------------+
         ^
         |
+------------------+------------------+
|                  |                  |
+------------------+  +---------------+
| AuditWorkOrderService | | CommunicationWorkOrderService |
+------------------+  +---------------+
| (特定方法)        |  | (特定方法)     |
+------------------+  +---------------+
```
        updateSelectedFeeDetails();
        updateFeeTypeTags();
        loadProblemTypes();
      });
    }
  });
</script>
```

#### 1.5.2 改进问题类型选择界面

优化问题类型选择界面，使其更加用户友好：

```erb
<%# app/views/admin/shared/_fee_details_selection.html.erb %>
<%# 修改问题类型选择区域 %>

<div class="problem-types-container" id="problem-types-container" style="display:none;">
  <h4>选择问题类型</h4>
  <div class="problem-types-filter">
    <input type="text" id="problem-type-search" placeholder="搜索问题类型..." />
  </div>
  <div class="problem-types-wrapper"></div>
</div>

<script>
  document.addEventListener('DOMContentLoaded', function() {
    // 现有代码...
    
    // 添加问题类型搜索功能
    const problemTypeSearch = document.getElementById('problem-type-search');
    if (problemTypeSearch) {
      problemTypeSearch.addEventListener('input', function() {
        const searchTerm = this.value.toLowerCase();
        const problemTypeCheckboxes = document.querySelectorAll('.problem-type-checkbox');
        
        problemTypeCheckboxes.forEach(checkbox => {
          const label = checkbox.querySelector('label');
          const text = label.textContent.toLowerCase();
          
          if (text.includes(searchTerm)) {
            checkbox.style.display = '';
          } else {
            checkbox.style.display = 'none';
          }
        });
      });
    }
  });
</script>
```
#### 1.3.2 添加查询范围

在`WorkOrder`模型中添加更多有用的查询范围：

```ruby
# app/models/work_order.rb
class WorkOrder < ApplicationRecord
  # 现有代码...
  
  # 添加查询范围
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date.beginning_of_day..end_date.end_of_day) }
  scope :with_problem_type, ->(problem_type_id) { joins(:problem_types).where(problem_types: { id: problem_type_id }) }
  scope :with_fee_type, ->(fee_type) { joins(:fee_details).where(fee_details: { fee_type: fee_type }).distinct }
end
```
def scoped_collection
  CommunicationWorkOrder.includes(:reimbursement, :creator, :fee_details, :problem_types, :communication_records)
end