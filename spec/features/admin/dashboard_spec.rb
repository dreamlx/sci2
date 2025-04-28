require 'rails_helper'

RSpec.describe "Dashboard", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'pending') }
  let!(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, status: 'pending') }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number, verification_status: 'verified') }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe "仪表盘页面" do
    it "显示系统概览" do
      visit admin_dashboard_path
      expect(page).to have_content("系统概览")
      expect(page).to have_content("报销单总数")
      expect(page).to have_content("工单总数")
      expect(page).to have_content("费用明细总数")
      expect(page).to have_content("已验证费用明细")
    end

    it "显示待处理审核工单" do
      visit admin_dashboard_path
      expect(page).to have_content("待处理审核工单")
      expect(page).to have_link(audit_work_order.id.to_s)
      expect(page).to have_link(reimbursement.invoice_number)
    end

    it "显示待处理沟通工单" do
      visit admin_dashboard_path
      expect(page).to have_content("待处理沟通工单")
      expect(page).to have_link(communication_work_order.id.to_s)
      expect(page).to have_link(reimbursement.invoice_number)
    end

    it "显示快速操作" do
      visit admin_dashboard_path
      expect(page).to have_content("快速操作")
      expect(page).to have_link("报销单管理")
      expect(page).to have_link("新建审核工单")
      expect(page).to have_link("新建沟通工单")
      expect(page).to have_link("导入报销单")
      expect(page).to have_link("导入费用明细")
      expect(page).to have_link("导入快递收单")
    end

    it "显示最近验证的费用明细" do
      visit admin_dashboard_path
      expect(page).to have_content("最近验证的费用明细")
      expect(page).to have_link(fee_detail.id.to_s)
      expect(page).to have_content(fee_detail.fee_type)
    end
  end
end