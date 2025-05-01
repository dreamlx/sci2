# spec/services/communication_work_order_service_spec.rb
require 'rails_helper'

RSpec.describe CommunicationWorkOrderService, type: :service do
  let(:reimbursement) { create(:reimbursement) }
  let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement) }
  let(:admin_user) { create(:admin_user) }
  
  subject { described_class.new(communication_work_order, admin_user) }
  
  describe "#start_processing" do
    it "starts processing the communication work order" do
      expect(subject.start_processing).to be_truthy
      expect(communication_work_order.status).to eq("processing")
    end
    
    it "adds errors if processing fails" do
      allow(communication_work_order).to receive(:start_processing!).and_raise(StandardError, "Test error")
      expect(subject.start_processing).to be_falsey
      expect(communication_work_order.errors.full_messages).to include("无法开始处理: Test error")
    end
  end
  
  describe "#toggle_needs_communication" do
    it "toggles the needs_communication flag to true when it was false" do
      communication_work_order.update_column(:needs_communication, false)
      expect(subject.toggle_needs_communication).to be_truthy
      expect(communication_work_order.reload.needs_communication).to be_truthy
    end
    
    it "toggles the needs_communication flag to false when it was true" do
      communication_work_order.update_column(:needs_communication, true)
      expect(subject.toggle_needs_communication).to be_truthy
      expect(communication_work_order.reload.needs_communication).to be_falsey
    end
    
    it "sets the needs_communication flag to the specified value" do
      communication_work_order.update_column(:needs_communication, false)
      expect(subject.toggle_needs_communication(true)).to be_truthy
      expect(communication_work_order.reload.needs_communication).to be_truthy
      
      expect(subject.toggle_needs_communication(true)).to be_truthy
      expect(communication_work_order.reload.needs_communication).to be_truthy
    end
    
    it "adds errors if update fails" do
      allow(communication_work_order).to receive(:update_column).and_raise(StandardError, "Test error")
      expect(subject.toggle_needs_communication).to be_falsey
      expect(communication_work_order.errors.full_messages).to include("无法更新沟通标志")
    end
  end
  
  describe "#approve" do
    it "approves the communication work order" do
      params = { resolution_summary: "All issues resolved" }
      expect(subject.approve(params)).to be_truthy
      expect(communication_work_order.status).to eq("approved")
      expect(communication_work_order.resolution_summary).to eq("All issues resolved")
    end
    
    it "adds errors if approval fails" do
      params = { resolution_summary: "All issues resolved" }
      allow(communication_work_order).to receive(:approve!).and_raise(StandardError, "Test error")
      expect(subject.approve(params)).to be_falsey
      expect(communication_work_order.errors.full_messages).to include("无法批准: Test error")
    end
    
    it "requires a resolution summary" do
      params = {}
      expect(subject.approve(params)).to be_falsey
      expect(communication_work_order.errors.full_messages).to include("无法批准: 必须填写拒绝理由/摘要")
    end
  end
  
  describe "#reject" do
    it "rejects the communication work order" do
      params = { resolution_summary: "Issues unresolved" }
      expect(subject.reject(params)).to be_truthy
      expect(communication_work_order.status).to eq("rejected")
      expect(communication_work_order.resolution_summary).to eq("Issues unresolved")
    end
    
    it "adds errors if rejection fails" do
      params = { resolution_summary: "Issues unresolved" }
      allow(communication_work_order).to receive(:reject!).and_raise(StandardError, "Test error")
      expect(subject.reject(params)).to be_falsey
      expect(communication_work_order.errors.full_messages).to include("无法拒绝: Test error")
    end
    
    it "requires a resolution summary" do
      params = {}
      expect(subject.reject(params)).to be_falsey
      expect(communication_work_order.errors.full_messages).to include("无法拒绝: 必须填写拒绝理由/摘要")
    end
  end
  
  describe "#add_communication_record" do
    it "adds a communication record" do
      params = {
        content: "Test communication",
        communicator_role: "auditor",
        communication_method: "email"
      }
      expect {
        subject.add_communication_record(params)
      }.to change(CommunicationRecord, :count).by(1)
      
      record = CommunicationRecord.last
      expect(record.content).to eq("Test communication")
      expect(record.communicator_role).to eq("auditor")
      expect(record.communication_method).to eq("email")
      expect(record.recorded_at).to be_within(1.second).of(Time.current)
    end
    
    it "sets communicator_name to current admin user's email if not provided" do
      params = {
        content: "Test communication",
        communicator_role: "auditor",
        communication_method: "email"
      }
      expect {
        subject.add_communication_record(params)
      }.to change(CommunicationRecord, :count).by(1)
      
      record = CommunicationRecord.last
      expect(record.communicator_name).to eq(admin_user.email)
    end
    
    it "adds errors if record creation fails" do
      params = {
        content: "Test communication",
        communicator_role: "auditor",
        communication_method: "email"
      }
      allow(communication_work_order).to receive(:add_communication_record).and_return(build(:communication_record, content: nil))
      expect(subject.add_communication_record(params)).to be_nil
      expect(communication_work_order.errors.full_messages).to include("添加沟通记录失败: Content can't be blank")
    end
  end
  
  describe "#select_fee_detail" do
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement) }
    
    it "selects a fee detail" do
      expect {
        subject.select_fee_detail(fee_detail)
      }.to change(FeeDetailSelection, :count).by(1)
      
      selection = FeeDetailSelection.last
      expect(selection.fee_detail_id).to eq(fee_detail.id)
      expect(selection.work_order_id).to eq(communication_work_order.id)
    end
    
    it "does not select a fee detail if it does not belong to the same reimbursement" do
      other_reimbursement = create(:reimbursement)
      other_fee_detail = create(:fee_detail, reimbursement: other_reimbursement)
      
      expect {
        subject.select_fee_detail(other_fee_detail)
      }.not_to change(FeeDetailSelection, :count)
    end
  end
  
  describe "#select_fee_details" do
    let(:fee_detail1) { create(:fee_detail, reimbursement: reimbursement) }
    let(:fee_detail2) { create(:fee_detail, reimbursement: reimbursement) }
    
    it "selects multiple fee details" do
      expect {
        subject.select_fee_details([fee_detail1.id, fee_detail2.id])
      }.to change(FeeDetailSelection, :count).by(2)
      
      selections = FeeDetailSelection.all
      expect(selections.map(&:fee_detail_id)).to include(fee_detail1.id, fee_detail2.id)
      expect(selections.map(&:work_order_id)).to all(eq(communication_work_order.id))
    end
    
    it "does not select fee details if they do not belong to the same reimbursement" do
      other_reimbursement = create(:reimbursement)
      other_fee_detail = create(:fee_detail, reimbursement: other_reimbursement)
      
      expect {
        subject.select_fee_details([other_fee_detail.id])
      }.not_to change(FeeDetailSelection, :count)
    end
  end
  
  describe "#update_fee_detail_verification" do
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement) }
    
    it "updates the verification status of a fee detail" do
      expect {
        subject.update_fee_detail_verification(fee_detail.id, 'verified', 'Test comment')
      }.not_to change(FeeDetailSelection, :count)
      
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('verified')
    end
    
    it "adds errors if the fee detail is not found" do
      expect(subject.update_fee_detail_verification(9999, 'verified', 'Test comment')).to be_falsey
      expect(communication_work_order.errors.full_messages).to include("无法更新费用明细验证状态: 未找到关联的费用明细 #9999")
    end
    
    it "adds errors if the verification update fails" do
      allow_any_instance_of(FeeDetailVerificationService).to receive(:update_verification_status).and_raise(StandardError, "Test error")
      expect(subject.update_fee_detail_verification(fee_detail.id, 'verified', 'Test comment')).to be_falsey
      expect(communication_work_order.errors.full_messages).to include("无法更新费用明细验证状态: Test error")
    end
  end
end