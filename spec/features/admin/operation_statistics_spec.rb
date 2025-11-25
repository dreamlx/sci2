# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Operation Statistics Page', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'accessing operation statistics' do
    it 'loads the page successfully' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('操作统计')
      expect(page.status_code).to eq(200)
    end

    it 'displays operation type statistics' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('按操作类型统计')
    end

    it 'displays user statistics' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('按操作人统计')
    end

    it 'displays operation trends' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('最近30天操作趋势')
    end

    it 'displays operation ranking' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('操作排行榜')
    end

    it 'displays overall statistics' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('总体统计')
    end
  end

  describe 'when there are no operations' do
    it 'shows appropriate messages for empty data' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('暂无操作记录')
    end
  end

  describe 'when there are operations' do
    let!(:work_order) { create(:express_receipt_work_order) }
    let!(:operation) do
      create(:work_order_operation,
             work_order: work_order,
             admin_user: admin_user,
             operation_type: 'start_processing'
      )
    end

    it 'displays operation counts correctly' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('start_processing')
      expect(page).to have_content(admin_user.email)
    end

    it 'shows overall statistics with counts' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('总操作数')
      expect(page).to have_content('今日操作数')
      expect(page).to have_content('本周操作数')
      expect(page).to have_content('本月操作数')
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      allow(WorkOrderOperation).to receive(:group).and_raise(StandardError.new('Database error'))

      visit '/admin/operation_statistics'
      expect(page.status_code).to eq(500)
    end
  end
end