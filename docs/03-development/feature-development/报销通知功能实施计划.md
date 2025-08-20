# 报销单通知功能实现计划

## 1. 功能概述

实现一个通知功能，当报销单有新的快递收单工单或操作历史记录时，在报销单列表中显示通知标签。用户查看特定报销单后，该报销单的通知标记将被清除，直到有新的相关记录添加。

## 2. 数据库变更

### 2.1 创建迁移文件

```bash
rails generate migration AddNotificationFieldsToReimbursements
```

### 2.2 编写迁移内容

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_notification_fields_to_reimbursements.rb
class AddNotificationFieldsToReimbursements < ActiveRecord::Migration[6.1]
  def change
    add_column :reimbursements, :last_viewed_operation_histories_at, :datetime
    add_column :reimbursements, :last_viewed_express_receipts_at, :datetime
    
    add_index :reimbursements, :last_viewed_operation_histories_at
    add_index :reimbursements, :last_viewed_express_receipts_at
  end
end
```

### 2.3 执行迁移

```bash
rails db:migrate
```

## 3. 模型变更

### 3.1 添加检查方法到Reimbursement模型

```ruby
# app/models/reimbursement.rb

# 检查是否有未查看的操作历史
def has_unviewed_operation_histories?
  return true if last_viewed_operation_histories_at.nil?
  operation_histories.where('created_at > ?', last_viewed_operation_histories_at).exists?
end

# 检查是否有未查看的快递收单
def has_unviewed_express_receipts?
  return true if last_viewed_express_receipts_at.nil?
  express_receipt_work_orders.where('created_at > ?', last_viewed_express_receipts_at).exists?
end

# 检查是否有任何未查看的记录
def has_unviewed_records?
  has_unviewed_operation_histories? || has_unviewed_express_receipts?
end

# 标记所有记录为已查看
def mark_all_as_viewed!
  update(
    last_viewed_operation_histories_at: Time.current,
    last_viewed_express_receipts_at: Time.current
  )
end
```

### 3.2 添加查询范围

```ruby
# app/models/reimbursement.rb

# 查询范围：有未查看操作历史的报销单
scope :with_unviewed_operation_histories, -> {
  where('last_viewed_operation_histories_at IS NULL OR EXISTS (SELECT 1 FROM operation_histories WHERE operation_histories.document_number = reimbursements.invoice_number AND operation_histories.created_at > reimbursements.last_viewed_operation_histories_at)')
}

# 查询范围：有未查看快递收单的报销单
scope :with_unviewed_express_receipts, -> {
  where('last_viewed_express_receipts_at IS NULL OR EXISTS (SELECT 1 FROM work_orders WHERE work_orders.reimbursement_id = reimbursements.id AND work_orders.type = ? AND work_orders.created_at > reimbursements.last_viewed_express_receipts_at)', 'ExpressReceiptWorkOrder')
}

# 查询范围：有任何未查看记录的报销单
scope :with_unviewed_records, -> {
  with_unviewed_operation_histories.or(with_unviewed_express_receipts)
}
```

## 4. ActiveAdmin变更

### 4.1 修改控制器

```ruby
# app/admin/reimbursements.rb

controller do
  def show
    # 当用户查看详情页面时，只标记当前查看的报销单为已查看
    resource.mark_all_as_viewed!
    super
  end
end
```

### 4.2 修改列表页面

```ruby
# app/admin/reimbursements.rb 中的index块

index do
  selectable_column
  id_column
  column :invoice_number
  # 其他现有列...
  
  # 添加通知状态列
  column "通知状态", :sortable => false do |reimbursement|
    span do
      if reimbursement.has_unviewed_express_receipts?
        status_tag "快递单", class: "warning" # 使用现有的warning样式（橙色）
      end
      
      if reimbursement.has_unviewed_operation_histories?
        status_tag "操作记录", class: "error" # 使用现有的error样式（红色）
      end
      
      unless reimbursement.has_unviewed_records?
        status_tag "已查看", class: "completed" # 使用现有的completed样式（绿色）
      end
    end
  end
  
  # 现有的操作列
  actions
end
```

### 4.3 添加筛选器

```ruby
# app/admin/reimbursements.rb

# 添加筛选器
filter :with_unviewed_records, label: '有新通知', as: :boolean
```

## 5. 测试计划

### 5.1 单元测试

```ruby
# spec/models/reimbursement_spec.rb

describe "notification methods" do
  let(:reimbursement) { create(:reimbursement) }
  
  describe "#has_unviewed_operation_histories?" do
    it "returns true when last_viewed_operation_histories_at is nil" do
      expect(reimbursement.has_unviewed_operation_histories?).to be true
    end
    
    it "returns true when there are operation histories created after last viewed" do
      reimbursement.update(last_viewed_operation_histories_at: 1.day.ago)
      create(:operation_history, document_number: reimbursement.invoice_number, created_at: Time.current)
      expect(reimbursement.has_unviewed_operation_histories?).to be true
    end
    
    it "returns false when all operation histories have been viewed" do
      create(:operation_history, document_number: reimbursement.invoice_number, created_at: 1.day.ago)
      reimbursement.update(last_viewed_operation_histories_at: Time.current)
      expect(reimbursement.has_unviewed_operation_histories?).to be false
    end
  end
  
  # 类似的测试用例用于has_unviewed_express_receipts?和has_unviewed_records?
end
```

### 5.2 集成测试

```ruby
# spec/system/admin/reimbursements_spec.rb

describe "notification feature" do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  
  before do
    login_as(admin_user)
  end
  
  it "shows notification badges for reimbursements with unviewed records" do
    create(:operation_history, document_number: reimbursement.invoice_number)
    visit admin_reimbursements_path
    
    within "#reimbursement_#{reimbursement.id}" do
      expect(page).to have_css(".status_tag.error", text: "操作记录")
    end
  end
  
  it "clears notification status after viewing the reimbursement" do
    create(:operation_history, document_number: reimbursement.invoice_number)
    
    # 首先访问列表页面，确认有通知
    visit admin_reimbursements_path
    within "#reimbursement_#{reimbursement.id}" do
      expect(page).to have_css(".status_tag.error", text: "操作记录")
    end
    
    # 查看详情页面
    click_link "查看", href: admin_reimbursement_path(reimbursement)
    
    # 返回列表页面，确认通知已清除
    visit admin_reimbursements_path
    within "#reimbursement_#{reimbursement.id}" do
      expect(page).to have_css(".status_tag.completed", text: "已查看")
    end
  end
  
  it "shows notification again when new records are added after viewing" do
    # 首先查看报销单
    visit admin_reimbursement_path(reimbursement)
    
    # 添加新的操作历史
    create(:operation_history, document_number: reimbursement.invoice_number)
    
    # 返回列表页面，确认通知重新出现
    visit admin_reimbursements_path
    within "#reimbursement_#{reimbursement.id}" do
      expect(page).to have_css(".status_tag.error", text: "操作记录")
    end
  end
end
```

## 6. 部署计划

1. 创建功能分支
   ```bash
   git checkout -b feature/reimbursement-notifications
   ```

2. 提交所有变更
   ```bash
   git add .
   git commit -m "Add notification feature for reimbursements"
   ```

3. 在测试环境中测试
   ```bash
   # 部署到测试环境
   cap staging deploy
   ```

4. 合并到主分支并部署到生产环境
   ```bash
   git checkout main
   git merge feature/reimbursement-notifications
   git push origin main
   
   # 部署到生产环境
   cap production deploy
   ```

## 7. 实施时间线

1. **数据库变更**：1天
2. **模型变更**：1天
3. **ActiveAdmin变更**：2天
4. **测试**：3天
5. **部署**：1天

**总计**：8个工作日

## 8. 注意事项

1. 确保在部署前进行充分的测试，特别是在多用户环境下的行为
2. 监控部署后的性能，确保添加的查询不会对系统性能产生负面影响
3. 考虑添加数据库索引以优化查询性能
4. 确保UI设计在不同浏览器中的兼容性

## 9. 功能示意图

```mermaid
graph TD
    A[报销单列表页面] -->|显示通知标签| B[通知状态列]
    B -->|快递单标签| C[橙色标签]
    B -->|操作记录标签| D[红色标签]
    B -->|已查看标签| E[绿色标签]
    A -->|点击查看按钮| F[报销单详情页]
    F -->|自动触发| G[标记当前报销单为已查看]
    H[新快递收单创建] -->|触发| I[更新通知状态]
    J[新操作历史创建] -->|触发| I
    I -->|影响| A