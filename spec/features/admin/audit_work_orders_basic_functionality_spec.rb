# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Audit Work Orders Page', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'accessing audit work orders page' do
    it 'loads the page successfully' do
      visit '/admin/audit_work_orders'
      expect(page).to have_content('审核工单')
      expect(page.status_code).to eq(200)
    end

    it 'displays the work orders table' do
      visit '/admin/audit_work_orders'
      expect(page).to have_content('筛选')
      expect(page).to have_content('每页显示')
    end

    it 'shows new work order button' do
      visit '/admin/audit_work_orders'
      expect(page).to have_link('新建审核工单')
    end
  end

  describe 'when there are no work orders' do
    it 'shows appropriate empty message' do
      visit '/admin/audit_work_orders'
      expect(page).to have_content('没有数据')
    end
  end

  describe 'when there are work orders' do
    let!(:work_order) { create(:audit_work_order) }

    it 'displays work order data' do
      visit '/admin/audit_work_orders'
      expect(page).to have_content(work_order.reimbursement_id)
    end

    it 'allows viewing individual work order' do
      visit "/admin/audit_work_orders/#{work_order.id}"
      expect(page).to have_content('审核工单详情')
      expect(page.status_code).to eq(200)
    end

    it 'allows editing work order' do
      visit "/admin/audit_work_orders/#{work_order.id}/edit"
      expect(page).to have_content('编辑审核工单')
      expect(page.status_code).to eq(200)
    end
  end

  describe 'creating new work order' do
    it 'shows the new work order form' do
      visit '/admin/audit_work_orders/new'
      expect(page).to have_content('新建审核工单')
      expect(page.status_code).to eq(200)
    end

    it 'displays required form fields' do
      visit '/admin/audit_work_orders/new'
      expect(page).to have_field('audit_work_order_reimbursement_id')
      expect(page).to have_field('audit_work_order_auditor_id')
    end

    it 'displays virtual attribute fields' do
      visit '/admin/audit_work_orders/new'
      expect(page).to have_field('audit_work_order_remark')
      expect(page).to have_field('audit_work_order_problem_description')
    end
  end

  describe 'work order actions' do
    let!(:work_order) { create(:audit_work_order) }

    it 'shows available actions for pending work orders' do
      visit "/admin/audit_work_orders/#{work_order.id}"
      if work_order.pending?
        expect(page).to have_content('开始处理')
      end
    end

    it 'shows status correctly' do
      visit "/admin/audit_work_orders/#{work_order.id}"
      expect(page).to have_content(work_order.status)
    end

    it 'displays audit-specific information' do
      visit "/admin/audit_work_orders/#{work_order.id}"
      expect(page).to have_content('审核信息')
    end
  end

  describe 'problem handling' do
    let!(:work_order) { create(:audit_work_order) }
    let!(:problem_type) { create(:problem_type) }

    it 'allows associating problem types' do
      visit "/admin/audit_work_orders/#{work_order.id}/edit"
      expect(page).to have_content('问题类型')
    end
  end

  describe 'error handling' do
    it 'handles invalid work order IDs gracefully' do
      visit '/admin/audit_work_orders/99999'
      expect(page.status_code).to eq(404)
    end

    it 'handles database errors gracefully' do
      allow(AuditWorkOrder).to receive(:page).and_raise(StandardError.new('Database error'))

      visit '/admin/audit_work_orders'
      expect(page.status_code).to eq(500)
    end
  end
end