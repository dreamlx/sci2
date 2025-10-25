require 'rails_helper'

RSpec.describe WorkOrderService, type: :service do
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
      external_fee_id: 'FEE001',
      document_number: reimbursement.invoice_number,
      fee_type: '月度交通费',
      amount: 100.0,
      fee_date: Date.today,
      verification_status: 'pending'
    )
  end

  let(:fee_type) do
    FeeType.create!(
      code: '00',
      title: '月度交通费',
      meeting_type: '个人',
      active: true
    )
  end

  let(:problem_type) do
    ProblemType.create!(
      code: '01',
      title: '燃油费行程问题',
      sop_description: '检查燃油费是否与行程匹配',
      standard_handling: '要求提供详细行程单',
      fee_type: fee_type,
      active: true
    )
  end

  # 设置Current.admin_user
  before do
    Current.admin_user = admin_user
  end

  # 清理Current.admin_user
  after do
    Current.admin_user = nil
  end

  describe '审核工单状态处理' do
    let(:audit_work_order) do
      # 创建工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
      )

      work_order
    end

    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }

    context "处理意见设置为'可以通过'" do
      it '工单状态变更为approved' do
        # 设置处理意见为"可以通过"
        audit_work_order.processing_opinion = '可以通过'

        # 直接调用方法
        audit_work_order.send(:set_status_based_on_processing_opinion)

        # 验证结果
        expect(audit_work_order.reload.status).to eq('approved')
      end

      it '关联的费用明细状态变更为verified' do
        # 设置处理意见为"可以通过"
        audit_work_order.processing_opinion = '可以通过'

        # 直接调用方法
        audit_work_order.send(:set_status_based_on_processing_opinion)

        # 验证费用明细状态
        expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
      end
    end

    context "处理意见设置为'无法通过'" do
      it '工单状态变更为rejected' do
        # 设置处理意见为"无法通过"
        audit_work_order.processing_opinion = '无法通过'

        # 直接调用方法
        audit_work_order.send(:set_status_based_on_processing_opinion)

        # 验证结果
        expect(audit_work_order.reload.status).to eq('rejected')
      end

      it '关联的费用明细状态变更为problematic' do
        # 设置处理意见为"无法通过"
        audit_work_order.processing_opinion = '无法通过'

        # 直接调用方法
        audit_work_order.send(:set_status_based_on_processing_opinion)

        # 验证费用明细状态
        expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
      end
    end
  end

  describe '沟通工单状态处理' do
    let(:communication_work_order) do
      # 创建工单
      work_order = CommunicationWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
      )

      work_order
    end

    let(:service) { WorkOrderService.new(communication_work_order, admin_user) }

    context "处理意见设置为'可以通过'" do
      it '工单状态变更为approved' do
        # 设置处理意见为"可以通过"
        communication_work_order.processing_opinion = '可以通过'

        # 直接调用方法
        communication_work_order.send(:set_status_based_on_processing_opinion)

        # 验证结果
        expect(communication_work_order.reload.status).to eq('approved')
      end

      it '关联的费用明细状态变更为verified' do
        # 设置处理意见为"可以通过"
        communication_work_order.processing_opinion = '可以通过'

        # 直接调用方法
        communication_work_order.send(:set_status_based_on_processing_opinion)

        # 验证费用明细状态
        expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
      end
    end

    context "处理意见设置为'无法通过'" do
      it '工单状态变更为rejected' do
        # 设置处理意见为"无法通过"
        communication_work_order.processing_opinion = '无法通过'

        # 直接调用方法
        communication_work_order.send(:set_status_based_on_processing_opinion)

        # 验证结果
        expect(communication_work_order.reload.status).to eq('rejected')
      end

      it '关联的费用明细状态变更为problematic' do
        # 设置处理意见为"无法通过"
        communication_work_order.processing_opinion = '无法通过'

        # 直接调用方法
        communication_work_order.send(:set_status_based_on_processing_opinion)

        # 验证费用明细状态
        expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
      end
    end
  end

  describe '多问题类型处理' do
    let(:another_problem_type) do
      ProblemType.create!(
        code: '02',
        title: '交通费超标',
        sop_description: '检查交通费是否超过标准',
        standard_handling: '要求提供说明',
        fee_type: fee_type,
        active: true
      )
    end

    let(:audit_work_order) do
      # 创建工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
      )

      work_order
    end

    it '支持添加多个问题类型' do
      # 设置多个问题类型
      audit_work_order.problem_type_ids = [problem_type.id, another_problem_type.id]

      # 直接调用方法
      audit_work_order.send(:process_problem_types)

      # 验证结果
      expect(audit_work_order.problem_types.count).to eq(2)
      expect(audit_work_order.problem_types).to include(problem_type, another_problem_type)
    end
  end

  describe '最新工单决定原则' do
    let(:audit_work_order_1) do
      # 创建第一个工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
      )

      work_order
    end

    let(:audit_work_order_2) do
      # 创建第二个工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
      )

      work_order
    end

    it '费用明细状态由最新工单决定' do
      # 第一个工单设置为拒绝
      audit_work_order_1.update_column(:status, 'rejected')
      audit_work_order_1.sync_fee_details_verification_status

      # 验证费用明细状态为problematic
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)

      # 第二个工单设置为通过
      audit_work_order_2.update_column(:status, 'approved')
      audit_work_order_2.sync_fee_details_verification_status

      # 验证费用明细状态变为verified
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)

      # 更新第二个工单的更新时间为更早的时间
      audit_work_order_2.update_column(:updated_at, 1.day.ago)

      # 重新触发第一个工单的状态更新
      audit_work_order_1.sync_fee_details_verification_status

      # 验证费用明细状态变回problematic
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
    end
  end

  describe '#approve' do
    let(:audit_work_order) do
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail
      )
      work_order
    end

    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }

    it '成功批准工单并更新状态' do
      result = service.approve(audit_comment: '审核通过')

      expect(result).to be true
      expect(audit_work_order.reload.status).to eq('approved')
      expect(audit_work_order.processing_opinion).to eq('可以通过')
      expect(audit_work_order.audit_comment).to eq('审核通过')
    end

    it '批准时设置审核日期' do
      result = service.approve

      expect(result).to be true
      expect(audit_work_order.reload.audit_date).to be_present
      expect(audit_work_order.audit_date).to be_a(Time)
    end

    it '批准时记录操作历史' do
      expect do
        service.approve(audit_comment: '测试批准')
      end.to change(WorkOrderOperation, :count).by(1)

      operation = WorkOrderOperation.last
      expect(operation.action).to eq('状态变更')
      expect(operation.new_value).to eq('approved')
    end

    it '批准后同步费用明细验证状态' do
      service.approve

      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
    end
  end

  describe '#reject' do
    let(:audit_work_order) do
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail
      )
      work_order
    end

    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }

    it '成功拒绝工单并更新状态' do
      result = service.reject(audit_comment: '存在问题')

      expect(result).to be true
      expect(audit_work_order.reload.status).to eq('rejected')
      expect(audit_work_order.processing_opinion).to eq('无法通过')
      expect(audit_work_order.audit_comment).to eq('存在问题')
    end

    it '拒绝时设置审核日期' do
      result = service.reject

      expect(result).to be true
      expect(audit_work_order.reload.audit_date).to be_present
    end

    it '拒绝时记录操作历史' do
      expect do
        service.reject(audit_comment: '测试拒绝')
      end.to change(WorkOrderOperation, :count).by(1)

      operation = WorkOrderOperation.last
      expect(operation.action).to eq('状态变更')
      expect(operation.new_value).to eq('rejected')
    end

    it '拒绝后同步费用明细验证状态' do
      service.reject

      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
    end
  end

  describe '#update' do
    let(:audit_work_order) do
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id,
        audit_comment: '初始审核意见'
      )
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail
      )
      work_order
    end

    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }

    it '更新工单属性' do
      result = service.update(audit_comment: '更新后的审核意见')

      expect(result).to be true
      expect(audit_work_order.reload.audit_comment).to eq('更新后的审核意见')
    end

    it '处理意见变更为"可以通过"时调用approve方法' do
      result = service.update(processing_opinion: '可以通过')

      expect(result).to be true
      expect(audit_work_order.reload.status).to eq('approved')
      expect(audit_work_order.processing_opinion).to eq('可以通过')
    end

    it '处理意见变更为"无法通过"时调用reject方法' do
      result = service.update(processing_opinion: '无法通过')

      expect(result).to be true
      expect(audit_work_order.reload.status).to eq('rejected')
      expect(audit_work_order.processing_opinion).to eq('无法通过')
    end

    it '更新时记录操作历史' do
      expect do
        service.update(audit_comment: '更新测试')
      end.to change(WorkOrderOperation, :count).by(1)

      operation = WorkOrderOperation.last
      expect(operation.action).to eq('更新')
    end

    context '工单已完成状态' do
      before do
        audit_work_order.update_column(:status, 'completed')
      end

      it '不允许修改' do
        result = service.update(audit_comment: '尝试修改')

        expect(result).to be false
        expect(audit_work_order.errors[:base]).to include('工单已完成，无法修改。')
      end
    end
  end

  describe '#mark_as_truly_completed' do
    let(:audit_work_order) do
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'approved',
        created_by: admin_user.id
      )
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail
      )
      work_order
    end

    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }

    it '成功标记工单为真正完成' do
      result = service.mark_as_truly_completed

      expect(result).to be true
      expect(audit_work_order.reload.is_truly_completed).to be true
      expect(audit_work_order.completed_at).to be_present
      expect(audit_work_order.completed_by_id).to eq(admin_user.id)
    end

    it '标记完成时记录操作历史' do
      expect do
        service.mark_as_truly_completed
      end.to change(WorkOrderOperation, :count).by(1)

      operation = WorkOrderOperation.last
      expect(operation.action).to eq('标记为真正完成')
    end

    context '当工单已经标记为完成' do
      before do
        audit_work_order.update_columns(
          is_truly_completed: true,
          completed_at: 1.day.ago,
          completed_by_id: admin_user.id
        )
      end

      it '返回错误' do
        result = service.mark_as_truly_completed

        expect(result).to be false
        expect(audit_work_order.errors[:base]).to include('工单已经标记为完成')
      end
    end
  end

  describe '#update_fee_detail_verification' do
    let(:audit_work_order) do
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail
      )
      work_order
    end

    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }

    it '成功更新费用明细验证状态' do
      result = service.update_fee_detail_verification(
        fee_detail.id,
        FeeDetail::VERIFICATION_STATUS_VERIFIED,
        '验证通过'
      )

      expect(result).to be true
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
    end

    it '费用明细不存在时返回错误' do
      result = service.update_fee_detail_verification(99999, 'verified', '测试')

      expect(result).to be false
      expect(audit_work_order.errors[:base].first).to include('费用明细 #99999 未找到')
    end

    context '工单已完成状态' do
      before do
        audit_work_order.update_column(:status, 'completed')
      end

      it '不允许修改费用明细验证状态' do
        result = service.update_fee_detail_verification(
          fee_detail.id,
          'verified',
          '尝试修改'
        )

        expect(result).to be false
        expect(audit_work_order.errors[:base]).to include('工单已完成，无法修改费用明细验证状态。')
      end
    end
  end

  describe '#process_action 统一逻辑' do
    let(:audit_work_order) do
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail
      )
      work_order
    end

    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }

    it 'approve和reject使用相同的process_action逻辑' do
      # Test approve
      result1 = service.approve
      expect(result1).to be true
      expect(audit_work_order.reload.status).to eq('approved')

      # Reset status for reject test
      audit_work_order.update_column(:status, 'pending')

      # Test reject
      result2 = service.reject
      expect(result2).to be true
      expect(audit_work_order.reload.status).to eq('rejected')
    end

    context '状态机异常处理' do
      it '捕获 StateMachines::InvalidTransition 异常' do
        # Set to a state that can't be approved
        audit_work_order.update_column(:status, 'completed')

        result = service.approve

        expect(result).to be false
        expect(audit_work_order.errors[:base].first).to include('无法批准工单')
      end
    end
  end

  describe '费用明细选择处理' do
    let(:audit_work_order) do
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )
      work_order
    end

    let(:fee_detail2) do
      FeeDetail.create!(
        external_fee_id: 'FEE002',
        document_number: reimbursement.invoice_number,
        fee_type: '月度餐费',
        amount: 200.0,
        fee_date: Date.today,
        verification_status: 'pending'
      )
    end

    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }

    it '处理费用明细选择' do
      service.send(:process_fee_detail_selections, [fee_detail.id, fee_detail2.id])

      expect(audit_work_order.work_order_fee_details.count).to eq(2)
      expect(audit_work_order.fee_details).to include(fee_detail, fee_detail2)
    end

    it '清除现有关联并创建新关联' do
      # Create initial association
      WorkOrderFeeDetail.create!(
        work_order: audit_work_order,
        fee_detail: fee_detail
      )

      expect(audit_work_order.work_order_fee_details.count).to eq(1)

      # Process new selections
      service.send(:process_fee_detail_selections, [fee_detail2.id])

      expect(audit_work_order.work_order_fee_details.count).to eq(1)
      expect(audit_work_order.fee_details).to eq([fee_detail2])
    end

    it '忽略不属于同一报销单的费用明细' do
      other_reimbursement = Reimbursement.create!(
        invoice_number: 'INV-002',
        document_name: '其他报销单',
        status: 'processing',
        is_electronic: true
      )

      other_fee_detail = FeeDetail.create!(
        external_fee_id: 'FEE003',
        document_number: other_reimbursement.invoice_number,
        fee_type: '月度交通费',
        amount: 300.0,
        fee_date: Date.today,
        verification_status: 'pending'
      )

      service.send(:process_fee_detail_selections, [fee_detail.id, other_fee_detail.id])

      expect(audit_work_order.work_order_fee_details.count).to eq(1)
      expect(audit_work_order.fee_details).to eq([fee_detail])
    end
  end

  describe '审核日期自动设置' do
    let(:audit_work_order) do
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail
      )
      work_order
    end

    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }

    it 'approve时自动设置audit_date' do
      freeze_time do
        service.approve

        expect(audit_work_order.reload.audit_date).to be_within(1.second).of(Time.current)
      end
    end

    it 'reject时自动设置audit_date' do
      freeze_time do
        service.reject

        expect(audit_work_order.reload.audit_date).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe '费用明细同步' do
    let(:audit_work_order) do
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail
      )
      work_order
    end

    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }

    it 'approve后调用sync_fee_details_verification_status' do
      expect(audit_work_order).to receive(:sync_fee_details_verification_status).and_call_original

      service.approve
    end

    it 'reject后调用sync_fee_details_verification_status' do
      expect(audit_work_order).to receive(:sync_fee_details_verification_status).and_call_original

      service.reject
    end
  end
end
