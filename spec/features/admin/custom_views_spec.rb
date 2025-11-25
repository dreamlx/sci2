require 'rails_helper'

RSpec.describe '自定义视图', type: :feature do
  let!(:admin_user) { create(:admin_user, :super_admin) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'processing') }
  let!(:communication_work_order) do
    create(:communication_work_order, reimbursement: reimbursement, status: 'processing', needs_communication: true)
  end
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let!(:fee_detail_selection) { create(:fee_detail_selection, work_order: audit_work_order, fee_detail: fee_detail) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe '审核工单审核通过表单' do
    it '显示工单信息和表单' do
      visit approve_admin_audit_work_order_path(audit_work_order)

      expect(page).to have_content('审核通过')
      expect(page).to have_content('工单信息')
      expect(page).to have_content(audit_work_order.id.to_s)
      expect(page).to have_content(reimbursement.invoice_number)

      expect(page).to have_field('audit_work_order[audit_comment]')
      expect(page).to have_select('audit_work_order[audit_date(1i)]') # 年份选择器
      expect(page).to have_select('audit_work_order[audit_date(2i)]') # 月份选择器
      expect(page).to have_select('audit_work_order[audit_date(3i)]') # 日期选择器
      expect(page).to have_field('audit_work_order[vat_verified]')

      expect(page).to have_button('确认通过')
      expect(page).to have_link('取消')
    end
  end

  describe '审核工单审核拒绝表单' do
    it '显示工单信息和表单' do
      visit reject_admin_audit_work_order_path(audit_work_order)

      expect(page).to have_content('审核拒绝')
      expect(page).to have_content('工单信息')
      expect(page).to have_content(audit_work_order.id.to_s)
      expect(page).to have_content(reimbursement.invoice_number)

      expect(page).to have_field('audit_work_order[audit_comment]')
      expect(page).to have_select('audit_work_order[audit_date(1i)]') # 年份选择器
      expect(page).to have_select('audit_work_order[audit_date(2i)]') # 月份选择器
      expect(page).to have_select('audit_work_order[audit_date(3i)]') # 日期选择器

      expect(page).to have_button('确认拒绝')
      expect(page).to have_link('取消')
    end
  end

  describe '沟通工单沟通后通过表单' do
    it '显示工单信息和表单' do
      visit approve_admin_communication_work_order_path(communication_work_order)

      expect(page).to have_content('沟通后通过')
      expect(page).to have_content('工单信息')
      expect(page).to have_content(communication_work_order.id.to_s)
      expect(page).to have_content(reimbursement.invoice_number)

      expect(page).to have_content('沟通记录')
      expect(page).to have_field('communication_work_order[resolution_summary]')

      expect(page).to have_button('确认通过')
      expect(page).to have_link('取消')
    end
  end

  describe '沟通工单沟通后拒绝表单' do
    it '显示工单信息和表单' do
      visit reject_admin_communication_work_order_path(communication_work_order)

      expect(page).to have_content('沟通后拒绝')
      expect(page).to have_content('工单信息')
      expect(page).to have_content(communication_work_order.id.to_s)
      expect(page).to have_content(reimbursement.invoice_number)

      expect(page).to have_content('沟通记录')
      expect(page).to have_field('communication_work_order[resolution_summary]')

      expect(page).to have_button('确认拒绝')
      expect(page).to have_link('取消')
    end
  end

  describe '费用明细验证表单' do
    it '显示费用明细信息和表单' do
      visit verify_fee_detail_admin_audit_work_order_path(audit_work_order, fee_detail_id: fee_detail.id)

      expect(page).to have_content('更新费用明细验证状态')
      expect(page).to have_content('费用明细信息')
      expect(page).to have_content(fee_detail.id.to_s)
      expect(page).to have_content(fee_detail.document_number)

      expect(page).to have_content('工单信息')
      expect(page).to have_content(audit_work_order.id.to_s)

      expect(page).to have_select('verification_status')
      expect(page).to have_field('comment')

      expect(page).to have_button('提交')
      expect(page).to have_link('取消')
    end
  end

  describe '沟通记录添加表单' do
    it '显示工单信息和表单' do
      visit new_communication_record_admin_communication_work_order_path(communication_work_order)

      expect(page).to have_content('添加沟通记录')
      expect(page).to have_content('沟通工单信息')
      expect(page).to have_content(communication_work_order.id.to_s)
      expect(page).to have_content(reimbursement.invoice_number)

      expect(page).to have_field('communication_record[content]')
      expect(page).to have_field('communication_record[communicator_role]')
      expect(page).to have_field('communication_record[communicator_name]')
      expect(page).to have_field('communication_record[communication_method]')

      expect(page).to have_button('添加记录')
      expect(page).to have_link('取消')
    end
  end
end
