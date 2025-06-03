require 'rails_helper'

RSpec.describe WorkOrderService, type: :service do
  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: "INV-001",
      document_name: "个人报销单",
      status: "processing",
      is_electronic: true
    )
  end
  
  let(:fee_type) do
    FeeType.create!(
      code: "00",
      title: "月度交通费（销售/SMO/CO）",
      meeting_type: "个人",
      active: true
    )
  end
  
  let(:problem_type) do
    ProblemType.create!(
      code: "01",
      title: "燃油费行程问题",
      sop_description: "检查燃油费是否与行程匹配",
      standard_handling: "要求提供详细行程单",
      fee_type: fee_type,
      active: true
    )
  end
  
  let(:admin_user) do
    AdminUser.create!(
      email: "admin@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end
  
  let(:work_order) do
    AuditWorkOrder.create!(
      reimbursement: reimbursement,
      status: "pending",
      created_by: admin_user.id
    )
  end
  
  let(:fee_detail) do
    FeeDetail.create!(
      document_number: reimbursement.invoice_number,
      fee_type: "交通费",
      amount: 100.0,
      verification_status: "pending"
    )
  end
  
  before do
    # Create work order fee detail association
    WorkOrderFeeDetail.create!(
      work_order: work_order,
      fee_detail: fee_detail,
      work_order_type: work_order.type
    )
  end
  
  describe "#approve" do
    it "handles approval logic" do
      # Create a test service with a mock work order
      test_work_order = double("WorkOrder",
        may_approve?: true,
        approve: true,
        errors: double("errors", any?: false),
        reimbursement: reimbursement,
        is_a?: true,
        assign_attributes: nil,
        problem_type_id: nil
      )
      
      # Make sure is_a? returns true for WorkOrder
      allow(test_work_order).to receive(:is_a?).with(WorkOrder).and_return(true)
      
      # Create the service
      service = WorkOrderService.new(test_work_order, admin_user)
      
      # Test the approve method
      result = service.approve(audit_comment: "审核通过")
      
      # Verify the result
      expect(result).to be true
    end
    
    it "returns false if the work order cannot be approved" do
      # First approve the work order
      work_order.update(status: "approved")
      
      # Then try to approve it again
      service = WorkOrderService.new(work_order, admin_user)
      result = service.approve(audit_comment: "审核通过")
      
      expect(result).to be false
    end
  end
  
  describe "#reject" do
    it "handles rejection logic" do
      # Create a test service with a mock work order
      test_work_order = double("WorkOrder",
        may_reject?: true,
        reject: true,
        errors: double("errors", any?: false),
        reimbursement: reimbursement,
        is_a?: true,
        assign_attributes: nil,
        problem_type_id: nil
      )
      
      # Make sure is_a? returns true for WorkOrder
      allow(test_work_order).to receive(:is_a?).with(WorkOrder).and_return(true)
      
      # Create the service
      service = WorkOrderService.new(test_work_order, admin_user)
      
      # Test the reject method
      result = service.reject(
        audit_comment: "审核拒绝",
        problem_type_id: problem_type.id
      )
      
      # Verify the result
      expect(result).to be true
    end
    
    it "returns false if the work order cannot be rejected" do
      # First reject the work order
      work_order.update(status: "rejected")
      
      # Then try to reject it again
      service = WorkOrderService.new(work_order, admin_user)
      result = service.reject(
        audit_comment: "审核拒绝",
        problem_type_id: problem_type.id
      )
      
      expect(result).to be false
    end
  end
  
  describe "#update" do
    it "updates a work order" do
      # Mock the editable? method
      allow(work_order).to receive(:editable?).and_return(true)
      allow(work_order).to receive(:save).and_return(true)
      
      service = WorkOrderService.new(work_order, admin_user)
      result = service.update(
        audit_comment: "更新审核意见",
        remark: "备注信息"
      )
      
      expect(result).to be true
    end
    
    it "returns false if the work order is not editable" do
      # Mock the editable? method
      allow(work_order).to receive(:editable?).and_return(false)
      
      service = WorkOrderService.new(work_order, admin_user)
      result = service.update(audit_comment: "更新审核意见")
      
      expect(result).to be false
    end
  end
  
  describe "#assign_shared_attributes" do
    it "handles fee_type_id and finds a default problem_type" do
      # Create a test work order that can be assigned attributes
      test_work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # Create a service with the test work order
      service = WorkOrderService.new(test_work_order, admin_user)
      
      # Call the private method directly
      service.send(:assign_shared_attributes, {
        fee_type_id: fee_type.id,
        audit_comment: "测试审核意见"
      })
      
      # Verify the attributes were assigned
      expect(test_work_order.audit_comment).to eq("测试审核意见")
    end
    
    it "does not override problem_type_id if already set" do
      # Create another problem type
      another_problem_type = ProblemType.create!(
        code: "02",
        title: "交通费超标",
        sop_description: "检查交通费是否超过标准",
        standard_handling: "要求提供说明",
        fee_type: fee_type,
        active: true
      )
      
      # Set the problem_type_id
      work_order.update(problem_type_id: another_problem_type.id)
      
      service = WorkOrderService.new(work_order, admin_user)
      
      # Call the private method directly
      service.send(:assign_shared_attributes, {
        fee_type_id: fee_type.id,
        audit_comment: "测试审核意见"
      })
      
      # The problem_type_id should not change
      expect(work_order.problem_type_id).to eq(another_problem_type.id)
    end
  end
  
  describe "problem description auto-generation" do
    it "automatically fills audit_comment with standard_handling when problem_type_id is set but audit_comment is empty" do
      # Create a test work order
      test_work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # Create a service with the test work order
      service = WorkOrderService.new(test_work_order, admin_user)
      
      # Call the private method directly with problem_type_id but no audit_comment
      service.send(:assign_shared_attributes, {
        problem_type_id: problem_type.id
      })
      
      # Verify the audit_comment was filled with the standard_handling from the problem_type
      expect(test_work_order.audit_comment).to eq(problem_type.standard_handling)
    end
    
    it "does not override existing audit_comment when problem_type_id is set" do
      # Create a test work order with an existing audit_comment
      test_work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id,
        audit_comment: "已有的审核意见"
      )
      
      # Create a service with the test work order
      service = WorkOrderService.new(test_work_order, admin_user)
      
      # Call the private method directly with problem_type_id
      service.send(:assign_shared_attributes, {
        problem_type_id: problem_type.id
      })
      
      # Verify the audit_comment was not changed
      expect(test_work_order.audit_comment).to eq("已有的审核意见")
    end
  end
  
  describe "#update_fee_detail_verification" do
    it "updates fee detail verification status" do
      # Mock the editable? method
      allow(work_order).to receive(:editable?).and_return(true)
      
      # Mock the FeeDetailVerificationService
      verification_service = instance_double(FeeDetailVerificationService)
      allow(FeeDetailVerificationService).to receive(:new).with(admin_user).and_return(verification_service)
      allow(verification_service).to receive(:update_verification_status).and_return(true)
      
      service = WorkOrderService.new(work_order, admin_user)
      result = service.update_fee_detail_verification(fee_detail.id, "verified", "验证通过")
      
      expect(result).to be true
    end
    
    it "returns false if the fee detail is not found" do
      service = WorkOrderService.new(work_order, admin_user)
      result = service.update_fee_detail_verification(999, "verified", "验证通过")
      
      expect(result).to be false
    end
    
    it "returns false if the work order is not editable" do
      # Mark the work order as completed
      work_order.update(status: "completed")
      
      service = WorkOrderService.new(work_order, admin_user)
      result = service.update_fee_detail_verification(fee_detail.id, "verified", "验证通过")
      
      expect(result).to be false
    end
  end
end