require 'rails_helper'

RSpec.describe ReimbursementAssignmentService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:assignee) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  let(:service) { described_class.new(admin_user) }

  describe '#assign' do
    it '创建一个新的报销单分配' do
      expect do
        service.assign(reimbursement.id, assignee.id, '测试分配')
      end.to change(ReimbursementAssignment, :count).by(1)

      assignment = ReimbursementAssignment.last
      expect(assignment.reimbursement).to eq(reimbursement)
      expect(assignment.assignee).to eq(assignee)
      expect(assignment.assigner).to eq(admin_user)
      expect(assignment.is_active).to be true
      expect(assignment.notes).to eq('测试分配')
    end

    it '如果报销单已有活跃分配，取消之前的分配' do
      # 创建一个已有的活跃分配
      existing_assignee = create(:admin_user)
      existing_assignment = create(:reimbursement_assignment,
                                   reimbursement: reimbursement,
                                   assignee: existing_assignee,
                                   assigner: admin_user,
                                   is_active: true)

      # 分配给新的用户
      service.assign(reimbursement.id, assignee.id, '新分配')

      # 检查原有分配是否被取消
      existing_assignment.reload
      expect(existing_assignment.is_active).to be false

      # 检查新分配是否创建成功
      new_assignment = ReimbursementAssignment.where(reimbursement: reimbursement, assignee: assignee).first
      expect(new_assignment.is_active).to be true
    end
  end

  describe '#batch_assign' do
    let(:reimbursement2) { create(:reimbursement) }
    let(:reimbursement3) { create(:reimbursement) }

    it '批量创建报销单分配' do
      reimbursement_ids = [reimbursement.id, reimbursement2.id, reimbursement3.id]

      expect do
        service.batch_assign(reimbursement_ids, assignee.id, '批量分配')
      end.to change(ReimbursementAssignment, :count).by(3)

      # 检查所有报销单是否都分配给了指定用户
      assignments = ReimbursementAssignment.where(reimbursement_id: reimbursement_ids)
      expect(assignments.count).to eq(3)
      expect(assignments.pluck(:assignee_id).uniq).to eq([assignee.id])
      expect(assignments.pluck(:is_active).uniq).to eq([true])
    end
  end

  describe '#unassign' do
    it '取消报销单分配' do
      # 创建一个活跃分配
      assignment = create(:reimbursement_assignment,
                          reimbursement: reimbursement,
                          assignee: assignee,
                          assigner: admin_user,
                          is_active: true)

      # 取消分配
      result = service.unassign(assignment.id)

      # 检查结果
      expect(result).to be true

      # 检查分配是否被取消
      assignment.reload
      expect(assignment.is_active).to be false
    end
  end

  describe '#transfer' do
    let(:new_assignee) { create(:admin_user) }

    it '转移报销单分配' do
      # 创建一个活跃分配
      assignment = create(:reimbursement_assignment,
                          reimbursement: reimbursement,
                          assignee: assignee,
                          assigner: admin_user,
                          is_active: true)

      # 转移分配
      expect do
        service.transfer(reimbursement.id, new_assignee.id, '转移分配')
      end.to change(ReimbursementAssignment, :count).by(1)

      # 检查原有分配是否被取消
      assignment.reload
      expect(assignment.is_active).to be false

      # 检查新分配是否创建成功
      new_assignment = ReimbursementAssignment.where(reimbursement: reimbursement, assignee: new_assignee).first
      expect(new_assignment.is_active).to be true
      expect(new_assignment.notes).to eq('转移分配')
    end
  end
end
