require 'rails_helper'

RSpec.describe '问题描述生成功能', type: :model do
  let(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }

  # 创建费用类型
  let!(:fee_type1) do
    FeeType.create!(
      code: '00',
      title: '月度交通费',
      meeting_type: '个人',
      active: true
    )
  end

  let!(:fee_type2) do
    FeeType.create!(
      code: '01',
      title: '住宿费',
      meeting_type: '个人',
      active: true
    )
  end

  # 创建问题类型
  let!(:problem_type1) do
    ProblemType.create!(
      code: '01',
      title: '燃油费行程问题',
      sop_description: '根据SOP规定需提供行程',
      standard_handling: '请补充行程信息',
      fee_type: fee_type1,
      active: true
    )
  end

  let!(:problem_type2) do
    ProblemType.create!(
      code: '02',
      title: '金额超标',
      sop_description: '检查金额是否超过规定限额',
      standard_handling: '要求说明超标原因',
      fee_type: fee_type1,
      active: true
    )
  end

  let!(:problem_type3) do
    ProblemType.create!(
      code: '01',
      title: '住宿天数与行程不符',
      sop_description: '核对住宿天数与行程安排',
      standard_handling: '要求提供行程说明',
      fee_type: fee_type2,
      active: true
    )
  end

  # 创建费用明细
  let!(:fee_detail) do
    FeeDetail.create!(
      document_number: 'R202501001',
      fee_type: '交通费',
      amount: 100.00,
      verification_status: 'pending'
    )
  end

  describe 'WorkOrderService 问题描述自动生成' do
    it '当选择问题类型但审核意见为空时，自动填充标准处理方法' do
      # 创建审核工单
      work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 创建服务
      service = WorkOrderService.new(work_order, admin_user)

      # 调用 assign_shared_attributes 方法，只设置 problem_type_id
      service.send(:assign_shared_attributes, {
                     problem_type_id: problem_type1.id
                   })

      # 验证审核意见是否自动填充了标准处理方法
      expect(work_order.audit_comment).to eq(problem_type1.standard_handling)
    end

    it '当已有审核意见时，不会被覆盖' do
      # 创建带有审核意见的审核工单
      work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id,
        audit_comment: '已有的审核意见',
        problem_type_id: problem_type1.id # 先设置问题类型
      )

      # 保存工单，确保问题类型已经设置
      work_order.save!

      # 创建服务
      service = WorkOrderService.new(work_order, admin_user)

      # 调用 update 方法，不包含 problem_type_id 参数
      service.update(
        remark: '新备注'
      )

      # 验证审核意见没有被覆盖
      expect(work_order.audit_comment).to eq('已有的审核意见')
    end

    it '当选择费用类型但没有选择问题类型时，自动选择第一个问题类型' do
      # 创建审核工单
      work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 创建服务
      service = WorkOrderService.new(work_order, admin_user)

      # 调用 assign_shared_attributes 方法，只设置 fee_type_id
      service.send(:assign_shared_attributes, {
                     fee_type_id: fee_type1.id
                   })

      # 验证问题类型是否自动设置为第一个问题类型
      expect(work_order.problem_type_id).to eq(problem_type1.id)

      # 验证审核意见是否自动填充了标准处理方法
      expect(work_order.audit_comment).to eq(problem_type1.standard_handling)
    end

    it '当选择不同的问题类型时，更新审核意见' do
      # 创建审核工单
      work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 创建服务
      service = WorkOrderService.new(work_order, admin_user)

      # 先选择第一个问题类型
      service.send(:assign_shared_attributes, {
                     problem_type_id: problem_type1.id
                   })

      # 验证审核意见是否自动填充了第一个问题类型的标准处理方法
      expect(work_order.audit_comment).to eq(problem_type1.standard_handling)

      # 然后选择第二个问题类型
      service.send(:assign_shared_attributes, {
                     problem_type_id: problem_type2.id
                   })

      # 验证审核意见是否更新为第二个问题类型的标准处理方法
      expect(work_order.audit_comment).to eq(problem_type2.standard_handling)
    end
  end

  describe 'ProblemType 模型关联' do
    it '通过费用类型筛选问题类型' do
      # 使用 by_fee_type 作用域查询问题类型
      problem_types = ProblemType.by_fee_type(fee_type1.id)

      # 验证结果只包含与指定费用类型关联的问题类型
      expect(problem_types).to include(problem_type1, problem_type2)
      expect(problem_types).not_to include(problem_type3)
    end

    it '只返回激活的问题类型' do
      # 将一个问题类型设为非激活
      problem_type2.update(active: false)

      # 使用 active 作用域查询问题类型
      active_problem_types = ProblemType.active

      # 验证结果只包含激活的问题类型
      expect(active_problem_types).to include(problem_type1, problem_type3)
      expect(active_problem_types).not_to include(problem_type2)
    end

    it '组合使用 active 和 by_fee_type 作用域' do
      # 将一个问题类型设为非激活
      problem_type2.update(active: false)

      # 组合使用作用域查询问题类型
      problem_types = ProblemType.active.by_fee_type(fee_type1.id)

      # 验证结果只包含激活的且与指定费用类型关联的问题类型
      expect(problem_types).to include(problem_type1)
      expect(problem_types).not_to include(problem_type2, problem_type3)
    end
  end

  describe '工单状态与费用明细状态联动' do
    it '拒绝工单将关联的费用明细状态设为 problematic' do
      # 创建审核工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
        work_order_type: work_order.type
      )

      # 拒绝工单
      work_order.update(status: 'rejected')

      # 重新加载费用明细
      fee_detail.reload

      # 验证费用明细状态是否更新为 problematic
      expect(fee_detail.verification_status).to eq('problematic')
    end

    it '通过工单将关联的费用明细状态设为 verified' do
      # 创建审核工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
        work_order_type: work_order.type
      )

      # 通过工单
      work_order.update(status: 'approved')

      # 重新加载费用明细
      fee_detail.reload

      # 验证费用明细状态是否更新为 verified
      expect(fee_detail.verification_status).to eq('verified')
    end

    it "遵循'最新工单决定'原则" do
      # 创建第一个审核工单（状态为 rejected）
      work_order1 = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'rejected', # 直接设置为 rejected
        created_by: admin_user.id,
        created_at: 1.day.ago,
        audit_comment: '拒绝原因'
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order1,
        fee_detail: fee_detail,
        work_order_type: work_order1.type
      )

      # 手动触发费用明细状态更新
      FeeDetailStatusService.new([fee_detail.id]).update_status

      # 验证费用明细状态是否更新为 problematic
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('problematic')

      # 创建第二个审核工单（状态为 approved）
      work_order2 = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'approved', # 直接设置为 approved
        created_by: admin_user.id,
        created_at: Time.current,
        audit_comment: '通过原因'
      )

      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order2,
        fee_detail: fee_detail,
        work_order_type: work_order2.type
      )

      # 手动触发费用明细状态更新
      FeeDetailStatusService.new([fee_detail.id]).update_status

      # 验证费用明细状态是否更新为 verified（根据最新工单决定）
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('verified')
    end
  end
end
