# 填充ID导入导出功能完善计划

## 概述

基于用户反馈，需要完善填充ID在导入导出流程中的处理逻辑。核心要求是：**更新记录只需要按filling_id判断**。

## 当前问题分析

### 1. ActiveAdmin导出功能问题
**文件**: `app/admin/express_receipt_work_orders.rb`
**问题**: 第183行显示的是工单ID而不是filling_id
```ruby
column("Filling ID") { |wo| wo.id }  # 错误：显示工单ID
```

### 2. 导入服务逻辑问题
**文件**: `app/services/express_receipt_import_service.rb`
**问题**: 第93-96行遇到重复记录时跳过，而不是更新
```ruby
# 重复检查（如果存在则跳过）
if ExpressReceiptWorkOrder.exists?(reimbursement_id: reimbursement.id, tracking_number: tracking_number)
  @skipped_count += 1
  return
end
```

## 实施计划

### 阶段一：修复ActiveAdmin导出功能

#### 1.1 修复标准CSV导出
**目标**: 确保ActiveAdmin标准CSV导出包含正确的filling_id

**修改文件**: `app/admin/express_receipt_work_orders.rb`
**修改位置**: 第182-194行

**修改前**:
```ruby
# ActiveAdmin 标准 CSV 导出配置
csv do
  column("Filling ID") { |wo| wo.id }
  column("报销单单号") { |wo| wo.reimbursement&.invoice_number }
  # ... 其他列
end
```

**修改后**:
```ruby
# ActiveAdmin 标准 CSV 导出配置
csv do
  column("填充ID") { |wo| wo.filling_id }
  column("报销单单号") { |wo| wo.reimbursement&.invoice_number }
  # ... 其他列
end
```

#### 1.2 修复自定义CSV导出
**目标**: 确保自定义export_csv action也包含正确的filling_id

**修改文件**: `app/admin/express_receipt_work_orders.rb`
**修改位置**: 第144-174行

**修改前**:
```ruby
csv_data = CSV.generate(headers: true, force_quotes: true) do |csv|
  csv << ["Filling ID", "报销单单号", "单据名称", "报销单申请人", "报销单申请人工号", 
          "申请人部门", "快递单号", "收单时间", "创建人", "创建时间", "Current Assignee"]
  
  work_orders.find_each do |wo|
    csv << [
      wo.id,  # 错误：应该是wo.filling_id
      wo.reimbursement&.invoice_number,
      # ... 其他字段
    ]
  end
end
```

**修改后**:
```ruby
csv_data = CSV.generate(headers: true, force_quotes: true) do |csv|
  csv << ["填充ID", "报销单单号", "单据名称", "报销单申请人", "报销单申请人工号", 
          "申请人部门", "快递单号", "收单时间", "创建人", "创建时间", "Current Assignee"]
  
  work_orders.find_each do |wo|
    csv << [
      wo.filling_id,  # 修正：显示filling_id
      wo.reimbursement&.invoice_number,
      # ... 其他字段
    ]
  end
end
```

#### 1.3 添加filling_id到列表显示
**目标**: 在列表页面显示filling_id列

**修改文件**: `app/admin/express_receipt_work_orders.rb`
**修改位置**: index块内

**修改内容**:
```ruby
index do
  selectable_column
  column("填充ID", :filling_id)
  column("报销单单号") { |wo| wo.reimbursement&.invoice_number }
  # ... 其他列
end
```

### 阶段二：实现基于filling_id的更新导入逻辑

#### 2.1 修改ExpressReceiptImportService核心逻辑
**目标**: 实现基于filling_id的更新逻辑

**修改文件**: `app/services/express_receipt_import_service.rb`
**修改位置**: 第70-139行

**核心逻辑变更**:

**修改前**:
```ruby
def import_express_receipt(row, row_number)
  document_number = row['单号']&.strip
  operation_notes = row['操作意见']&.strip
  received_at_str = row['操作时间']
  
  # 使用正则表达式提取快递单号
  tracking_number = operation_notes&.match(TRACKING_NUMBER_REGEX)&.captures&.first&.strip
  
  unless document_number.present? && tracking_number.present?
    @error_count += 1
    @errors << "行 #{row_number}: 无法找到有效的单号或从操作意见中提取快递单号"
    return
  end
  
  # 查找报销单
  reimbursement = Reimbursement.find_by(invoice_number: document_number)
  
  unless reimbursement
    @unmatched_receipts << { row: row_number, document_number: document_number, tracking_number: tracking_number, error: "报销单不存在" }
    return
  end
  
  # 重复检查（如果存在则跳过）
  if ExpressReceiptWorkOrder.exists?(reimbursement_id: reimbursement.id, tracking_number: tracking_number)
    @skipped_count += 1
    return
  end
  
  # ... 创建新记录的逻辑
end
```

**修改后**:
```ruby
def import_express_receipt(row, row_number)
  document_number = row['单号']&.strip
  operation_notes = row['操作意见']&.strip
  received_at_str = row['操作时间']
  filling_id = row['填充ID']&.strip  # 新增：读取填充ID
  
  # 使用正则表达式提取快递单号
  tracking_number = operation_notes&.match(TRACKING_NUMBER_REGEX)&.captures&.first&.strip
  
  unless document_number.present? && tracking_number.present?
    @error_count += 1
    @errors << "行 #{row_number}: 无法找到有效的单号或从操作意见中提取快递单号"
    return
  end
  
  # 查找报销单
  reimbursement = Reimbursement.find_by(invoice_number: document_number)
  
  unless reimbursement
    @unmatched_receipts << { row: row_number, document_number: document_number, tracking_number: tracking_number, error: "报销单不存在" }
    return
  end
  
  received_at = parse_datetime(received_at_str) || Time.current
  
  # 基于filling_id的更新逻辑
  if filling_id.present?
    # 尝试通过filling_id查找现有记录
    existing_work_order = ExpressReceiptWorkOrder.find_by(filling_id: filling_id)
    
    if existing_work_order
      # 更新现有记录
      begin
        existing_work_order.update!(
          reimbursement: reimbursement,  # 允许更改关联的报销单
          tracking_number: tracking_number,
          received_at: received_at,
          # 不更新filling_id，保持原值
          # 其他需要更新的字段...
        )
        @updated_count += 1
        Rails.logger.info "更新快递收单工单: filling_id=#{filling_id}, tracking_number=#{tracking_number}"
      rescue => e
        @error_count += 1
        @errors << "行 #{row_number} (填充ID: #{filling_id}): 更新失败 - #{e.message}"
        Rails.logger.error "更新失败: #{e.message}"
      end
      return
    else
      # filling_id不存在，可能是错误的filling_id
      @error_count += 1
      @errors << "行 #{row_number}: 填充ID #{filling_id} 不存在"
      return
    end
  end
  
  # 没有filling_id，创建新记录
  # 检查是否已存在相同的(reimbursement_id, tracking_number)组合
  if ExpressReceiptWorkOrder.exists?(reimbursement_id: reimbursement.id, tracking_number: tracking_number)
    @skipped_count += 1
    Rails.logger.info "跳过重复记录: reimbursement_id=#{reimbursement.id}, tracking_number=#{tracking_number}"
    return
  end
  
  # 创建新记录的逻辑保持不变
  work_order = ExpressReceiptWorkOrder.new(
    reimbursement: reimbursement,
    status: 'completed',
    tracking_number: tracking_number,
    received_at: received_at,
    created_by: @current_admin_user.id
  )
  
  # 使用事务确保工单创建和报销单状态更新的原子性
  ActiveRecord::Base.transaction do
    if work_order.save
      @created_count += 1
      # 更新报销单状态
      reimbursement.mark_as_received(received_at)
      
      # 重置通知状态
      if reimbursement.last_viewed_express_receipts_at.present?
        reimbursement.update_column(:last_viewed_express_receipts_at, nil)
        Rails.logger.debug "ExpressReceiptImportService: 重置报销单 ##{reimbursement.id} 的通知状态"
      end
    else
      @error_count += 1
      error_messages = work_order.errors.full_messages.join(', ')
      @errors << "行 #{row_number} (单号: #{document_number}, 快递: #{tracking_number}): #{error_messages}"
      Rails.logger.debug "WorkOrder Save Failed for Row #{row_number} (DN: #{document_number}, TN: #{tracking_number}): #{error_messages}"
      raise ActiveRecord::Rollback
    end
  end
rescue StateMachines::InvalidTransition => e
  @error_count += 1
  @errors << "行 #{row_number} (单号: #{document_number}): 更新报销单状态失败 - #{e.message}"
  Rails.logger.error "Failed to update reimbursement status for WO on row #{row_number} (DN: #{document_number}): #{e.message}"
end
```

#### 2.2 添加更新计数器
**目标**: 区分创建、更新和跳过的记录数量

**修改文件**: `app/services/express_receipt_import_service.rb`
**修改位置**: initialize方法

**修改前**:
```ruby
def initialize(file, current_admin_user)
  @file = file
  @current_admin_user = current_admin_user
  @created_count = 0
  @skipped_count = 0 # 用于重复记录
  @error_count = 0
  @errors = []
  @unmatched_receipts = []
  Current.admin_user = current_admin_user # 设置 Current.admin_user 用于回调
end
```

**修改后**:
```ruby
def initialize(file, current_admin_user)
  @file = file
  @current_admin_user = current_admin_user
  @created_count = 0
  @updated_count = 0  # 新增：更新计数器
  @skipped_count = 0  # 用于重复记录
  @error_count = 0
  @errors = []
  @unmatched_receipts = []
  Current.admin_user = current_admin_user # 设置 Current.admin_user 用于回调
end
```

#### 2.3 修改导入结果返回
**目标**: 在导入结果中包含更新数量

**修改文件**: `app/services/express_receipt_import_service.rb`
**修改位置**: import方法的返回值

**修改前**:
```ruby
{
  success: @error_count == 0,
  created: @created_count,
  skipped: @skipped_count,
  errors: @error_count,
  error_details: @errors,
  unmatched_receipts: @unmatched_receipts
}
```

**修改后**:
```ruby
{
  success: @error_count == 0,
  created: @created_count,
  updated: @updated_count,  # 新增：更新数量
  skipped: @skipped_count,
  errors: @error_count,
  error_details: @errors,
  unmatched_receipts: @unmatched_receipts
}
```

### 阶段三：更新文档说明

#### 3.1 更新数据导入格式参考文档
**目标**: 说明填充ID在导入导出中的处理

**修改文件**: `docs/SCI-系统设计/3.数据导入格式参考.md`

**修改内容**:

在"快递收单导出数据"部分的字段说明中添加：
```markdown
### 字段说明
| 字段名 | 说明 | 示例值 |
|-------|------|-------|
| 序号 | 记录序号 | 1 |
| 单据类型 | 报销单类型 | 学术会议报销单 |
| 单号 | 报销单号 | ER19886133 |
| 申请人 | 申请人姓名 | 潘志琦 |
| 操作时间 | 收单操作时间 | 2025-03-31 17:51:35 |
| 操作类型 | 操作类型 | 单据接收 |
| 操作意见 | 操作意见（包含快递单号） | 快递单号：73547754777673 |

**系统生成字段**
| 字段名 | 说明 | 示例值 |
|-------|------|-------|
| 填充ID (filling_id) | 系统自动生成的10位唯一标识符，格式为YYYYMMNNNN（4位年+2位月+4位序列号） | 2025090001 |

**导入更新支持**
| 字段名 | 说明 | 必填 | 更新导入时的作用 |
|-------|------|------|----------------|
| 填充ID | 用于识别现有记录的唯一标识 | 否 | 如果提供且存在对应记录，则更新该记录；如果提供但不存在，则报错；如果不提供，则创建新记录 |
```

在"数据导入流程"部分的"快递收单导入流程"中更新：
```markdown
### 2. 快递收单导入流程
1. 系统读取CSV文件
2. 检查是否包含填充ID列
   - 如果包含填充ID：
     - 查找对应的快递收单记录
     - 如果找到，更新该记录的其他字段（保留原填充ID）
     - 如果没找到，记录错误
   - 如果不包含填充ID：
     - 从操作意见中提取快递单号
     - 检查是否存在匹配的报销单
     - 检查是否已存在相同的(reimbursement_id, tracking_number)组合
     - 如果存在，跳过该记录
     - 如果不存在，创建新记录并生成新的填充ID
3. 对于匹配成功的记录，自动创建收件工单
```

#### 3.2 更新功能增强文档
**目标**: 在现有功能文档中添加填充ID导入导出说明

**修改文件**: `docs/03-development/feature-development/快递收据和报销增强.md`

**修改内容**:

在"填充ID (Filling ID) 功能"部分添加导入导出说明：
```markdown
#### 1.5 填充ID (Filling ID) 功能
- **文件**: `app/models/express_receipt_work_order.rb`, `app/services/filling_id_generator.rb`, `app/services/express_receipt_import_service.rb`, `app/admin/express_receipt_work_orders.rb`
- **功能**: 为每个快递收单工单生成唯一的10位填充ID，格式为YYYYMMNNNN（4位年+2位月+4位序列号），序列号每月重置
- **导入导出支持**:
  - **首次导入**: 系统自动生成填充ID
  - **导出数据**: CSV文件包含填充ID列，可用于后续更新
  - **更新导入**: 
    - 如果CSV中包含填充ID，系统会查找并更新对应记录
    - 如果CSV中不包含填充ID，系统会创建新记录
    - 填充ID一旦生成，在记录生命周期内保持不变
```

### 阶段四：测试验证

#### 4.1 单元测试
**目标**: 验证填充ID的导入导出逻辑

**测试文件**: `spec/models/express_receipt_work_order_spec.rb`

**新增测试用例**:
```ruby
describe "填充ID导入导出" do
  let(:reimbursement) { create(:reimbursement) }
  
  it "导出CSV包含正确的filling_id" do
    work_order = create(:express_receipt_work_order, reimbursement: reimbursement)
    
    # 模拟ActiveAdmin CSV导出
    csv_content = CSV.generate do |csv|
      csv << ["填充ID", "快递单号"]
      csv << [work_order.filling_id, work_order.tracking_number]
    end
    
    expect(csv_content).to include(work_order.filling_id)
  end
  
  it "通过filling_id更新现有记录" do
    # 创建初始记录
    original_work_order = create(:express_receipt_work_order, 
      reimbursement: reimbursement, 
      tracking_number: "SF123456",
      received_at: Time.current - 1.day
    )
    original_filling_id = original_work_order.filling_id
    
    # 模拟导入更新
    import_service = ExpressReceiptImportService.new(
      double("file"), 
      @current_admin_user
    )
    
    # 模拟包含filling_id的行数据
    row_with_filling_id = {
      '单号' => reimbursement.invoice_number,
      '操作意见' => "快递单号：SF123456",
      '操作时间' => Time.current.strftime('%Y-%m-%d %H:%M:%S'),
      '填充ID' => original_filling_id
    }
    
    # 调用导入方法
    import_service.send(:import_express_receipt, row_with_filling_id, 1)
    
    # 验证记录被更新而不是创建新记录
    expect(ExpressReceiptWorkOrder.count).to eq(1)
    updated_work_order = ExpressReceiptWorkOrder.first
    expect(updated_work_order.filling_id).to eq(original_filling_id)
    expect(updated_work_order.received_at).to be_within(1.second).of(Time.current)
  end
  
  it "处理不存在的filling_id" do
    import_service = ExpressReceiptImportService.new(
      double("file"), 
      @current_admin_user
    )
    
    # 模拟包含不存在filling_id的行数据
    row_with_invalid_filling_id = {
      '单号' => reimbursement.invoice_number,
      '操作意见' => "快递单号：SF123456",
      '操作时间' => Time.current.strftime('%Y-%m-%d %H:%M:%S'),
      '填充ID' => "9999999999"  # 不存在的filling_id
    }
    
    # 调用导入方法
    import_service.send(:import_express_receipt, row_with_invalid_filling_id, 1)
    
    # 验证没有创建新记录，且有错误记录
    expect(ExpressReceiptWorkOrder.count).to eq(0)
    expect(import_service.instance_variable_get(:@error_count)).to eq(1)
    expect(import_service.instance_variable_get(:@errors).first).to include("填充ID 9999999999 不存在")
  end
end
```

#### 4.2 集成测试
**目标**: 验证完整的导出→修改→导入流程

**测试文件**: `spec/services/express_receipt_import_service_spec.rb`

**新增测试用例**:
```ruby
describe "填充ID更新导入流程" do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  
  it "支持完整的导出更新导入流程" do
    # 1. 创建初始数据
    original_work_order = create(:express_receipt_work_order,
      reimbursement: reimbursement,
      tracking_number: "SF123456",
      received_at: Time.current - 1.day
    )
    
    # 2. 模拟导出CSV
    exported_csv = CSV.generate(headers: true) do |csv|
      csv << ["填充ID", "单号", "操作意见", "操作时间"]
      csv << [
        original_work_order.filling_id,
        reimbursement.invoice_number,
        "快递单号：SF123456",
        Time.current.strftime('%Y-%m-%d %H:%M:%S')
      ]
    end
    
    # 3. 创建导入文件
    csv_file = Tempfile.new(['test_import', '.csv'])
    csv_file.write(exported_csv)
    csv_file.close
    
    # 4. 执行导入
    import_service = ExpressReceiptImportService.new(
      csv_file,
      admin_user
    )
    result = import_service.import
    
    # 5. 验证结果
    expect(result[:success]).to be true
    expect(result[:updated]).to eq(1)
    expect(result[:created]).to eq(0)
    
    # 6. 验证数据更新
    updated_work_order = ExpressReceiptWorkOrder.find_by(filling_id: original_work_order.filling_id)
    expect(updated_work_order.received_at).to be_within(1.second).of(Time.current)
    expect(updated_work_order.filling_id).to eq(original_work_order.filling_id)  # filling_id保持不变
    
    csv_file.unlink
  end
end
```

## 实施优先级

1. **高优先级**: 修复ActiveAdmin导出功能（阶段一）
   - 影响用户日常使用
   - 修改简单，风险低

2. **中优先级**: 实现基于filling_id的更新导入逻辑（阶段二）
   - 核心业务功能
   - 需要仔细测试

3. **低优先级**: 更新文档说明（阶段三）
   - 不影响系统功能
   - 可以在功能验证后更新

## 风险评估

### 高风险点
1. **导入逻辑变更**: 可能影响现有导入流程
   - 缓解措施：充分测试，确保向后兼容

2. **数据一致性**: 更新操作可能影响数据完整性
   - 缓解措施：使用事务，确保原子性

### 低风险点
1. **导出显示修改**: 只影响显示内容，不涉及业务逻辑
2. **文档更新**: 只影响文档内容，不影响系统功能

## 验收标准

### 功能验收
1. ✅ ActiveAdmin导出CSV包含正确的filling_id
2. ✅ 导入时能通过filling_id更新现有记录
3. ✅ 导入时没有filling_id则创建新记录
4. ✅ 导入时filling_id不存在则报错
5. ✅ 导入结果正确区分创建、更新和跳过的记录数量

### 性能验收
1. ✅ 导出性能不受影响
2. ✅ 导入性能在可接受范围内
3. ✅ 数据库查询优化，避免N+1问题

### 数据完整性验收
1. ✅ filling_id一旦生成不再变更
2. ✅ 更新操作保持数据一致性
3. ✅ 并发导入不会导致数据冲突

## 实施时间估计

- **阶段一（导出修复）**: 0.5小时
- **阶段二（导入逻辑）**: 2小时
- **阶段三（文档更新）**: 0.5小时
- **阶段四（测试验证）**: 1小时
- **总计**: 约4小时