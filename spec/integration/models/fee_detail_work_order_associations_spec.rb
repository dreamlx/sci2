# spec/integration/models/fee_detail_work_order_associations_spec.rb
require 'rails_helper'

RSpec.describe 'FeeDetail Work Order Associations', type: :model do
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let(:admin_user) { create(:admin_user) }

  describe 'accessing related work orders' do
    let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, created_by: admin_user.id) }
    let(:communication_work_order) do
      create(:communication_work_order, reimbursement: reimbursement, created_by: admin_user.id)
    end

    before do
      # 直接创建关联
      WorkOrderFeeDetail.create!(
        work_order: audit_work_order,
        fee_detail: fee_detail
      )

      WorkOrderFeeDetail.create!(
        work_order: communication_work_order,
        fee_detail: fee_detail
      )
    end

    it 'can access all related work orders' do
      # Reload fee detail to ensure associations are loaded
      fee_detail.reload

      # Check that fee detail is associated with both work orders
      work_orders = fee_detail.work_orders

      expect(work_orders.count).to eq(2)
      expect(work_orders.pluck(:id)).to include(audit_work_order.id)
      expect(work_orders.pluck(:id)).to include(communication_work_order.id)
    end

    it 'can access audit work orders specifically' do
      fee_detail.reload

      # 使用 where 查询替代可能不存在的方法
      audit_work_orders = fee_detail.work_orders.where(type: 'AuditWorkOrder')

      expect(audit_work_orders.count).to eq(1)
      expect(audit_work_orders.first).to eq(audit_work_order)
    end

    it 'can access communication work orders specifically' do
      fee_detail.reload

      # 使用 where 查询替代可能不存在的方法
      communication_work_orders = fee_detail.work_orders.where(type: 'CommunicationWorkOrder')

      expect(communication_work_orders.count).to eq(1)
      expect(communication_work_orders.first).to eq(communication_work_order)
    end
  end

  describe 'accessing related fee details from work orders' do
    let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, created_by: admin_user.id) }
    let(:fee_detail2) { create(:fee_detail, document_number: reimbursement.invoice_number) }

    before do
      # 直接创建关联
      WorkOrderFeeDetail.create!(
        work_order: audit_work_order,
        fee_detail: fee_detail
      )

      WorkOrderFeeDetail.create!(
        work_order: audit_work_order,
        fee_detail: fee_detail2
      )
    end

    it 'can access all related fee details using the fee_details association' do
      # 使用标准关联方法
      related_fee_details = audit_work_order.fee_details

      expect(related_fee_details.count).to eq(2)
      expect(related_fee_details).to include(fee_detail)
      expect(related_fee_details).to include(fee_detail2)
    end

    it 'updates all related fee details when work order status changes' do
      # Change work order status
      audit_work_order.processing_opinion = '可以通过'
      audit_work_order.save!

      # Reload fee details
      fee_detail.reload
      fee_detail2.reload

      # Both fee details should be verified
      expect(fee_detail.verification_status).to eq('verified')
      expect(fee_detail2.verification_status).to eq('verified')
    end
  end
end
