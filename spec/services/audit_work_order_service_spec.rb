# spec/services/audit_work_order_service_spec.rb
require 'rails_helper'

RSpec.describe AuditWorkOrderService, type: :service do
  let(:reimbursement) { create(:reimbursement) }
  let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }
  let(:admin_user) { create(:admin_user) }

  subject { described_class.new(audit_work_order, admin_user) }

  describe '#start_processing' do
    it 'starts processing the audit work order' do
      expect(subject.start_processing).to be_truthy
      expect(audit_work_order.status).to eq('processing')
    end

    it 'adds errors if processing fails' do
      allow(audit_work_order).to receive(:start_processing!).and_raise(StandardError, 'Test error')
      expect(subject.start_processing).to be_falsey
      expect(audit_work_order.errors.full_messages).to include('无法开始处理: Test error')
    end
  end

  describe '#approve' do
    it 'approves the audit work order' do
      params = { audit_comment: 'All issues resolved' }
      expect(subject.approve(params)).to be_truthy
      expect(audit_work_order.status).to eq('approved')
      expect(audit_work_order.audit_comment).to eq('All issues resolved')
      expect(audit_work_order.audit_date).to be_within(1.second).of(Time.current)
    end

    it 'adds errors if approval fails' do
      params = { audit_comment: 'All issues resolved' }
      allow(audit_work_order).to receive(:approve!).and_raise(StandardError, 'Test error')
      expect(subject.approve(params)).to be_falsey
      expect(audit_work_order.errors.full_messages).to include('无法批准: Test error')
    end

    # 移除批准时要求填写评论的测试，因为设计文档中只要求拒绝时需要填写评论
  end

  describe '#reject' do
    it 'rejects the audit work order' do
      params = { audit_comment: 'Issues unresolved' }
      expect(subject.reject(params)).to be_truthy
      expect(audit_work_order.status).to eq('rejected')
      expect(audit_work_order.audit_comment).to eq('Issues unresolved')
      expect(audit_work_order.audit_date).to be_within(1.second).of(Time.current)
    end

    it 'adds errors if rejection fails' do
      params = { audit_comment: 'Issues unresolved' }
      allow(audit_work_order).to receive(:reject!).and_raise(StandardError, 'Test error')
      expect(subject.reject(params)).to be_falsey
      expect(audit_work_order.errors.full_messages).to include('无法拒绝: Test error')
    end

    it 'requires an audit comment' do
      params = {}
      expect(subject.reject(params)).to be_falsey
      expect(audit_work_order.errors.full_messages).to include('无法拒绝: 必须填写拒绝理由')
    end
  end

  describe '#select_fee_detail' do
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement) }

    it 'selects a fee detail' do
      expect do
        subject.select_fee_detail(fee_detail)
      end.to change(WorkOrderFeeDetail, :count).by(1)

      selection = WorkOrderFeeDetail.last
      expect(selection.fee_detail_id).to eq(fee_detail.id)
      expect(selection.work_order_id).to eq(audit_work_order.id)
    end

    it 'does not select a fee detail if it does not belong to the same reimbursement' do
      other_reimbursement = create(:reimbursement)
      other_fee_detail = create(:fee_detail, reimbursement: other_reimbursement)

      expect do
        subject.select_fee_detail(other_fee_detail)
      end.not_to change(WorkOrderFeeDetail, :count)
    end
  end

  describe '#select_fee_details' do
    let(:fee_detail1) { create(:fee_detail, reimbursement: reimbursement) }
    let(:fee_detail2) { create(:fee_detail, reimbursement: reimbursement) }

    it 'selects multiple fee details' do
      expect do
        subject.select_fee_details([fee_detail1.id, fee_detail2.id])
      end.to change(WorkOrderFeeDetail, :count).by(2)

      selections = WorkOrderFeeDetail.all
      expect(selections.map(&:fee_detail_id)).to include(fee_detail1.id, fee_detail2.id)
      expect(selections.map(&:work_order_id)).to all(eq(audit_work_order.id))
    end

    it 'does not select fee details if they do not belong to the same reimbursement' do
      other_reimbursement = create(:reimbursement)
      other_fee_detail = create(:fee_detail, reimbursement: other_reimbursement)

      expect do
        subject.select_fee_details([other_fee_detail.id])
      end.not_to change(WorkOrderFeeDetail, :count)
    end
  end

  describe '#update_fee_detail_verification' do
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement) }

    it 'updates the verification status of a fee detail' do
      expect do
        subject.update_fee_detail_verification(fee_detail.id, 'verified', 'Test comment')
      end.not_to change(WorkOrderFeeDetail, :count)

      fee_detail.reload
      expect(fee_detail.verification_status).to eq('verified')
    end

    it 'adds errors if the fee detail is not found' do
      expect(subject.update_fee_detail_verification(9999, 'verified', 'Test comment')).to be_falsey
      expect(audit_work_order.errors.full_messages).to include('无法更新费用明细验证状态: 未找到关联的费用明细 #9999')
    end

    it 'adds errors if the verification update fails' do
      allow_any_instance_of(FeeDetailVerificationService).to receive(:update_verification_status).and_raise(
        StandardError, 'Test error'
      )
      expect(subject.update_fee_detail_verification(fee_detail.id, 'verified', 'Test comment')).to be_falsey
      expect(audit_work_order.errors.full_messages).to include('无法更新费用明细验证状态: Test error')
    end
  end
end
