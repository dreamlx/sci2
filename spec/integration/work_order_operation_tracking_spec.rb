require 'rails_helper'

RSpec.describe "Work Order Operation Tracking", type: :integration do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  let(:problem_type) { create(:problem_type) }
  
  before do
    Current.admin_user = admin_user
  end
  
  describe "WorkOrderService integration" do
    let(:work_order) { build(:audit_work_order, reimbursement: reimbursement) }
    let(:service) { WorkOrderService.new(work_order, admin_user) }
    
    it "records create operation when creating a work order" do
      # Set up the work order with necessary attributes
      work_order.assign_attributes(
        reimbursement: reimbursement,
        created_by: admin_user.id
      )
      
      # Save the work order using the service
      expect {
        service.update({})
      }.to change(WorkOrderOperation, :count).by(1)
      
      # Verify the operation
      operation = WorkOrderOperation.last
      expect(operation.work_order).to eq(work_order)
      expect(operation.admin_user).to eq(admin_user)
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_UPDATE)
    end
    
    context "with an existing work order" do
      let!(:work_order) { create(:audit_work_order, reimbursement: reimbursement, created_by: admin_user.id) }
      let(:service) { WorkOrderService.new(work_order, admin_user) }
      
      it "records update operation when updating a work order" do
        expect {
          service.update(remark: "Updated remark")
        }.to change(WorkOrderOperation, :count).by(1)
        
        # Verify the operation
        operation = WorkOrderOperation.last
        expect(operation.work_order).to eq(work_order)
        expect(operation.admin_user).to eq(admin_user)
        expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_UPDATE)
        expect(operation.previous_state_hash).to include("remark" => nil)
        expect(operation.current_state_hash).to include("remark" => "Updated remark")
      end
      
      it "calls the operation service when approving a work order" do
        # Mock the record_status_change method to verify it's called
        expect_any_instance_of(WorkOrderOperationService).to receive(:record_status_change)
        
        # Call the approve method
        service.approve(processing_opinion: "可以通过", audit_comment: "Approved")
      end
      
      it "calls the operation service when rejecting a work order" do
        # Mock the record_status_change method to verify it's called
        expect_any_instance_of(WorkOrderOperationService).to receive(:record_status_change)
        
        # Call the reject method
        service.reject(processing_opinion: "无法通过", audit_comment: "Rejected", problem_type_id: problem_type.id)
      end
    end
  end
  
  describe "WorkOrderProblemService integration" do
    let!(:work_order) { create(:audit_work_order, reimbursement: reimbursement, created_by: admin_user.id) }
    let(:problem_service) { WorkOrderProblemService.new(work_order, admin_user) }
    
    it "records add_problem operation when adding a problem" do
      expect {
        problem_service.add_problem(problem_type.id)
      }.to change(WorkOrderOperation, :count).by(1)
      
      # Verify the operation
      operation = WorkOrderOperation.last
      expect(operation.work_order).to eq(work_order)
      expect(operation.admin_user).to eq(admin_user)
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM)
      expect(operation.details_hash).to include("problem_type_id" => problem_type.id)
    end
    
    context "with an existing problem" do
      before do
        problem_service.add_problem(problem_type.id)
        # Clear operations to start fresh
        WorkOrderOperation.delete_all
      end
      
      it "records remove_problem operation when clearing problems" do
        expect {
          problem_service.clear_problems
        }.to change(WorkOrderOperation, :count).by(1)
        
        # Verify the operation
        operation = WorkOrderOperation.last
        expect(operation.work_order).to eq(work_order)
        expect(operation.admin_user).to eq(admin_user)
        expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM)
      end
      
      it "records modify_problem operation when modifying a problem" do
        new_content = "Modified problem content"
        
        expect {
          problem_service.modify_problem(problem_type.id, new_content)
        }.to change(WorkOrderOperation, :count).by(1)
        
        # Verify the operation
        operation = WorkOrderOperation.last
        expect(operation.work_order).to eq(work_order)
        expect(operation.admin_user).to eq(admin_user)
        expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM)
        expect(operation.current_state_hash).to include("audit_comment" => new_content)
      end
    end
  end
end