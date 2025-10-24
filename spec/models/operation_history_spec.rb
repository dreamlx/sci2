require 'rails_helper'

RSpec.describe OperationHistory, type: :model do
  describe 'validations' do
    it 'requires document_number' do
      operation_history = OperationHistory.new
      expect(operation_history).not_to be_valid
      expect(operation_history.errors[:document_number]).to include("不能为空")
    end

    it 'requires operation_type' do
      operation_history = OperationHistory.new(document_number: 'ER123456')
      expect(operation_history).not_to be_valid
      expect(operation_history.errors[:operation_type]).to include("不能为空")
    end

    it 'requires operation_time' do
      operation_history = OperationHistory.new(document_number: 'ER123456', operation_type: '审批')
      expect(operation_history).not_to be_valid
      expect(operation_history.errors[:operation_time]).to include("不能为空")
    end

    it 'requires operator' do
      operation_history = OperationHistory.new(
        document_number: 'ER123456',
        operation_type: '审批',
        operation_time: Time.current
      )
      expect(operation_history).not_to be_valid
      expect(operation_history.errors[:operator]).to include("不能为空")
    end

    it 'validates currency inclusion' do
      operation_history = OperationHistory.new(
        document_number: 'ER123456',
        operation_type: '审批',
        operation_time: Time.current,
        operator: '张三',
        currency: 'INVALID'
      )
      expect(operation_history).not_to be_valid
      expect(operation_history.errors[:currency]).to include('不包含于列表中')
    end

    it 'validates amount numericality' do
      operation_history = OperationHistory.new(
        document_number: 'ER123456',
        operation_type: '审批',
        operation_time: Time.current,
        operator: '张三',
        amount: -100
      )
      expect(operation_history).not_to be_valid
      expect(operation_history.errors[:amount]).to include('必须大于或等于0')
    end
  end

  # Scopes have been migrated to OperationHistoryRepository (spec/repositories/operation_history_repository_spec.rb)
  # This model test now focuses on data integrity: validations, associations, and basic model behavior
  # Following the new architecture pattern of separating concerns across layers

  describe 'formatting methods' do
    let(:operation_history) do
      OperationHistory.new(
        amount: 1234.56,
        operation_time: Time.parse('2025-08-04 10:30:00 UTC'),
        created_date: Time.parse('2025-08-03 15:45:00 UTC')
      )
    end

    it 'formats amount correctly' do
      expect(operation_history.formatted_amount).to eq(1234.56)
    end

    it 'formats operation_time correctly' do
      expect(operation_history.formatted_operation_time).to eq('2025-08-04 10:30:00')
    end

    it 'formats created_date correctly' do
      expect(operation_history.formatted_created_date).to eq('2025-08-03 15:45:00')
    end

    it 'handles nil values' do
      empty_history = OperationHistory.new
      expect(empty_history.formatted_amount).to eq('0')
      expect(empty_history.formatted_operation_time).to eq('0')
      expect(empty_history.formatted_created_date).to eq('0')
    end
  end

  describe 'ransackable attributes' do
    it 'includes all expected attributes' do
      expected_attributes = %w[
        id document_number operation_type operation_time operator notes form_type operation_node 
        applicant employee_id employee_company employee_department employee_department_path
        document_company document_department document_department_path submitter document_name
        currency amount created_date created_at updated_at
      ]
      
      expect(OperationHistory.ransackable_attributes).to match_array(expected_attributes)
    end
  end

  describe 'associations' do
    it 'belongs to reimbursement optionally' do
      operation_history = OperationHistory.new(
        document_number: 'ER123456',
        operation_type: '审批',
        operation_time: Time.current,
        operator: '张三'
      )
      
      expect(operation_history).to be_valid
    end
  end
end