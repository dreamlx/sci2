# SCI2工单系统需求分析与开发计划（更新版）

## 1. 现状与需求分析

### 1.1 数据库结构现状

现有的数据模型包含以下核心表：
- `reimbursements`：报销单主表
- `fee_details`：费用明细表
- `work_orders`：工单基表（STI实现）
- `work_order_fee_details`：工单和费用明细的关联表
- `problem_types`、`fee_types`、`document_categories`等：问题代码相关表

**主要问题**:
1. 数据模型过于复杂，不符合简单两级结构需求
2. 现有的问题代码库表结构不支持两级级联下拉设计
3. 费用明细状态逻辑不符合"最新工单决定"原则
4. 缺乏对多问题添加到工单的明确支持

### 1.2 业务需求澄清

根据测试计划和用户确认，主要需求为：

1. **问题代码库两级结构**:
   - 需简化为 FeeType -> ProblemType 两层结构
   - FeeType 需包含 code, title, meeting_type 字段
   - ProblemType 需包含 code, title, sop_description, standard_handling 字段
   - 使用 meeting_type 区分"个人"和"学术"类型

2. **工单与费用明细关系**:
   - **最新工单决定原则**：费用明细的状态由最新关联的工单状态决定
   - 如果最新工单是approved，则费用明细为verified
   - 如果最新工单是rejected，则费用明细为problematic
   - 工单处理流程：选择费用明细组 -> 添加多个问题 -> 设置处理意见

3. **工单问题添加**:
   - 支持在一个工单中添加多个问题
   - 问题信息需显示在审核描述文本中，并以空行分隔

### 1.3 界面需求更新（2025年6月）

根据客户最新反馈，需要对审核工单表单进行调整：

1. **费用类型显示方式变更**：
   - 原设计：通过下拉列表选择费用类型
   - 新需求：根据选择的费用明细自动分组显示费用类型标签

2. **问题类型选择方式变更**：
   - 原设计：单选下拉列表
   - 新需求：多选复选框，允许选择多个问题类型

3. **审核意见生成方式变更**：
   - 原设计：根据选择的问题类型自动填充审核意见
   - 新需求：完全由用户手动输入，不再自动填充

## 2. 项目对齐与开发计划

### 2.1 数据库结构调整

```mermaid
erDiagram
    FeeType {
        integer id PK
        string code "唯一"
        string title
        string meeting_type "个人/学术"
        boolean active
    }
    ProblemType {
        integer id PK
        integer fee_type_id FK
        string code "在fee_type内唯一"
        string title
        text sop_description
        text standard_handling
        boolean active
    }
    Reimbursement {
        integer id PK
        string invoice_number "唯一"
        string document_name
        string status "pending/processing/closed"
        boolean is_electronic
    }
    FeeDetail {
        integer id PK
        string document_number FK "关联到Reimbursement.invoice_number"
        string verification_status "pending/problematic/verified"
        decimal amount
    }
    WorkOrder {
        integer id PK
        integer reimbursement_id FK
        string type "STI"
        string status
        text audit_comment
    }
    WorkOrderFeeDetail {
        integer id PK
        integer work_order_id FK
        integer fee_detail_id FK
        string work_order_type
    }
    WorkOrderProblem {
        integer id PK
        integer work_order_id FK
        integer problem_type_id FK
    }
    
    FeeType ||--o{ ProblemType : "has"
    WorkOrder ||--o{ WorkOrderProblem : "has"
    ProblemType ||--o{ WorkOrderProblem : "used_in"
    Reimbursement ||--o{ WorkOrder : "has"
    Reimbursement ||--o{ FeeDetail : "has"
    WorkOrder ||--o{ WorkOrderFeeDetail : "has"
    FeeDetail ||--o{ WorkOrderFeeDetail : "associated_with"
```

需执行的数据库变更：

1. 修改 FeeType 表结构
   - 添加 `code` (字符串，唯一)
   - 添加 `title` (字符串)
   - 添加 `meeting_type` (字符串，例如"个人"或"学术论坛")
   - 添加 `active` (布尔值，默认true)

2. 修改 ProblemType 表结构
   - 添加 `code` (字符串，在其fee_type_id范围内唯一)
   - 重命名 `name` 为 `title` (或添加 `title` 并保持兼容)
   - 添加 `sop_description` (文本)
   - 添加 `standard_handling` (文本)
   - 添加 `fee_type_id` (外键，关联到FeeType表)
   - 移除 `document_category_id` 字段

3. 简化关联表结构
   - 移除不必要的 ProblemTypeFeeTye, Material, ProblemDescription 等表
   - 确保 WorkOrderFeeDetail 表的功能完整

4. 创建工单问题关联表
   - 创建 `work_order_problems` 表
   - 添加 `work_order_id` 和 `problem_type_id` 外键
   - 添加唯一索引确保不重复添加同一问题

### 2.2 模型实现调整

1. **FeeType 模型**
```ruby
class FeeType < ApplicationRecord
  has_many :problem_types, dependent: :destroy
  
  validates :code, presence: true, uniqueness: true
  validates :title, presence: true
  validates :meeting_type, presence: true
  validates :active, inclusion: { in: [true, false] }
  
  scope :active, -> { where(active: true) }
  scope :by_meeting_type, ->(type) { where(meeting_type: type) }
  
  def display_name
    "#{code} - #{title}"
  end
end
```

2. **ProblemType 模型**
```ruby
class ProblemType < ApplicationRecord
  belongs_to :fee_type
  has_many :work_order_problems
  has_many :work_orders, through: :work_order_problems
  
  validates :code, presence: true, uniqueness: { scope: :fee_type_id }
  validates :title, presence: true
  validates :sop_description, presence: true
  validates :standard_handling, presence: true
  validates :active, inclusion: { in: [true, false] }
  
  scope :active, -> { where(active: true) }
  scope :by_fee_type, ->(fee_type_id) { where(fee_type_id: fee_type_id) }
  
  def display_name
    "#{code} - #{title}"
  end
  
  def full_description
    "#{display_name}\n    #{sop_description}\n    #{standard_handling}"
  end
end
```

3. **WorkOrder 模型调整**
```ruby
class WorkOrder < ApplicationRecord
  # 使用STI实现不同类型的工单
  self.inheritance_column = :type
  
  # 关联
  belongs_to :reimbursement
  belongs_to :problem_type, optional: true # 保留向后兼容
  
  # 新增多对多关联
  has_many :work_order_problems, dependent: :destroy
  has_many :problem_types, through: :work_order_problems
  
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

4. **WorkOrderProblem 模型**
```ruby
class WorkOrderProblem < ApplicationRecord
  belongs_to :work_order
  belongs_to :problem_type
  
  validates :work_order_id, uniqueness: { scope: :problem_type_id }
  
  # 记录操作日志
  after_create :log_problem_added
  after_destroy :log_problem_removed
end
```

### 2.3 服务层实现

1. **问题代码库服务**
```ruby
# app/services/problem_code_import_service.rb
class ProblemCodeImportService
  def initialize(file_path, meeting_type)
    @file_path = file_path
    @meeting_type = meeting_type
  end
  
  def import
    # CSV导入逻辑
    # 创建FeeType和ProblemType记录
  end
end
```

2. **工单问题服务**
```ruby
# app/services/work_order_problem_service.rb
class WorkOrderProblemService
  def initialize(work_order)
    @work_order = work_order
  end
  
  # 添加多个问题类型
  def add_problems(problem_type_ids)
    return false if problem_type_ids.blank?
    
    # 清除现有关联
    @work_order.work_order_problems.destroy_all
    
    # 创建新关联
    problem_type_ids.each do |problem_type_id|
      @work_order.work_order_problems.create(problem_type_id: problem_type_id)
    end
    
    true
  end
  
  # 获取当前关联的所有问题类型
  def get_problems
    @work_order.problem_types
  end
end
```

3. **费用明细分组服务**
```ruby
# app/services/fee_detail_group_service.rb
class FeeDetailGroupService
  def initialize(fee_detail_ids)
    @fee_detail_ids = Array(fee_detail_ids)
    @fee_details = FeeDetail.where(id: @fee_detail_ids)
  end
  
  # 按费用类型分组
  def group_by_fee_type
    @fee_details.group_by(&:fee_type)
  end
  
  # 获取所有相关的问题类型
  def available_problem_types
    ProblemType.active.where(fee_type: fee_type_ids)
  end
end
```

4. **费用明细状态服务**
```ruby
# app/services/fee_detail_status_service.rb
class FeeDetailStatusService
  def initialize(fee_detail_ids)
    @fee_detail_ids = Array(fee_detail_ids)
  end
  
  def update_status
    FeeDetail.where(id: @fee_detail_ids).find_each do |fee_detail|
      # 获取最新关联工单（按更新时间排序）
      latest_work_order = fee_detail.work_orders.order(updated_at: :desc).first
      
      if latest_work_order.nil?
        # 如果没有关联工单，保持pending状态
        fee_detail.update(verification_status: FeeDetail::VERIFICATION_STATUS_PENDING)
        next
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
end
```

### 2.4 控制器实现

1. **AuditWorkOrdersController 调整**
```ruby
# app/admin/audit_work_order.rb
ActiveAdmin.register AuditWorkOrder do
  permit_params :reimbursement_id, :audit_comment,
                :remark, :processing_opinion,
                submitted_fee_detail_ids: [], problem_type_ids: []
  
  # 创建方法
  def create
    @audit_work_order = AuditWorkOrder.new(audit_work_order_params.except(:submitted_fee_detail_ids, :problem_type_ids))
    
    # 设置费用明细关联
    if audit_work_order_params[:submitted_fee_detail_ids].present?
      @audit_work_order.submitted_fee_detail_ids = audit_work_order_params[:submitted_fee_detail_ids]
    end
    
    # 设置问题类型IDs
    if audit_work_order_params[:problem_type_ids].present?
      @audit_work_order.problem_type_ids = audit_work_order_params[:problem_type_ids]
    end
    
    if @audit_work_order.save
      redirect_to admin_audit_work_order_path(@audit_work_order)
    else
      render :new
    end
  end
end
```

2. **ProblemTypesController JSON端点**
```ruby
# app/admin/problem_types.rb
ActiveAdmin.register ProblemType do
  # 添加JSON端点
  collection_action :index, format: :json do
    if params[:fee_type_id].present?
      # 单个费用类型查询
      @problem_types = ProblemType.active.by_fee_type(params[:fee_type_id])
    elsif params[:fee_type_ids].present?
      # 多个费用类型查询
      fee_type_ids = params[:fee_type_ids].split(',')
      @problem_types = ProblemType.active.where(fee_type_id: fee_type_ids)
    else
      @problem_types = ProblemType.active
    end
    
    render json: @problem_types.as_json(
      only: [:id, :code, :title, :fee_type_id],
      methods: [:display_name]
    )
  end
end
```

### 2.5 界面实现

1. **费用明细选择与费用类型标签**
```erb
<%# app/views/admin/shared/_fee_details_selection.html.erb %>
<div class="panel">
  <h3>选择关联的费用明细</h3>
  <div class="fee-details-selection">
    <% reimbursement.fee_details.each do |fee_detail| %>
      <div class="fee-detail-item">
        <%= check_box_tag "#{param_name}[submitted_fee_detail_ids][]",
                        fee_detail.id,
                        work_order.submitted_fee_detail_ids&.include?(fee_detail.id.to_s),
                        id: "fee_detail_#{fee_detail.id}",
                        class: "fee-detail-checkbox",
                        data: { fee_type: fee_detail.fee_type } %>
        <span class="fee-detail-id">#<%= fee_detail.id %></span>
        <span class="fee-detail-type"><%= fee_detail.fee_type %></span>
        <span class="fee-detail-amount"><%= number_to_currency(fee_detail.amount, unit: "¥") %></span>
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
</div>
```

2. **JavaScript实现**
```javascript
document.addEventListener('DOMContentLoaded', function() {
  const feeDetailCheckboxes = document.querySelectorAll('.fee-detail-checkbox');
  const feeTypeTagsContainer = document.querySelector('.fee-type-tags-container');
  const problemTypesContainer = document.getElementById('problem-types-container');
  
  // 监听费用明细复选框变化
  feeDetailCheckboxes.forEach(checkbox => {
    checkbox.addEventListener('change', function() {
      updateSelectedFeeDetails();
      updateFeeTypeTags();
      loadProblemTypes();
    });
  });
  
  // 更新选中的费用明细
  function updateSelectedFeeDetails() {
    // 按费用类型分组
    feeTypeGroups = {};
    
    feeDetailCheckboxes.forEach(checkbox => {
      if (checkbox.checked) {
        const feeType = checkbox.dataset.feeType;
        
        if (!feeTypeGroups[feeType]) {
          feeTypeGroups[feeType] = [];
        }
        feeTypeGroups[feeType].push(checkbox.value);
      }
    });
  }
  
  // 更新费用类型标签
  function updateFeeTypeTags() {
    feeTypeTagsContainer.innerHTML = '';
    
    for (const feeType in feeTypeGroups) {
      const tagDiv = document.createElement('div');
      tagDiv.className = 'fee-type-tag';
      tagDiv.textContent = `${feeType} (${feeTypeGroups[feeType].length}项)`;
      feeTypeTagsContainer.appendChild(tagDiv);
    }
    
    problemTypesContainer.style.display = Object.keys(feeTypeGroups).length > 0 ? 'block' : 'none';
  }
  
  // 加载问题类型
  function loadProblemTypes() {
    // 获取所有相关费用类型的ID
    const feeTypeIds = Object.keys(feeTypeGroups).map(feeType => {
      return getFeeTypeIdByName(feeType);
    }).filter(id => id);
    
    // 按费用类型获取问题类型
    fetch('/admin/problem_types.json?fee_type_ids=' + feeTypeIds.join(','))
      .then(response => response.json())
      .then(data => {
        // 按费用类型分组显示问题类型
        renderProblemTypeCheckboxes(data);
      });
  }
});
```

## 3. 开发阶段划分

### 3.1 阶段一：数据库结构调整 (1周)
- 创建和执行数据库迁移脚本
- 数据模型调整
- 基础测试编写

**具体任务**:
1. 创建FeeType表结构迁移
2. 创建ProblemType表结构迁移
3. 创建关联表清理迁移
4. 创建WorkOrderProblem表迁移
5. 编写数据迁移脚本，迁移现有数据到新结构
6. 更新模型关联和验证
7. 编写单元测试确保数据一致性

### 3.2 阶段二：模型与服务实现 (2周)
- 修改工单相关模型
- 实现服务层逻辑
- 编写单元测试和集成测试

**具体任务**:
1. 实现FeeType和ProblemType模型
2. 实现问题代码导入服务
3. 调整WorkOrder模型，支持多问题处理
4. 实现WorkOrderProblem模型
5. 实现WorkOrderProblemService服务
6. 实现FeeDetailGroupService服务
7. 修改费用明细状态处理逻辑
8. 编写单元测试和集成测试

### 3.3 阶段三：UI实现 (2周)
- ActiveAdmin界面调整
- 费用类型标签显示实现
- 问题类型多选组件实现

**具体任务**:
1. 实现FeeType和ProblemType管理界面
2. 实现工单创建/编辑表单
3. 实现费用明细选择与费用类型标签显示
4. 实现问题类型多选界面
5. 实现相关JavaScript交互逻辑
6. 调整费用明细关联工单显示
7. 实现报销单状态管理界面

### 3.4 阶段四：测试与部署 (1周)
- 运行全套测试
- 修复问题
- 准备部署文档

**具体任务**:
1. 运行所有单元测试和集成测试
2. 执行端到端测试，验证所有场景
3. 修复发现的问题
4. 准备数据库迁移脚本
5. 编写部署文档
6. 准备上线计划

## 4. 总结

本开发计划针对SCI2工单系统的最新需求变动，通过自顶向下分析，确定了当前系统与目标需求之间的差距，并提出了详细的开发策略。主要变更集中在数据库结构简化、两级问题代码库实现、工单与费用明细关系逻辑优化，以及界面交互优化等方面。

整个开发预计需要6周时间，分为四个主要阶段，确保系统能够满足业务需求的同时保持良好的可维护性。