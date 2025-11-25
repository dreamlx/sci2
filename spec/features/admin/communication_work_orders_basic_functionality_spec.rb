# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Communication Work Orders Page', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'accessing communication work orders page' do
    it 'loads the page successfully' do
      visit '/admin/communication_work_orders'
      expect(page).to have_content('沟通工单')
      expect(page.status_code).to eq(200)
    end

    it 'displays the work orders table' do
      visit '/admin/communication_work_orders'
      expect(page).to have_content('筛选')
      expect(page).to have_content('每页显示')
    end

    it 'shows new work order button' do
      visit '/admin/communication_work_orders'
      expect(page).to have_link('新建沟通工单')
    end
  end

  describe 'when there are no work orders' do
    it 'shows appropriate empty message' do
      visit '/admin/communication_work_orders'
      expect(page).to have_content('没有数据')
    end
  end

  describe 'when there are work orders' do
    let!(:work_order) { create(:communication_work_order) }

    it 'displays work order data' do
      visit '/admin/communication_work_orders'
      expect(page).to have_content(work_order.reimbursement_id)
    end

    it 'allows viewing individual work order' do
      visit "/admin/communication_work_orders/#{work_order.id}"
      expect(page).to have_content('沟通工单详情')
      expect(page.status_code).to eq(200)
    end

    it 'allows editing work order' do
      visit "/admin/communication_work_orders/#{work_order.id}/edit"
      expect(page).to have_content('编辑沟通工单')
      expect(page.status_code).to eq(200)
    end
  end

  describe 'creating new work order' do
    it 'shows the new work order form' do
      visit '/admin/communication_work_orders/new'
      expect(page).to have_content('新建沟通工单')
      expect(page.status_code).to eq(200)
    end

    it 'displays required form fields' do
      visit '/admin/communication_work_orders/new'
      expect(page).to have_field('communication_work_order_reimbursement_id')
      expect(page).to have_field('communication_work_order_communicator_id')
    end

    it 'displays communication-specific fields' do
      visit '/admin/communication_work_orders/new'
      expect(page).to have_field('communication_work_order_communication_type')
      expect(page).to have_field('communication_work_order_contact_person')
      expect(page).to have_field('communication_work_order_contact_phone')
    end
  end

  describe 'work order actions' do
    let!(:work_order) { create(:communication_work_order) }

    it 'shows available actions for pending work orders' do
      visit "/admin/communication_work_orders/#{work_order.id}"
      if work_order.pending?
        expect(page).to have_content('开始处理')
      end
    end

    it 'shows status correctly' do
      visit "/admin/communication_work_orders/#{work_order.id}"
      expect(page).to have_content(work_order.status)
    end

    it 'displays communication-specific information' do
      visit "/admin/communication_work_orders/#{work_order.id}"
      expect(page).to have_content('沟通信息')
    end
  end

  describe 'communication details' do
    let!(:work_order) { create(:communication_work_order, communication_type: 'phone', contact_person: '张三', contact_phone: '13800138000') }

    it 'displays communication type and contact info' do
      visit "/admin/communication_work_orders/#{work_order.id}"
      expect(page).to have_content('phone')
      expect(page).to have_content('张三')
      expect(page).to have_content('13800138000')
    end
  end

  describe 'error handling' do
    it 'handles invalid work order IDs gracefully' do
      visit '/admin/communication_work_orders/99999'
      expect(page.status_code).to eq(404)
    end

    it 'handles database errors gracefully' do
      allow(CommunicationWorkOrder).to receive(:page).and_raise(StandardError.new('Database error'))

      visit '/admin/communication_work_orders'
      expect(page.status_code).to eq(500)
    end
  end
end