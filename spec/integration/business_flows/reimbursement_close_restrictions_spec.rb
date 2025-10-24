# spec/integration/business_flows/reimbursement_close_restrictions_spec.rb

require 'rails_helper'

RSpec.describe 'Reimbursement Close Restrictions', type: :integration do
  let(:admin_user) { create(:admin_user) }

  before do
    Current.admin_user = admin_user
  end

  after do
    Current.admin_user = nil
  end

  describe 'INT-009: 报销单关闭后工单操作限制测试' do
    let!(:reimbursement) { create(:reimbursement) }
    let!(:fee_details) do
      create_list(:fee_detail, 3, document_number: reimbursement.invoice_number, verification_status: 'verified')
    end

    it 'prevents work order operations after reimbursement is closed' do
      # 1. 创建审核工单，使报销单变为processing
      audit_work_order = create(:audit_work_order, reimbursement: reimbursement)
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', fee_details.map(&:id))
      audit_work_order.process_fee_detail_selections

      # 验证报销单状态为processing
      reimbursement.reload
      expect(reimbursement.status).to eq('processing')

      # 2. 将报销单标记为close
      reimbursement.mark_as_close!

      # 3. 尝试创建新的沟通工单
      expect do
        comm_work_order = build(:communication_work_order, reimbursement: reimbursement)
        comm_work_order.instance_variable_set('@fee_detail_ids_to_select', fee_details.map(&:id))
        comm_work_order.save!
      end.to raise_error(ActiveRecord::RecordInvalid, /报销单已关闭/)

      # 4. 尝试修改现有审核工单
      expect do
        audit_work_order.update!(problem_type: '新问题类型')
      end.to raise_error(ActiveRecord::RecordInvalid, /报销单已关闭/)

      # 5. 验证报销单状态保持close
      expect(reimbursement.reload.status).to eq('close')
    end
  end

  describe 'REL-008: 报销单close状态触发条件' do
    let!(:reimbursement) { create(:reimbursement, status: 'processing') }
    let!(:fee_details) do
      create_list(:fee_detail, 3, document_number: reimbursement.invoice_number, verification_status: 'verified')
    end

    it 'requires user action to close reimbursement even when all fee details are verified' do
      # 验证所有费用明细已验证
      expect(reimbursement.all_fee_details_verified?).to be true

      # 验证报销单状态仍为processing
      expect(reimbursement.status).to eq('processing')

      # 模拟用户点击"处理完成"按钮
      reimbursement.mark_as_close!

      # 验证报销单状态变为close
      expect(reimbursement.reload.status).to eq('close')
    end
  end

  describe 'FEE-006: 费用明细状态对报销单close状态的影响' do
    let!(:reimbursement) { create(:reimbursement, status: 'processing') }
    let!(:fee_details) do
      create_list(:fee_detail, 3, document_number: reimbursement.invoice_number, verification_status: 'pending')
    end

    it 'requires all fee details to be verified before reimbursement can be closed' do
      # 验证不是所有费用明细都已验证
      expect(reimbursement.all_fee_details_verified?).to be false

      # 验证不能将报销单标记为close
      expect(reimbursement.can_mark_as_close?).to be false
      expect { reimbursement.mark_as_close! }.to raise_error(ActiveRecord::RecordInvalid, /存在未验证的费用明细/)

      # 将所有费用明细标记为已验证
      fee_details.each { |fd| fd.update(verification_status: 'verified') }

      # 验证所有费用明细已验证
      expect(reimbursement.all_fee_details_verified?).to be true

      # 验证可以将报销单标记为close
      expect(reimbursement.can_mark_as_close?).to be true
      expect { reimbursement.mark_as_close! }.not_to raise_error
      expect(reimbursement.reload.status).to eq('close')
    end
  end
end
