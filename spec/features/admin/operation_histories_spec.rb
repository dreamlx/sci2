require 'rails_helper'

RSpec.describe '操作历史管理', type: :feature do
  let!(:admin_user) { create(:admin_user, :super_admin) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:operation_history) { create(:operation_history, document_number: reimbursement.invoice_number) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe '列表页' do
    it '显示所有操作历史' do
      visit admin_operation_histories_path
      expect(page).to have_content('操作历史')
      expect(page).to have_content(operation_history.document_number)
    end

    it '不显示新建按钮' do
      visit admin_operation_histories_path
      expect(page).not_to have_link('新建操作历史')
    end

    it '显示导入按钮' do
      visit admin_operation_histories_path
      expect(page).to have_link('导入操作历史')
    end

    it '只显示查看操作，不显示编辑和删除操作' do
      visit admin_operation_histories_path
      expect(page).to have_link('查看')
      expect(page).not_to have_link('编辑')
      expect(page).not_to have_link('删除')
    end
  end

  describe '详情页' do
    it '显示操作历史详细信息' do
      visit admin_operation_history_path(operation_history)
      expect(page).to have_content(operation_history.document_number)
      expect(page).to have_content(operation_history.operation_type)
    end

    it '不显示编辑按钮' do
      visit admin_operation_history_path(operation_history)
      expect(page).not_to have_link('编辑操作历史')
    end
  end

  describe '导入页面' do
    it '显示导入表单' do
      visit admin_imports_operation_histories_path
      expect(page).to have_content('导入操作历史')
      expect(page).to have_field('file')
      expect(page).to have_button('导入')
    end
  end
end