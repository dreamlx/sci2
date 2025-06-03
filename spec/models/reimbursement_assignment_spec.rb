require 'rails_helper'

RSpec.describe ReimbursementAssignment, type: :model do
  describe "关联" do
    it { should belong_to(:reimbursement) }
    it { should belong_to(:assignee).class_name('AdminUser') }
    it { should belong_to(:assigner).class_name('AdminUser') }
  end

  describe "验证" do
    it "对于活跃的分配，验证报销单ID的唯一性" do
      reimbursement = create(:reimbursement)
      admin_user1 = create(:admin_user)
      admin_user2 = create(:admin_user)
      
      # 创建第一个活跃分配
      assignment1 = ReimbursementAssignment.create(
        reimbursement: reimbursement,
        assignee: admin_user1,
        assigner: admin_user2,
        is_active: true
      )
      
      # 尝试创建第二个活跃分配，应该失败
      assignment2 = ReimbursementAssignment.new(
        reimbursement: reimbursement,
        assignee: admin_user2,
        assigner: admin_user1,
        is_active: true
      )
      
      expect(assignment2).not_to be_valid
      expect(assignment2.errors[:reimbursement_id]).to include("已经有一个活跃的分配")
    end
    
    it "允许为同一报销单创建多个非活跃分配" do
      reimbursement = create(:reimbursement)
      admin_user1 = create(:admin_user)
      admin_user2 = create(:admin_user)
      
      # 创建第一个非活跃分配
      assignment1 = ReimbursementAssignment.create(
        reimbursement: reimbursement,
        assignee: admin_user1,
        assigner: admin_user2,
        is_active: false
      )
      
      # 创建第二个非活跃分配，应该成功
      assignment2 = ReimbursementAssignment.new(
        reimbursement: reimbursement,
        assignee: admin_user2,
        assigner: admin_user1,
        is_active: false
      )
      
      expect(assignment2).to be_valid
    end
  end

  describe "作用域" do
    let!(:active_assignment) { create(:reimbursement_assignment, is_active: true) }
    let!(:inactive_assignment) { create(:reimbursement_assignment, is_active: false) }
    
    it "active 返回活跃的分配" do
      expect(ReimbursementAssignment.active).to include(active_assignment)
      expect(ReimbursementAssignment.active).not_to include(inactive_assignment)
    end
    
    it "by_assignee 返回指定被分配人的分配" do
      expect(ReimbursementAssignment.by_assignee(active_assignment.assignee_id)).to include(active_assignment)
    end
    
    it "by_assigner 返回指定分配人的分配" do
      expect(ReimbursementAssignment.by_assigner(active_assignment.assigner_id)).to include(active_assignment)
    end
    
    it "recent_first 按创建时间降序排序" do
      expect(ReimbursementAssignment.recent_first.to_a).to eq([inactive_assignment, active_assignment].sort_by(&:created_at).reverse)
    end
  end

  # 注意：取消活跃分配的功能在服务层测试中进行测试
end