require 'rails_helper'

RSpec.describe 'WorkOrder手动状态处理', type: :model do
  let(:admin_user) { AdminUser.create!(email: 'admin@example.com', password: 'password') }

  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: 'INV-001',
      document_name: '个人报销单',
      status: 'processing',
      is_electronic: true
    )
  end

  let(:fee_detail) do
    FeeDetail.create!(
      document_number: reimbursement.invoice_number,
      fee_type: '月度交通费',
      amount: 100.0,
      fee_date: Date.today,
      verification_status: 'pending'
    )
  end

  before do
    Current.admin_user = admin_user
  end

  after do
    Current.admin_user = nil
  end

  describe '手动状态处理' do
    let(:work_order) do
      # 创建工单
      order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: order,
        fee_detail: fee_detail
      )

      order
    end

    it '手动设置状态为approved并更新费用明细状态' do
      # 手动设置状态
      work_order.update_column(:status, 'approved')

      # 手动触发费用明细状态更新
      FeeDetailStatusService.new([fee_detail.id]).update_status

      # 验证费用明细状态
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
    end

    it '手动设置状态为rejected并更新费用明细状态' do
      # 手动设置状态
      work_order.update_column(:status, 'rejected')

      # 手动触发费用明细状态更新
      FeeDetailStatusService.new([fee_detail.id]).update_status

      # 验证费用明细状态
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
    end
  end

  describe '最新工单决定原则' do
    let(:work_order_1) do
      # 创建第一个工单
      order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: order,
        fee_detail: fee_detail
      )

      order
    end

    let(:work_order_2) do
      # 创建第二个工单
      order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: order,
        fee_detail: fee_detail
      )

      order
    end

    it '费用明细状态由最新工单决定' do
      # 第一个工单设置为拒绝
      work_order_1.update_column(:status, 'rejected')

      # 手动触发费用明细状态更新
      FeeDetailStatusService.new([fee_detail.id]).update_status

      # 验证费用明细状态为problematic
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)

      # 第二个工单设置为通过
      work_order_2.update_column(:status, 'approved')

      # 手动触发费用明细状态更新
      FeeDetailStatusService.new([fee_detail.id]).update_status

      # 验证费用明细状态变为verified
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)

      # 更新第二个工单的更新时间为更早的时间
      work_order_2.update_column(:updated_at, 1.day.ago)

      # 手动触发费用明细状态更新
      FeeDetailStatusService.new([fee_detail.id]).update_status

      # 验证费用明细状态变回problematic
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
    end
  end
end
