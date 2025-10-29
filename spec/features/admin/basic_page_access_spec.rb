# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Basic Page Access Tests', type: :feature do
  let(:admin_user) { create(:admin_user, role: 'super_admin') }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'admin pages basic access' do
    it 'can access dashboard' do
      visit '/admin'
      expect(page).to have_content('SCI2工单系统')
      expect(page.status_code).to eq(200)
    end

    it 'can access admin users page' do
      visit '/admin/admin_users'
      expect(page).to have_content('管理员用户')
      expect(page.status_code).to eq(200)
    end

    it 'can access reimbursements page' do
      visit '/admin/reimbursements'
      expect(page).to have_content('报销单')
      expect(page.status_code).to eq(200)
    end

    it 'can access express receipt work orders page' do
      visit '/admin/express_receipt_work_orders'
      expect(page).to have_content('快递收单工单')
      expect(page.status_code).to eq(200)
    end

    it 'can access communication work orders page' do
      visit '/admin/communication_work_orders'
      expect(page).to have_content('沟通工单')
      expect(page.status_code).to eq(200)
    end

    it 'can access audit work orders page' do
      visit '/admin/audit_work_orders'
      expect(page).to have_content('审核工单')
      expect(page.status_code).to eq(200)
    end

    it 'can access operation histories page' do
      visit '/admin/operation_histories'
      expect(page).to have_content('操作历史')
      expect(page.status_code).to eq(200)
    end

    it 'can access operation statistics page' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('操作统计')
      expect(page.status_code).to eq(200)
    end

    it 'can access fee details page' do
      visit '/admin/fee_details'
      expect(page).to have_content('费用明细')
      expect(page.status_code).to eq(200)
    end

    it 'can access problem types page' do
      visit '/admin/problem_types'
      expect(page).to have_content('Problem Types')
      expect(page.status_code).to eq(200)
    end

    it 'can access imports page' do
      visit '/admin/imports'
      expect(page.status_code).to eq(200)
    end
  end

  describe 'error handling' do
    it 'handles non-existent pages gracefully' do
      visit '/admin/nonexistent_page'
      expect(page.status_code).to eq(404)
    end

    it 'handles invalid record access gracefully' do
      visit '/admin/reimbursements/99999'
      expect(page.status_code).to eq(404)
    end
  end

  describe 'navigation consistency' do
    it 'shows consistent navigation across pages' do
      pages = [
        '/admin',
        '/admin/admin_users',
        '/admin/reimbursements',
        '/admin/express_receipt_work_orders'
      ]

      pages.each do |page_url|
        visit page_url
        expect(page).to have_content('SCI2工单系统')
        expect(page).to have_content('报销单管理')
        expect(page).to have_content('工单管理')
      end
    end
  end

  describe 'user session management' do
    it 'maintains login across multiple pages' do
      visit '/admin'
      expect(page).to have_content('退出')

      visit '/admin/admin_users'
      expect(page).to have_content('退出')

      visit '/admin/reimbursements'
      expect(page).to have_content('退出')
    end

    it 'shows user info in navigation' do
      visit '/admin'
      expect(page).to have_content('管理员用户')
      expect(page).to have_content('退出')
    end
  end
end