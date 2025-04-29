require 'rails_helper'

RSpec.describe "Import Duplicate Handling", type: :feature do
  let!(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe "Reimbursement Import" do
    let!(:existing_reimbursement) { create(:reimbursement, invoice_number: "R202500001", document_name: "旧报销单") }
    
    it "updates existing records instead of creating duplicates" do
      # Create a test CSV file with a duplicate invoice_number
      csv_content = <<~CSV
        单号,单据名称,申请人,申请人ID,公司,部门,金额,收单状态,外部状态,收单日期,提交日期,电子发票,审批日期,审批人
        #{existing_reimbursement.invoice_number},新报销单,新申请人,NEW001,新公司,新部门,1000.00,pending,审批中,,2025-04-01,true,2025-04-15,新审批人
      CSV
      
      file = Tempfile.new(['test_reimbursements', '.csv'])
      file.write(csv_content)
      file.close
      
      # Import the file
      visit new_import_admin_reimbursements_path
      attach_file('file', file.path)
      click_button "导入"
      
      # Verify update instead of creating a new record
      expect(page).to have_content("导入成功")
      expect(page).to have_content("更新")
      
      # Check that the record was updated
      updated = Reimbursement.find_by(invoice_number: existing_reimbursement.invoice_number)
      expect(updated.document_name).to eq("新报销单")
      expect(updated.applicant).to eq("新申请人")
      expect(updated.is_electronic).to eq(true)
      
      # Check that no duplicate was created
      expect(Reimbursement.where(invoice_number: existing_reimbursement.invoice_number).count).to eq(1)
      
      file.unlink
    end
  end

  describe "Express Receipt Import" do
    let!(:reimbursement) { create(:reimbursement, invoice_number: "R202500002") }
    let!(:existing_work_order) do
      create(:express_receipt_work_order,
             reimbursement: reimbursement,
             tracking_number: "SF1001",
             courier_name: "顺丰")
    end
    
    it "skips duplicate records" do
      # Create a test CSV file with a duplicate tracking_number for the same reimbursement
      csv_content = <<~CSV
        单号,操作意见,操作时间,操作人
        #{reimbursement.invoice_number},快递单号: SF1001 快递公司: 新快递,2025-04-01 10:00:00,测试用户
      CSV
      
      file = Tempfile.new(['test_express_receipts', '.csv'])
      file.write(csv_content)
      file.close
      
      # Import the file
      visit new_import_admin_express_receipt_work_orders_path
      attach_file('file', file.path)
      click_button "导入"
      
      # Verify skipping duplicate
      expect(page).to have_content("导入成功")
      expect(page).to have_content("跳过")
      
      # Check that no duplicate was created
      expect(ExpressReceiptWorkOrder.where(reimbursement: reimbursement, tracking_number: "SF1001").count).to eq(1)
      
      # Check that the original record was not updated
      work_order = ExpressReceiptWorkOrder.find_by(reimbursement: reimbursement, tracking_number: "SF1001")
      expect(work_order.courier_name).to eq("顺丰")
      
      file.unlink
    end
  end

  describe "Fee Detail Import" do
    let!(:reimbursement) { create(:reimbursement, invoice_number: "R202500003") }
    let!(:existing_fee_detail) do
      create(:fee_detail,
             document_number: reimbursement.invoice_number,
             fee_type: "住宿费",
             amount: 500.00,
             fee_date: "2025-04-01")
    end
    
    it "skips duplicate records" do
      # Create a test CSV file with a duplicate fee detail
      csv_content = <<~CSV
        单号,费用类型,金额,币种,费用日期,支付方式,备注
        #{reimbursement.invoice_number},住宿费,500.00,CNY,2025-04-01,现金,重复记录
      CSV
      
      file = Tempfile.new(['test_fee_details', '.csv'])
      file.write(csv_content)
      file.close
      
      # Import the file
      visit new_import_admin_fee_details_path
      attach_file('file', file.path)
      click_button "导入"
      
      # Verify skipping duplicate
      expect(page).to have_content("导入成功")
      expect(page).to have_content("跳过")
      
      # Check that no duplicate was created
      count = FeeDetail.where(
        document_number: reimbursement.invoice_number,
        fee_type: "住宿费",
        amount: 500.00,
        fee_date: "2025-04-01"
      ).count
      expect(count).to eq(1)
      
      file.unlink
    end
  end

  describe "Operation History Import" do
    let!(:reimbursement) { create(:reimbursement, invoice_number: "R202500004", status: "waiting_completion") }
    let!(:existing_operation) do
      create(:operation_history,
             document_number: reimbursement.invoice_number,
             operation_type: "审批",
             operation_time: "2025-04-01 10:00:00",
             operator: "审批人A",
             notes: "审批通过")
    end
    
    it "skips duplicate records and updates reimbursement status" do
      # Create a test CSV file with a duplicate operation history
      csv_content = <<~CSV
        单号,操作类型,操作时间,操作人,备注
        #{reimbursement.invoice_number},审批,2025-04-01 10:00:00,审批人A,审批通过
      CSV
      
      file = Tempfile.new(['test_operation_histories', '.csv'])
      file.write(csv_content)
      file.close
      
      # Import the file
      visit new_import_admin_operation_histories_path
      attach_file('file', file.path)
      click_button "导入"
      
      # Verify skipping duplicate
      expect(page).to have_content("导入成功")
      expect(page).to have_content("跳过")
      
      # Check that no duplicate was created
      count = OperationHistory.where(
        document_number: reimbursement.invoice_number,
        operation_type: "审批",
        operation_time: "2025-04-01 10:00:00",
        operator: "审批人A"
      ).count
      expect(count).to eq(1)
      
      # Check that reimbursement status was updated to closed
      reimbursement.reload
      expect(reimbursement.status).to eq("closed")
      
      file.unlink
    end
  end
end