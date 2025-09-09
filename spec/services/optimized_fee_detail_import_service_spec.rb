require 'rails_helper'

RSpec.describe OptimizedFeeDetailImportService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, invoice_number: 'TEST001') }
  let(:fee_type) { create(:fee_type, name: '差旅费', meeting_name: '个人') }
  
  # 创建一个简单的CSV文件内容
  let(:csv_content) do
    <<~CSV
      报销单单号,费用id,费用类型,原始金额,费用发生日期
      TEST001,FEE001,差旅费,100.00,2024-01-01
    CSV
  end
  
  let(:temp_file) do
    file = Tempfile.new(['test', '.csv'])
    file.write(csv_content)
    file.rewind
    file
  end

  describe '#import' do
    context 'when importing a simple fee detail' do
      it 'should create a fee detail without callback errors' do
        service = OptimizedFeeDetailImportService.new(temp_file, admin_user)
        
        expect {
          result = service.import
          expect(result[:success]).to be true
          expect(result[:created]).to eq 1
        }.to change(FeeDetail, :count).by(1)
      end
    end
    
    context 'with skip_existing option' do
      it 'should skip existing records when option is enabled' do
        # 先创建一个已存在的记录
        create(:fee_detail, external_fee_id: 'FEE001', document_number: 'TEST001')
        
        service = OptimizedFeeDetailImportService.new(temp_file, admin_user, skip_existing: true)
        
        expect {
          result = service.import
          expect(result[:success]).to be true
          expect(result[:created]).to eq 0
          expect(result[:skipped]).to eq 1
        }.not_to change(FeeDetail, :count)
      end
    end
  end
  
  describe 'callback error reproduction' do
    it 'should identify the source of callback error' do
      # 直接测试 BatchImportManager
      batch_manager = BatchImportManager.new(FeeDetail)
      
      record_data = [{
        external_fee_id: 'FEE001',
        document_number: 'TEST001',
        fee_type: '差旅费',
        amount: 100.00,
        fee_date: Date.parse('2024-01-01'),
        verification_status: 'pending'
      }]
      
      expect {
        batch_manager.batch_insert(record_data)
      }.not_to raise_error
    end
  end
end