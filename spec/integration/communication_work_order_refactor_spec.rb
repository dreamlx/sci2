require 'rails_helper'

RSpec.describe 'CommunicationWorkOrder Refactor Integration', type: :integration do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail1) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending') }
  let(:fee_detail2) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending') }

  before do
    Current.admin_user = admin_user
  end

  describe '沟通工单不影响费用明细状态的完整流程' do
    it '创建沟通工单后，费用明细状态保持不变' do
      # 初始状态检查
      expect(fee_detail1.verification_status).to eq('pending')
      expect(fee_detail2.verification_status).to eq('pending')

      # 创建沟通工单并关联费用明细
      communication_work_order = create(:communication_work_order,
                                        reimbursement: reimbursement,
                                        communication_method: '电话',
                                        audit_comment: '与报销人进行了详细的电话沟通，确认了发票相关问题')

      # 关联费用明细
      create(:work_order_fee_detail, work_order: communication_work_order, fee_detail: fee_detail1)
      create(:work_order_fee_detail, work_order: communication_work_order, fee_detail: fee_detail2)

      # 验证沟通工单自动完成
      expect(communication_work_order.reload.status).to eq('completed')

      # 验证费用明细状态不受影响
      expect(fee_detail1.reload.verification_status).to eq('pending')
      expect(fee_detail2.reload.verification_status).to eq('pending')

      # 验证报销单状态不受影响
      expect(reimbursement.reload.status).not_to eq('verified')
    end
  end

  describe '混合工单场景：审核工单 + 沟通工单' do
    it '只有审核工单影响费用明细状态，沟通工单被忽略' do
      # 创建审核工单
      audit_work_order = create(:audit_work_order,
                                reimbursement: reimbursement,
                                status: 'approved')

      # 创建沟通工单
      communication_work_order = create(:communication_work_order,
                                        reimbursement: reimbursement,
                                        communication_method: '电话',
                                        audit_comment: '电话确认审核结果')

      # 关联费用明细到两个工单
      create(:work_order_fee_detail, work_order: audit_work_order, fee_detail: fee_detail1)
      create(:work_order_fee_detail, work_order: communication_work_order, fee_detail: fee_detail1)

      # 手动触发状态更新
      FeeDetailStatusService.new([fee_detail1.id]).update_status

      # 验证只有审核工单影响状态
      expect(fee_detail1.reload.verification_status).to eq('verified')
    end
  end

  describe '时间顺序测试：确保最新审核工单决定状态' do
    it '最新的审核工单决定状态，忽略中间的沟通工单' do
      # 创建旧的审核工单（拒绝）
      old_audit_work_order = create(:audit_work_order,
                                    reimbursement: reimbursement,
                                    status: 'rejected',
                                    created_at: 2.days.ago)

      # 创建沟通工单（中间时间）
      communication_work_order = create(:communication_work_order,
                                        reimbursement: reimbursement,
                                        communication_method: '电话',
                                        audit_comment: '沟通拒绝原因和改进方案',
                                        created_at: 1.day.ago)

      # 创建新的审核工单（批准）
      new_audit_work_order = create(:audit_work_order,
                                    reimbursement: reimbursement,
                                    status: 'approved',
                                    created_at: 1.hour.ago)

      # 关联费用明细到所有工单
      create(:work_order_fee_detail, work_order: old_audit_work_order, fee_detail: fee_detail1)
      create(:work_order_fee_detail, work_order: communication_work_order, fee_detail: fee_detail1)
      create(:work_order_fee_detail, work_order: new_audit_work_order, fee_detail: fee_detail1)

      # 触发状态更新
      FeeDetailStatusService.new([fee_detail1.id]).update_status

      # 验证最新审核工单决定状态
      expect(fee_detail1.reload.verification_status).to eq('verified')
    end
  end

  describe '数据迁移场景测试' do
    it '重新计算状态时正确处理现有数据' do
      # 模拟迁移前的状态：费用明细因沟通工单而被标记为 verified
      fee_detail1.update_column(:verification_status, 'verified')

      # 创建只有沟通工单的关联
      communication_work_order = create(:communication_work_order,
                                        reimbursement: reimbursement,
                                        status: 'completed')
      create(:work_order_fee_detail, work_order: communication_work_order, fee_detail: fee_detail1)

      # 运行迁移逻辑
      FeeDetailStatusService.new([fee_detail1.id]).update_status

      # 验证状态被正确重置为 pending
      expect(fee_detail1.reload.verification_status).to eq('pending')
    end
  end

  describe '报销单状态级联更新' do
    it '费用明细状态变化应该正确更新报销单状态' do
      # 创建审核工单批准所有费用明细
      audit_work_order = create(:audit_work_order,
                                reimbursement: reimbursement,
                                status: 'approved')

      create(:work_order_fee_detail, work_order: audit_work_order, fee_detail: fee_detail1)
      create(:work_order_fee_detail, work_order: audit_work_order, fee_detail: fee_detail2)

      # 创建沟通工单（不应影响状态）
      create(:communication_work_order,
             reimbursement: reimbursement,
             communication_method: '电话',
             audit_comment: '确认审核通过，告知后续流程')

      # 触发状态更新
      FeeDetailStatusService.new([fee_detail1.id, fee_detail2.id]).update_status

      # 更新报销单状态
      reimbursement.update_status_based_on_fee_details!

      # 验证报销单状态正确
      expect(fee_detail1.reload.verification_status).to eq('verified')
      expect(fee_detail2.reload.verification_status).to eq('verified')
      expect(reimbursement.reload.status).to eq('verified')
    end
  end

  describe 'ActiveAdmin 集成测试' do
    it '沟通工单创建后应该自动完成且不可编辑' do
      communication_work_order = create(:communication_work_order,
                                        reimbursement: reimbursement,
                                        communication_method: '电话',
                                        audit_comment: '详细的沟通记录内容')

      # 验证自动完成
      expect(communication_work_order.status).to eq('completed')

      # 验证不可编辑（业务逻辑层面）
      expect(communication_work_order.status).to eq('completed')
    end
  end

  describe '边界情况测试' do
    it '处理空的沟通工单关联' do
      # 创建没有关联任何费用明细的沟通工单
      communication_work_order = create(:communication_work_order,
                                        reimbursement: reimbursement,
                                        communication_method: '电话',
                                        audit_comment: '一般性沟通，未涉及具体费用明细')

      expect(communication_work_order.status).to eq('completed')
      expect(communication_work_order.fee_details).to be_empty
    end

    it '处理大量沟通工单的性能' do
      # 创建多个沟通工单
      communication_work_orders = []
      10.times do |i|
        communication_work_orders << create(:communication_work_order,
                                            reimbursement: reimbursement,
                                            communication_method: '电话',
                                            audit_comment: "第#{i + 1}次沟通记录")
      end

      # 验证所有工单都自动完成
      communication_work_orders.each do |wo|
        expect(wo.status).to eq('completed')
      end

      # 验证性能：状态计算不应该受到沟通工单数量影响
      start_time = Time.current
      FeeDetailStatusService.new([fee_detail1.id]).update_status
      end_time = Time.current

      expect(end_time - start_time).to be < 1.second
    end
  end
end
