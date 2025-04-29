# SCI2 工单系统 ActiveAdmin UI 补充测试

根据 `docs/activeadmin_ui_test_analysis.md` 的分析，以下是需要补充的测试内容。

## 1. 下拉列表选项配置测试

### 1.1 问题类型选项测试

```ruby
# spec/models/problem_type_options_spec.rb
require 'rails_helper'

RSpec.describe ProblemTypeOptions do
  describe '.all' do
    it "返回正确的问题类型选项列表" do
      expected_options = [
        "发票问题",
        "金额错误",
        "费用类型错误",
        "缺少附件",
        "其他问题"
      ]
      
      expect(ProblemTypeOptions.all).to match_array(expected_options)
    end
    
    it "返回的选项与设计文档一致" do
      # 这个测试确保选项与设计文档中定义的一致
      # 如果设计文档更新，这个测试也需要更新
      expect(ProblemTypeOptions.all).to include("发票问题")
      expect(ProblemTypeOptions.all).to include("金额错误")
      expect(ProblemTypeOptions.all).to include("费用类型错误")
      expect(ProblemTypeOptions.all).to include("缺少附件")
      expect(ProblemTypeOptions.all).to include("其他问题")
      expect(ProblemTypeOptions.all.length).to eq(5)
    end
  end
end
```

### 1.2 问题说明选项测试

```ruby
# spec/models/problem_description_options_spec.rb
require 'rails_helper'

RSpec.describe ProblemDescriptionOptions do
  describe '.all' do
    it "返回正确的问题说明选项列表" do
      expected_options = [
        "发票信息不完整",
        "发票金额与申报金额不符",
        "费用类型选择错误",
        "缺少必要证明材料",
        "其他问题说明"
      ]
      
      expect(ProblemDescriptionOptions.all).to match_array(expected_options)
    end
    
    it "返回的选项与设计文档一致" do
      expect(ProblemDescriptionOptions.all).to include("发票信息不完整")
      expect(ProblemDescriptionOptions.all).to include("发票金额与申报金额不符")
      expect(ProblemDescriptionOptions.all).to include("费用类型选择错误")
      expect(ProblemDescriptionOptions.all).to include("缺少必要证明材料")
      expect(ProblemDescriptionOptions.all).to include("其他问题说明")
      expect(ProblemDescriptionOptions.all.length).to eq(5)
    end
  end
end
```

### 1.3 处理意见选项测试

```ruby
# spec/models/processing_opinion_options_spec.rb
require 'rails_helper'

RSpec.describe ProcessingOpinionOptions do
  describe '.all' do
    it "返回正确的处理意见选项列表" do
      expected_options = [
        "需要补充材料",
        "需要修改申报信息",
        "需要重新提交",
        "可以通过",
        "无法通过"
      ]
      
      expect(ProcessingOpinionOptions.all).to match_array(expected_options)
    end
    
    it "返回的选项与设计文档一致" do
      expect(ProcessingOpinionOptions.all).to include("需要补充材料")
      expect(ProcessingOpinionOptions.all).to include("需要修改申报信息")
      expect(ProcessingOpinionOptions.all).to include("需要重新提交")
      expect(ProcessingOpinionOptions.all).to include("可以通过")
      expect(ProcessingOpinionOptions.all).to include("无法通过")
      expect(ProcessingOpinionOptions.all.length).to eq(5)
    end
  end
end
```

### 1.4 沟通方式选项测试

```ruby
# spec/models/communication_method_options_spec.rb
require 'rails_helper'

RSpec.describe CommunicationMethodOptions do
  describe '.all' do
    it "返回正确的沟通方式选项列表" do
      expected_options = [
        "电话",
        "邮件",
        "微信",
        "当面沟通",
        "其他方式"
      ]
      
      expect(CommunicationMethodOptions.all).to match_array(expected_options)
    end
  end
end
```

### 1.5 发起人角色选项测试

```ruby
# spec/models/initiator_role_options_spec.rb
require 'rails_helper'

RSpec.describe InitiatorRoleOptions do
  describe '.all' do
    it "返回正确的发起人角色选项列表" do
      expected_options = [
        "财务人员",
        "申请人",
        "审批人",
        "其他角色"
      ]
      
      expect(InitiatorRoleOptions.all).to match_array(expected_options)
    end
  end
end
```

## 2. 表单 Partial 实现测试

### 2.1 审核工单表单 Partial 测试

```ruby
# spec/features/admin/audit_work_order_form_spec.rb
require 'rails_helper'

RSpec.describe "审核工单表单", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  
  before do
    login_as(admin_user, scope: :admin_user)
  end
  
  it "使用 partial 并包含所有必要字段" do
    visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)
    
    # 检查共享字段是否存在
    expect(page).to have_select("audit_work_order[problem_type]")
    expect(page).to have_select("audit_work_order[problem_description]")
    expect(page).to have_field("audit_work_order[remark]")
    expect(page).to have_select("audit_work_order[processing_opinion]")
    
    # 检查审核工单特有字段是否存在
    expect(page).to have_field("audit_work_order[audit_comment]")
    expect(page).to have_field("audit_work_order[vat_verified]")
    
    # 检查费用明细选择是否存在
    expect(page).to have_css("fieldset legend", text: "选择费用明细")
  end
  
  it "下拉列表包含正确的选项" do
    visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)
    
    # 检查问题类型下拉列表选项
    within("select#audit_work_order_problem_type") do
      ProblemTypeOptions.all.each do |option|
        expect(page).to have_css("option", text: option)
      end
    end
    
    # 检查问题说明下拉列表选项
    within("select#audit_work_order_problem_description") do
      ProblemDescriptionOptions.all.each do |option|
        expect(page).to have_css("option", text: option)
      end
    end
    
    # 检查处理意见下拉列表选项
    within("select#audit_work_order_processing_opinion") do
      ProcessingOpinionOptions.all.each do |option|
        expect(page).to have_css("option", text: option)
      end
    end
  end
end
```

### 2.2 沟通工单表单 Partial 测试

```ruby
# spec/features/admin/communication_work_order_form_spec.rb
require 'rails_helper'

RSpec.describe "沟通工单表单", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  
  before do
    login_as(admin_user, scope: :admin_user)
  end
  
  it "使用 partial 并包含所有必要字段" do
    visit new_admin_communication_work_order_path(reimbursement_id: reimbursement.id)
    
    # 检查共享字段是否存在
    expect(page).to have_select("communication_work_order[problem_type]")
    expect(page).to have_select("communication_work_order[problem_description]")
    expect(page).to have_field("communication_work_order[remark]")
    expect(page).to have_select("communication_work_order[processing_opinion]")
    
    # 检查沟通工单特有字段是否存在
    expect(page).to have_select("communication_work_order[communication_method]")
    expect(page).to have_select("communication_work_order[initiator_role]")
    expect(page).to have_field("communication_work_order[resolution_summary]")
    
    # 检查费用明细选择是否存在
    expect(page).to have_css("fieldset legend", text: "选择费用明细")
  end
  
  it "下拉列表包含正确的选项" do
    visit new_admin_communication_work_order_path(reimbursement_id: reimbursement.id)
    
    # 检查问题类型下拉列表选项
    within("select#communication_work_order_problem_type") do
      ProblemTypeOptions.all.each do |option|
        expect(page).to have_css("option", text: option)
      end
    end
    
    # 检查问题说明下拉列表选项
    within("select#communication_work_order_problem_description") do
      ProblemDescriptionOptions.all.each do |option|
        expect(page).to have_css("option", text: option)
      end
    end
    
    # 检查处理意见下拉列表选项
    within("select#communication_work_order_processing_opinion") do
      ProcessingOpinionOptions.all.each do |option|
        expect(page).to have_css("option", text: option)
      end
    end
    
    # 检查沟通方式下拉列表选项
    within("select#communication_work_order_communication_method") do
      CommunicationMethodOptions.all.each do |option|
        expect(page).to have_css("option", text: option)
      end
    end
    
    # 检查发起人角色下拉列表选项
    within("select#communication_work_order_initiator_role") do
      InitiatorRoleOptions.all.each do |option|
        expect(page).to have_css("option", text: option)
      end
    end
  end
  
  it "不包含审核工单关联字段" do
    visit new_admin_communication_work_order_path(reimbursement_id: reimbursement.id)
    
    # 确保没有审核工单关联字段
    expect(page).not_to have_field("communication_work_order[audit_work_order_id]")
    expect(page).not_to have_select("communication_work_order[audit_work_order_id]")
  end
end
```

## 3. 重复记录处理策略测试

### 3.1 报销单重复处理测试

```ruby
# spec/features/admin/reimbursement_duplicate_handling_spec.rb
require 'rails_helper'

RSpec.describe "报销单重复处理", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:existing_reimbursement) { create(:reimbursement, 
    invoice_number: "R202501001", 
    document_name: "旧报销单",
    applicant: "张三",
    amount: 100.00
  )}
  
  before do
    login_as(admin_user, scope: :admin_user)
  end
  
  it "重复导入时更新已存在的报销单" do
    # 创建一个临时的 CSV 文件用于上传
    temp_file = Tempfile.new(['test_reimbursements', '.csv'])
    csv_content = <<~CSV
      报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,收单状态,收单日期,提交报销日期,报销单状态,单据标签,报销单审核通过日期,审核通过人
      R202501001,新报销单,李四,TEST001,测试公司,测试部门,200.00,未收单,,2025-01-01,审批中,,,
    CSV
    temp_file.write(csv_content)
    temp_file.rewind
    
    visit new_import_admin_reimbursements_path
    attach_file('file', temp_file.path)
    click_button "导入"
    
    # 验证导入结果
    expect(page).to have_content("导入成功")
    expect(page).to have_content("更新: 1")
    
    # 验证报销单被更新而不是创建新记录
    expect(Reimbursement.where(invoice_number: "R202501001").count).to eq(1)
    
    # 验证字段被更新
    updated_reimbursement = Reimbursement.find_by(invoice_number: "R202501001")
    expect(updated_reimbursement.document_name).to eq("新报销单")
    expect(updated_reimbursement.applicant).to eq("李四")
    expect(updated_reimbursement.amount).to eq(200.00)
    
    # 清理临时文件
    temp_file.close
    temp_file.unlink
  end
end
```

### 3.2 费用明细重复处理测试

```ruby
# spec/features/admin/fee_detail_duplicate_handling_spec.rb
require 'rails_helper'

RSpec.describe "费用明细重复处理", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement, invoice_number: "R202501001") }
  let!(:existing_fee_detail) { create(:fee_detail, 
    document_number: "R202501001", 
    fee_type: "交通费",
    amount: 100.00,
    fee_date: Date.parse("2025-01-01")
  )}
  
  before do
    login_as(admin_user, scope: :admin_user)
  end
  
  it "完全相同的费用明细记录被跳过" do
    # 创建一个临时的 CSV 文件用于上传
    temp_file = Tempfile.new(['test_fee_details', '.csv'])
    csv_content = <<~CSV
      报销单单号,费用类型,原始金额,原始币种,费用发生日期,弹性字段11,所属月,首次提交日期
      R202501001,交通费,100.00,CNY,2025-01-01,现金,2025-01,2025-01-02
      R202501001,餐费,200.00,CNY,2025-01-02,现金,2025-01,2025-01-02
    CSV
    temp_file.write(csv_content)
    temp_file.rewind
    
    visit new_import_admin_fee_details_path
    attach_file('file', temp_file.path)
    click_button "导入"
    
    # 验证导入结果
    expect(page).to have_content("导入成功")
    expect(page).to have_content("导入: 1") # 只有一条新记录被导入
    expect(page).to have_content("跳过: 1") # 一条重复记录被跳过
    
    # 验证只有一条新记录被创建
    expect(FeeDetail.where(document_number: "R202501001").count).to eq(2)
    expect(FeeDetail.where(document_number: "R202501001", fee_type: "交通费").count).to eq(1)
    expect(FeeDetail.where(document_number: "R202501001", fee_type: "餐费").count).to eq(1)
    
    # 清理临时文件
    temp_file.close
    temp_file.unlink
  end
end
```

### 3.3 操作历史重复处理测试

```ruby
# spec/features/admin/operation_history_duplicate_handling_spec.rb
require 'rails_helper'

RSpec.describe "操作历史重复处理", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement, invoice_number: "R202501001") }
  let!(:existing_operation_history) { create(:operation_history, 
    document_number: "R202501001", 
    operation_type: "提交",
    operation_time: DateTime.parse("2025-01-01 10:00:00"),
    operator: "张三"
  )}
  
  before do
    login_as(admin_user, scope: :admin_user)
  end
  
  it "完全相同的操作历史记录被跳过" do
    # 创建一个临时的 CSV 文件用于上传
    temp_file = Tempfile.new(['test_operation_histories', '.csv'])
    csv_content = <<~CSV
      单据编号,操作类型,操作日期,操作人,操作意见,表单类型,操作节点
      R202501001,提交,2025-01-01 10:00:00,张三,提交报销单,报销单,提交节点
      R202501001,审批,2025-01-02 10:00:00,李四,审批通过,报销单,审批节点
    CSV
    temp_file.write(csv_content)
    temp_file.rewind
    
    visit new_import_admin_operation_histories_path
    attach_file('file', temp_file.path)
    click_button "导入"
    
    # 验证导入结果
    expect(page).to have_content("导入成功")
    expect(page).to have_content("导入: 1") # 只有一条新记录被导入
    expect(page).to have_content("跳过: 1") # 一条重复记录被跳过
    
    # 验证只有一条新记录被创建
    expect(OperationHistory.where(document_number: "R202501001").count).to eq(2)
    expect(OperationHistory.where(document_number: "R202501001", operation_type: "提交").count).to eq(1)
    expect(OperationHistory.where(document_number: "R202501001", operation_type: "审批").count).to eq(1)
    
    # 清理临时文件
    temp_file.close
    temp_file.unlink
  end
  
  it "导入审批通过的操作历史会更新报销单状态" do
    # 确保报销单状态为 waiting_completion
    reimbursement.update(status: 'waiting_completion')
    
    # 创建一个临时的 CSV 文件用于上传
    temp_file = Tempfile.new(['test_operation_histories', '.csv'])
    csv_content = <<~CSV
      单据编号,操作类型,操作日期,操作人,操作意见,表单类型,操作节点
      R202501001,审批,2025-01-02 10:00:00,李四,审批通过,报销单,审批节点
    CSV
    temp_file.write(csv_content)
    temp_file.rewind
    
    visit new_import_admin_operation_histories_path
    attach_file('file', temp_file.path)
    click_button "导入"
    
    # 验证导入结果
    expect(page).to have_content("导入成功")
    
    # 验证报销单状态被更新为 closed
    reimbursement.reload
    expect(reimbursement.status).to eq('closed')
    
    # 清理临时文件
    temp_file.close
    temp_file.unlink
  end
end
```

## 4. 实施建议

1. 创建上述测试文件，并运行测试以验证 ActiveAdmin UI 是否符合设计和集成要求。

2. 如果测试失败，根据失败原因修复相应的代码：
   - 如果下拉列表选项不符合要求，更新选项配置类
   - 如果表单 partial 缺少必要字段，更新表单模板
   - 如果重复记录处理策略不正确，更新导入服务

3. 确保所有测试都通过，以确保 ActiveAdmin UI 完全符合设计和集成要求。

4. 考虑添加更多的边界条件测试，例如：
   - 测试表单验证
   - 测试错误处理
   - 测试权限控制