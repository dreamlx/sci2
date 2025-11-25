# spec/services/communication_work_order_service_spec.rb
require 'rails_helper'

RSpec.describe CommunicationWorkOrderService, type: :service do
  let(:reimbursement) { create(:reimbursement, status: 'processing') }  # 创建时就是processing状态，避免回调
  let(:communication_work_order) { build(:communication_work_order, reimbursement: reimbursement) }
  let(:admin_user) { create(:admin_user) }

  subject { described_class.new(communication_work_order, admin_user) }

  describe "#update" do
    it "updates the communication work order successfully" do
      params = { audit_comment: "Updated communication content" }
      expect(subject.update(params)).to be_truthy
      expect(communication_work_order.audit_comment).to eq("Updated communication content")
    end

    it "adds errors if update fails" do
      # Mock the save method to return false without triggering callbacks
      allow(communication_work_order).to receive(:save).and_return(false)
      allow(communication_work_order).to receive(:errors).and_return(double(full_messages: ["Update failed"]))

      params = { audit_comment: "Updated communication content" }
      expect(subject.update(params)).to be_falsey
    end
  end
end