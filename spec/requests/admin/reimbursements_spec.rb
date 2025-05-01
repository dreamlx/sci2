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

  describe "POST /admin/reimbursements" do
    it "创建新的报销单" do
      reimbursement_params = attributes_for(:reimbursement, invoice_number: "NEW123", is_electronic: true)
      expect {
        post admin_reimbursements_path, params: { reimbursement: reimbursement_params }
      }.to change(Reimbursement, :count).by(1)
      expect(response).to redirect_to(admin_reimbursement_path(Reimbursement.last))
      expect(Reimbursement.last.is_electronic).to be true
    end
  end

  describe "PUT /admin/reimbursements/:id" do
    it "更新报销单" do
      put admin_reimbursement_path(reimbursement), params: { reimbursement: { document_name: "Updated Name", is_electronic: true } }
      reimbursement.reload
      expect(reimbursement.document_name).to eq("Updated Name")
      expect(reimbursement.is_electronic).to be true
      expect(response).to redirect_to(admin_reimbursement_path(reimbursement))
    end
  end

  describe "GET /admin/reimbursements/:id" do
    it "返回成功响应" do
      get admin_reimbursement_path(reimbursement)
      expect(response).to be_successful
    end
  end

  describe "PUT /admin/reimbursements/:id/start_processing" do
    it "更新报销单状态为 processing" do
      put start_processing_admin_reimbursement_path(reimbursement)
      expect(response).to redirect_to(admin_reimbursement_path(reimbursement))
      follow_redirect!
      expect(response.body).to include("报销单已开始处理")
      reimbursement.reload
      expect(reimbursement.status).to eq("processing")
    end
  end

  describe "PUT /admin/reimbursements/:id/mark_waiting_completion" do
    let!(:reimbursement_processing) { create(:reimbursement, :processing) }
    it "更新报销单状态为 waiting_completion" do
      # 模拟所有费用明细已验证
      allow_any_instance_of(Reimbursement).to receive(:all_fee_details_verified?).and_return(true)
      put mark_waiting_completion_admin_reimbursement_path(reimbursement_processing)
      expect(response).to redirect_to(admin_reimbursement_path(reimbursement_processing))
      follow_redirect!
      expect(response.body).to include("报销单已标记为等待完成")
      reimbursement_processing.reload
      expect(reimbursement_processing.status).to eq("waiting_completion")
    end
  end

  describe "PUT /admin/reimbursements/:id/close" do
    let!(:reimbursement_waiting) { create(:reimbursement, :waiting_completion) }
    it "更新报销单状态为 closed" do
      put close_admin_reimbursement_path(reimbursement_waiting)
      expect(response).to redirect_to(admin_reimbursement_path(reimbursement_waiting))
      follow_redirect!
      expect(response.body).to include("报销单已关闭")
      reimbursement_waiting.reload
      expect(reimbursement_waiting.status).to eq("closed")
    end
  end

  describe "POST /admin/reimbursements/import" do
    let(:file) { fixture_file_upload('spec/test_data/test_reimbursements.csv', 'text/csv') }

    it "处理没有文件的情况" do
      post import_admin_reimbursements_path
      expect(response).to redirect_to(new_import_admin_reimbursements_path)
      follow_redirect!
      expect(response.body).to include("请选择要导入的文件")
    end

    it "调用导入服务并重定向" do
      # 模拟导入服务成功
      service_double = instance_double(ReimbursementImportService, import: { success: true, created: 1, updated: 0, errors: 0 })
      allow(ReimbursementImportService).to receive(:new).with(instance_of(ActionDispatch::Http::UploadedFile), admin_user).and_return(service_double)

      post import_admin_reimbursements_path, params: { file: file }
      expect(response).to redirect_to(admin_reimbursements_path)
      follow_redirect!
      expect(response.body).to include("导入成功: 1 创建, 0 更新.")
    end

    it "处理导入服务失败" do
      # 模拟导入服务失败
      service_double = instance_double(ReimbursementImportService, import: { success: false, errors: ["导入错误"] })
      allow(ReimbursementImportService).to receive(:new).with(instance_of(ActionDispatch::Http::UploadedFile), admin_user).and_return(service_double)

      post import_admin_reimbursements_path, params: { file: file }
      expect(response).to redirect_to(new_import_admin_reimbursements_path)
      follow_redirect!
      expect(response.body).to include("导入失败: 导入错误")
    end
  end
end