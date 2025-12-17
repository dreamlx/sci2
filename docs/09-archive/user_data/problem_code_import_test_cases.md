# 问题代码导入功能测试用例

## 📋 测试概述

本文档详细描述了问题代码导入功能的测试用例，包括单元测试、集成测试和用户验收测试。

## 🧪 单元测试用例

### 测试类：ProblemCodeImportServiceTest

#### 1. Legacy Problem Code处理测试

```ruby
# test/services/problem_code_import_service_test.rb

require 'test_helper'

class ProblemCodeImportServiceTest < ActiveSupport::TestCase
  def setup
    @service = ProblemCodeImportService.new('test.csv')
  end

  # 测试1.1：CSV中有legacy_problem_code时使用CSV值
  test "should use legacy_problem_code from CSV when provided" do
    # 准备测试数据
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,EN000101
    CSV
    
    # 模拟文件读取
    allow(File).to receive(:read).and_return(csv_content)
    
    # 执行导入
    result = @service.import
    
    # 验证结果
    assert result[:success]
    problem_type = ProblemType.find_by(title: '燃油费行程问题')
    assert_equal 'EN000101', problem_type.legacy_problem_code
  end

  # 测试1.2：CSV中无legacy_problem_code时使用计算值
  test "should calculate legacy_problem_code when not provided in CSV" do
    # 准备测试数据（无legacy_problem_code列）
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling
      EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整
    CSV
    
    allow(File).to receive(:read).and_return(csv_content)
    
    result = @service.import
    
    assert result[:success]
    problem_type = ProblemType.find_by(title: '燃油费行程问题')
    assert_equal 'EN000101', problem_type.legacy_problem_code
  end

  # 测试1.3：legacy_problem_code为空时的处理
  test "should handle empty legacy_problem_code in CSV" do
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,
    CSV
    
    allow(File).to receive(:read).and_return(csv_content)
    
    result = @service.import
    
    assert result[:success]
    problem_type = ProblemType.find_by(title: '燃油费行程问题')
    assert_equal 'EN000101', problem_type.legacy_problem_code
  end
end
```

#### 2. 代码格式化测试

```ruby
# 测试2.1：单数字补零
test "should pad single digit codes with leading zero" do
  assert_equal '01', @service.send(:format_code_value, '1')
  assert_equal '09', @service.send(:format_code_value, '9')
end

# 测试2.2：已有2位数字保持不变
test "should keep 2-digit codes unchanged" do
  assert_equal '01', @service.send(:format_code_value, '01')
  assert_equal '10', @service.send(:format_code_value, '10')
end

# 测试2.3：通用类型处理
test "should handle generic expense type code" do
  assert_equal '00', @service.send(:format_code_value, '00')
end

# 测试2.4：非数字格式保持不变
test "should keep non-numeric codes unchanged" do
  assert_equal 'ABC', @service.send(:format_code_value, 'ABC')
  assert_equal 'A1', @service.send(:format_code_value, 'A1')
end

# 测试2.5：空值处理
test "should handle nil and empty values" do
  assert_nil @service.send(:format_code_value, nil)
  assert_nil @service.send(:format_code_value, '')
  assert_nil @service.send(:format_code_value, '   ')
end
```

#### 3. 数据验证测试

```ruby
# 测试3.1：有效的reimbursement_type_code
test "should validate valid reimbursement_type_code" do
  params = { reimbursement_type_code: 'EN' }
  errors = @service.send(:validate_fee_type_params, params)
  assert_empty errors
end

# 测试3.2：无效的reimbursement_type_code
test "should reject invalid reimbursement_type_code" do
  params = { reimbursement_type_code: 'XX' }
  errors = @service.send(:validate_fee_type_params, params)
  assert_includes errors, "Invalid reimbursement_type_code: XX"
end

# 测试3.3：有效的数字格式
test "should validate valid numeric codes" do
  params = { 
    meeting_type_code: '01',
    expense_type_code: '01'
  }
  errors = @service.send(:validate_fee_type_params, params)
  assert_empty errors
end

# 测试3.4：无效的数字格式
test "should reject invalid numeric codes" do
  params = { 
    meeting_type_code: 'ABC',
    expense_type_code: '1'
  }
  errors = @service.send(:validate_fee_type_params, params)
  assert_includes errors, "Invalid meeting_type_code: ABC"
  assert_includes errors, "Invalid expense_type_code: 1"
end
```

#### 4. 错误处理测试

```ruby
# 测试4.1：单行错误不影响整体导入
test "should continue import when single row has error" do
  csv_content = <<~CSV
    reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
    EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,EN000101
    XX,00,个人,01,月度交通费,02,出租车行程问题,根据SOP规定,请补充完整,EN000102
    EN,00,个人,01,月度交通费,03,网约车行程问题,根据SOP规定,请补充完整,EN000103
  CSV
  
  allow(File).to receive(:read).and_return(csv_content)
  
  result = @service.import
  
  # 导入应该成功（部分成功）
  assert result[:success]
  
  # 应该有错误记录
  assert result[:details][:errors].present?
  assert_equal 1, result[:details][:errors].length
  
  # 应该有成功导入的记录
  assert_equal 2, result[:details][:problem_types].length
end

# 测试4.2：详细错误信息记录
test "should record detailed error information" do
  csv_content = <<~CSV
    reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
    XX,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,EN000101
  CSV
  
  allow(File).to receive(:read).and_return(csv_content)
  
  result = @service.import
  
  error = result[:details][:errors].first
  assert_equal 2, error[:row]
  assert_includes error[:error], "Invalid reimbursement_type_code"
  assert_equal 'XX', error[:data]['reimbursement_type_code']
end
```

#### 5. 特殊字符处理测试

```ruby
# 测试5.1：中文引号处理
test "should handle Chinese quotation marks" do
  text_with_chinese_quotes = '"微信零钱"、"支付宝花呗"及"京东白条"支付'
  cleaned = @service.send(:clean_text_field, text_with_chinese_quotes)
  assert_equal '"微信零钱"、"支付宝花呗"及"京东白条"支付', cleaned
end

# 测试5.2：BOM字符处理
test "should remove BOM characters" do
  text_with_bom = "\xEF\xBB\xBF测试内容"
  cleaned = @service.send(:clean_text_field, text_with_bom)
  assert_equal '测试内容', cleaned
end

# 测试5.3：中文括号处理
test "should handle Chinese brackets" do
  text_with_chinese_brackets = '【测试内容】'
  cleaned = @service.send(:clean_text_field, text_with_chinese_brackets)
  assert_equal '[测试内容]', cleaned
end
```

## 🔧 集成测试用例

### 测试类：ProblemCodeImportIntegrationTest

```ruby
# test/integration/problem_code_import_integration_test.rb

class ProblemCodeImportIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @test_csv_path = Rails.root.join('tmp', 'test_import.csv')
  end

  def teardown
    File.delete(@test_csv_path) if File.exist?(@test_csv_path)
  end

  # 测试1：完整CSV导入测试
  test "should import complete CSV file successfully" do
    # 使用实际的CSV数据创建测试文件
    csv_content = File.read(Rails.root.join('docs', 'user_data', '问题类型样式-20250908.csv'))
    File.write(@test_csv_path, csv_content)
    
    # 执行导入
    service = ProblemCodeImportService.new(@test_csv_path)
    result = service.import
    
    # 验证导入结果
    assert result[:success]
    
    # 验证数据完整性
    imported_fee_types = result[:details][:fee_types].length
    imported_problem_types = result[:details][:problem_types].length
    
    assert imported_fee_types > 0
    assert imported_problem_types > 0
    
    # 验证具体数据
    en_fee_type = FeeType.find_by(reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01')
    assert_not_nil en_fee_type
    assert_equal '月度交通费（销售/SMO/CO)', en_fee_type.name
    
    mn_fee_type = FeeType.find_by(reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '00')
    assert_not_nil mn_fee_type
    assert_equal '通用', mn_fee_type.name
    
    # 验证legacy_problem_code
    problem_type = ProblemType.joins(:fee_type)
                              .find_by(fee_types: { reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01' },
                                       issue_code: '01')
    assert_not_nil problem_type
    assert_equal 'EN000101', problem_type.legacy_problem_code
  end

  # 测试2：部分数据更新测试
  test "should update existing data on re-import" do
    # 首次导入
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,EN000101
    CSV
    
    File.write(@test_csv_path, csv_content)
    
    service = ProblemCodeImportService.new(@test_csv_path)
    result1 = service.import
    
    assert result1[:success]
    assert_equal 1, result1[:details][:fee_types].length
    assert_equal 1, result1[:details][:problem_types].length
    
    # 更新导入
    updated_csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定更新,请补充完整更新,EN000101
    CSV
    
    File.write(@test_csv_path, updated_csv_content)
    
    service = ProblemCodeImportService.new(@test_csv_path)
    result2 = service.import
    
    assert result2[:success]
    assert_equal 0, result2[:details][:fee_types].length  # 没有新的fee_type
    assert_equal 1, result2[:details][:problem_types].length # 更新了problem_type
    
    # 验证数据已更新
    problem_type = ProblemType.find_by(title: '燃油费行程问题')
    assert_equal '根据SOP规定更新', problem_type.sop_description
    assert_equal '请补充完整更新', problem_type.standard_handling
  end

  # 测试3：大数据量导入测试
  test "should handle large CSV file import" do
    # 创建大数据量测试文件
    csv_lines = ['reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code']
    
    1000.times do |i|
      csv_lines << "EN,00,个人,01,月度交通费,#{sprintf('%02d', i)},测试问题#{i},根据SOP规定#{i},请补充完整#{i},EN0001#{sprintf('%02d', i)}"
    end
    
    File.write(@test_csv_path, csv_lines.join("\n"))
    
    # 测量导入时间
    start_time = Time.current
    
    service = ProblemCodeImportService.new(@test_csv_path)
    result = service.import
    
    end_time = Time.current
    import_duration = end_time - start_time
    
    # 验证导入结果
    assert result[:success]
    assert_equal 1000, result[:details][:problem_types].length
    
    # 验证性能（应该在合理时间内完成）
    assert import_duration < 30.seconds, "Import took too long: #{import_duration} seconds"
    
    # 验证数据完整性
    assert_equal 1000, ProblemType.where("title LIKE '测试问题%'").count
  end

  # 测试4：并发导入测试
  test "should handle concurrent imports" do
    # 创建测试数据
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,EN000101
      EN,00,个人,01,月度交通费,02,出租车行程问题,根据SOP规定,请补充完整,EN000102
    CSV
    
    File.write(@test_csv_path, csv_content)
    
    # 并发执行导入
    threads = []
    results = []
    
    3.times do |i|
      threads << Thread.new do
        service = ProblemCodeImportService.new(@test_csv_path)
        results[i] = service.import
      end
    end
    
    threads.each(&:join)
    
    # 验证所有导入都成功
    results.each do |result|
      assert result[:success]
    end
    
    # 验证数据一致性
    assert_equal 1, FeeType.where(reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01').count
    assert_equal 2, ProblemType.joins(:fee_type).where(fee_types: { reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01' }).count
  end
end
```

## 👥 用户验收测试用例

### 测试场景1：正常业务流程

```ruby
# test/acceptance/problem_code_import_acceptance_test.rb

class ProblemCodeImportAcceptanceTest < ActionDispatch::IntegrationTest
  test "business user should successfully import problem codes" do
    # 登录业务用户
    admin_user = admin_users(:business_admin)
    sign_in admin_user
    
    # 访问导入页面
    get admin_imports_problem_codes_path
    assert_response :success
    
    # 上传CSV文件
    csv_file = fixture_file_upload('files/problem_codes_test.csv', 'text/csv')
    post admin_imports_problem_codes_import_path, params: { file: csv_file }
    
    # 验证导入结果
    assert_response :success
    assert_match /导入成功/, response.body
    
    # 验证数据已导入
    assert ProblemType.where(title: '燃油费行程问题').exists?
  end
end
```

### 测试场景2：错误处理验证

```ruby
test "should display clear error messages for invalid data" do
  admin_user = admin_users(:business_admin)
  sign_in admin_user
  
  # 创建包含错误的CSV文件
  invalid_csv_content = <<~CSV
    reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
    XX,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,EN000101
  CSV
  
  csv_file = StringIO.new(invalid_csv_content)
  csv_file.content_type = 'text/csv'
  
  post admin_imports_problem_codes_import_path, params: { file: csv_file }
  
  # 验证错误信息显示
  assert_response :success
  assert_match /Invalid reimbursement_type_code/, response.body
end
```

## 📊 性能测试用例

### 测试1：内存使用测试

```ruby
test "should not cause memory leaks during large import" do
  # 获取初始内存使用
  initial_memory = get_memory_usage
  
  # 执行大数据量导入
  large_csv_content = generate_large_csv(5000)
  service = ProblemCodeImportService.new(StringIO.new(large_csv_content))
  service.import
  
  # 强制垃圾回收
  GC.start
  
  # 获取最终内存使用
  final_memory = get_memory_usage
  
  # 验证内存增长在合理范围内
  memory_increase = final_memory - initial_memory
  assert memory_increase < 100.megabytes, "Memory increase too large: #{memory_increase}"
end

private

def get_memory_usage
  `ps -o rss= -p #{Process.pid}`.to_i.kilobytes
end

def generate_large_csv(rows)
  csv_lines = ['reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code']
  
  rows.times do |i|
    csv_lines << "EN,00,个人,01,月度交通费,#{sprintf('%02d', i % 99)},测试问题#{i},根据SOP规定#{i},请补充完整#{i},EN0001#{sprintf('%02d', i % 99)}"
  end
  
  csv_lines.join("\n")
end
```

## 📋 测试数据准备

### 测试CSV文件

```csv
# test/fixtures/files/problem_codes_test.csv
reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
EN,00,个人,01,月度交通费（销售/SMO/CO),1,燃油费行程问题,根据SOP规定，月度交通费报销燃油费需提供每张燃油费的使用时间区间，行程为医院的需具体到科室,请根据要求在评论区将行程补充完整,EN000101
EN,00,个人,01,月度交通费（销售/SMO/CO),2,出租车行程问题,根据SOP规定，月度交通费报销出租车费用，需注明具体的行程地点和事由，行程为医院的，应明确注明拜访医院及科室,请根据要求补充至HLY评论区,EN000102
MN,01,学术论坛,00,通用,1,会议权限_学术论坛,根据SOP规定，学术论坛可举办的组织者岗位为地区业务销售经理及以上、市场、医学、临床运营、市场准入和商务，您无权限举办此类型会议,请提供逐级审批至部门负责人的授权邮件并抄送合规,MN010001
```

### 测试工厂

```ruby
# test/factories/problem_types.rb
FactoryBot.define do
  factory :problem_type do
    association :fee_type
    issue_code { '01' }
    title { '测试问题' }
    sop_description { '根据SOP规定' }
    standard_handling { '请补充完整' }
    active { true }
  end
end

# test/factories/fee_types.rb
FactoryBot.define do
  factory :fee_type do
    reimbursement_type_code { 'EN' }
    meeting_type_code { '00' }
    expense_type_code { '01' }
    name { '月度交通费' }
    meeting_name { '个人' }
    active { true }
  end
end
```

## 🚀 测试执行计划

### 阶段1：单元测试
- 执行所有单元测试用例
- 确保代码覆盖率达到90%以上
- 验证所有边界条件

### 阶段2：集成测试
- 执行完整CSV导入测试
- 验证数据一致性
- 测试并发场景

### 阶段3：性能测试
- 大数据量导入测试
- 内存使用监控
- 响应时间验证

### 阶段4：用户验收测试
- 业务流程验证
- 错误处理验证
- 用户体验测试

## 📊 测试报告模板

```
# 问题代码导入功能测试报告

## 测试概述
- 测试日期：[日期]
- 测试环境：[环境]
- 测试人员：[姓名]

## 测试结果汇总
- 总测试用例：[数量]
- 通过：[数量]
- 失败：[数量]
- 跳过：[数量]
- 覆盖率：[百分比]

## 详细测试结果
### 单元测试
- Legacy Problem Code处理：✅/❌
- 代码格式化：✅/❌
- 数据验证：✅/❌
- 错误处理：✅/❌

### 集成测试
- 完整CSV导入：✅/❌
- 数据更新：✅/❌
- 大数据量导入：✅/❌
- 并发导入：✅/❌

### 性能测试
- 内存使用：✅/❌
- 响应时间：✅/❌

### 用户验收测试
- 业务流程：✅/❌
- 错误处理：✅/❌

## 问题记录
[记录发现的问题和解决方案]

## 测试结论
[总体评估和建议]