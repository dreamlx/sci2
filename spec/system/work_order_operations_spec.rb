require 'rails_helper'

RSpec.describe 'Work Order Operations', type: :system do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  let(:problem_type) { create(:problem_type) }
  let!(:work_order) { create(:audit_work_order, reimbursement: reimbursement, created_by: admin_user.id) }

  before do
    # Create some operations for the work order
    operation_service = WorkOrderOperationService.new(work_order, admin_user)
    operation_service.record_create
    operation_service.record_update({ 'remark' => nil })

    # Log in as admin user
    login_as(admin_user, scope: :admin_user)
  end

  describe 'viewing operations on work order show page' do
    it 'displays operations panel with operations' do
      visit admin_audit_work_order_path(work_order)

      # Check that the operations panel exists
      expect(page).to have_content('操作记录')

      # Check that operations are displayed
      expect(page).to have_content('创建工单')
      expect(page).to have_content('更新工单')

      # Check that admin user is displayed
      expect(page).to have_content(admin_user.email)
    end

    it 'allows viewing operation details' do
      visit admin_audit_work_order_path(work_order)

      # Find and click on the first operation
      first_operation = WorkOrderOperation.where(work_order: work_order).first
      click_link first_operation.id.to_s

      # Check that operation details are displayed
      expect(page).to have_content('操作详情')
      expect(page).to have_content('状态变化')

      # Check that tabs exist
      expect(page).to have_content('操作前')
      expect(page).to have_content('操作后')
      expect(page).to have_content('差异对比')
    end
  end

  describe 'operation statistics page' do
    it 'displays operation statistics' do
      visit '/admin/operation_statistics'

      # Check that statistics are displayed
      expect(page).to have_content('操作统计')
      expect(page).to have_content('按操作类型统计')
      expect(page).to have_content('按操作人统计')
      expect(page).to have_content('最近30天操作趋势')
      expect(page).to have_content('操作排行榜')
    end
  end
end
