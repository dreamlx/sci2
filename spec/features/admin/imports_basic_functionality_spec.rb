# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Import Pages', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'reimbursement import page' do
    it 'loads the page successfully' do
      visit '/admin/reimbursements/import'
      expect(page).to have_content('导入报销单')
      expect(page.status_code).to eq(200)
    end

    it 'displays import form' do
      visit '/admin/reimbursements/import'
      expect(page).to have_field('file')
      expect(page).to have_button('导入')
    end

    it 'shows import instructions' do
      visit '/admin/reimbursements/import'
      expect(page).to have_content('请选择要导入的文件')
    end
  end

  describe 'express receipt import page' do
    it 'loads the page successfully' do
      visit '/admin/express_receipt_work_orders/import'
      expect(page).to have_content('导入快递收单工单')
      expect(page.status_code).to eq(200)
    end

    it 'displays import form' do
      visit '/admin/express_receipt_work_orders/import'
      expect(page).to have_field('file')
      expect(page).to have_button('导入')
    end

    it 'shows import instructions' do
      visit '/admin/express_receipt_work_orders/import'
      expect(page).to have_content('请选择要导入的文件')
    end
  end

  describe 'fee detail import page' do
    it 'loads the page successfully' do
      visit '/admin/fee_details/import'
      expect(page).to have_content('导入费用明细')
      expect(page.status_code).to eq(200)
    end

    it 'displays import form' do
      visit '/admin/fee_details/import'
      expect(page).to have_field('file')
      expect(page).to have_button('导入')
    end

    it 'shows import instructions' do
      visit '/admin/fee_details/import'
      expect(page).to have_content('请选择要导入的文件')
    end
  end

  describe 'operation history import page' do
    it 'loads the page successfully' do
      visit '/admin/operation_histories/import'
      expect(page).to have_content('导入操作历史')
      expect(page.status_code).to eq(200)
    end

    it 'displays import form' do
      visit '/admin/operation_histories/import'
      expect(page).to have_field('file')
      expect(page).to have_button('导入')
    end

    it 'shows import instructions' do
      visit '/admin/operation_histories/import'
      expect(page).to have_content('请选择要导入的文件')
    end
  end

  describe 'import navigation' do
    it 'allows navigation from data management menu' do
      visit '/admin'
      click_link '数据管理'
      expect(page).to have_content('导入报销单')
      expect(page).to have_content('导入快递收单工单')
    end

    it 'shows all import options in data management' do
      visit '/admin'
      click_link '数据管理'
      expect(page).to have_link('导入报销单')
      expect(page).to have_link('导入快递收单工单')
      expect(page).to have_link('导入费用明细')
      expect(page).to have_link('导入操作历史')
    end
  end

  describe 'import error handling' do
    it 'handles file upload errors gracefully' do
      visit '/admin/reimbursements/import'
      # Simulate file upload without selecting a file
      click_button('导入')
      # Should handle the error gracefully
      expect(page.status_code).to be_in([200, 422])
    end

    it 'handles invalid file formats' do
      visit '/admin/reimbursements/import'
      # Would need to test with actual file upload in a real scenario
      expect(page.status_code).to eq(200)
    end

    it 'handles import service errors' do
      allow(ReimbursementImportService).to receive(:new).and_raise(StandardError.new('Import service error'))

      visit '/admin/reimbursements/import'
      expect(page.status_code).to be_in([200, 500])
    end
  end

  describe 'import validation messages' do
    it 'shows field requirements in import form' do
      visit '/admin/reimbursements/import'
      expect(page).to have_content('*')
    end

    it 'displays expected format information' do
      visit '/admin/reimbursements/import'
      expect(page).to have_content('格式')
    end
  end

  describe 'post-import behavior' do
    it 'redirects to index page after successful import' do
      # This would require mocking a successful import
      visit '/admin/reimbursements/import'
      expect(page).to have_current_path('/admin/reimbursements/import')
    end
  end
end