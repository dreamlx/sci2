# spec/services/express_receipt_import_service_spec.rb
require 'rails_helper'
require 'tempfile'

RSpec.describe ExpressReceiptImportService do
  let(:admin_user) { create(:admin_user) }
  let(:file) do
    # Create a mock file object that responds to path and present?
    file = double('file')
    allow(file).to receive(:path).and_return('test_express_receipts.csv')
    allow(file).to receive(:present?).and_return(true)
    file
  end
  let(:service) { described_class.new(file, admin_user) }

  describe '#import' do
    context 'with valid file and existing reimbursements' do
      let!(:reimbursement1) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }
      let!(:reimbursement2) { create(:reimbursement, invoice_number: 'R202501002', status: 'pending') }
      
      it 'creates express receipt work orders' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作意见', '操作时间'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00'], 1)
                                                      .and_yield(['R202501002', '快递单号：SF1002', '2025-01-02 10:00:00'], 2)
                                                      .and_yield(['R999999', '快递单号: SF9999', '2025-01-03 10:00:00'], 3) # 不存在的报销单
        
        result = nil
        expect { 
          result = service.import(spreadsheet) 
        }.to change(ExpressReceiptWorkOrder, :count).by(2)

        # Test passed successfully
        expect(result[:success]).to be true
        expect(result[:created]).to eq(2)
        expect(result[:skipped]).to eq(0)
        expect(result[:unmatched]).to eq(1)
        expect(result[:errors]).to eq(0)
      end
      
      it 'extracts tracking numbers correctly' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作意见', '操作时间'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00'], 1)
                                                      .and_yield(['R202501002', '快递单号：SF1002', '2025-01-02 10:00:00'], 2)
        
        service.import(spreadsheet)
        
        work_order1 = ExpressReceiptWorkOrder.find_by(reimbursement_id: reimbursement1.id)
        work_order2 = ExpressReceiptWorkOrder.find_by(reimbursement_id: reimbursement2.id)
        
        expect(work_order1.tracking_number).to eq('SF1001')
        expect(work_order2.tracking_number).to eq('SF1002')
      end
      
      it 'sets work order status to completed' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作意见', '操作时间'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00'], 1)
                                                      .and_yield(['R202501002', '快递单号：SF1002', '2025-01-02 10:00:00'], 2)
        
        service.import(spreadsheet)
        
        work_orders = ExpressReceiptWorkOrder.all
        expect(work_orders.all? { |wo| wo.status == 'completed' }).to be true
      end
      
      it 'updates reimbursement status' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作意见', '操作时间'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00'], 1)
                                                      .and_yield(['R202501002', '快递单号：SF1002', '2025-01-02 10:00:00'], 2)
        
        service.import(spreadsheet)
        
        reimbursement1.reload
        reimbursement2.reload
        
        expect(reimbursement1.receipt_status).to eq('received')
        expect(reimbursement1.status).to eq('processing')
        expect(reimbursement2.receipt_status).to eq('received')
        expect(reimbursement2.status).to eq('processing')
      end
      
      it 'tracks unmatched receipts' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作意见', '操作时间'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R999999', '快递单号: SF9999', '2025-01-03 10:00:00'], 1) # 不存在的报销单
        
        result = service.import(spreadsheet)
        
        expect(result[:unmatched]).to eq(1)
        expect(result[:unmatched_details].first[:document_number]).to eq('R999999')
        expect(result[:unmatched_details].first[:tracking_number]).to eq('SF9999')
      end
    end
    
    context 'with duplicate records' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }
      let!(:existing_work_order) { create(:express_receipt_work_order, reimbursement: reimbursement, tracking_number: 'SF1001') }
      
      it 'skips duplicate records' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作意见', '操作时间'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00'], 1)
        
        result = nil
        expect { 
          result = service.import(spreadsheet) 
        }.not_to change(ExpressReceiptWorkOrder, :count)

        # Test passed successfully
        expect(result[:success]).to be true
        expect(result[:created]).to eq(0)
        expect(result[:skipped]).to eq(1)
      end
    end
    
    context 'with invalid data' do
      it 'handles errors' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单号', '操作意见', '操作时间'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '没有快递单号', '2025-01-01 10:00:00'], 1)
        
        result = service.import(spreadsheet)
        
        expect(result[:success]).to be true # 整体导入仍然成功
        expect(result[:created]).to eq(0)
        expect(result[:errors]).to eq(1)
        expect(result[:error_details].first).to include('无法找到有效的单号或从操作意见中提取快递单号')
      end
    end
    
    context 'with file error' do
      it 'handles missing file' do
        service = described_class.new(nil, admin_user)
        result = service.import
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('文件不存在')
      end
      
      it 'handles missing user' do
        service = described_class.new(file, nil)
        result = service.import
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include('导入用户不存在')
      end
      
      it 'handles file processing errors' do
        tempfile = double('tempfile', path: '/tmp/test.csv', to_path: '/tmp/test.csv')
        file = double('file', tempfile: tempfile)
        service = described_class.new(file, admin_user)
        allow(Roo::Spreadsheet).to receive(:open).and_raise(StandardError.new('测试错误'))
        
        result = service.import
        
        expect(result[:success]).to be false
        expect(result[:errors].first).to include('导入过程中发生错误')
      end
    end
  end
end