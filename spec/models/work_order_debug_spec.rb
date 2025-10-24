require 'rails_helper'

RSpec.describe 'WorkOrder调试', type: :model do
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

  describe '调试关联关系' do
    it '检查关联关系' do
      # 创建工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      wofd = WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail
      )

      # 调试输出
      puts "工单ID: #{work_order.id}"
      puts "费用明细ID: #{fee_detail.id}"
      puts "工单类型: #{work_order.class.name}"
      puts "WorkOrderFeeDetail ID: #{wofd.id}"
      puts "WorkOrderFeeDetail work_order_id: #{wofd.work_order_id}"
      puts "WorkOrderFeeDetail fee_detail_id: #{wofd.fee_detail_id}"

      # 直接从数据库查询关联
      wofds = WorkOrderFeeDetail.where(fee_detail_id: fee_detail.id)
      puts "WorkOrderFeeDetail记录数: #{wofds.count}"
      wofds.each do |wofd|
        puts "  work_order_id: #{wofd.work_order_id}"
      end

      # 重新加载工单和费用明细
      work_order.reload
      fee_detail.reload

      # 检查工单关联的费用明细ID
      fee_detail_ids = WorkOrderFeeDetail.where(work_order_id: work_order.id).pluck(:fee_detail_id)
      puts "直接查询的费用明细ID: #{fee_detail_ids}"
      expect(fee_detail_ids).to include(fee_detail.id)

      # 检查费用明细关联的工单ID
      work_order_ids = WorkOrderFeeDetail.where(fee_detail_id: fee_detail.id).pluck(:work_order_id)
      puts "直接查询的工单ID: #{work_order_ids}"
      expect(work_order_ids).to include(work_order.id)

      # 设置工单状态为approved
      work_order.update_column(:status, 'approved')

      # 手动触发费用明细状态更新
      work_order.sync_fee_details_verification_status

      # 验证费用明细状态是否更新为verified
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
    end
  end

  describe '调试状态变更' do
    it '检查状态变更' do
      # 创建工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      wofd = WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail
      )

      # 调试输出
      puts "工单ID: #{work_order.id}"
      puts "费用明细ID: #{fee_detail.id}"
      puts "WorkOrderFeeDetail ID: #{wofd.id}"

      # 重新加载工单和费用明细
      work_order.reload
      fee_detail.reload

      # 设置处理意见
      work_order.processing_opinion = '可以通过'

      # 直接调用方法
      work_order.send(:set_status_based_on_processing_opinion)

      # 调试输出
      puts "工单状态: #{work_order.reload.status}"
      puts "费用明细状态: #{fee_detail.reload.verification_status}"

      # 验证工单状态
      expect(work_order.reload.status).to eq('approved')

      # 验证费用明细状态
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
    end
  end
end
