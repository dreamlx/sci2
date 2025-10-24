require 'rails_helper'

RSpec.describe ReimbursementQueryService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:other_admin_user) { create(:admin_user) }
  let(:service) { described_class.new(admin_user) }

  # 创建测试数据
  let!(:reimbursement1) { create(:reimbursement, status: 'pending') }
  let!(:reimbursement2) { create(:reimbursement, status: 'processing') }
  let!(:reimbursement3) { create(:reimbursement, status: 'closed') }

  # 创建分配
  let!(:assignment1) do
    create(:reimbursement_assignment, reimbursement: reimbursement1, assignee: admin_user, is_active: true)
  end
  let!(:assignment2) do
    create(:reimbursement_assignment, reimbursement: reimbursement2, assignee: other_admin_user, is_active: true)
  end
  # reimbursement3 没有分配

  describe '#assigned_to_me' do
    it '返回分配给当前用户的报销单' do
      result = service.assigned_to_me

      expect(result).to include(reimbursement1)
      expect(result).not_to include(reimbursement2)
      expect(result).not_to include(reimbursement3)
    end

    it '应用过滤条件' do
      # 按状态过滤
      result = service.assigned_to_me(status: 'pending')
      expect(result).to include(reimbursement1)

      result = service.assigned_to_me(status: 'processing')
      expect(result).to be_empty
    end
  end

  describe '#all_reimbursements' do
    it '返回所有报销单' do
      result = service.all_reimbursements

      expect(result).to include(reimbursement1)
      expect(result).to include(reimbursement2)
      expect(result).to include(reimbursement3)
    end

    it '应用过滤条件' do
      # 按状态过滤
      result = service.all_reimbursements(status: 'closed')
      expect(result).to include(reimbursement3)
      expect(result).not_to include(reimbursement1)
      expect(result).not_to include(reimbursement2)
    end
  end

  describe '#unassigned' do
    it '返回未分配的报销单' do
      result = service.unassigned

      expect(result).to include(reimbursement3)
      expect(result).not_to include(reimbursement1)
      expect(result).not_to include(reimbursement2)
    end

    it '应用过滤条件' do
      # 按状态过滤
      result = service.unassigned(status: 'pending')
      expect(result).to be_empty

      result = service.unassigned(status: 'closed')
      expect(result).to include(reimbursement3)
    end
  end

  describe '#assigned_to_user' do
    it '返回分配给指定用户的报销单' do
      result = service.assigned_to_user(admin_user.id)

      expect(result).to include(reimbursement1)
      expect(result).not_to include(reimbursement2)
      expect(result).not_to include(reimbursement3)

      result = service.assigned_to_user(other_admin_user.id)

      expect(result).not_to include(reimbursement1)
      expect(result).to include(reimbursement2)
      expect(result).not_to include(reimbursement3)
    end

    it '应用过滤条件' do
      # 按状态过滤
      result = service.assigned_to_user(admin_user.id, status: 'pending')
      expect(result).to include(reimbursement1)

      result = service.assigned_to_user(admin_user.id, status: 'processing')
      expect(result).to be_empty
    end
  end

  describe '#workload_statistics' do
    it '返回工作量统计信息' do
      # 创建更多测试数据
      reimbursement4 = create(:reimbursement, status: 'closed')
      reimbursement5 = create(:reimbursement, status: 'processing')

      create(:reimbursement_assignment, reimbursement: reimbursement4, assignee: admin_user, is_active: true)
      create(:reimbursement_assignment, reimbursement: reimbursement5, assignee: admin_user, is_active: true)

      stats = service.workload_statistics

      # 检查当前用户的统计信息
      admin_user_stats = stats[admin_user.id]
      expect(admin_user_stats[:assigned_count]).to eq(3) # reimbursement1, reimbursement4, reimbursement5
      expect(admin_user_stats[:processed_count]).to eq(1) # reimbursement4 (closed)
      expect(admin_user_stats[:pending_count]).to eq(2) # reimbursement1 (pending), reimbursement5 (processing)
      expect(admin_user_stats[:completion_rate]).to be_within(0.1).of(33.3) # 1/3 * 100 = 33.3%

      # 检查其他用户的统计信息
      other_admin_user_stats = stats[other_admin_user.id]
      expect(other_admin_user_stats[:assigned_count]).to eq(1) # reimbursement2
      expect(other_admin_user_stats[:processed_count]).to eq(0) # none closed
      expect(other_admin_user_stats[:pending_count]).to eq(1) # reimbursement2 (processing)
      expect(other_admin_user_stats[:completion_rate]).to eq(0) # 0/1 * 100 = 0%
    end
  end

  describe 'apply_filters' do
    it '按发票号过滤' do
      reimbursement1.update(invoice_number: 'INV001')
      reimbursement2.update(invoice_number: 'INV002')

      result = service.all_reimbursements(invoice_number: 'INV001')
      expect(result).to include(reimbursement1)
      expect(result).not_to include(reimbursement2)
    end

    it '按申请人过滤' do
      reimbursement1.update(applicant: '张三')
      reimbursement2.update(applicant: '李四')

      result = service.all_reimbursements(applicant: '张三')
      expect(result).to include(reimbursement1)
      expect(result).not_to include(reimbursement2)
    end

    it '按日期范围过滤' do
      reimbursement1.update(created_at: 3.days.ago)
      reimbursement2.update(created_at: 1.day.ago)

      result = service.all_reimbursements(start_date: 2.days.ago, end_date: Time.current)
      expect(result).not_to include(reimbursement1)
      expect(result).to include(reimbursement2)
    end

    it '按金额范围过滤' do
      reimbursement1.update(amount: 100)
      reimbursement2.update(amount: 500)

      result = service.all_reimbursements(min_amount: 200, max_amount: 600)
      expect(result).not_to include(reimbursement1)
      expect(result).to include(reimbursement2)

      result = service.all_reimbursements(min_amount: 50)
      expect(result).to include(reimbursement1)
      expect(result).to include(reimbursement2)

      result = service.all_reimbursements(max_amount: 200)
      expect(result).to include(reimbursement1)
      expect(result).not_to include(reimbursement2)
    end

    it '按排序条件排序' do
      # 确保创建时间有明确的先后顺序
      reimbursement1.update(created_at: 5.days.ago)
      reimbursement2.update(created_at: 3.days.ago)
      reimbursement3.update(created_at: 1.day.ago)

      # 按创建时间升序排序
      result = service.all_reimbursements(sort_by: 'created_at', sort_direction: 'asc')
      expect(result.to_a[0]).to eq(reimbursement1)
      expect(result.to_a[1]).to eq(reimbursement2)
      expect(result.to_a[2]).to eq(reimbursement3)

      # 按创建时间降序排序
      result = service.all_reimbursements(sort_by: 'created_at', sort_direction: 'desc')
      expect(result.to_a[0]).to eq(reimbursement3)
      expect(result.to_a[1]).to eq(reimbursement2)
      expect(result.to_a[2]).to eq(reimbursement1)
    end
  end
end
