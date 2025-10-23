require 'rails_helper'

RSpec.describe ProblemType, type: :model do
  describe "关联" do
    it { should belong_to(:fee_type) }
    it { should have_many(:work_orders) }
  end
  
  describe "验证" do
    context "当fee_type存在时" do
      it "可以使用code别名设置和获取issue_code" do
        fee_type = create(:fee_type)
        problem_type = build(:problem_type, code: 'PT001', fee_type: fee_type)

        expect(problem_type.code).to eq('PT001')
        expect(problem_type.issue_code).to eq('PT001')
      end
    end
    
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:sop_description) }
    it { should validate_presence_of(:standard_handling) }
    it { should validate_inclusion_of(:active).in_array([true, false]) }
  end
  
  describe "作用域" do
    it "active返回活跃的问题类型" do
      active = create(:problem_type, active: true)
      inactive = create(:problem_type, active: false)
      
      expect(ProblemType.active).to include(active)
      expect(ProblemType.active).not_to include(inactive)
    end
    
    it "by_fee_type返回指定费用类型的问题类型" do
      fee_type1 = create(:fee_type)
      fee_type2 = create(:fee_type)
      problem1 = create(:problem_type, fee_type: fee_type1)
      problem2 = create(:problem_type, fee_type: fee_type2)
      
      expect(ProblemType.by_fee_type(fee_type1.id)).to include(problem1)
      expect(ProblemType.by_fee_type(fee_type1.id)).not_to include(problem2)
    end
  end
  
  describe "#display_name" do
    it "包含费用类型代码前缀" do
      fee_type = create(:fee_type)
      problem_type = create(:problem_type, code: 'PT001', title: '发票不合规', fee_type: fee_type)

      # The actual format includes reimbursement_type_code, meeting_type_code, expense_type_code, and issue_code
      expected_pattern = /\A[A-Z]{2}\d{2}\d{2}PT001 - 发票不合规\z/
      expect(problem_type.display_name).to match(expected_pattern)
    end
  end
  
  describe "#full_description" do
    it "包含费用类型信息" do
      fee_type = create(:fee_type)
      problem_type = create(:problem_type,
                          code: 'PT001',
                          title: '发票不合规',
                          sop_description: '发票信息不完整',
                          standard_handling: '请提供完整发票',
                          fee_type: fee_type)

      # The actual format includes display_name followed by SOP and Handling sections
      expected_pattern = /\A[A-Z]{2}\d{2}\d{2}PT001 - 发票不合规\nSOP: 发票信息不完整\nHandling: 请提供完整发票\z/
      expect(problem_type.full_description).to match(expected_pattern)
    end
  end
  
  describe "与FeeType的关系" do
    it "通过费用类型名称查找" do
      fee_type = create(:fee_type, name: '会议讲课费')
      problem_type = create(:problem_type, fee_type: fee_type)

      # 模拟通过费用类型名称查找问题类型的过程
      found_fee_type = FeeType.find_by(name: '会议讲课费')
      found_problem_types = ProblemType.where(fee_type_id: found_fee_type.id)

      expect(found_problem_types).to include(problem_type)
    end
  end
end
