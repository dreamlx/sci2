require 'rails_helper'

RSpec.describe "Admin::Statistics", type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement_pending) { create(:reimbursement, status: 'pending') }
  let!(:reimbursement_processing) { create(:reimbursement, status: 'processing') }

  before do
    sign_in admin_user
  end

  describe "GET /admin/statistics/reimbursement_status_counts" do
    it "返回报销单状态统计数据" do
      get admin_statistics_reimbursement_status_counts_path
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json).to have_key("pending")
      expect(json).to have_key("processing")
      expect(json).to have_key("waiting_completion")
      expect(json).to have_key("closed")

      expect(json["pending"]).to eq(1)
      expect(json["processing"]).to eq(1)
    end
  end

  describe "GET /admin/statistics/work_order_status_counts" do
    it "返回工单状态统计数据" do
      get admin_statistics_work_order_status_counts_path
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json).to have_key("audit")
      expect(json).to have_key("communication")

      expect(json["audit"]).to have_key("pending")
      expect(json["communication"]).to have_key("pending")
    end
  end

  describe "GET /admin/statistics/fee_detail_verification_counts" do
    it "返回费用明细验证状态统计数据" do
      get admin_statistics_fee_detail_verification_counts_path
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json).to have_key("pending")
      expect(json).to have_key("problematic")
      expect(json).to have_key("verified")
    end
  end
end