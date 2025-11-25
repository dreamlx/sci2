# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Express Receipt Work Orders Page', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'accessing express receipt work orders page' do
    it 'loads the page successfully' do
      visit '/admin/express_receipt_work_orders'
      expect(page).to have_content('快递收单工单')
      expect(page.status_code).to eq(200)
    end

    it 'displays the work orders table' do
      visit '/admin/express_receipt_work_orders'
      expect(page).to have_content('筛选')
      expect(page).to have_content('每页显示')
    end

    it 'shows new work order button' do
      visit '/admin/express_receipt_work_orders'
      expect(page).to have_link('新建快递收单工单')
    end
  end

  describe 'when there are no work orders' do
    it 'shows appropriate empty message' do
      visit '/admin/express_receipt_work_orders'
      expect(page).to have_content('没有数据')
    end
  end

  describe 'when there are work orders' do
    let!(:work_order) { create(:express_receipt_work_order) }

    it 'displays work order data' do
      visit '/admin/express_receipt_work_orders'
      expect(page).to have_content(work_order.express_company)
      expect(page).to have_content(work_order.tracking_number)
    end

    it 'allows viewing individual work order' do
      visit "/admin/express_receipt_work_orders/#{work_order.id}"
      expect(page).to have_content('快递收单工单详情')
      expect(page.status_code).to eq(200)
    end

    it 'allows editing work order' do
      visit "/admin/express_receipt_work_orders/#{work_order.id}/edit"
      expect(page).to have_content('编辑快递收单工单')
      expect(page.status_code).to eq(200)
    end
  end

  describe 'creating new work order' do
    it 'shows the new work order form' do
      visit '/admin/express_receipt_work_orders/new'
      expect(page).to have_content('新建快递收单工单')
      expect(page.status_code).to eq(200)
    end

    it 'displays required form fields' do
      visit '/admin/express_receipt_work_orders/new'
      expect(page).to have_field('express_receipt_work_order_express_company')
      expect(page).to have_field('express_receipt_work_order_tracking_number')
      expect(page).to have_field('express_receipt_work_order_reimbursement_id')
    end
  end

  describe 'work order actions' do
    let!(:work_order) { create(:express_receipt_work_order) }

    it 'shows available actions for pending work orders' do
      visit "/admin/express_receipt_work_orders/#{work_order.id}"
      if work_order.pending?
        expect(page).to have_content('开始处理')
      end
    end

    it 'shows status correctly' do
      visit "/admin/express_receipt_work_orders/#{work_order.id}"
      expect(page).to have_content(work_order.status)
    end
  end

  describe 'error handling' do
    it 'handles invalid work order IDs gracefully' do
      visit '/admin/express_receipt_work_orders/99999'
      expect(page.status_code).to eq(404)
    end

    it 'handles database errors gracefully' do
      allow(ExpressReceiptWorkOrder).to receive(:page).and_raise(StandardError.new('Database error'))

      visit '/admin/express_receipt_work_orders'
      expect(page.status_code).to eq(500)
    end
  end
end