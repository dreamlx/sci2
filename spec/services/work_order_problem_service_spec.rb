require 'rails_helper'

RSpec.describe WorkOrderProblemService, type: :service do
  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: "INV-001",
      document_name: "个人报销单",
      status: "processing",
      is_electronic: true
    )
  end
  
  let(:work_order) do
    AuditWorkOrder.create!(
      reimbursement: reimbursement,
      status: "pending",
      created_by: nil
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
  
  let(:another_problem_type) do
    ProblemType.create!(
      code: "02",
      title: "交通费超标",
      sop_description: "检查交通费是否超过标准",
      standard_handling: "要求提供说明",
      fee_type: fee_type,
      active: true
    )
  end
  
  describe "#add_problem" do
    it "adds a single problem type" do
      service = WorkOrderProblemService.new(work_order)
      result = service.add_problem(problem_type.id)
      
      expect(result).to be true
      expect(work_order.problem_types).to include(problem_type)
    end
    
    it "does not add duplicate problem type" do
      service = WorkOrderProblemService.new(work_order)
      service.add_problem(problem_type.id)
      
      # 尝试再次添加同一问题类型
      expect {
        service.add_problem(problem_type.id)
      }.not_to change { work_order.work_order_problems.count }
    end
  end
  
  describe "#add_problems" do
    it "adds multiple problem types" do
      service = WorkOrderProblemService.new(work_order)
      result = service.add_problems([problem_type.id, another_problem_type.id])
      
      expect(result).to be true
      expect(work_order.problem_types).to include(problem_type, another_problem_type)
    end
    
    it "replaces existing problem types" do
      # 先添加一个问题类型
      service = WorkOrderProblemService.new(work_order)
      service.add_problem(problem_type.id)
      
      # 然后添加另一个问题类型，替换现有的
      result = service.add_problems([another_problem_type.id])
      
      expect(result).to be true
      expect(work_order.problem_types).to include(another_problem_type)
      expect(work_order.problem_types).not_to include(problem_type)
    end
    
    it "returns false if problem_type_ids is blank" do
      service = WorkOrderProblemService.new(work_order)
      result = service.add_problems([])
      
      expect(result).to be false
    end
  end
  
  describe "#remove_problem" do
    it "removes a problem type" do
      service = WorkOrderProblemService.new(work_order)
      service.add_problem(problem_type.id)
      
      result = service.remove_problem(problem_type.id)
      
      expect(result).to be true
      expect(work_order.problem_types).not_to include(problem_type)
    end
    
    it "returns true even if problem type was not associated" do
      service = WorkOrderProblemService.new(work_order)
      result = service.remove_problem(problem_type.id)
      
      expect(result).to be true
    end
  end
  
  describe "#clear_problems" do
    it "removes all problem types" do
      service = WorkOrderProblemService.new(work_order)
      service.add_problems([problem_type.id, another_problem_type.id])
      
      result = service.clear_problems
      
      expect(result).to be true
      expect(work_order.problem_types).to be_empty
    end
    
    it "clears audit_comment if present" do
      work_order.update(audit_comment: "测试审核意见")
      service = WorkOrderProblemService.new(work_order)
      
      service.clear_problems
      
      expect(work_order.reload.audit_comment).to be_nil
    end
    
    it "clears problem_type_id if present" do
      work_order.update(problem_type_id: problem_type.id)
      service = WorkOrderProblemService.new(work_order)
      
      service.clear_problems
      
      expect(work_order.reload.problem_type_id).to be_nil
    end
  end
  
  describe "#get_problems" do
    it "returns all associated problem types" do
      service = WorkOrderProblemService.new(work_order)
      service.add_problems([problem_type.id, another_problem_type.id])
      
      problems = service.get_problems
      
      expect(problems).to include(problem_type, another_problem_type)
      expect(problems.count).to eq(2)
    end
    
    it "returns empty array when there are no problems" do
      service = WorkOrderProblemService.new(work_order)
      problems = service.get_problems
      
      expect(problems).to be_empty
    end
  end
  
  describe "#get_formatted_problems" do
    it "returns formatted problem descriptions" do
      service = WorkOrderProblemService.new(work_order)
      service.add_problems([problem_type.id, another_problem_type.id])
      
      formatted_problems = service.get_formatted_problems
      
      expect(formatted_problems.size).to eq(2)
      expect(formatted_problems[0]).to include(problem_type.display_name)
      expect(formatted_problems[0]).to include(problem_type.sop_description)
      expect(formatted_problems[0]).to include(problem_type.standard_handling)
      
      expect(formatted_problems[1]).to include(another_problem_type.display_name)
      expect(formatted_problems[1]).to include(another_problem_type.sop_description)
      expect(formatted_problems[1]).to include(another_problem_type.standard_handling)
    end
  end
  
  describe "#generate_audit_comment" do
    it "generates audit comment from problem types" do
      service = WorkOrderProblemService.new(work_order)
      service.add_problems([problem_type.id, another_problem_type.id])
      
      audit_comment = service.generate_audit_comment
      
      expect(audit_comment).to include(problem_type.display_name)
      expect(audit_comment).to include(problem_type.sop_description)
      expect(audit_comment).to include(problem_type.standard_handling)
      
      expect(audit_comment).to include(another_problem_type.display_name)
      expect(audit_comment).to include(another_problem_type.sop_description)
      expect(audit_comment).to include(another_problem_type.standard_handling)
      
      # 检查是否有空行分隔
      expect(audit_comment).to include("\n\n")
    end
    
    it "returns nil when there are no problems" do
      service = WorkOrderProblemService.new(work_order)
      audit_comment = service.generate_audit_comment
      
      expect(audit_comment).to be_nil
    end
  end
end