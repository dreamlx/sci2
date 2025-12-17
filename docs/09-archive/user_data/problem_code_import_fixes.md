# 问题代码导入功能修复文档

## 📋 修复概述

本文档详细描述了问题代码导入功能的修复方案，包括问题分析、解决方案和实施步骤。

## 🔴 关键问题修复

### 问题1：Legacy Problem Code未从CSV读取

**问题描述：**
当前导入服务忽略CSV中的`legacy_problem_code`字段，导致系统重新生成编码，可能与CSV中的不一致。

**影响：**
- CSV中的legacy_problem_code数据丢失
- 可能导致与现有系统的编码不一致
- 影响数据追溯和兼容性

**修复方案：**

#### 1.1 修改ProblemCodeImportService#process_problem_type方法

```ruby
# 修改前（当前代码）
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

# 修改后（修复代码）
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

#### 1.2 修改process_row方法，添加legacy_problem_code参数

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

### 问题2：代码格式不统一

**问题描述：**
CSV中使用单数字格式（0,1,2,3...），但系统需要2位格式（00,01,02,03...），可能导致legacy_problem_code生成错误。

**修复方案：**

#### 2.1 改进format_code_value方法

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

## 🟡 增强功能

### 增强1：数据验证

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

### 增强2：错误处理改进

```ruby
def import
  result = initialize_result

  begin
    content = File.read(@file_path, encoding: 'bom|utf-8')
    Rails.logger.debug '========== [Debug Import] File content read with BOM|UTF-8 encoding. =========='
    Rails.logger.debug "  Content encoding before processing: #{content.encoding.name}"
    Rails.logger.debug "  Content starts with (first 50 chars): #{content[0..49].dump}"

    content.strip!
    content.sub!("\xEF\xBB\xBF", '')

    Rails.logger.debug "  BOM removal check: #{original_length - new_length} bytes removed."
    Rails.logger.debug "  Content encoding after processing: #{content.encoding.name}"
    Rails.logger.debug "  Content starts with after processing (first 50 chars): #{content[0..49].dump}"

    Rails.logger.debug '========== [Debug Import] Starting CSV parsing... =========='
    
    CSV.parse(content, headers: true, encoding: 'UTF-8').each.with_index do |row, index|
      begin
        Rails.logger.debug "  Processing row #{index + 1}: #{row.to_h.inspect}"
        process_row(row, result, index + 1)
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
  end

  result
end
```

### 增强3：特殊字符处理

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

## 🧪 测试策略

### 单元测试用例

1. **Legacy Problem Code处理测试**
   - CSV中有legacy_problem_code时使用CSV值
   - CSV中无legacy_problem_code时使用计算值
   - legacy_problem_code为空时的处理

2. **代码格式化测试**
   - 单数字补零（1 → 01）
   - 已有2位数字保持不变（01 → 01）
   - 通用类型处理（00 → 00）
   - 非数字格式保持不变

3. **数据验证测试**
   - 有效的reimbursement_type_code（EN/MN）
   - 无效的reimbursement_type_code
   - 有效的数字格式
   - 无效的数字格式

4. **错误处理测试**
   - 单行错误不影响整体导入
   - 详细错误信息记录
   - 成功/失败统计

### 集成测试用例

1. **完整CSV导入测试**
   - 使用提供的CSV文件进行完整导入
   - 验证所有数据正确导入
   - 验证legacy_problem_code正确保存

2. **部分数据更新测试**
   - 导入相同数据，验证更新逻辑
   - 验证重复导入不会创建重复记录

3. **大数据量导入测试**
   - 测试性能表现
   - 验证内存使用情况

## 📋 实施检查清单

### 修复实施前检查
- [ ] 备份当前数据库
- [ ] 备份当前代码版本
- [ ] 准备测试环境
- [ ] 准备回滚方案

### 修复实施步骤
- [ ] 修改ProblemCodeImportService#process_problem_type方法
- [ ] 修改ProblemCodeImportService#process_row方法
- [ ] 改进ProblemCodeImportService#format_code_value方法
- [ ] 添加数据验证方法
- [ ] 改进错误处理逻辑
- [ ] 添加特殊字符处理

### 修复实施后验证
- [ ] 运行单元测试
- [ ] 运行集成测试
- [ ] 使用测试CSV文件验证导入功能
- [ ] 验证legacy_problem_code正确保存
- [ ] 验证代码格式化正确工作
- [ ] 验证错误处理正确工作

## 🚀 部署计划

### 预发布环境
1. 部署修复代码
2. 运行完整测试套件
3. 使用生产数据副本进行测试
4. 验证性能影响

### 生产环境
1. 在低峰期部署
2. 监控系统性能
3. 验证导入功能正常
4. 准备快速回滚方案

## 📞 联系信息

如有问题，请联系：
- 开发团队：dev-team@company.com
- 测试团队：qa-team@company.com
- 项目经理：pm@company.com