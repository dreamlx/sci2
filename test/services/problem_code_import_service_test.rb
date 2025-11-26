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
  test 'should use legacy_problem_code from CSV when provided' do
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

  test 'should calculate legacy_problem_code when not provided in CSV' do
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling
      EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整
    CSV

    File.write(@test_csv_path, csv_content)
    service = ProblemCodeImportService.new(@test_csv_path)
    result = service.import

    assert result[:success]
    problem_type = ProblemType.find_by(title: '燃油费行程问题')
    assert_equal 'EN000101', problem_type.legacy_problem_code
  end

  test 'should handle empty legacy_problem_code in CSV' do
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,
    CSV

    File.write(@test_csv_path, csv_content)
    service = ProblemCodeImportService.new(@test_csv_path)
    result = service.import

    assert result[:success]
    problem_type = ProblemType.find_by(title: '燃油费行程问题')
    assert_equal 'EN000101', problem_type.legacy_problem_code
  end

  # 代码格式化测试
  test 'should format code values correctly' do
    assert_equal '01', @service.send(:format_code_value, '1')
    assert_equal '09', @service.send(:format_code_value, '9')
    assert_equal '01', @service.send(:format_code_value, '01')
    assert_equal '00', @service.send(:format_code_value, '00')
    assert_nil @service.send(:format_code_value, nil)
  end

  test 'should format code values with custom target length' do
    assert_equal '001', @service.send(:format_code_value, '1', 3)
    assert_equal '009', @service.send(:format_code_value, '9', 3)
    assert_equal '001', @service.send(:format_code_value, '001', 3)
  end

  # 数据验证测试
  test 'should validate valid fee type parameters' do
    valid_params = {
      reimbursement_type_code: 'EN',
      meeting_type_code: '01',
      expense_type_code: '01'
    }
    errors = @service.send(:validate_fee_type_params, valid_params)
    assert_empty errors
  end

  test 'should reject invalid fee type parameters' do
    invalid_params = {
      reimbursement_type_code: 'XX',
      meeting_type_code: 'ABC',
      expense_type_code: '1'
    }
    errors = @service.send(:validate_fee_type_params, invalid_params)
    assert_equal 3, errors.length
    assert_includes errors, 'Invalid reimbursement_type_code: XX'
    assert_includes errors, 'Invalid meeting_type_code: ABC'
    assert_includes errors, 'Invalid expense_type_code: 1'
  end

  test 'should validate valid problem type parameters' do
    valid_params = {
      issue_code: '01',
      sop_description: 'Valid description',
      standard_handling: 'Valid handling'
    }
    errors = @service.send(:validate_problem_type_params, valid_params)
    assert_empty errors
  end

  test 'should reject invalid problem type parameters' do
    invalid_params = {
      issue_code: 'ABC',
      sop_description: 'a' * 2001, # 超过长度限制
      standard_handling: 'b' * 1001 # 超过长度限制
    }
    errors = @service.send(:validate_problem_type_params, invalid_params)
    assert_equal 3, errors.length
    assert_includes errors, 'Invalid issue_code: ABC'
    assert_includes errors, 'SOP description too long (max 2000 characters)'
    assert_includes errors, 'Standard handling too long (max 1000 characters)'
  end

  # 文本清理测试
  test 'should clean text fields properly' do
    chinese_quotes = '"微信零钱"、"支付宝花呗"及"京东白条"支付'
    cleaned = @service.send(:clean_text_field, chinese_quotes)
    assert_equal '"微信零钱"、"支付宝花呗"及"京东白条"支付', cleaned

    bom_text = "\xEF\xBB\xBF测试内容"
    cleaned = @service.send(:clean_text_field, bom_text)
    assert_equal '测试内容', cleaned

    chinese_brackets = '【测试内容】'
    cleaned = @service.send(:clean_text_field, chinese_brackets)
    assert_equal '[测试内容]', cleaned
  end

  test 'should handle nil and empty text fields' do
    assert_nil @service.send(:clean_text_field, nil)
    assert_equal '', @service.send(:clean_text_field, '')
    assert_equal '', @service.send(:clean_text_field, '   ')
  end

  # 错误处理测试
  test 'should continue import when single row has error' do
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,EN000101
      XX,00,个人,01,月度交通费,02,出租车行程问题,根据SOP规定,请补充完整,EN000102
      EN,00,个人,01,月度交通费,03,网约车行程问题,根据SOP规定,请补充完整,EN000103
    CSV

    File.write(@test_csv_path, csv_content)
    service = ProblemCodeImportService.new(@test_csv_path)
    result = service.import

    # 导入应该成功（部分成功）
    assert result[:success]

    # 应该有错误记录
    assert result[:details][:errors].present?
    assert_equal 1, result[:details][:errors].length

    # 应该有成功导入的记录
    assert_equal 2, result[:details][:problem_types].length
  end

  test 'should record detailed error information' do
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      XX,00,个人,01,月度交通费,01,燃油费行程问题,根据SOP规定,请补充完整,EN000101
    CSV

    File.write(@test_csv_path, csv_content)
    service = ProblemCodeImportService.new(@test_csv_path)
    result = service.import

    error = result[:details][:errors].first
    assert_equal 2, error[:row]
    assert_includes error[:error], 'Invalid reimbursement_type_code'
    assert_equal 'XX', error[:data]['reimbursement_type_code']
  end

  # 完整导入测试
  test 'should import complete CSV file successfully' do
    csv_content = <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费（销售/SMO/CO),1,燃油费行程问题,根据SOP规定，月度交通费报销燃油费需提供每张燃油费的使用时间区间，行程为医院的需具体到科室,请根据要求在评论区将行程补充完整,EN000101
      EN,00,个人,01,月度交通费（销售/SMO/CO),2,出租车行程问题,根据SOP规定，月度交通费报销出租车费用，需注明具体的行程地点和事由，行程为医院的，应明确注明拜访医院及科室,请根据要求补充至HLY评论区,EN000102
      MN,01,学术论坛,00,通用,1,会议权限_学术论坛,根据SOP规定，学术论坛可举办的组织者岗位为地区业务销售经理及以上、市场、医学、临床运营、市场准入和商务，您无权限举办此类型会议,请提供逐级审批至部门负责人的授权邮件并抄送合规,MN010001
    CSV

    File.write(@test_csv_path, csv_content)
    service = ProblemCodeImportService.new(@test_csv_path)
    result = service.import

    assert result[:success]
    assert_equal 3, result[:details][:problem_types].length

    # 验证具体数据
    en_fee_type = FeeType.find_by(reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01')
    assert_not_nil en_fee_type
    assert_equal '月度交通费（销售/SMO/CO)', en_fee_type.name

    mn_fee_type = FeeType.find_by(reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '00')
    assert_not_nil mn_fee_type
    assert_equal '通用', mn_fee_type.name

    # 验证legacy_problem_code
    problem_type = ProblemType.joins(:fee_type)
                              .find_by(fee_types: { reimbursement_type_code: 'EN', meeting_type_code: '00',
                                                    expense_type_code: '01' },
                                       issue_code: '01')
    assert_not_nil problem_type
    assert_equal 'EN000101', problem_type.legacy_problem_code
  end
end
