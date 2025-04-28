require 'rails_helper'

RSpec.describe "Admin::Reimbursements", type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }

  before do
    sign_in admin_user
  end

  describe "GET /admin/reimbursements" do
    it "返回成功响应" do
      get admin_reimbursements_path
      expect(response).to be_successful
    end
  end

  describe "GET /admin/reimbursements/:id" do
    it "返回成功响应" do
      get admin_reimbursement_path(reimbursement)
      expect(response).to be_successful
    end
  end

  describe "PUT /admin/reimbursements/:id/start_processing" do
    it "更新报销单状态" do
      put start_processing_admin_reimbursement_path(reimbursement)
      expect(response).to redirect_to(admin_reimbursement_path(reimbursement))
      follow_redirect!
      expect(response.body).to include("报销单已开始处理")
    end
  end

  describe "POST /admin/reimbursements/import" do
    it "处理没有文件的情况" do
      post import_admin_reimbursements_path
      expect(response).to redirect_to(new_import_admin_reimbursements_path)
      follow_redirect!
      expect(response.body).to include("请选择要导入的文件")
    end
  end
end