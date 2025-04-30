require 'rails_helper'
require 'csv'

RSpec.describe "Full Workflow Integration Test", type: :model do
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

  describe "第一阶段：数据导入" do
    it "导入报销单数据" do
      # Create a mock file
      mock_file = double('file')
      allow(mock_file).to receive(:path).and_return('test_reimbursements.csv')
      allow(mock_file).to receive(:present?).and_return(true)
      
      # Create a mock spreadsheet
      spreadsheet = double('spreadsheet')
      
      # Mock the spreadsheet behavior
      allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门', '收单状态', '收单日期', '提交报销日期', '报销金额（单据币种）', '报销单状态'])
      
      # Mock the data rows
      rows = [
        ['R2025001', '差旅费报销', '李明', 'E001', '科技有限公司', '研发部', 'pending', nil, '2025-04-01', '1200.50', '待审批'],
        ['R2025002', '办公用品报销', '王芳', 'E002', '科技有限公司', '行政部', 'pending', nil, '2025-04-02', '458.75', '待审批'],
        ['R2025003', '会议费用报销', '张伟', 'E003', '科技有限公司', '市场部', 'pending', nil, '2025-04-03', '3500.00', '待审批'],
        ['R2025004', '培训费用报销', '刘洋', 'E004', '科技有限公司', '人力资源部', 'pending', nil, '2025-04-04', '2800.00', '待审批'],
        ['R2025005', '交通费报销', '赵静', 'E005', '科技有限公司', '财务部', 'pending', nil, '2025-04-05', '320.50', '待审批'],
        ['R2025006', '餐费报销', '陈明', 'E006', '科技有限公司', '销售部', 'pending', nil, '2025-04-06', '680.00', '待审批'],
        ['R2025007', '设备采购报销', '林华', 'E007', '科技有限公司', 'IT部', 'pending', nil, '2025-04-07', '12500.00', '待审批'],
        ['R2025008', '广告费用报销', '黄强', 'E008', '科技有限公司', '市场部', 'pending', nil, '2025-04-08', '8600.00', '待审批'],
        ['R2025009', '维修费用报销', '周丽', 'E009', '科技有限公司', '行政部', 'pending', nil, '2025-04-09', '1450.00', '待审批'],
        ['R2025010', '通讯费报销', '吴刚', 'E010', '科技有限公司', '研发部', 'pending', nil, '2025-04-10', '350.00', '待审批']
      ]
      
      # Setup each_with_index to yield each row with its index
      allow(spreadsheet).to receive(:each_with_index) do |&block|
        rows.each_with_index do |row, idx|
          block.call(row, idx + 1) # +1 because we're skipping the header row (index 0)
        end
      end

      expect {
        ReimbursementImportService.new(mock_file, admin_user).import(spreadsheet)
      }.to change(Reimbursement, :count).by(10)

      Reimbursement.all.each do |reimbursement|
        expect(reimbursement.status).to eq('pending')
      end
    end

    it "导入快递收单数据" do
      # First, import reimbursements as express receipts need to link to them
      # Create a mock file for reimbursements
      reimbursement_file = double('reimbursement_file')
      allow(reimbursement_file).to receive(:path).and_return('test_reimbursements.csv')
      allow(reimbursement_file).to receive(:present?).and_return(true)
      
      reimbursement_spreadsheet = double('reimbursement_spreadsheet')
      allow(reimbursement_spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(reimbursement_spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门', '收单状态', '收单日期', '提交报销日期', '报销金额（单据币种）', '报销单状态'])
      
      # Mock the data rows for reimbursements
      reimbursement_rows = [
        ['R2025001', '差旅费报销', '李明', 'E001', '科技有限公司', '研发部', 'pending', nil, '2025-04-01', '1200.50', '待审批'],
        ['R2025002', '办公用品报销', '王芳', 'E002', '科技有限公司', '行政部', 'pending', nil, '2025-04-02', '458.75', '待审批'],
        ['R2025003', '会议费用报销', '张伟', 'E003', '科技有限公司', '市场部', 'pending', nil, '2025-04-03', '3500.00', '待审批'],
        ['R2025004', '培训费用报销', '刘洋', 'E004', '科技有限公司', '人力资源部', 'pending', nil, '2025-04-04', '2800.00', '待审批'],
        ['R2025005', '交通费报销', '赵静', 'E005', '科技有限公司', '财务部', 'pending', nil, '2025-04-05', '320.50', '待审批'],
        ['R2025006', '餐费报销', '陈明', 'E006', '科技有限公司', '销售部', 'pending', nil, '2025-04-06', '680.00', '待审批'],
        ['R2025007', '设备采购报销', '林华', 'E007', '科技有限公司', 'IT部', 'pending', nil, '2025-04-07', '12500.00', '待审批'],
        ['R2025008', '广告费用报销', '黄强', 'E008', '科技有限公司', '市场部', 'pending', nil, '2025-04-08', '8600.00', '待审批'],
        ['R2025009', '维修费用报销', '周丽', 'E009', '科技有限公司', '行政部', 'pending', nil, '2025-04-09', '1450.00', '待审批'],
        ['R2025010', '通讯费报销', '吴刚', 'E010', '科技有限公司', '研发部', 'pending', nil, '2025-04-10', '350.00', '待审批']
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
      allow(express_receipt_spreadsheet).to receive(:row).with(1).and_return(['单号', '操作类型', '操作日期', '操作人', '操作意见'])
      
      # Mock the data rows for express receipts
      express_receipt_rows = [
        ['R2025001', '收单', '2025-04-11', '张经理', '快递单号: SF1234567890'],
        ['R2025002', '收单', '2025-04-11', '张经理', '快递单号: YT9876543210'],
        ['R2025003', '收单', '2025-04-12', '张经理', '快递单号: ZT1122334455'],
        ['R2025004', '收单', '2025-04-12', '张经理', '快递单号: JD5566778899'],
        ['R2025005', '收单', '2025-04-13', '张经理', '快递单号: SF2468135790'],
        ['R2025006', '收单', '2025-04-13', '张经理', '快递单号: YT1357924680'],
        ['R2025007', '收单', '2025-04-14', '张经理', '快递单号: ZT2468013579'],
        ['R2025008', '收单', '2025-04-14', '张经理', '快递单号: JD1324354657'],
        ['R2025009', '收单', '2025-04-15', '张经理', '快递单号: SF9876543210'],
        ['R2025010', '收单', '2025-04-15', '张经理', '快递单号: YT1234567890']
      ]
      
      allow(express_receipt_spreadsheet).to receive(:each_with_index) do |&block|
        express_receipt_rows.each_with_index do |row, idx|
          block.call(row, idx + 1)
        end
      end

      result = nil
      expect {
        result = ExpressReceiptImportService.new(express_receipt_file, admin_user).import(express_receipt_spreadsheet)
        puts "Express Receipt Import Result: #{result.inspect}"
      }.to change(ExpressReceiptWorkOrder, :count).by(10) # Express receipts create work orders

      # Verify ExpressReceiptWorkOrders are created and completed
      expect(ExpressReceiptWorkOrder.count).to eq(10)
      ExpressReceiptWorkOrder.all.each do |work_order|
        expect(work_order.status).to eq('completed')
        expect(work_order.creator).to eq(admin_user)
      end

      # Verify Reimbursement status is updated to processing
      Reimbursement.all.each do |reimbursement|
        expect(reimbursement.status).to eq('processing')
      end
    end

    it "导入费用明细数据" do
      # First, import reimbursements as fee details need to link to them
      # Create a mock file for reimbursements
      reimbursement_file = double('reimbursement_file')
      allow(reimbursement_file).to receive(:path).and_return('test_reimbursements.csv')
      allow(reimbursement_file).to receive(:present?).and_return(true)
      
      reimbursement_spreadsheet = double('reimbursement_spreadsheet')
      allow(reimbursement_spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(reimbursement_spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门', '收单状态', '收单日期', '提交报销日期', '报销金额（单据币种）', '报销单状态'])
      
      # Mock the data rows for reimbursements
      reimbursement_rows = [
        ['R2025001', '差旅费报销', '李明', 'E001', '科技有限公司', '研发部', 'pending', nil, '2025-04-01', '1200.50', '待审批'],
        ['R2025002', '办公用品报销', '王芳', 'E002', '科技有限公司', '行政部', 'pending', nil, '2025-04-02', '458.75', '待审批'],
        ['R2025003', '会议费用报销', '张伟', 'E003', '科技有限公司', '市场部', 'pending', nil, '2025-04-03', '3500.00', '待审批'],
        ['R2025004', '培训费用报销', '刘洋', 'E004', '科技有限公司', '人力资源部', 'pending', nil, '2025-04-04', '2800.00', '待审批'],
        ['R2025005', '交通费报销', '赵静', 'E005', '科技有限公司', '财务部', 'pending', nil, '2025-04-05', '320.50', '待审批'],
        ['R2025006', '餐费报销', '陈明', 'E006', '科技有限公司', '销售部', 'pending', nil, '2025-04-06', '680.00', '待审批'],
        ['R2025007', '设备采购报销', '林华', 'E007', '科技有限公司', 'IT部', 'pending', nil, '2025-04-07', '12500.00', '待审批'],
        ['R2025008', '广告费用报销', '黄强', 'E008', '科技有限公司', '市场部', 'pending', nil, '2025-04-08', '8600.00', '待审批'],
        ['R2025009', '维修费用报销', '周丽', 'E009', '科技有限公司', '行政部', 'pending', nil, '2025-04-09', '1450.00', '待审批'],
        ['R2025010', '通讯费报销', '吴刚', 'E010', '科技有限公司', '研发部', 'pending', nil, '2025-04-10', '350.00', '待审批']
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
      allow(fee_detail_spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '费用类型', '原始金额', '原始币种', '费用发生日期', '弹性字段11'])
      
      # Mock the data rows for fee details
      fee_detail_rows = [
        ['R2025001', '机票', '800.00', 'CNY', '2025-03-25', '信用卡'],
        ['R2025001', '住宿', '300.50', 'CNY', '2025-03-26', '信用卡'],
        ['R2025001', '餐费', '100.00', 'CNY', '2025-03-26', '现金'],
        ['R2025002', '打印纸', '158.75', 'CNY', '2025-03-30', '公司账户'],
        ['R2025002', '文具', '300.00', 'CNY', '2025-03-30', '公司账户'],
        ['R2025003', '场地租赁', '2500.00', 'CNY', '2025-03-15', '公司账户'],
        ['R2025003', '茶点', '1000.00', 'CNY', '2025-03-15', '现金'],
        ['R2025004', '培训费', '2800.00', 'CNY', '2025-03-20', '公司账户'],
        ['R2025005', '出租车', '120.50', 'CNY', '2025-04-01', '现金'],
        ['R2025005', '地铁', '200.00', 'CNY', '2025-04-02', '交通卡'],
        ['R2025006', '团队午餐', '680.00', 'CNY', '2025-04-03', '信用卡'],
        ['R2025007', '电脑', '8500.00', 'CNY', '2025-03-28', '公司账户'],
        ['R2025007', '显示器', '4000.00', 'CNY', '2025-03-28', '公司账户'],
        ['R2025008', '线上广告', '5600.00', 'CNY', '2025-03-25', '公司账户'],
        ['R2025008', '平面广告', '3000.00', 'CNY', '2025-03-26', '公司账户'],
        ['R2025009', '空调维修', '950.00', 'CNY', '2025-04-05', '现金'],
        ['R2025009', '门锁更换', '500.00', 'CNY', '2025-04-06', '现金'],
        ['R2025010', '手机费', '200.00', 'CNY', '2025-04-01', '信用卡'],
        ['R2025010', '宽带费', '150.00', 'CNY', '2025-04-01', '信用卡']
      ]
      
      allow(fee_detail_spreadsheet).to receive(:each_with_index) do |&block|
        fee_detail_rows.each_with_index do |row, idx|
          block.call(row, idx + 1)
        end
      end

      expect {
        FeeDetailImportService.new(fee_detail_file, admin_user).import(fee_detail_spreadsheet)
      }.to change(FeeDetail, :count).by(19)

      FeeDetail.all.each do |fee_detail|
        expect(fee_detail.verification_status).to eq('pending')
      end
    end

    it "导入操作历史数据" do
      # First, import reimbursements as operation histories need to link to them
      # Create a mock file for reimbursements
      reimbursement_file = double('reimbursement_file')
      allow(reimbursement_file).to receive(:path).and_return('test_reimbursements.csv')
      allow(reimbursement_file).to receive(:present?).and_return(true)
      
      reimbursement_spreadsheet = double('reimbursement_spreadsheet')
      allow(reimbursement_spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
      allow(reimbursement_spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门', '收单状态', '收单日期', '提交报销日期', '报销金额（单据币种）', '报销单状态'])
      
      # Mock the data rows for reimbursements
      reimbursement_rows = [
        ['R2025001', '差旅费报销', '李明', 'E001', '科技有限公司', '研发部', 'pending', nil, '2025-04-01', '1200.50', '待审批'],
        ['R2025002', '办公用品报销', '王芳', 'E002', '科技有限公司', '行政部', 'pending', nil, '2025-04-02', '458.75', '待审批'],
        ['R2025003', '会议费用报销', '张伟', 'E003', '科技有限公司', '市场部', 'pending', nil, '2025-04-03', '3500.00', '待审批'],
        ['R2025004', '培训费用报销', '刘洋', 'E004', '科技有限公司', '人力资源部', 'pending', nil, '2025-04-04', '2800.00', '待审批'],
        ['R2025005', '交通费报销', '赵静', 'E005', '科技有限公司', '财务部', 'pending', nil, '2025-04-05', '320.50', '待审批'],
        ['R2025006', '餐费报销', '陈明', 'E006', '科技有限公司', '销售部', 'pending', nil, '2025-04-06', '680.00', '待审批'],
        ['R2025007', '设备采购报销', '林华', 'E007', '科技有限公司', 'IT部', 'pending', nil, '2025-04-07', '12500.00', '待审批'],
        ['R2025008', '广告费用报销', '黄强', 'E008', '科技有限公司', '市场部', 'pending', nil, '2025-04-08', '8600.00', '待审批'],
        ['R2025009', '维修费用报销', '周丽', 'E009', '科技有限公司', '行政部', 'pending', nil, '2025-04-09', '1450.00', '待审批'],
        ['R2025010', '通讯费报销', '吴刚', 'E010', '科技有限公司', '研发部', 'pending', nil, '2025-04-10', '350.00', '待审批']
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
      allow(operation_history_spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作类型', '操作日期', '操作人', '操作意见'])
      
      # Mock the data rows for operation histories
      operation_history_rows = [
        ['R2025001', '提交', '2025-04-01', '李明', '请审批'],
        ['R2025002', '提交', '2025-04-02', '王芳', '请审批'],
        ['R2025003', '提交', '2025-04-03', '张伟', '请审批'],
        ['R2025004', '提交', '2025-04-04', '刘洋', '请审批'],
        ['R2025005', '提交', '2025-04-05', '赵静', '请审批'],
        ['R2025006', '提交', '2025-04-06', '陈明', '请审批'],
        ['R2025007', '提交', '2025-04-07', '林华', '请审批'],
        ['R2025008', '提交', '2025-04-08', '黄强', '请审批'],
        ['R2025009', '提交', '2025-04-09', '周丽', '请审批'],
        ['R2025010', '提交', '2025-04-10', '吴刚', '请审批']
      ]
      
      allow(operation_history_spreadsheet).to receive(:each_with_index) do |&block|
        operation_history_rows.each_with_index do |row, idx|
          block.call(row, idx + 1)
        end
      end

      expect {
        OperationHistoryImportService.new(operation_history_file, admin_user).import(operation_history_spreadsheet)
      }.to change(OperationHistory, :count).by(10)
    end
  end
end