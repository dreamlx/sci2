require 'rails_helper'

describe "Reimbursement Import Status Test" do
  let(:admin_user) { create(:admin_user) }
  let(:csv_content) do
    <<~CSV
      报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,收单状态,收单日期,提交报销日期,报销单状态,单据标签,报销单审核通过日期,审核通过人
      R202501001,测试报销单1,测试用户1,TEST001,测试公司,测试部门,100.00,已收单,2025-01-01,2025-01-01,已付款,,,
    CSV
  end

  it "sets imported reimbursements to pending status regardless of external status" do
    # Create a test file
    file = Tempfile.new(['test_reimbursements', '.csv'])
    file.write(csv_content)
    file.close

    # Create the service and import
    service = ReimbursementImportService.new(file, admin_user)
    result = service.import

    # Verify the result
    expect(result[:success]).to be true
    expect(result[:created]).to eq(1)
    
    # Find the imported reimbursement
    reimbursement = Reimbursement.find_by(invoice_number: 'R202501001')
    
    # Verify the status
    expect(reimbursement).not_to be_nil
    expect(reimbursement.external_status).to eq('已付款')
    expect(reimbursement.status).to eq('pending')
    
    # Clean up
    file.unlink
  end
end