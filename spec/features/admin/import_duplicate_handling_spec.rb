require 'rails_helper'

RSpec.describe 'Import Duplicate Handling', type: :feature do
  let!(:admin_user) { create(:admin_user, :super_admin) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'Reimbursement Import' do
    let!(:existing_reimbursement) { create(:reimbursement, invoice_number: 'R202500001', document_name: '旧报销单') }

    it 'can access the import page without errors' do
      visit new_import_admin_reimbursements_path

      # First, just check we don't get the system error
      expect(page).not_to have_content('系统发生错误，请稍后重试')
    end

    it 'can access the import page' do
      visit new_import_admin_reimbursements_path

      # Check if we can see the import form title
      expect(page).to have_content('导入报销单')

      # Check if file input field exists (may be hidden)
      expect(page).to have_css('input[type="file"]', visible: :all)
    end

    it 'updates existing records instead of creating duplicates' do
      # Use the real data format based on actual Excel file
      csv_content = <<~CSV
        报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,收单状态,收单日期,关联申请单号,提交报销日期,记账日期,报销单状态,当前审批节点,当前审批人,报销单审核通过日期,审核通过人,报销金额（单据币种）,弹性字段2,当前审批节点转入时间,首次提交时间,单据标签,弹性字段8
        #{existing_reimbursement.invoice_number},更新后的报销单,更新申请人,NEW001,更新公司,更新部门,已收单,2025-04-01 10:00:00,EA08683924,2025-04-01 11:43:06,2025-04-15,审批中,财务审批,张三,2025-04-10 17:13:01,财务经理,1500.00,2025-03,,2025-04-01 14:48:21,连号; 暂挂,备注信息
      CSV

      # Use the real test data file
      reimbursements_csv_path = Rails.root.join('test_reimbursement_data.csv')
      File.write(reimbursements_csv_path, csv_content)

      # Import the file using fixture_file_upload
      visit new_import_admin_reimbursements_path

      # Debug: print page content to see what's available
      save_and_open_page if ENV['DEBUG'] == 'true'

      # Try different selectors for the file field
      file_field = find('input[type="file"]', visible: true)
      attach_file(file_field[:id], reimbursements_csv_path)
      click_button '导入'

      # Verify update instead of creating a new record
      expect(page).to have_content('导入成功')
      expect(page).to have_content('更新')

      # Check that the record was updated
      updated = Reimbursement.find_by(invoice_number: existing_reimbursement.invoice_number)
      expect(updated.document_name).to eq('更新后的报销单')
      expect(updated.applicant).to eq('更新申请人')
      # is_electronic field logic depends on the import service implementation

      # Check that no duplicate was created
      expect(Reimbursement.where(invoice_number: existing_reimbursement.invoice_number).count).to eq(1)

      # Clean up the test file
      File.delete(reimbursements_csv_path) if File.exist?(reimbursements_csv_path)
    end
  end

  describe 'Express Receipt Import' do
    let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202500002') }
    let!(:existing_work_order) do
      create(:express_receipt_work_order,
             reimbursement: reimbursement,
             tracking_number: 'SF1001',
             courier_name: '顺丰')
    end

    it 'skips duplicate records' do
      # Use the real data format based on actual Excel file analysis
      csv_content = <<~CSV
        报销单号,快递单号,快递公司,收单日期
        #{reimbursement.invoice_number},SF1001,顺丰快递,2025-04-01 10:00:00
        #{reimbursement.invoice_number},YT1002,圆通快递,2025-04-01 11:00:00
      CSV

      # Use the real test data file
      express_receipts_csv_path = Rails.root.join('test_express_receipt_data.csv')
      File.write(express_receipts_csv_path, csv_content)

      # Import the file using fixture_file_upload
      visit new_import_admin_express_receipt_work_orders_path
      attach_file('file', express_receipts_csv_path)
      click_button '导入'

      # Verify skipping duplicate
      expect(page).to have_content('导入成功')
      expect(page).to have_content('跳过')

      # Check that no duplicate was created
      expect(ExpressReceiptWorkOrder.where(reimbursement: reimbursement, tracking_number: 'SF1001').count).to eq(1)

      # Check that the original record was not updated
      work_order = ExpressReceiptWorkOrder.find_by(reimbursement: reimbursement, tracking_number: 'SF1001')
      expect(work_order.courier_name).to eq('顺丰')

      # Clean up the test file
      File.delete(express_receipts_csv_path) if File.exist?(express_receipts_csv_path)
    end
  end

  describe 'Fee Detail Import' do
    let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202500003') }
    let!(:existing_fee_detail) do
      create(:fee_detail,
             document_number: reimbursement.invoice_number,
             fee_type: '住宿费',
             amount: 500.00,
             fee_date: Date.parse('2025-04-01'),
             external_fee_id: 'FEE001') # Match the CSV fee ID
    end

    it 'skips duplicate records' do
      # Use the real data format based on actual fee detail CSV structure
      csv_content = <<~CSV
        所属月,费用类型,申请人名称,申请人工号,申请人公司,申请人部门,费用发生日期,原始金额,单据名称,报销单单号,关联申请单号,计划/预申请,产品,弹性字段11,弹性字段6(报销单),弹性字段7(报销单),费用id,首次提交日期,费用对应计划,费用关联申请单
        2025-04,住宿费,测试用户,TEST001,SPC,IBU-E-SH,2025-04-01 00:00:00,500.00,测试报销单,#{reimbursement.invoice_number},EA08683924,,,商务住宿,,,FEE001,2025-04-02 16:13:33,计划A,申请单B
        2025-04,餐饮费,测试用户,TEST001,SPC,IBU-E-SH,2025-04-02 00:00:00,300.00,测试报销单,#{reimbursement.invoice_number},EA08683924,,,客户招待,,,FEE002,2025-04-03 17:58:18,计划B,申请单C
      CSV

      # Use the real test data file
      fee_details_csv_path = Rails.root.join('test_fee_detail_data.csv')
      File.write(fee_details_csv_path, csv_content)

      # Import the file using fixture_file_upload with skip_existing option
      visit new_import_admin_fee_details_path
      attach_file('file', fee_details_csv_path)
      check('跳过已存在的记录（推荐用于大文件导入以提升速度）') # Enable skip_existing option
      click_button '导入'

      # Verify skipping duplicate
      expect(page).to have_content('导入成功')
      expect(page).to have_content('跳过')

      # Check that no duplicate was created
      count = FeeDetail.where(
        document_number: reimbursement.invoice_number,
        fee_type: '住宿费',
        amount: 500.00,
        fee_date: '2025-04-01'
      ).count
      expect(count).to eq(1)

      # Clean up the test file
      File.delete(fee_details_csv_path) if File.exist?(fee_details_csv_path)
    end
  end

  describe 'Operation History Import' do
    let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202500004', status: 'processing') }
    let!(:existing_operation) do
      create(:operation_history,
             document_number: reimbursement.invoice_number,
             operation_type: '审批',
             operation_time: DateTime.parse('2025-04-01 10:00:00').in_time_zone,
             operator: '审批人A',
             notes: '审批通过')
    end

    it 'skips duplicate records and updates reimbursement status' do
      # Create a test CSV file with a duplicate operation history
      csv_content = <<~CSV
        单据编号,操作类型,操作日期,操作人,操作意见
        #{reimbursement.invoice_number},审批,2025-04-01 10:00:00,审批人A,审批通过
      CSV

      # Create a test CSV file in spec/test_data
      operation_histories_csv_path = Rails.root.join('spec', 'test_data',
                                                     'test_operation_histories_import_duplicate.csv')
      File.write(operation_histories_csv_path, csv_content)

      # Reload reimbursement before import to ensure latest state
      reimbursement.reload

      # Stub the close! method and expect it to be called
      allow(reimbursement).to receive(:close!).and_call_original

      # Import the file using fixture_file_upload
      visit admin_imports_operation_histories_path
      attach_file('file', operation_histories_csv_path)
      click_button '导入'

      # Verify that close! was called
      expect(reimbursement).to have_received(:close!)

      # Verify skipping duplicate
      # Verify skipping duplicate
      expect(page).to have_content('导入成功')
      expect(page).to have_content('跳过')

      # Check that no duplicate was created
      count = OperationHistory.where(
        document_number: reimbursement.invoice_number,
        operation_type: '审批',
        operation_time: '2025-04-01 10:00:00',
        operator: '审批人A'
      ).count
      expect(count).to eq(1)

      # Check that reimbursement status was updated to closed
      reimbursement.reload
      expect(reimbursement.status).to eq('closed')

      # Clean up the test file
      File.delete(operation_histories_csv_path) if File.exist?(operation_histories_csv_path)
    end
  end
end
