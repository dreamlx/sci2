require 'rails_helper'

RSpec.describe 'WorkOrder Reimbursement Status Updates', type: :model do
  let(:admin_user) { AdminUser.create!(email: 'test@example.com', password: 'password') }
  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: "TEST-#{Time.current.to_i}",
      document_name: '测试报销单',
      is_electronic: true
    )
  end

  # 模拟 Current.admin_user
  before do
    allow(Current).to receive(:admin_user).and_return(admin_user)
  end

  # 禁用 WorkOrderOperation 创建，因为它不是我们测试的重点
  around do |example|
    original_log_creation = WorkOrder.instance_method(:log_creation)
    WorkOrder.define_method(:log_creation) { true } # 替换为空方法

    example.run

    # 恢复原始方法
    WorkOrder.define_method(:log_creation, original_log_creation)
  end

  describe 'when creating an AuditWorkOrder' do
    it 'changes the reimbursement status from pending to processing' do
      expect(reimbursement.status).to eq('pending')

      audit_work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        created_by: admin_user.id
      )

      expect(audit_work_order.save).to be true

      # Reload the reimbursement to get the updated status
      reimbursement.reload
      expect(reimbursement.status).to eq('processing')
    end
  end

  describe 'when creating a CommunicationWorkOrder' do
    it 'changes the reimbursement status from pending to processing' do
      expect(reimbursement.status).to eq('pending')

      communication_work_order = CommunicationWorkOrder.new(
        reimbursement: reimbursement,
        created_by: admin_user.id
      )

      expect(communication_work_order.save).to be true

      # Reload the reimbursement to get the updated status
      reimbursement.reload
      expect(reimbursement.status).to eq('processing')
    end
  end

  describe 'when creating an ExpressReceiptWorkOrder' do
    it 'does not change the reimbursement status' do
      expect(reimbursement.status).to eq('pending')

      express_receipt_work_order = ExpressReceiptWorkOrder.new(
        reimbursement: reimbursement,
        tracking_number: 'TEST-TRACKING-123',
        received_at: Time.current,
        created_by: admin_user.id,
        status: 'completed' # ExpressReceiptWorkOrder 只允许 'completed' 状态
      )

      # 保存工单
      result = express_receipt_work_order.save

      # 如果保存失败，输出错误信息以便调试
      unless result
        puts "ExpressReceiptWorkOrder save failed: #{express_receipt_work_order.errors.full_messages.join(', ')}"
      end

      expect(result).to be true

      # Reload the reimbursement to get the updated status
      reimbursement.reload
      expect(reimbursement.status).to eq('pending') # Status should remain pending
    end
  end
end
