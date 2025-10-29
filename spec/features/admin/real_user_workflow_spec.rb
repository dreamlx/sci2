# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Real User Workflow Tests', type: :feature do
  let(:admin_user) { create(:admin_user, role: 'super_admin') }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'Complete admin user workflow' do
    it 'can access and manage admin users successfully' do
      # Step 1: Access admin users page
      visit '/admin/admin_users'
      expect(page).to have_content('管理员用户')
      expect(page.status_code).to eq(200)

      # Step 2: Create a new admin user
      click_link 'New'
      expect(page).to have_content('New Admin User')

      # Step 3: Fill in user creation form
      fill_in 'admin_user_email', with: 'new_admin@example.com'
      fill_in 'admin_user_password', with: 'password123'
      fill_in 'admin_user_password_confirmation', with: 'password123'

      click_button 'Create Admin user'
      expect(page).to have_content('管理员用户')

      # Step 4: Verify the new user appears in the list
      expect(page).to have_content('new_admin@example.com')
    end

    it 'can view and manage reimbursements' do
      # Step 1: Access reimbursements page
      visit '/admin/reimbursements'
      expect(page).to have_content('报销单')
      expect(page.status_code).to eq(200)

      # Step 2: Create a reimbursement
      click_link 'New'
      expect(page).to have_content('New Reimbursement')

      # Step 3: Fill in basic reimbursement data
      fill_in 'reimbursement_reimbursement_id', with: 'TEST001'
      fill_in 'reimbursement_company', with: '测试公司'
      fill_in 'reimbursement_total_amount', with: '1000.00'

      click_button 'Create Reimbursement'
      expect(page).to have_content('报销单')

      # Step 4: Verify the reimbursement appears
      expect(page).to have_content('TEST001')
    end

    it 'can create and manage work orders' do
      # First create a reimbursement to associate with
      reimbursement = create(:reimbursement)

      # Step 1: Access express receipt work orders
      visit '/admin/express_receipt_work_orders'
      expect(page).to have_content('快递收单工单')
      expect(page.status_code).to eq(200)

      # Step 2: Create a new work order
      click_link 'New'
      expect(page).to have_content('New Express Receipt Work Order')

      # Step 3: Fill in work order form
      fill_in 'express_receipt_work_order_express_company', with: '顺丰快递'
      fill_in 'express_receipt_work_order_tracking_number', with: 'SF123456789'
      select reimbursement.reimbursement_id, from: 'express_receipt_work_order_reimbursement_id'

      click_button 'Create Express receipt work order'
      expect(page).to have_content('快递收单工单')

      # Step 4: Verify the work order appears
      expect(page).to have_content('SF123456789')
    end

    it 'can view operation statistics' do
      visit '/admin/operation_statistics'
      expect(page).to have_content('操作统计')
      expect(page.status_code).to eq(200)

      # Should show statistics panels
      expect(page).to have_content('按操作类型统计')
      expect(page).to have_content('按操作人统计')
      expect(page).to have_content('总体统计')
    end

    it 'can manage fee details' do
      # Step 1: Access fee details page
      visit '/admin/fee_details'
      expect(page).to have_content('费用明细')
      expect(page.status_code).to eq(200)

      # Step 2: Create a fee detail
      click_link 'New'
      expect(page).to have_content('New Fee Detail')

      # Step 3: Fill in fee detail form
      fill_in 'fee_detail_external_fee_id', with: 'FEE001'
      fill_in 'fee_detail_amount', with: '100.50'

      click_button 'Create Fee detail'
      expect(page).to have_content('费用明细')

      # Step 4: Verify the fee detail appears
      expect(page).to have_content('FEE001')
    end

    it 'can manage problem types' do
      visit '/admin/problem_types'
      expect(page).to have_content('Problem Types')
      expect(page.status_code).to eq(200)

      # Step 2: Create a new problem type
      click_link 'New'
      expect(page).to have_content('New Problem Type')

      # Step 3: Fill in problem type form
      fill_in 'problem_type_name', with: '测试问题'
      fill_in 'problem_type_severity', with: 'medium'

      click_button 'Create Problem type'
      expect(page).to have_content('Problem Types')

      # Step 4: Verify the problem type appears
      expect(page).to have_content('测试问题')
    end

    it 'can access communication work orders' do
      reimbursement = create(:reimbursement)

      visit '/admin/communication_work_orders'
      expect(page).to have_content('沟通工单')
      expect(page.status_code).to eq(200)

      # Create a communication work order
      click_link 'New'
      expect(page).to have_content('New Communication Work Order')

      select reimbursement.reimbursement_id, from: 'communication_work_order_reimbursement_id'
      select admin_user.id.to_s, from: 'communication_work_order_communicator_id'

      click_button 'Create Communication work order'
      expect(page).to have_content('沟通工单')
    end

    it 'can access audit work orders' do
      reimbursement = create(:reimbursement)

      visit '/admin/audit_work_orders'
      expect(page).to have_content('审核工单')
      expect(page.status_code).to eq(200)

      # Create an audit work order
      click_link 'New'
      expect(page).to have_content('New Audit Work Order')

      select reimbursement.reimbursement_id, from: 'audit_work_order_reimbursement_id'
      select admin_user.id.to_s, from: 'audit_work_order_auditor_id'

      click_button 'Create Audit work order'
      expect(page).to have_content('审核工单')
    end

    it 'can access operation histories' do
      visit '/admin/operation_histories'
      expect(page).to have_content('操作历史')
      expect(page.status_code).to eq(200)
    end

    it 'can access dashboard' do
      visit '/admin'
      expect(page).to have_content('SCI2工单系统')
      expect(page.status_code).to eq(200)

      # Should show navigation menu
      expect(page).to have_content('报销单管理')
      expect(page).to have_content('工单管理')
      expect(page).to have_content('操作统计')
      expect(page).to have_content('数据管理')
    end
  end

  describe 'Error handling in real workflows' do
    it 'handles invalid form submissions gracefully' do
      visit '/admin/reimbursements'
      click_link 'New'

      # Submit empty form
      click_button 'Create Reimbursement'

      # Should show validation errors, not crash
      expect(page.status_code).to be_in([200, 422])
    end

    it 'handles navigation to non-existent resources gracefully' do
      visit '/admin/reimbursements/99999'
      expect(page.status_code).to eq(404)
    end

    it 'handles permission restrictions' do
      # Create a regular admin user (not super admin)
      regular_admin = create(:admin_user, role: 'admin')

      logout(:admin_user)
      login_as(regular_admin, scope: :admin_user)

      visit '/admin/admin_users'
      # Should redirect or show access denied
      expect(page.status_code).not_to eq(500)
    end
  end

  describe 'Performance and reliability' do
    it 'loads pages within reasonable time' do
      start_time = Time.current

      visit '/admin'
      visit '/admin/reimbursements'
      visit '/admin/express_receipt_work_orders'
      visit '/admin/operation_statistics'

      end_time = Time.current
      load_time = end_time - start_time

      # Should load all pages within 5 seconds
      expect(load_time).to be < 5.seconds
    end

    it 'maintains session across multiple page visits' do
      visit '/admin'
      expect(page).to have_content(admin_user.email)

      visit '/admin/reimbursements'
      expect(page).to have_content(admin_user.email)

      visit '/admin/admin_users'
      expect(page).to have_content(admin_user.email)
    end
  end
end