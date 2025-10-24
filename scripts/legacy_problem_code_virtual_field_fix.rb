#!/usr/bin/env ruby
# Legacy Problem Code 虚拟字段实现方案

require_relative 'config/environment'

puts '🔧 Legacy Problem Code 虚拟字段实现方案'
puts '=' * 50

# 1. 创建迁移以移除 legacy_problem_code 字段
puts "\n1. 📝 创建迁移文件"
puts '-' * 30

migration_content = <<~MIGRATION
  class RemoveLegacyProblemCodeFromProblemTypes < ActiveRecord::Migration[7.1]
    def change
      # 首先移除索引（如果存在）
      remove_index :problem_types, :legacy_problem_code if index_exists?(:problem_types, :legacy_problem_code)
  #{'    '}
      # 然后移除字段
      remove_column :problem_types, :legacy_problem_code, :string
    end

    def down
      # 回滚时重新添加字段
      add_column :problem_types, :legacy_problem_code, :string
  #{'    '}
      # 重新创建索引
      add_index :problem_types, :legacy_problem_code
    end
  end
MIGRATION

puts '迁移文件内容：'
puts migration_content

# 2. 修改 ProblemType 模型
puts "\n2. 📋 修改 ProblemType 模型"
puts '-' * 30

model_modification = <<~MODEL
  # 在 app/models/problem_type.rb 中添加虚拟字段方法

  def legacy_problem_code
    "#{reimbursement_type_code}#{meeting_type_code.rjust(2, '0')}#{expense_type_code.rjust(2, '0')}#{code}"
  end

  # 更新 ransackable_attributes
  def self.ransackable_attributes(auth_object = nil)
    %w[id code title sop_description standard_handling active created_at updated_at
       reimbursement_type_code meeting_type_code expense_type_code]
  end
MODEL

puts '模型修改内容：'
puts model_modification

# 3. 修改导入服务
puts "\n3. 📥 修改导入服务"
puts '-' * 30

import_service_modification = <<~IMPORT
  # 在 app/services/problem_code_import_service.rb 中修改 process_row 方法

  def process_row(row, result)
    # Standardize row data
    fee_type_params = {
      reimbursement_type_code: row['reimbursement_type_code']&.strip,
      meeting_type_code: row['meeting_type_code']&.strip,
      expense_type_code: row['expense_type_code']&.strip,
      name: row['expense_type_name']&.strip,
      meeting_name: row['meeting_type_name']&.strip
    }

    problem_type_params = {
      reimbursement_type_code: fee_type_params[:reimbursement_type_code],
      meeting_type_code: fee_type_params[:meeting_type_code],
      expense_type_code: fee_type_params[:expense_type_code],
      code: row['issue_code']&.strip,
      title: row['problem_title']&.strip,
      sop_description: row['sop_description']&.strip,
      standard_handling: row['standard_handling']&.strip
      # 移除 legacy_problem_code，因为它现在是虚拟字段
    }
  #{'  '}
    # Skip if essential data is missing
    return if fee_type_params.values.any?(&:blank?) || problem_type_params.values.any?(&:blank?)

    # Process FeeType
    fee_type, fee_type_action = process_fee_type(fee_type_params)
    update_result_with_action(result, :fee_types, fee_type_action, fee_type.as_json)
  #{'  '}
    # Process ProblemType
    problem_type_params[:name] = fee_type_params[:name]
    problem_type, problem_type_action = process_problem_type(problem_type_params)
    update_result_with_action(result, :problem_types, problem_type_action, problem_type.as_json)
  end

  def process_problem_type(params)
    problem_type = ProblemType.find_or_initialize_by(
      reimbursement_type_code: params[:reimbursement_type_code],
      meeting_type_code: params[:meeting_type_code],
      expense_type_code: params[:expense_type_code],
      code: params[:code]
    )

    action = problem_type.new_record? ? :imported : :updated
  #{'  '}
    problem_type.assign_attributes(
      title: params[:title],
      sop_description: params[:sop_description],
      standard_handling: params[:standard_handling],
      active: true
      # 移除 legacy_problem_code 赋值
    )
  #{'  '}
    if problem_type.changed?
      problem_type.save!
    else
      # 即使没有变更也要尝试保存，以检查验证错误
      problem_type.save!
    end
  #{'  '}
    [problem_type, action]
  end
IMPORT

puts '导入服务修改内容：'
puts import_service_modification

# 4. 修正测试数据
puts "\n4. 🧪 修正测试数据"
puts '-' * 30

test_data_fix = <<~TEST
  # 在 spec/services/problem_code_import_service_spec.rb 中修正测试数据

  let(:csv_content) do
    <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费,01,"燃油费行程问题","根据SOP规定...","请根据要求...",EN000101
      EN,00,个人,02,市内交通费,02,"出租车行程问题","根据SOP规定...","请根据要求...",EN000102
      MN,01,学术论坛,01,会议讲课费,01,"非讲者库讲者","根据SOP规定...","不符合要求...",MN010101
      MN,01,学术论坛,00,通用,01,"会议权限问题","根据SOP规定...","请提供...",MN010001
    CSV
  end

  # 修正测试预期
  it 'creates the correct number of FeeType records' do
    expect { service.import }.to change(FeeType, :count).by(4)
    # EN-00-01, EN-00-02, MN-01-01, MN-01-00
  end
TEST

puts '测试数据修正内容：'
puts test_data_fix

puts "\n" + ('=' * 50)
puts '🎯 实施建议：'
puts '1. 首先应用测试数据修正，确保测试通过'
puts '2. 然后实现虚拟字段迁移'
puts '3. 最后更新模型和导入服务'
puts '4. 验证所有功能正常工作'
puts '=' * 50
