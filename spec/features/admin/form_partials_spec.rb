require 'rails_helper'

RSpec.describe 'Form Partials', type: :feature do
  let!(:admin_user) { create(:admin_user, :super_admin) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'Audit Work Order Form' do
    it 'uses partial and includes all necessary fields' do
      visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)

      # Check for shared fields
      expect(page).to have_select('audit_work_order[problem_type]')
      expect(page).to have_select('audit_work_order[problem_description]')
      expect(page).to have_field('audit_work_order[remark]')
      expect(page).to have_select('audit_work_order[processing_opinion]')

      # Check for audit-specific fields
      expect(page).to have_field('audit_work_order[audit_comment]')
      expect(page).to have_field('audit_work_order[vat_verified]')

      # Check for fee detail selection
      expect(page).to have_css("input[type='checkbox'][name='audit_work_order[fee_detail_ids][]']")
    end
  end

  describe 'Communication Work Order Form' do
    it 'uses partial and includes all necessary fields' do
      visit new_admin_communication_work_order_path(reimbursement_id: reimbursement.id)

      # Check for shared fields
      expect(page).to have_select('communication_work_order[problem_type]')
      expect(page).to have_select('communication_work_order[problem_description]')
      expect(page).to have_field('communication_work_order[remark]')
      expect(page).to have_select('communication_work_order[processing_opinion]')

      # Check for communication-specific fields
      expect(page).to have_select('communication_work_order[communication_method]')
      expect(page).to have_select('communication_work_order[initiator_role]')

      # Check for fee detail selection
      expect(page).to have_css("input[type='checkbox'][name='communication_work_order[fee_detail_ids][]']")
    end
  end

  describe 'Approve/Reject Forms' do
    let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'processing') }
    let!(:communication_work_order) do
      create(:communication_work_order, reimbursement: reimbursement, status: 'processing')
    end

    it 'audit work order approve form includes necessary fields' do
      visit approve_admin_audit_work_order_path(audit_work_order)

      expect(page).to have_field('audit_work_order[audit_comment]')
      expect(page).to have_field('audit_work_order[audit_date]')
      expect(page).to have_field('audit_work_order[vat_verified]')
      expect(page).to have_button('确认通过')
    end

    it 'audit work order reject form includes necessary fields' do
      visit reject_admin_audit_work_order_path(audit_work_order)

      expect(page).to have_field('audit_work_order[audit_comment]')
      expect(page).to have_field('audit_work_order[audit_date]')
      expect(page).to have_button('确认拒绝')
    end

    it 'communication work order approve form includes necessary fields' do
      visit approve_admin_communication_work_order_path(communication_work_order)

      expect(page).to have_field('communication_work_order[resolution_summary]')
      expect(page).to have_button('确认通过')
    end

    it 'communication work order reject form includes necessary fields' do
      visit reject_admin_communication_work_order_path(communication_work_order)

      expect(page).to have_field('communication_work_order[resolution_summary]')
      expect(page).to have_button('确认拒绝')
    end
  end
end
