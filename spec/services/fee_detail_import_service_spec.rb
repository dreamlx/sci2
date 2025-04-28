# spec/services/fee_detail_import_service_spec.rb
require 'rails_helper'
require 'tempfile'

RSpec.describe FeeDetailImportService do
  let(:admin_user) { create(:admin_user) }
  let(:file) do
    # Create a mock file object that responds to path and present?
    file = double('file')
    allow(file).to receive(:path).and_return('test_fee_details.csv')
    allow(file).to receive(:present?).and_return(true)
    file
  end
  let(:service) { described_class.new(file, admin_user) }

  describe '#import' do
    context 'with valid file and existing reimbursements' do
      let!(:reimbursement1) { create(:reimbursement, invoice_number: 'R202501001') }
      let!(:reimbursement2) { create(:reimbursement, invoice_number: 'R202501002') }
      
      it 'creates fee details' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '费用类型', '原始金额', '原始币种', '费用发生日期', '弹性字段11', '所属月', '首次提交日期'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '交通费', '100.00', 'CNY', '2025-01-01', '现金', '2025-01', '2025-01-02'], 1)
                                                      .and_yield(['R202501002', '餐费', '200.00', 'CNY', '2025-01-02', '信用卡', '2025-01', '2025-01-03'], 2)
                                                      .and_yield(['R999999', '办公用品', '300.00', 'CNY', '2025-01-03', '公司账户', '2025-01', '2025-01-04'], 3) # 不存在的报销单
        
        result = nil
        expect { 
          result = service.import(spreadsheet) 
        }.to change(FeeDetail, :count).by(2)

        # Test passed successfully
        expect(result[:success]).to be true
        expect(result[:imported]).to eq(2)
        expect(result[:skipped]).to eq(0)
        expect(result[:unmatched]).to eq(1)
        expect(result[:errors]).to eq(0)
      end
      
      it 'sets verification_status to pending' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '费用类型', '原始金额', '原始币种', '费用发生日期', '弹性字段11', '所属月', '首次提交日期'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '交通费', '100.00', 'CNY', '2025-01-01', '现金', '2025-01', '2025-01-02'], 1)
                                                      .and_yield(['R202501002', '餐费', '200.00', 'CNY', '2025-01-02', '信用卡', '2025-01', '2025-01-03'], 2)
        
        service.import(spreadsheet)
        
        fee_details = FeeDetail.all
        expect(fee_details.all? { |fd| fd.verification_status == 'pending' }).to be true
      end
      
      it 'tracks unmatched details' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '费用类型', '原始金额', '原始币种', '费用发生日期', '弹性字段11', '所属月', '首次提交日期'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R999999', '办公用品', '300.00', 'CNY', '2025-01-03', '公司账户', '2025-01', '2025-01-04'], 1) # 不存在的报销单
        
        result = service.import(spreadsheet)
        
        expect(result[:unmatched]).to eq(1)
        expect(result[:unmatched_details].first[:document_number]).to eq('R999999')
      end
    end
    
    context 'with duplicate records' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }
      let!(:existing_fee_detail) do
        create(:fee_detail,
               document_number: 'R202501001',
               fee_type: '交通费',
               amount: 100.00,
               fee_date: Date.parse('2025-01-01'))
      end
      
      it 'skips duplicate records' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')
        
        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '费用类型', '原始金额', '原始币种', '费用发生日期'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '交通费', '100.00', 'CNY', '2025-01-01'], 1)
        
        result = nil
        expect { 
          result = service.import(spreadsheet) 
        }.not_to change(FeeDetail, :count)

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
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '费用类型', '原始金额', '原始币种', '费用发生日期'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', nil, '100.00', 'CNY', '2025-01-01'], 1)
        
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