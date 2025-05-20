# spec/models/reimbursement_close_restrictions_spec.rb

require 'rails_helper'

RSpec.describe "Reimbursement Close Restrictions", type: :model do
  describe "WF-CL-003: close状态下禁止创建新工单" do
    let(:reimbursement) { create(:reimbursement, status: 'close') }
    
    it "prevents creating new audit work orders" do
      expect {
        create(:audit_work_order, reimbursement: reimbursement)
      }.to raise_error(ActiveRecord::RecordInvalid, /报销单已关闭/)
    end
    
    it "prevents creating new communication work orders" do
      expect {
        create(:communication_work_order, reimbursement: reimbursement)
      }.to raise_error(ActiveRecord::RecordInvalid, /报销单已关闭/)
    end
  end
  
  describe "WF-CL-004: close状态下禁止修改现有工单" do
    let(:reimbursement) { create(:reimbursement) }
    let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }
    
    before do
      # 创建工单后将报销单关闭
      reimbursement.update(status: 'close')
    end
    
    it "prevents updating existing work orders" do
      expect {
        audit_work_order.update!(problem_type: "新问题类型")
      }.to raise_error(ActiveRecord::RecordInvalid, /报销单已关闭/)
    end
    
    it "prevents changing work order status" do
      expect {
        audit_work_order.start_processing!
      }.to raise_error(AASM::InvalidTransition, /报销单已关闭/)
    end
  end
end