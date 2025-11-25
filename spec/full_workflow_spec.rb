require 'rails_helper'
require 'csv'
require 'rack/test'

RSpec.describe 'Full Workflow Integration Test', type: :model do
  include ActiveJob::TestHelper

  let!(:admin_user) { create(:admin_user, email: 'zhangjingli@example.com', password: 'password') }

  before do
    # Ensure the database is clean before each test
    Reimbursement.destroy_all
    ExpressReceiptWorkOrder.destroy_all
    AuditWorkOrder.destroy_all
    CommunicationWorkOrder.destroy_all
    FeeDetail.destroy_all
    OperationHistory.destroy_all
    FeeDetailSelection.destroy_all
    WorkOrderStatusChange.destroy_all

    # Set Current.admin_user for callbacks
    Current.admin_user = admin_user
  end

  describe '第一阶段：数据导入' do
    it '导入报销单数据' do
      # Use real file upload with Rack::Test::UploadedFile
      file_path = Rails.root.join('spec', 'fixtures', 'files', 'test_reimbursements.csv')
      file = Rack::Test::UploadedFile.new(file_path, 'text/csv')

      # Create a mock spreadsheet
      spreadsheet = double('spreadsheet')

      # Mock the spreadsheet behavior
      allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
                                                              '收单状态', '收单日期', '提交报销日期', '报销金额（单据币种）', '报销单状态'])

      # Mock the data rows
      rows = [
        ['ER14228251', '报销单1', '申请人1', 'E001', '科技有限公司', '部门1', 'pending', nil, '2025-04-01', '150', '待审批'],
        ['ER14228252', '报销单2', '申请人2', 'E002', '科技有限公司', '部门2', 'pending', nil, '2025-04-02', '200', '待审批'],
        ['ER14228253', '报销单3', '申请人3', 'E003', '科技有限公司', '部门3', 'pending', nil, '2025-04-03', '250', '待审批'],
        ['ER14228254', '报销单4', '申请人4', 'E004', '科技有限公司', '部门4', 'pending', nil, '2025-04-04', '300', '待审批'],
        ['ER14228255', '报销单5', '申请人5', 'E005', '科技有限公司', '部门5', 'pending', nil, '2025-04-05', '350', '待审批']
      ]

      # Setup each_with_index to yield each row with its index
      allow(spreadsheet).to receive(:each_with_index) do |&block|
        rows.each_with_index do |row, idx|
          block.call(row, idx + 1) # +1 because we're skipping the header row (index 0)
        end
      end

      expect do
        ReimbursementImportService.new(file, admin_user).import(spreadsheet)
      end.to change(Reimbursement, :count).by(5)

      Reimbursement.all.each do |reimbursement|
        expect(reimbursement.status).to eq('pending')
      end
    end

    it '导入快递收单数据' do
      # First, import reimbursements as express receipts need to link to them
      # Create a mock file for reimbursements
      reimbursement_file = double('reimbursement_file')
      allow(reimbursement_file).to receive(:path).and_return('test_reimbursements.csv')
      allow(reimbursement_file).to receive(:present?).and_return(true)

      reimbursement_spreadsheet = double('reimbursement_spreadsheet')
      allow(reimbursement_spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(reimbursement_spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号',
                                                                            '申请人公司', '申请人部门', '收单状态', '收单日期', '提交报销日期', '报销金额（单据币种）', '报销单状态'])

      # Mock the data rows for reimbursements
      reimbursement_rows = [
        ['ER14228251', '报销单1', '申请人1', 'E001', '科技有限公司', '部门1', 'pending', nil, '2025-04-01', '150', '待审批'],
        ['ER14228252', '报销单2', '申请人2', 'E002', '科技有限公司', '部门2', 'pending', nil, '2025-04-02', '200', '待审批'],
        ['ER14228253', '报销单3', '申请人3', 'E003', '科技有限公司', '部门3', 'pending', nil, '2025-04-03', '250', '待审批'],
        ['ER14228254', '报销单4', '申请人4', 'E004', '科技有限公司', '部门4', 'pending', nil, '2025-04-04', '300', '待审批'],
        ['ER14228255', '报销单5', '申请人5', 'E005', '科技有限公司', '部门5', 'pending', nil, '2025-04-05', '350', '待审批']
      ]

      allow(reimbursement_spreadsheet).to receive(:each_with_index) do |&block|
        reimbursement_rows.each_with_index do |row, idx|
          block.call(row, idx + 1)
        end
      end

      ReimbursementImportService.new(reimbursement_file, admin_user).import(reimbursement_spreadsheet)

      # Create a mock file for express receipts
      express_receipt_file = double('express_receipt_file')
      allow(express_receipt_file).to receive(:path).and_return('test_express_receipts.csv')
      allow(express_receipt_file).to receive(:present?).and_return(true)

      # Create a mock spreadsheet for express receipts
      express_receipt_spreadsheet = double('express_receipt_spreadsheet')

      # Mock the spreadsheet behavior
      allow(express_receipt_spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(express_receipt_spreadsheet).to receive(:row).with(1).and_return(%w[单据编号 操作类型 操作日期 操作人 操作意见])

      # Mock the data rows for express receipts
      express_receipt_rows = [
        ['ER14228251', '收单', '2025-04-11', '张经理', '快递单号：SF1001'],
        ['ER14228252', '收单', '2025-04-11', '张经理', '快递单号：SF1002'],
        ['ER14228253', '收单', '2025-04-12', '张经理', '快递单号：SF1003'],
        ['ER14228254', '收单', '2025-04-12', '张经理', '快递单号：SF1004'],
        ['ER14228255', '收单', '2025-04-13', '张经理', '快递单号：SF1005']
      ]

      allow(express_receipt_spreadsheet).to receive(:each_with_index) do |&block|
        express_receipt_rows.each_with_index do |row, idx|
          block.call(row, idx + 1)
        end
      end

      result = nil
      # Express receipts create work orders
      expect do
        result = UnifiedExpressReceiptImportService.new(express_receipt_file,
                                                 admin_user).import(express_receipt_spreadsheet)
        puts "Express Receipt Import Result: #{result.inspect}"
      end.to change(ExpressReceiptWorkOrder, :count).by(5)
      # Verify ExpressReceiptWorkOrders are created and completed
      expect(ExpressReceiptWorkOrder.count).to eq(5)
      ExpressReceiptWorkOrder.all.each do |work_order|
        expect(work_order.status).to eq('completed')
        expect(work_order.creator).to eq(admin_user)
      end

      # Verify Reimbursement receipt status is updated but internal status remains unchanged
      Reimbursement.all.each do |reimbursement|
        expect(reimbursement.receipt_status).to eq('received')
        expect(reimbursement.status).to eq('pending') # 根据新需求，导入快递收单不改变报销单内部状态
      end
    end

    it '导入费用明细数据' do
      # First, import reimbursements as fee details need to link to them
      # Create a mock file for reimbursements
      reimbursement_file = double('reimbursement_file')
      allow(reimbursement_file).to receive(:path).and_return('test_reimbursements.csv')
      allow(reimbursement_file).to receive(:present?).and_return(true)

      reimbursement_spreadsheet = double('reimbursement_spreadsheet')
      allow(reimbursement_spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(reimbursement_spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号',
                                                                            '申请人公司', '申请人部门', '收单状态', '收单日期', '提交报销日期', '报销金额（单据币种）', '报销单状态'])

      # Mock the data rows for reimbursements
      reimbursement_rows = [
        ['ER14228251', '报销单1', '申请人1', 'E001', '科技有限公司', '部门1', 'pending', nil, '2025-04-01', '150', '待审批'],
        ['ER14228252', '报销单2', '申请人2', 'E002', '科技有限公司', '部门2', 'pending', nil, '2025-04-02', '200', '待审批'],
        ['ER14228253', '报销单3', '申请人3', 'E003', '科技有限公司', '部门3', 'pending', nil, '2025-04-03', '250', '待审批'],
        ['ER14228254', '报销单4', '申请人4', 'E004', '科技有限公司', '部门4', 'pending', nil, '2025-04-04', '300', '待审批'],
        ['ER14228255', '报销单5', '申请人5', 'E005', '科技有限公司', '部门5', 'pending', nil, '2025-04-05', '350', '待审批']
      ]

      allow(reimbursement_spreadsheet).to receive(:each_with_index) do |&block|
        reimbursement_rows.each_with_index do |row, idx|
          block.call(row, idx + 1)
        end
      end

      ReimbursementImportService.new(reimbursement_file, admin_user).import(reimbursement_spreadsheet)

      # Create a mock file for fee details
      fee_detail_file = double('fee_detail_file')
      allow(fee_detail_file).to receive(:path).and_return('test_fee_details.csv')
      allow(fee_detail_file).to receive(:present?).and_return(true)

      # Create a mock spreadsheet for fee details
      fee_detail_spreadsheet = double('fee_detail_spreadsheet')

      # Mock the spreadsheet behavior
      allow(fee_detail_spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(fee_detail_spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用类型 原始金额 原始币种 费用发生日期
                                                                           弹性字段11])

      # Mock the data rows for fee details
      fee_detail_rows = [
        ['ER14228251', '费用类型1', '110', 'CNY', '2025-04-01', '支付方式A'],
        ['ER14228252', '费用类型2', '120', 'CNY', '2025-04-02', '支付方式A'],
        ['ER14228253', '费用类型3', '130', 'CNY', '2025-04-03', '支付方式A'],
        ['ER14228254', '费用类型4', '140', 'CNY', '2025-04-04', '支付方式A'],
        ['ER14228255', '费用类型5A', '150.0', 'CNY', '2025-04-05', '支付方式A'],
        ['ER14228255', '费用类型5B', '200.0', 'CNY', '2025-04-05', '支付方式B']
      ]

      allow(fee_detail_spreadsheet).to receive(:each_with_index) do |&block|
        fee_detail_rows.each_with_index do |row, idx|
          block.call(row, idx + 1)
        end
      end

      expect do
        FeeDetailImportService.new(fee_detail_file, admin_user).import(fee_detail_spreadsheet)
      end.to change(FeeDetail, :count).by(6)

      FeeDetail.all.each do |fee_detail|
        expect(fee_detail.verification_status).to eq('pending')
      end
    end

    it '导入操作历史数据' do
      # First, import reimbursements as operation histories need to link to them
      # Create a mock file for reimbursements
      reimbursement_file = double('reimbursement_file')
      allow(reimbursement_file).to receive(:path).and_return('test_reimbursements.csv')
      allow(reimbursement_file).to receive(:present?).and_return(true)

      reimbursement_spreadsheet = double('reimbursement_spreadsheet')
      allow(reimbursement_spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(reimbursement_spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号',
                                                                            '申请人公司', '申请人部门', '收单状态', '收单日期', '提交报销日期', '报销金额（单据币种）', '报销单状态'])

      # Mock the data rows for reimbursements
      reimbursement_rows = [
        ['ER14228251', '报销单1', '申请人1', 'E001', '科技有限公司', '部门1', 'pending', nil, '2025-04-01', '150', '待审批'],
        ['ER14228252', '报销单2', '申请人2', 'E002', '科技有限公司', '部门2', 'pending', nil, '2025-04-02', '200', '待审批'],
        ['ER14228253', '报销单3', '申请人3', 'E003', '科技有限公司', '部门3', 'pending', nil, '2025-04-03', '250', '待审批'],
        ['ER14228254', '报销单4', '申请人4', 'E004', '科技有限公司', '部门4', 'pending', nil, '2025-04-04', '300', '待审批'],
        ['ER14228255', '报销单5', '申请人5', 'E005', '科技有限公司', '部门5', 'pending', nil, '2025-04-05', '350', '待审批']
      ]

      allow(reimbursement_spreadsheet).to receive(:each_with_index) do |&block|
        reimbursement_rows.each_with_index do |row, idx|
          block.call(row, idx + 1)
        end
      end

      ReimbursementImportService.new(reimbursement_file, admin_user).import(reimbursement_spreadsheet)

      # Create a mock file for operation histories
      operation_history_file = double('operation_history_file')
      allow(operation_history_file).to receive(:path).and_return('test_operation_histories.csv')
      allow(operation_history_file).to receive(:present?).and_return(true)

      # Create a mock spreadsheet for operation histories
      operation_history_spreadsheet = double('operation_history_spreadsheet')

      # Mock the spreadsheet behavior
      allow(operation_history_spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(operation_history_spreadsheet).to receive(:row).with(1).and_return(%w[单据编号 操作类型 操作日期 操作人 操作意见])

      # Mock the data rows for operation histories
      operation_history_rows = [
        %w[ER14228251 提交 2025-04-01 申请人1 请审批],
        %w[ER14228252 提交 2025-04-02 申请人2 请审批],
        %w[ER14228253 提交 2025-04-03 申请人3 请审批],
        %w[ER14228254 提交 2025-04-04 申请人4 请审批],
        %w[ER14228255 提交 2025-04-05 申请人5 请审批]
      ]

      allow(operation_history_spreadsheet).to receive(:each_with_index) do |&block|
        operation_history_rows.each_with_index do |row, idx|
          block.call(row, idx + 1)
        end
      end

      expect do
        OperationHistoryImportService.new(operation_history_file, admin_user).import(operation_history_spreadsheet)
      end.to change(OperationHistory, :count).by(5)
    end
  end
end