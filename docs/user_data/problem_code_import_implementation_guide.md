# 问题代码导入功能开发实施指南

## 🚀 实施概述

本指南详细描述了问题代码导入功能修复的开发实施步骤，确保开发团队能够高效、安全地完成修复工作。

## 📋 实施前准备

### 环境准备

```bash
# 1. 创建开发分支
git checkout -b fix/problem-code-import-$(date +%Y%m%d)

# 2. 确保数据库是最新的
rails db:migrate

# 3. 运行现有测试确保基础功能正常
rails test

# 4. 备份当前数据（生产环境）
rails db:backup:create
```

### 代码审查准备

```bash
# 1. 安装代码质量检查工具
bundle exec rubocop --version
bundle exec brakeman --version

# 2. 运行代码质量检查
bundle exec rubocop app/services/problem_code_import_service.rb
bundle exec brakeman
```

## 🔧 第一阶段：紧急修复实施

### 步骤1.1：修复Legacy Problem Code处理

**文件：** `app/services/problem_code_import_service.rb`

**位置：** 第98-119行

```ruby
# 修改前
def process_problem_type(params, fee_type)
  problem_type = ProblemType.find_or_initialize_by(
    fee_type_id: fee_type.id,
    issue_code: params[:issue_code]
  )

  action = problem_type.new_record? ? :imported : :updated

  problem_type.assign_attributes(
    title: params[:title],
    sop_description: params[:sop_description],
    standard_handling: params[:standard_handling],
    active: true
  )

  # 触发虚拟字段计算，确保 legacy_problem_code 数据库列被正确设置
  problem_type.legacy_problem_code

  problem_type.save! if problem_type.changed?
  [problem_type, action]
end

# 修改后
def process_problem_type(params, fee_type)
  problem_type = ProblemType.find_or_initialize_by(
    fee_type_id: fee_type.id,
    issue_code: params[:issue_code]
  )

  action = problem_type.new_record? ? :imported : :updated

  problem_type.assign_attributes(
    title: params[:title],
    sop_description: params[:sop_description],
    standard_handling: params[:standard_handling],
    active: true
  )

  # 修复：如果CSV中提供了legacy_problem_code，使用CSV中的值
  if params[:legacy_problem_code].present?
    problem_type.legacy_problem_code = params[:legacy_problem_code]
  else
    # 否则使用虚拟字段计算
    problem_type.legacy_problem_code
  end

  problem_type.save! if problem_type.changed?
  [problem_type, action]
end
```

**验证步骤：**
```bash
# 1. 运行相关测试
rails test test/services/problem_code_import_service_test.rb

# 2. 手动测试
rails console
# 在console中测试legacy_problem_code处理逻辑
```

### 步骤1.2：添加legacy_problem_code参数处理

**文件：** `app/services/problem_code_import_service.rb`

**位置：** 第58-63行

```ruby
# 修改前
problem_type_params = {
  issue_code: format_code_value(row['issue_code']),
  title: row['problem_title'],
  sop_description: row['sop_description'],
  standard_handling: row['standard_handling']
}

# 修改后
problem_type_params = {
  issue_code: format_code_value(row['issue_code']),
  title: row['problem_title'],
  sop_description: row['sop_description'],
  standard_handling: row['standard_handling'],
  legacy_problem_code: row['legacy_problem_code']&.strip
}
```

### 步骤1.3：改进代码格式化方法

**文件：** `app/services/problem_code_import_service.rb`

**位置：** 第128-145行

```ruby
# 修改前
def format_code_value(value)
  return nil if value.nil? || value.to_s.strip.empty?

  # 转换为字符串并去除前后空格
  code_str = value.to_s.strip

  # 如果已经是2位数字格式，直接返回
  return code_str if code_str.match?(/^\d{2}$/)

  # 如果是1位数字，前面补0
  return code_str.rjust(2, '0') if code_str.match?(/^\d$/)

  # 如果是 "00"（通用类型），直接返回
  return code_str if code_str == '00'

  # 其他情况，原样返回（包括非数字格式）
  code_str
end

# 修改后
def format_code_value(value, target_length = 2)
  return nil if value.nil? || value.to_s.strip.empty?

  # 转换为字符串并去除前后空格
  code_str = value.to_s.strip

  # 如果已经是目标长度的数字格式，直接返回
  return code_str if code_str.match?(/^\d{#{target_length}}$/)

  # 如果是数字且长度不足，前面补0
  if code_str.match?(/^\d+$/)
    return code_str.rjust(target_length, '0')
  end

  # 如果是 "00"（通用类型），直接返回
  return code_str if code_str == '00'

  # 其他情况，原样返回（包括非数字格式）
  code_str
end
```

## 🔧 第二阶段：数据验证增强

### 步骤2.1：添加数据验证方法

**文件：** `app/services/problem_code_import_service.rb`

**位置：** 在private方法区域添加

```ruby
def validate_fee_type_params(params)
  errors = []

  # 验证reimbursement_type_code
  unless %w[EN MN].include?(params[:reimbursement_type_code])
    errors << "Invalid reimbursement_type_code: #{params[:reimbursement_type_code]}"
  end

  # 验证meeting_type_code格式
  unless params[:meeting_type_code].match?(/^\d{2}$/)
    errors << "Invalid meeting_type_code: #{params[:meeting_type_code]}"
  end

  # 验证expense_type_code格式
  unless params[:expense_type_code].match?(/^\d{2}$/)
    errors << "Invalid expense_type_code: #{params[:expense_type_code]}"
  end

  errors
end

def validate_problem_type_params(params)
  errors = []

  # 验证issue_code格式
  unless params[:issue_code].match?(/^\d+$/)
    errors << "Invalid issue_code: #{params[:issue_code]}"
  end

  # 验证字段长度
  if params[:sop_description]&.length > 2000
    errors << "SOP description too long (max 2000 characters)"
  end

  if params[:standard_handling]&.length > 1000
    errors << "Standard handling too long (max 1000 characters)"
  end

  errors
end
```

### 步骤2.2：改进process_row方法

**文件：** `app/services/problem_code_import_service.rb`

**位置：** 第49-76行

```ruby
# 修改前
def process_row(row, result)
  fee_type_params = {
    reimbursement_type_code: row['reimbursement_type_code'],
    meeting_type_code: format_code_value(row['meeting_type_code']),
    expense_type_code: format_code_value(row['expense_type_code']),
    name: row['expense_type_name'],
    meeting_name: row['meeting_type_name']
  }

  problem_type_params = {
    issue_code: format_code_value(row['issue_code']),
    title: row['problem_title'],
    sop_description: row['sop_description'],
    standard_handling: row['standard_handling'],
    legacy_problem_code: row['legacy_problem_code']&.strip
  }

  # Skip if essential data is missing
  return if fee_type_params.values_at(:reimbursement_type_code, :meeting_type_code, :expense_type_code).any?(&:blank?)
  return if problem_type_params.values.any?(&:blank?)

  # Process FeeType
  fee_type, fee_type_action = process_fee_type(fee_type_params)
  update_result_with_action(result, :fee_types, fee_type_action, fee_type.as_json)

  # Process ProblemType
  problem_type, problem_type_action = process_problem_type(problem_type_params, fee_type)
  update_result_with_action(result, :problem_types, problem_type_action, problem_type.as_json)
end

# 修改后
def process_row(row, result)
  # 清理数据
  fee_type_params = {
    reimbursement_type_code: clean_text_field(row['reimbursement_type_code']),
    meeting_type_code: format_code_value(row['meeting_type_code']),
    expense_type_code: format_code_value(row['expense_type_code']),
    name: clean_text_field(row['expense_type_name']),
    meeting_name: clean_text_field(row['meeting_type_name'])
  }

  problem_type_params = {
    issue_code: format_code_value(row['issue_code']),
    title: clean_text_field(row['problem_title']),
    sop_description: clean_text_field(row['sop_description']),
    standard_handling: clean_text_field(row['standard_handling']),
    legacy_problem_code: clean_text_field(row['legacy_problem_code'])
  }

  # 验证数据
  fee_type_errors = validate_fee_type_params(fee_type_params)
  problem_type_errors = validate_problem_type_params(problem_type_params)

  if fee_type_errors.any? || problem_type_errors.any?
    result[:details][:errors] ||= []
    result[:details][:errors] << {
      row: result[:current_row] || 0,
      errors: fee_type_errors + problem_type_errors,
      data: row.to_h
    }
    return
  end

  # Skip if essential data is missing
  return if fee_type_params.values_at(:reimbursement_type_code, :meeting_type_code, :expense_type_code).any?(&:blank?)
  return if problem_type_params.values.any?(&:blank?)

  # Process FeeType
  fee_type, fee_type_action = process_fee_type(fee_type_params)
  update_result_with_action(result, :fee_types, fee_type_action, fee_type.as_json)

  # Process ProblemType
  problem_type, problem_type_action = process_problem_type(problem_type_params, fee_type)
  update_result_with_action(result, :problem_types, problem_type_action, problem_type.as_json)
end
```

### 步骤2.3：添加文本清理方法

**文件：** `app/services/problem_code_import_service.rb`

**位置：** 在private方法区域添加

```ruby
def clean_text_field(value)
  return nil if value.nil?

  # 移除BOM和特殊字符
  cleaned = value.to_s.strip
  cleaned = cleaned.gsub("\xEF\xBB\xBF", '')  # BOM
  cleaned = cleaned.gsub(/[""]/, '"')        # 中文引号替换
  cleaned = cleaned.gsub(/['']/, "'")        # 中文单引号替换
  cleaned = cleaned.gsub(/【/, '[')          # 中文括号替换
  cleaned = cleaned.gsub(/】/, ']')          # 中文括号替换

  cleaned
end
```

## 🔧 第三阶段：错误处理改进

### 步骤3.1：改进import方法

**文件：** `app/services/problem_code_import_service.rb`

**位置：** 第9-41行

```ruby
# 修改前
def import
  result = initialize_result

  begin
    # 强制使用 UTF-8 a编码读取文件，并处理BOM
    content = File.read(@file_path, encoding: 'bom|utf-8')
    Rails.logger.debug '========== [Debug Import] File content read with BOM|UTF-8 encoding. =========='
    Rails.logger.debug "  Content encoding before processing: #{content.encoding.name}"
    Rails.logger.debug "  Content starts with (first 50 chars): #{content[0..49].dump}"

    content.strip!
    # BOM should be removed by 'bom|utf-8', but we can log for verification
    original_length = content.bytesize
    content.sub!("\xEF\xBB\xBF", '')
    new_length = content.bytesize

    Rails.logger.debug "  BOM removal check: #{original_length - new_length} bytes removed."
    Rails.logger.debug "  Content encoding after processing: #{content.encoding.name}"
    Rails.logger.debug "  Content starts with after processing (first 50 chars): #{content[0..49].dump}"

    Rails.logger.debug '========== [Debug Import] Starting CSV parsing... =========='
    CSV.parse(content, headers: true, encoding: 'UTF-8').each.with_index do |row, index|
      Rails.logger.debug "  Processing row #{index + 1}: #{row.to_h.inspect}"
      process_row(row, result)
    end
    Rails.logger.debug '========== [Debug Import] CSV parsing finished. =========='
  rescue StandardError => e
    result[:success] = false
    result[:error] = e.message
  end

  result
end

# 修改后
def import
  result = initialize_result

  begin
    # 强制使用 UTF-8 a编码读取文件，并处理BOM
    content = File.read(@file_path, encoding: 'bom|utf-8')
    Rails.logger.debug '========== [Debug Import] File content read with BOM|UTF-8 encoding. =========='
    Rails.logger.debug "  Content encoding before processing: #{content.encoding.name}"
    Rails.logger.debug "  Content starts with (first 50 chars): #{content[0..49].dump}"

    content.strip!
    # BOM should be removed by 'bom|utf-8', but we can log for verification
    original_length = content.bytesize
    content.sub!("\xEF\xBB\xBF", '')
    new_length = content.bytesize

    Rails.logger.debug "  BOM removal check: #{original_length - new_length} bytes removed."
    Rails.logger.debug "  Content encoding after processing: #{content.encoding.name}"
    Rails.logger.debug "  Content starts with after processing (first 50 chars): #{content[0..49].dump}"

    Rails.logger.debug '========== [Debug Import] Starting CSV parsing... =========='
    CSV.parse(content, headers: true, encoding: 'UTF-8').each.with_index do |row, index|
      Rails.logger.debug "  Processing row #{index + 1}: #{row.to_h.inspect}"
      
      begin
        result[:current_row] = index + 1
        process_row(row, result)
      rescue StandardError => e
        result[:details][:errors] ||= []
        result[:details][:errors] << {
          row: index + 1,
          error: e.message,
          data: row.to_h
        }
        Rails.logger.error "Row #{index + 1} import failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
    Rails.logger.debug '========== [Debug Import] CSV parsing finished. =========='
  rescue StandardError => e
    result[:success] = false
    result[:error] = e.message
    Rails.logger.error "Import failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  ensure
    result[:current_row] = nil
  end

  result
end
```

## 🧪 第四阶段：测试实施

### 步骤4.1：创建测试文件

```bash
# 创建测试目录
mkdir -p test/services

# 创建测试文件
touch test/services/problem_code_import_service_test.rb
touch test/integration/problem_code_import_integration_test.rb
```

### 步骤4.2：实施单元测试

**文件：** `test/services/problem_code_import_service_test.rb`

```ruby
require 'test_helper'

class ProblemCodeImportServiceTest < ActiveSupport::TestCase
  def setup
    @service = ProblemCodeImportService.new('test.csv')
    @test_csv_path = Rails.root.join('tmp', 'test_import.csv')
  end

  def teardown
    File.delete(@test_csv_path) if File.exist?(@test_csv_path)
  end

  # Legacy Problem Code测试
  test "should use legacy_problem_code from CSV when provided" do
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,EN000101
    CSV
    
    File.write(@test_csv_path, csv_content)
    service = ProblemCodeImportService.new(@test_csv_path)
    result = service.import
    
    assert result[:success]
    problem_type = ProblemType.find_by(title: '燃油费行程问题')
    assert_equal 'EN000101', problem_type.legacy_problem_code
  end

  # 代码格式化测试
  test "should format code values correctly" do
    assert_equal '01', @service.send(:format_code_value, '1')
    assert_equal '09', @service.send(:format_code_value, '9')
    assert_equal '01', @service.send(:format_code_value, '01')
    assert_equal '00', @service.send(:format_code_value, '00')
    assert_nil @service.send(:format_code_value, nil)
  end

  # 数据验证测试
  test "should validate fee type parameters" do
    valid_params = { reimbursement_type_code: 'EN', meeting_type_code: '01', expense_type_code: '01' }
    errors = @service.send(:validate_fee_type_params, valid_params)
    assert_empty errors

    invalid_params = { reimbursement_type_code: 'XX', meeting_type_code: 'ABC', expense_type_code: '1' }
    errors = @service.send(:validate_fee_type_params, invalid_params)
    assert_equal 3, errors.length
  end

  # 文本清理测试
  test "should clean text fields properly" do
    chinese_quotes = '"微信零钱"、"支付宝花呗"及"京东白条"支付'
    cleaned = @service.send(:clean_text_field, chinese_quotes)
    assert_equal '"微信零钱"、"支付宝花呗"及"京东白条"支付', cleaned

    bom_text = "\xEF\xBB\xBF测试内容"
    cleaned = @service.send(:clean_text_field, bom_text)
    assert_equal '测试内容', cleaned
  end
end
```

### 步骤4.3：运行测试

```bash
# 1. 运行单元测试
rails test test/services/problem_code_import_service_test.rb

# 2. 运行集成测试
rails test test/integration/problem_code_import_integration_test.rb

# 3. 运行所有相关测试
rails test test/services/ test/integration/ --name problem_code

# 4. 检查测试覆盖率
rails test:coverage
```

## 🚀 第五阶段：部署准备

### 步骤5.1：代码质量检查

```bash
# 1. RuboCop检查
bundle exec rubocop app/services/problem_code_import_service.rb

# 2. 安全检查
bundle exec brakeman

# 3. 代码复杂度检查
bundle exec rubycritic app/services/problem_code_import_service.rb
```

### 步骤5.2：性能测试

```bash
# 1. 创建大数据量测试文件
rails runner "
  csv_lines = ['reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code']
  1000.times do |i|
    csv_lines << \"EN,00,个人,01,月度交通费,#{sprintf('%02d', i)},测试问题#{i},根据SOP规定#{i},请补充完整#{i},EN0001#{sprintf('%02d', i)}\"
  end
  File.write('tmp/large_test.csv', csv_lines.join(\"\n\"))
"

# 2. 性能测试
time rails runner "
  service = ProblemCodeImportService.new('tmp/large_test.csv')
  result = service.import
  puts \"Imported #{result[:details][:problem_types].length} records\"
"
```

### 步骤5.3：预发布验证

```bash
# 1. 在预发布环境部署
cap staging deploy

# 2. 运行预发布测试
rails staging:test

# 3. 验证导入功能
rails staging:runner "
  service = ProblemCodeImportService.new('docs/user_data/问题类型样式-20250908.csv')
  result = service.import
  puts \"Import result: #{result[:success]}\"
  puts \"Imported fee types: #{result[:details][:fee_types].length}\"
  puts \"Imported problem types: #{result[:details][:problem_types].length}\"
"
```

## 📋 实施检查清单

### 代码修改检查
- [ ] 修复Legacy Problem Code处理逻辑
- [ ] 添加legacy_problem_code参数处理
- [ ] 改进代码格式化方法
- [ ] 添加数据验证方法
- [ ] 改进错误处理逻辑
- [ ] 添加文本清理方法

### 测试检查
- [ ] 单元测试全部通过
- [ ] 集成测试全部通过
- [ ] 性能测试通过
- [ ] 代码覆盖率达到90%以上

### 质量检查
- [ ] RuboCop检查通过
- [ ] 安全检查通过
- [ ] 代码复杂度在合理范围内

### 部署检查
- [ ] 预发布环境验证通过
- [ ] 数据库备份完成
- [ ] 回滚方案准备就绪
- [ ] 监控配置完成

## 🚨 回滚计划

如果部署后出现问题，按以下步骤回滚：

```bash
# 1. 立即回滚代码
git checkout HEAD~1

# 2. 重新部署
cap production deploy

# 3. 验证系统正常
rails production:runner "puts 'System is healthy'"

# 4. 如需要，恢复数据库
rails production:db:restore:latest
```

## 📞 支持联系

如实施过程中遇到问题，请联系：
- 技术负责人：tech-lead@company.com
- 项目经理：pm@company.com
- 运维团队：ops@company.com

## 📊 实施时间表

| 阶段 | 任务 | 预计时间 | 负责人 |
|------|------|----------|--------|
| 1 | 紧急修复 | 3小时 | 开发团队 |
| 2 | 数据验证增强 | 5小时 | 开发团队 |
| 3 | 错误处理改进 | 2小时 | 开发团队 |
| 4 | 测试实施 | 4小时 | 测试团队 |
| 5 | 部署准备 | 2小时 | 运维团队 |

**总计：** 16小时（2个工作日）