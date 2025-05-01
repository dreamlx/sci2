# spec/services/operation_history_import_service_spec.rb
require 'rails_helper'
require 'tempfile'
require 'rack/test'

RSpec.describe OperationHistoryImportService do
  let(:admin_user) { create(:admin_user) }
  let(:file) do
    file_path = Rails.root.join('spec', 'test_data', 'test_operation_histories.csv')
    Rack::Test::UploadedFile.new(file_path, 'text/csv')
  end
  let(:service) { described_class.new(file, admin_user) }

  describe '#import' do
    context 'with valid file and existing reimbursements' do
      let!(:reimbursement1) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }
      let!(:reimbursement2) { create(:reimbursement, invoice_number: 'R202501002', status: 'waiting_completion') }
      
      it 'creates operation histories' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作类型', '操作日期', '操作人', '操作意见', '表单类型', '操作节点'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '提交', '2025-01-01 10:00:00', '测试用户1', '提交报销单', '报销单', '提交节点'], 1)
                                                      .and_yield(['R202501002', '审批', '2025-01-02 10:00:00', '测试用户2', '审批通过', '报销单', '审批节点'], 2)
                                                      .and_yield(['R999999', '审批', '2025-01-03 10:00:00', '测试用户3', '审批通过', '报销单', '审批节点'], 3) # 不存在的报销单
        
        result = nil
        expect { 
          result = service.import(spreadsheet) 
        }.to change(OperationHistory, :count).by(2)

        # Test passed successfully
        expect(result[:success]).to be true
        expect(result[:imported]).to eq(2)
        expect(result[:skipped]).to eq(0)
        expect(result[:unmatched]).to eq(1)
        expect(result[:errors]).to eq(0)
      end
      
      it 'updates reimbursement status based on operation type and notes' do
        # 测试导入审批通过的操作历史会将报销单状态更新为 closed
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作类型', '操作日期', '操作人', '操作意见', '表单类型', '操作节点'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501002', '审批', '2025-01-02 10:00:00', '测试用户2', '审批通过', '报销单', '审批节点'], 1)
        
        result = service.import(spreadsheet)
        
        reimbursement1.reload
        reimbursement2.reload
        
        # 验证报销单状态
        expect(reimbursement1.status).to eq('pending') # 不应该改变
        expect(reimbursement2.status).to eq('closed') # 应该变为 closed
        
        # 验证导入结果
        expect(result[:success]).to be true
        expect(result[:imported]).to eq(1) # 应该导入 1 条记录
        expect(result[:updated_reimbursements]).to eq(1) # 应该更新 1 个报销单状态
      end
      
      it 'tracks unmatched histories' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作类型', '操作日期', '操作人', '操作意见', '表单类型', '操作节点'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R999999', '审批', '2025-01-03 10:00:00', '测试用户3', '审批通过', '报销单', '审批节点'], 1) # 不存在的报销单
        
        result = service.import(spreadsheet)
        
        expect(result[:unmatched]).to eq(1)
        expect(result[:unmatched_histories].first[:document_number]).to eq('R999999')
      end
    end
    
    context 'with duplicate records' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }
      let!(:existing_history) do
        create(:operation_history,
               document_number: 'R202501001',
               operation_type: '提交',
               operation_time: DateTime.parse('2025-01-01 10:00:00'),
               operator: '测试用户1')
      end
      
      it 'skips duplicate records' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作类型', '操作日期', '操作人', '操作意见'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '提交', '2025-01-01 10:00:00', '测试用户1', '提交报销单'], 1)
        
        result = nil
        expect { 
          result = service.import(spreadsheet) 
        }.not_to change(OperationHistory, :count)

        # Test passed successfully
        expect(result[:success]).to be true
        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(1)
      end
    end
    
    context 'with invalid data' do
      it 'handles errors' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作类型', '操作日期', '操作人', '操作意见'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', nil, '2025-01-01 10:00:00', '测试用户1', '提交报销单'], 1)
        
        result = service.import(spreadsheet)
        
        expect(result[:success]).to be true # 整体导入仍然成功
        expect(result[:imported]).to eq(0)
        expect(result[:errors]).to eq(1)
        expect(result[:error_details].first).to include('缺少必要字段')
      end
    end
    
    context 'with file error' do
      it 'handles missing file' do
        service = described_class.new(nil, admin_user)
        result = service.import
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('文件不存在')
      end
      
      it 'handles file processing errors' do
        allow(Roo::Spreadsheet).to receive(:open).and_raise(StandardError.new('测试错误'))
        
        result = service.import
        
        expect(result[:success]).to be false
        expect(result[:errors].first).to include('导入过程中发生错误')
      end
    end
  end
end