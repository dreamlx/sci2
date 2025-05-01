# spec/integration/models/needs_communication_flag_spec.rb
require 'rails_helper'

RSpec.describe "CommunicationWorkOrder needs_communication Flag", type: :model do
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let(:communication_work_order) { build(:communication_work_order, reimbursement: reimbursement) }
  
  before do
    communication_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
    communication_work_order.save!
    communication_work_order.process_fee_detail_selections
  end
  
  describe "needs_communication flag behavior" do
    it "defaults to false" do
      expect(communication_work_order.needs_communication).to be_falsey
    end
    
    it "can be set to true" do
      communication_work_order.needs_communication = true
      communication_work_order.save!
      communication_work_order.reload
      
      expect(communication_work_order.needs_communication).to be_truthy
    end
    
    it "can be toggled using mark_needs_communication! method" do
      expect(communication_work_order.needs_communication).to be_falsey
      
      communication_work_order.mark_needs_communication!
      communication_work_order.reload
      
      expect(communication_work_order.needs_communication).to be_truthy
    end
    
    it "can be toggled using unmark_needs_communication! method" do
      communication_work_order.mark_needs_communication!
      communication_work_order.reload
      expect(communication_work_order.needs_communication).to be_truthy
      
      communication_work_order.unmark_needs_communication!
      communication_work_order.reload
      
      expect(communication_work_order.needs_communication).to be_falsey
    end
  end
  
  describe "needs_communication flag with status transitions" do
    it "maintains flag value when status changes" do
      # Set needs_communication to true
      communication_work_order.mark_needs_communication!
      expect(communication_work_order.needs_communication).to be_truthy
      
      # Change status to processing
      communication_work_order.processing_opinion = "需要补充材料"
      communication_work_order.save!
      communication_work_order.reload
      
      # Flag should still be true
      expect(communication_work_order.status).to eq("processing")
      expect(communication_work_order.needs_communication).to be_truthy
      
      # Change status to approved
      communication_work_order.processing_opinion = "审核通过"
      communication_work_order.resolution_summary = "测试通过原因"
      communication_work_order.save!
      communication_work_order.reload
      
      # Flag should still be true
      expect(communication_work_order.status).to eq("approved")
      expect(communication_work_order.needs_communication).to be_truthy
    end
    
    it "can be changed independently of status" do
      # Set status to processing
      communication_work_order.processing_opinion = "需要补充材料"
      communication_work_order.save!
      communication_work_order.reload
      expect(communication_work_order.status).to eq("processing")
      expect(communication_work_order.needs_communication).to be_falsey
      
      # Set needs_communication to true
      communication_work_order.mark_needs_communication!
      communication_work_order.reload
      expect(communication_work_order.status).to eq("processing")
      expect(communication_work_order.needs_communication).to be_truthy
      
      # Set needs_communication to false
      communication_work_order.unmark_needs_communication!
      communication_work_order.reload
      expect(communication_work_order.status).to eq("processing")
      expect(communication_work_order.needs_communication).to be_falsey
    end
  end
  
  describe "needs_communication flag with service methods" do
    let(:admin_user) { create(:admin_user) }
    let(:service) { CommunicationWorkOrderService.new(communication_work_order, admin_user) }
    
    it "can be toggled using service toggle_needs_communication method" do
      expect(communication_work_order.needs_communication).to be_falsey
      
      service.toggle_needs_communication
      communication_work_order.reload
      
      expect(communication_work_order.needs_communication).to be_truthy
      
      service.toggle_needs_communication
      communication_work_order.reload
      
      expect(communication_work_order.needs_communication).to be_falsey
    end
    
    it "can be set to specific value using service toggle_needs_communication method" do
      expect(communication_work_order.needs_communication).to be_falsey
      
      service.toggle_needs_communication(true)
      communication_work_order.reload
      
      expect(communication_work_order.needs_communication).to be_truthy
      
      service.toggle_needs_communication(true) # Setting to true again
      communication_work_order.reload
      
      expect(communication_work_order.needs_communication).to be_truthy
      
      service.toggle_needs_communication(false)
      communication_work_order.reload
      
      expect(communication_work_order.needs_communication).to be_falsey
    end
  end
end