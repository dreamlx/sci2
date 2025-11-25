require 'rails_helper'

RSpec.describe 'Dashboard', type: :feature do
  let!(:admin_user) { create(:admin_user, :super_admin) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'pending') }
  let!(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, status: 'pending') }
  let!(:fee_detail) do
    create(:fee_detail, document_number: reimbursement.invoice_number, verification_status: 'verified')
  end

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe '仪表盘页面' do
    it '显示系统概览' do
      visit admin_dashboard_path
      expect(page).to have_content('系统概览')
      expect(page).to have_content('今日导入报销单')
      expect(page).to have_content('今日导入快递收单')
      expect(page).to have_content('今日导入费用明细')
      expect(page).to have_content('今日导入操作历史记录')
    end

    it '显示系统操作' do
      visit admin_dashboard_path
      expect(page).to have_content('系统操作')
      expect(page).to have_content('导入报销单')
      expect(page).to have_content('导入费用明细')
      expect(page).to have_content('导入快递收单')
      expect(page).to have_content('导入操作历史')
    end

    it '显示分配的报销单' do
      visit admin_dashboard_path
      expect(page).to have_content('今日分配给我的报销单')
      expect(page).to have_content('今日未分配的报销单')
    end
  end
end
