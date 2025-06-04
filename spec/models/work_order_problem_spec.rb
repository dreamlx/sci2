require 'rails_helper'

RSpec.describe WorkOrderProblem, type: :model do
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
  
  describe "associations" do
    it "belongs to work_order" do
      association = described_class.reflect_on_association(:work_order)
      expect(association.macro).to eq :belongs_to
    end
    
    it "belongs to problem_type" do
      association = described_class.reflect_on_association(:problem_type)
      expect(association.macro).to eq :belongs_to
    end
  end
  
  describe "validations" do
    it "validates uniqueness of work_order_id scoped to problem_type_id" do
      # 创建第一个关联
      work_order_problem = WorkOrderProblem.create!(
        work_order: work_order,
        problem_type: problem_type
      )
      
      # 尝试创建重复的关联
      duplicate = WorkOrderProblem.new(
        work_order: work_order,
        problem_type: problem_type
      )
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:work_order_id]).to include("已关联此问题类型")
    end
  end
  
  describe "callbacks" do
    context "when WorkOrderOperation is defined" do
      before do
        # 模拟WorkOrderOperation类
        class_double("WorkOrderOperation", create!: true).as_stubbed_const
        
        # 模拟Current.admin_user
        module Current
          def self.admin_user
            nil
          end
        end
      end
      
      it "logs problem added operation after create" do
        expect(WorkOrderOperation).to receive(:create!).with(
          hash_including(
            work_order: work_order,
            operation_type: WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM
          )
        )
        
        WorkOrderProblem.create!(
          work_order: work_order,
          problem_type: problem_type
        )
      end
      
      it "logs problem removed operation after destroy" do
        work_order_problem = WorkOrderProblem.create!(
          work_order: work_order,
          problem_type: problem_type
        )
        
        expect(WorkOrderOperation).to receive(:create!).with(
          hash_including(
            work_order: work_order,
            operation_type: WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM
          )
        )
        
        work_order_problem.destroy
      end
    end
  end
end