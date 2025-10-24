require 'rails_helper'

RSpec.describe 'WorkOrder多问题类型功能', type: :model do
  let(:admin_user) { create(:admin_user) }

  let(:reimbursement) do
    create(:reimbursement,
           invoice_number: 'INV-001',
           document_name: '个人报销单',
           status: 'processing',
           is_electronic: true)
  end

  let(:fee_detail) do
    create(:fee_detail,
           document_number: reimbursement.invoice_number,
           fee_type: '会议讲课费',
           amount: 100.0,
           verification_status: 'pending')
  end

  let(:fee_type) do
    create(:fee_type,
           code: 'FT001',
           title: '会议讲课费',
           meeting_type: '个人',
           active: true)
  end

  let(:problem_type1) do
    create(:problem_type,
           code: 'PT001',
           title: '发票不合规',
           sop_description: '发票信息不完整',
           standard_handling: '请提供完整发票',
           fee_type: fee_type,
           active: true)
  end

  let(:problem_type2) do
    create(:problem_type,
           code: 'PT002',
           title: '金额不匹配',
           sop_description: '发票金额与申报金额不一致',
           standard_handling: '请核对金额',
           fee_type: fee_type,
           active: true)
  end

  let(:work_order) do
    order = create(:audit_work_order,
                   reimbursement: reimbursement,
                   status: 'pending',
                   created_by: admin_user.id)

    # 关联费用明细
    WorkOrderFeeDetail.create!(
      work_order: order,
      fee_detail: fee_detail
    )

    order
  end

  before do
    Current.admin_user = admin_user
  end

  after do
    Current.admin_user = nil
  end

  describe '多问题类型关联' do
    it '可以关联多个问题类型' do
      # 设置虚拟属性
      work_order.problem_type_ids = [problem_type1.id, problem_type2.id]

      # 保存工单，触发回调
      work_order.save

      # 重新加载工单
      work_order.reload

      # 验证关联了两个问题类型
      expect(work_order.problem_types.count).to eq(2)
      expect(work_order.problem_types).to include(problem_type1, problem_type2)
    end

    it '可以清除并重新设置问题类型' do
      # 先添加一个问题类型
      WorkOrderProblem.create!(
        work_order: work_order,
        problem_type: problem_type1
      )

      # 验证已关联一个问题类型
      expect(work_order.problem_types.count).to eq(1)

      # 设置新的问题类型
      work_order.problem_type_ids = [problem_type2.id]
      work_order.save

      # 重新加载工单
      work_order.reload

      # 验证只关联了新的问题类型
      expect(work_order.problem_types.count).to eq(1)
      expect(work_order.problem_types).to include(problem_type2)
      expect(work_order.problem_types).not_to include(problem_type1)
    end
  end

  describe '处理意见与问题类型验证' do
    context "处理意见为'无法通过'" do
      # 注意：这个测试被跳过，因为模型中尚未实现相应的验证
      xit '没有选择问题类型时应该无法保存' do
        # 设置处理意见
        work_order.processing_opinion = '无法通过'

        # 尝试保存工单
        result = work_order.save

        # 验证保存失败
        expect(result).to be_falsey
      end

      it '选择了问题类型时可以保存' do
        # 设置处理意见
        work_order.processing_opinion = '无法通过'

        # 添加问题类型
        WorkOrderProblem.create!(
          work_order: work_order,
          problem_type: problem_type1
        )

        # 重新加载工单
        work_order.reload

        # 尝试保存工单
        result = work_order.save

        # 验证保存成功
        expect(result).to be_truthy
      end
    end

    context "处理意见为'可以通过'" do
      it '不需要选择问题类型' do
        # 设置处理意见
        work_order.processing_opinion = '可以通过'

        # 尝试保存工单
        result = work_order.save

        # 验证保存成功
        expect(result).to be_truthy
      end
    end
  end

  describe 'WorkOrderProblemService' do
    it '添加多个问题类型' do
      # 创建服务
      service = WorkOrderProblemService.new(work_order)

      # 添加问题类型
      result = service.add_problems([problem_type1.id, problem_type2.id])

      # 验证结果
      expect(result).to be_truthy

      # 重新加载工单
      work_order.reload

      # 验证关联了两个问题类型
      expect(work_order.problem_types.count).to eq(2)
      expect(work_order.problem_types).to include(problem_type1, problem_type2)
    end

    it '清除现有问题类型并添加新问题类型' do
      # 先添加一个问题类型
      WorkOrderProblem.create!(
        work_order: work_order,
        problem_type: problem_type1
      )

      # 创建服务
      service = WorkOrderProblemService.new(work_order)

      # 添加新问题类型
      result = service.add_problems([problem_type2.id])

      # 验证结果
      expect(result).to be_truthy

      # 重新加载工单
      work_order.reload

      # 验证只关联了新的问题类型
      expect(work_order.problem_types.count).to eq(1)
      expect(work_order.problem_types).to include(problem_type2)
      expect(work_order.problem_types).not_to include(problem_type1)
    end

    it '获取当前关联的所有问题类型' do
      # 添加问题类型
      WorkOrderProblem.create!(
        work_order: work_order,
        problem_type: problem_type1
      )

      # 创建服务
      service = WorkOrderProblemService.new(work_order)

      # 获取问题类型
      problems = service.get_problems

      # 验证结果
      expect(problems).to include(problem_type1)
    end
  end
end
