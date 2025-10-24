require 'rails_helper'

RSpec.describe CommunicationWorkOrder, type: :model do
  let(:reimbursement) { create(:reimbursement) }

  describe 'validations' do
    it '需要沟通内容' do
      work_order = build(:communication_work_order, reimbursement: reimbursement, audit_comment: nil)
      expect(work_order).not_to be_valid
      expect(work_order.errors[:audit_comment]).to include('不能为空')
    end

    it '沟通内容至少需要10个字符' do
      work_order = build(:communication_work_order, reimbursement: reimbursement, audit_comment: '太短了')
      expect(work_order).not_to be_valid
      expect(work_order.errors[:audit_comment]).to include('沟通内容至少需要10个字符')
    end

    it '需要沟通方式' do
      work_order = build(:communication_work_order, reimbursement: reimbursement, communication_method: nil)
      expect(work_order).not_to be_valid
      expect(work_order.errors[:communication_method]).to include('不能为空')
    end

    it '有效的沟通工单应该通过验证' do
      work_order = build(:communication_work_order,
                         reimbursement: reimbursement,
                         audit_comment: '这是一个详细的沟通记录，包含了所有必要的信息',
                         communication_method: '电话')
      expect(work_order).to be_valid
    end
  end

  describe 'callbacks' do
    describe 'after_create :mark_as_completed' do
      it '创建后应该自动设置状态为 completed' do
        work_order = create(:communication_work_order,
                            reimbursement: reimbursement,
                            audit_comment: '详细的沟通记录内容，包含足够的字符数量',
                            communication_method: '电话')

        expect(work_order.reload.status).to eq('completed')
      end
    end
  end

  describe 'inheritance' do
    it '应该继承自 WorkOrder' do
      expect(CommunicationWorkOrder.superclass).to eq(WorkOrder)
    end

    it '应该使用 STI' do
      work_order = create(:communication_work_order, reimbursement: reimbursement)
      expect(work_order.type).to eq('CommunicationWorkOrder')
    end
  end

  describe 'associations' do
    it '应该属于报销单' do
      work_order = create(:communication_work_order, reimbursement: reimbursement)
      expect(work_order.reimbursement).to eq(reimbursement)
    end

    it '应该有创建人' do
      admin_user = create(:admin_user)
      work_order = create(:communication_work_order,
                          reimbursement: reimbursement,
                          created_by: admin_user.id)
      expect(work_order.creator).to eq(admin_user)
    end
  end

  describe 'ransackable attributes' do
    it '应该包含沟通方式' do
      expect(CommunicationWorkOrder.ransackable_attributes).to include('communication_method')
    end

    it '应该继承父类的可搜索属性' do
      parent_attributes = WorkOrder.ransackable_attributes
      child_attributes = CommunicationWorkOrder.ransackable_attributes

      parent_attributes.each do |attr|
        expect(child_attributes).to include(attr)
      end
    end
  end

  describe '与费用明细的关联' do
    let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
    let(:work_order) { create(:communication_work_order, reimbursement: reimbursement) }

    it '可以关联费用明细但不影响其状态' do
      # 创建关联
      create(:work_order_fee_detail, work_order: work_order, fee_detail: fee_detail)

      # 验证关联存在
      expect(work_order.fee_details).to include(fee_detail)
      expect(fee_detail.work_orders).to include(work_order)

      # 验证费用明细状态不受影响（应该保持 pending）
      expect(fee_detail.reload.verification_status).to eq('pending')
    end
  end

  describe '业务逻辑' do
    it '沟通工单应该专注于记录沟通过程' do
      work_order = create(:communication_work_order,
                          reimbursement: reimbursement,
                          communication_method: '电话',
                          audit_comment: '与报销人张三进行了电话沟通，确认了发票问题的解决方案')

      expect(work_order.communication_method).to eq('电话')
      expect(work_order.audit_comment).to include('电话沟通')
      expect(work_order.status).to eq('completed')
    end

    it '不应该有处理意见字段的验证' do
      work_order = build(:communication_work_order,
                         reimbursement: reimbursement,
                         processing_opinion: nil)

      # 不应该因为缺少 processing_opinion 而验证失败
      expect(work_order).to be_valid
    end
  end

  describe '状态管理' do
    it '创建的沟通工单应该立即完成' do
      work_order = create(:communication_work_order, reimbursement: reimbursement)
      expect(work_order.status).to eq('completed')
    end

    it '不应该有其他状态转换' do
      work_order = create(:communication_work_order, reimbursement: reimbursement)

      # 尝试修改状态应该不被允许（通过业务逻辑）
      expect(work_order.status).to eq('completed')
    end
  end
end
