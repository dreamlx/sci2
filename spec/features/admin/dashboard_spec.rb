require 'rails_helper'

RSpec.describe 'Dashboard', type: :feature do
  let!(:admin_user) { create(:admin_user) }
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
    it '显示报销单状态统计' do
      visit admin_dashboard_path
      expect(page).to have_content('报销单状态统计')
      expect(page).to have_content('待处理')
      expect(page).to have_content('处理中')
      expect(page).to have_content('等待完成')
      expect(page).to have_content('已关闭')

      # 创建不同状态的报销单来测试计数
      create(:reimbursement, status: 'processing')
      create(:reimbursement, status: 'waiting_completion')
      create(:reimbursement, status: 'closed')
      visit admin_dashboard_path

      expect(page).to have_content('待处理 1') # 初始创建的 reimbursement
      expect(page).to have_content('处理中 1')
      expect(page).to have_content('等待完成 1')
      expect(page).to have_content('已关闭 1')
    end

    it '显示待处理工单统计' do
      visit admin_dashboard_path
      expect(page).to have_content('待处理审核工单')
      expect(page).to have_content('待处理沟通工单')

      # 创建不同状态的工单来测试计数
      create(:audit_work_order, status: 'processing')
      create(:communication_work_order, :needs_communication, status: 'processing')
      visit admin_dashboard_path

      expect(page).to have_content('待处理审核工单 1') # 初始创建的 audit_work_order
      expect(page).to have_content('待处理沟通工单 1') # 初始创建的 communication_work_order
    end

    it '显示快速操作' do
      visit admin_dashboard_path
      expect(page).to have_content('快速操作')
      expect(page).to have_link('报销单管理')
      expect(page).to have_link('新建审核工单')
      expect(page).to have_link('新建沟通工单')
      expect(page).to have_link('导入报销单')
      expect(page).to have_link('导入费用明细')
      expect(page).to have_link('导入快递收单')
    end

    it '显示快速操作链接' do
      visit admin_dashboard_path
      expect(page).to have_content('快速操作')
      expect(page).to have_link('导入报销单')
      expect(page).to have_link('导入快递收单')
      expect(page).to have_link('导入费用明细')
      expect(page).to have_link('导入操作历史')
    end
  end
end
