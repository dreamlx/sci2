require 'rails_helper'

RSpec.describe 'Admin::Statistics', type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement_pending) { create(:reimbursement, status: 'pending') }
  let!(:reimbursement_processing) { create(:reimbursement, status: 'processing') }

  before do
    sign_in admin_user
  end

  describe 'GET /admin/statistics/reimbursement_status_counts' do
    it '返回报销单状态统计数据' do
      # 创建不同状态的报销单来测试计数
      create(:reimbursement, status: 'waiting_completion')
      create(:reimbursement, status: 'closed')

      get admin_statistics_reimbursement_status_counts_path
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json).to have_key('pending')
      expect(json).to have_key('processing')
      expect(json).to have_key('waiting_completion')
      expect(json).to have_key('closed')

      expect(json['pending']).to eq(1) # 初始创建的 reimbursement_pending
      expect(json['processing']).to eq(1) # 初始创建的 reimbursement_processing
      expect(json['waiting_completion']).to eq(1)
      expect(json['closed']).to eq(1)
    end
  end

  describe 'GET /admin/statistics/work_order_status_counts' do
    let!(:audit_pending) { create(:audit_work_order, status: 'pending') }
    let!(:audit_processing) { create(:audit_work_order, status: 'processing') }
    let!(:communication_pending) { create(:communication_work_order, status: 'pending') }
    let!(:communication_needs) { create(:communication_work_order, :needs_communication, status: 'processing') }

    it '返回工单状态统计数据' do
      get admin_statistics_work_order_status_counts_path
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json).to have_key('audit')
      expect(json).to have_key('communication')

      expect(json['audit']).to have_key('pending')
      expect(json['audit']).to have_key('processing')
      expect(json['audit']).to have_key('approved')
      expect(json['audit']).to have_key('rejected')

      expect(json['communication']).to have_key('pending')
      expect(json['communication']).to have_key('processing')
      expect(json['communication']).to have_key('approved')
      expect(json['communication']).to have_key('rejected')
      expect(json).to have_key('needs_communication_count') # 现在是一个单独的计数，不是状态

      expect(json['audit']['pending']).to eq(1)
      expect(json['audit']['processing']).to eq(1)
      expect(json['communication']['pending']).to eq(1)
      expect(json['communication']['processing']).to eq(1) # 现在是 processing 状态
      expect(json['needs_communication_count']).to eq(1) # 需要沟通的工单数量
    end
  end

  describe 'GET /admin/statistics/fee_detail_verification_counts' do
    let!(:fee_detail_pending) { create(:fee_detail, verification_status: 'pending') }
    let!(:fee_detail_problematic) { create(:fee_detail, verification_status: 'problematic') }
    let!(:fee_detail_verified) { create(:fee_detail, verification_status: 'verified') }

    it '返回费用明细验证状态统计数据' do
      get admin_statistics_fee_detail_verification_counts_path
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json).to have_key('pending')
      expect(json).to have_key('problematic')
      expect(json).to have_key('verified')

      expect(json['pending']).to eq(1)
      expect(json['problematic']).to eq(1)
      expect(json['verified']).to eq(1)
    end
  end
end
