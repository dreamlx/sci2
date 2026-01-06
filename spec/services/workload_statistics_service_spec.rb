# spec/services/workload_statistics_service_spec.rb
require 'rails_helper'

RSpec.describe WorkloadStatisticsService do
  let!(:admin_user1) { create(:admin_user, name: '审核员A', email: 'auditor_a@example.com') }
  let!(:admin_user2) { create(:admin_user, name: '审核员B', email: 'auditor_b@example.com') }
  let!(:reimbursement1) { create(:reimbursement) }
  let!(:reimbursement2) { create(:reimbursement) }

  describe '#summary' do
    context '当没有工单时' do
      it '返回零统计' do
        service = described_class.new(period: 'today')
        summary = service.summary

        expect(summary[:audit_work_orders]).to eq(0)
        expect(summary[:communication_work_orders]).to eq(0)
        expect(summary[:total_work_orders]).to eq(0)
        expect(summary[:active_auditors]).to eq(0)
      end
    end

    context '当有工单时' do
      before do
        # 创建审核工单
        create(:audit_work_order, reimbursement: reimbursement1, creator: admin_user1)
        create(:audit_work_order, reimbursement: reimbursement2, creator: admin_user1)
        # 创建沟通工单
        create(:communication_work_order, reimbursement: reimbursement1, creator: admin_user2)
      end

      it '正确统计工单数量' do
        service = described_class.new(period: 'today')
        summary = service.summary

        expect(summary[:audit_work_orders]).to eq(2)
        expect(summary[:communication_work_orders]).to eq(1)
        expect(summary[:total_work_orders]).to eq(3)
        expect(summary[:active_auditors]).to eq(2)
      end
    end
  end

  describe '#auditor_workload' do
    before do
      # admin_user1 创建 2 个审核工单
      @wo1 = create(:audit_work_order, reimbursement: reimbursement1, creator: admin_user1)
      @wo2 = create(:audit_work_order, reimbursement: reimbursement2, creator: admin_user1)

      # admin_user2 创建 1 个沟通工单
      @wo3 = create(:communication_work_order, reimbursement: reimbursement1, creator: admin_user2)
    end

    it '正确统计单个审核员的工作量' do
      service = described_class.new(period: 'today')
      workload = service.auditor_workload(admin_user1)

      expect(workload[:auditor_name]).to eq('审核员A')
      expect(workload[:audit_work_orders]).to eq(2)
      expect(workload[:communication_work_orders]).to eq(0)
      expect(workload[:total_work_orders]).to eq(2)
    end

    it '计算加权工作量分' do
      service = described_class.new(period: 'today')
      workload = service.auditor_workload(admin_user1)

      # 2 个审核工单 * 1.0 = 2.0
      expect(workload[:weighted_score]).to eq(2.0)
    end
  end

  describe '#all_auditors_workload' do
    before do
      create(:audit_work_order, reimbursement: reimbursement1, creator: admin_user1)
      create(:audit_work_order, reimbursement: reimbursement2, creator: admin_user1)
      create(:communication_work_order, reimbursement: reimbursement1, creator: admin_user2)
    end

    it '返回按加权分排序的审核员列表' do
      service = described_class.new(period: 'today')
      workloads = service.all_auditors_workload

      expect(workloads.length).to eq(2)
      # admin_user1 有 2 个审核工单 (2.0分)，应该排第一
      expect(workloads.first[:auditor_id]).to eq(admin_user1.id)
    end
  end

  describe '#leaderboard' do
    before do
      5.times do
        create(:audit_work_order, reimbursement: reimbursement1, creator: admin_user1)
      end
      create(:audit_work_order, reimbursement: reimbursement1, creator: admin_user2)
    end

    it '返回指定数量的排行榜' do
      service = described_class.new(period: 'today')
      leaderboard = service.leaderboard(limit: 1)

      expect(leaderboard.length).to eq(1)
      expect(leaderboard.first[:auditor_id]).to eq(admin_user1.id)
    end
  end

  describe '时间段筛选' do
    before do
      # 今天的工单
      create(:audit_work_order, reimbursement: reimbursement1, creator: admin_user1)

      # 昨天的工单（通过修改 created_at）
      old_work_order = create(:audit_work_order, reimbursement: reimbursement2, creator: admin_user1)
      old_work_order.update_column(:created_at, 2.days.ago)
    end

    it '今日统计只包含今天的数据' do
      service = described_class.new(period: 'today')
      summary = service.summary

      expect(summary[:audit_work_orders]).to eq(1)
    end

    it '本周统计包含最近7天的数据' do
      service = described_class.new(period: 'week')
      summary = service.summary

      expect(summary[:audit_work_orders]).to eq(2)
    end
  end

  describe '#daily_trend' do
    before do
      create(:audit_work_order, reimbursement: reimbursement1, creator: admin_user1)
    end

    it '返回每日统计数据' do
      service = described_class.new(period: 'today')
      trend = service.daily_trend(days: 7)

      expect(trend.length).to eq(8) # 7天 + 今天
      expect(trend.last[:audit_work_orders]).to eq(1) # 今天有1个工单
    end
  end
end
