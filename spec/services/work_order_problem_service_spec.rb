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
    it "adds a problem to an empty audit_comment" do
      service = WorkOrderProblemService.new(work_order)
      service.add_problem(problem_type.id)
      
      expected_comment = [
        "#{fee_type.display_name}: #{problem_type.display_name}",
        "    #{problem_type.sop_description}",
        "    #{problem_type.standard_handling}"
      ].join("\n")
      
      expect(work_order.reload.audit_comment).to eq(expected_comment)
      expect(work_order.problem_type_id).to eq(problem_type.id)
    end
    
    it "adds a problem to an existing audit_comment with proper spacing" do
      # First add a problem
      service = WorkOrderProblemService.new(work_order)
      service.add_problem(problem_type.id)
      
      # Then add another problem
      service.add_problem(another_problem_type.id)
      
      first_problem = [
        "#{fee_type.display_name}: #{problem_type.display_name}",
        "    #{problem_type.sop_description}",
        "    #{problem_type.standard_handling}"
      ].join("\n")
      
      second_problem = [
        "#{fee_type.display_name}: #{another_problem_type.display_name}",
        "    #{another_problem_type.sop_description}",
        "    #{another_problem_type.standard_handling}"
      ].join("\n")
      
      expected_comment = "#{first_problem}\n\n#{second_problem}"
      
      expect(work_order.reload.audit_comment).to eq(expected_comment)
      expect(work_order.problem_type_id).to eq(another_problem_type.id)
    end
  end
  
  describe "#clear_problems" do
    it "clears all problems from the audit_comment" do
      # First add a problem
      service = WorkOrderProblemService.new(work_order)
      service.add_problem(problem_type.id)
      
      # Then clear all problems
      service.clear_problems
      
      expect(work_order.reload.audit_comment).to be_nil
      expect(work_order.problem_type_id).to be_nil
    end
  end
  
  describe "#get_problems" do
    it "returns an empty array when there are no problems" do
      service = WorkOrderProblemService.new(work_order)
      expect(service.get_problems).to eq([])
    end
    
    it "returns an array of problems when there are problems" do
      service = WorkOrderProblemService.new(work_order)
      service.add_problem(problem_type.id)
      service.add_problem(another_problem_type.id)
      
      problems = service.get_problems
      
      expect(problems.size).to eq(2)
      expect(problems[0]).to include(problem_type.display_name)
      expect(problems[1]).to include(another_problem_type.display_name)
    end
  end
end