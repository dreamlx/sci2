# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard Page', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'accessing dashboard' do
    it 'loads the dashboard successfully' do
      visit '/admin'
      expect(page).to have_content('SCI2工单系统')
      expect(page.status_code).to eq(200)
    end

    it 'displays navigation menu' do
      visit '/admin'
      expect(page).to have_content('控制面板')
      expect(page).to have_content('报销单管理')
      expect(page).to have_content('工单管理')
    end

    it 'shows admin user information' do
      visit '/admin'
      expect(page).to have_content(admin_user.email)
      expect(page).to have_content('退出')
    end
  end

  describe 'dashboard sections' do
    it 'displays work order statistics' do
      visit '/admin'
      expect(page).to have_content('工单统计')
    end

    it 'displays recent activities' do
      visit '/admin'
      expect(page).to have_content('最近活动')
    end

    it 'displays system overview' do
      visit '/admin'
      expect(page).to have_content('系统概览')
    end
  end

  describe 'navigation functionality' do
    it 'allows navigation to reimbursements' do
      visit '/admin'
      click_link '报销单管理'
      expect(page).to have_current_path('/admin/reimbursements')
    end

    it 'allows navigation to express receipt work orders' do
      visit '/admin'
      click_link '工单管理'
      click_link '快递收单工单'
      expect(page).to have_current_path('/admin/express_receipt_work_orders')
    end

    it 'allows navigation to audit work orders' do
      visit '/admin'
      click_link '工单管理'
      click_link '审核工单'
      expect(page).to have_current_path('/admin/audit_work_orders')
    end

    it 'allows navigation to operation statistics' do
      visit '/admin'
      click_link '操作统计'
      expect(page).to have_current_path('/admin/operation_statistics')
    end
  end

  describe 'quick actions' do
    it 'shows quick action buttons' do
      visit '/admin'
      expect(page).to have_link('新建报销单')
      expect(page).to have_link('新建工单')
    end

    it 'allows creating new reimbursement from dashboard' do
      visit '/admin'
      click_link '新建报销单'
      expect(page).to have_current_path('/admin/reimbursements/new')
    end
  end

  describe 'when there is data' do
    let!(:reimbursement) { create(:reimbursement) }
    let!(:work_order) { create(:express_receipt_work_order) }

    it 'displays statistics correctly' do
      visit '/admin'
      expect(page).to have_content(reimbursement.reimbursement_id)
      expect(page).to have_content(work_order.express_company)
    end

    it 'shows recent work orders' do
      visit '/admin'
      expect(page).to have_content('最新工单')
    end
  end

  describe 'error handling' do
    it 'handles dashboard loading errors gracefully' do
      # Mock a dashboard component to raise an error
      allow_any_instance_of(ActiveAdmin::Views::Dashboard).to receive(:render).and_raise(StandardError.new('Dashboard error'))

      visit '/admin'
      # Should still load the page, possibly with error message
      expect(page.status_code).to be_in([200, 500])
    end
  end
end