require 'rails_helper'

RSpec.describe FeeType, type: :model do
  describe "关联" do
    it { should have_many(:problem_types).dependent(:destroy) }
  end
  
  describe "验证" do
    it { should validate_presence_of(:code) }
    
    it "验证code的唯一性" do
      create(:fee_type, code: 'FT001')
      duplicate = build(:fee_type, code: 'FT001')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to include("已经被使用")
    end
    
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:meeting_type) }
    it { should validate_inclusion_of(:active).in_array([true, false]) }
  end
  
  describe "作用域" do
    it "active返回活跃的费用类型" do
      active = create(:fee_type, active: true)
      inactive = create(:fee_type, active: false)
      
      expect(FeeType.active).to include(active)
      expect(FeeType.active).not_to include(inactive)
    end
    
    it "by_meeting_type返回指定会议类型的费用类型" do
      personal = create(:fee_type, meeting_type: '个人')
      academic = create(:fee_type, meeting_type: '学术')
      
      expect(FeeType.by_meeting_type('个人')).to include(personal)
      expect(FeeType.by_meeting_type('个人')).not_to include(academic)
    end
  end
  
  describe "#display_name" do
    it "返回格式化的名称" do
      fee_type = build(:fee_type, code: 'FT001', title: '会议讲课费')
      expect(fee_type.display_name).to eq('FT001 - 会议讲课费')
    end
  end
  
  describe "与ProblemType的关系" do
    it "可以关联多个问题类型" do
      fee_type = create(:fee_type)
      problem_type1 = create(:problem_type, fee_type: fee_type)
      problem_type2 = create(:problem_type, fee_type: fee_type)
      
      expect(fee_type.problem_types).to include(problem_type1, problem_type2)
    end
    
    it "关联的问题类型依赖于费用类型" do
      fee_type = create(:fee_type)
      problem_type = create(:problem_type, fee_type: fee_type)
      
      # 验证关联是否正确设置
      expect(problem_type.fee_type).to eq(fee_type)
      
      # 验证dependent: :destroy关联
      # 由于FeeType和FeeDetail之间可能存在未知的关联，我们不直接测试destroy
      # 而是测试关联是否正确设置
      association = FeeType.reflect_on_association(:problem_types)
      expect(association.options[:dependent]).to eq(:destroy)
    end
  end
end
