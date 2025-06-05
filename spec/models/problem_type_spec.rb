require 'rails_helper'

RSpec.describe ProblemType, type: :model do
  describe "关联" do
    it { should belong_to(:fee_type).optional }
    it { should have_many(:work_orders) }
  end
  
  describe "验证" do
    context "当fee_type_id存在时" do
      it "验证code在fee_type范围内唯一" do
        fee_type = create(:fee_type)
        create(:problem_type, code: 'PT001', fee_type: fee_type)
        duplicate = build(:problem_type, code: 'PT001', fee_type: fee_type)
        
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include("should be unique within a fee type")
      end
    end
    
    context "当fee_type_id不存在时" do
      it "验证code全局唯一" do
        create(:problem_type, code: 'PT001', fee_type: nil)
        duplicate = build(:problem_type, code: 'PT001', fee_type: nil)
        
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include("已经被使用")
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
      fee_type = create(:fee_type, code: 'FT001')
      problem_type = create(:problem_type, code: 'PT001', title: '发票不合规', fee_type: fee_type)
      
      expect(problem_type.display_name).to eq('FT001:PT001 - 发票不合规')
    end
    
    it "当没有费用类型时不包含前缀" do
      problem_type = create(:problem_type, code: 'PT001', title: '发票不合规', fee_type: nil)
      
      expect(problem_type.display_name).to eq('PT001 - 发票不合规')
    end
  end
  
  describe "#full_description" do
    it "包含费用类型信息" do
      fee_type = create(:fee_type, code: 'FT001', title: '会议讲课费')
      problem_type = create(:problem_type, 
                          code: 'PT001', 
                          title: '发票不合规', 
                          sop_description: '发票信息不完整', 
                          standard_handling: '请提供完整发票',
                          fee_type: fee_type)
      
      expected = "FT001 - 会议讲课费 > FT001:PT001 - 发票不合规\n    发票信息不完整\n    请提供完整发票"
      expect(problem_type.full_description).to eq(expected)
    end
    
    it "当没有费用类型时不包含费用类型信息" do
      problem_type = create(:problem_type, 
                          code: 'PT001', 
                          title: '发票不合规', 
                          sop_description: '发票信息不完整', 
                          standard_handling: '请提供完整发票',
                          fee_type: nil)
      
      expected = "PT001 - 发票不合规\n    发票信息不完整\n    请提供完整发票"
      expect(problem_type.full_description).to eq(expected)
    end
  end
  
  describe "与FeeType的关系" do
    it "通过费用类型名称查找" do
      fee_type = create(:fee_type, title: '会议讲课费')
      problem_type = create(:problem_type, fee_type: fee_type)
      
      # 模拟通过费用类型名称查找问题类型的过程
      found_fee_type = FeeType.find_by(title: '会议讲课费')
      found_problem_types = ProblemType.where(fee_type_id: found_fee_type.id)
      
      expect(found_problem_types).to include(problem_type)
    end
  end
end
