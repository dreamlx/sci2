require 'rails_helper'

RSpec.describe "Admin::Reimbursements", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe "列表页" do
    before { visit admin_reimbursements_path }

    it "显示报销单列表" do
      expect(page).to have_content(reimbursement.invoice_number)
      expect(page).to have_content(reimbursement.applicant)
    end

    it "有导入按钮" do
      expect(page).to have_link("导入报销单")
    end
  end

  describe "详情页" do
    before { visit admin_reimbursement_path(reimbursement) }

    it "显示报销单详情" do
      expect(page).to have_content(reimbursement.invoice_number)
      expect(page).to have_content(reimbursement.applicant)
      expect(page).to have_content(reimbursement.status)
    end

    it "有创建工单按钮" do
      expect(page).to have_link("新建审核工单")
      expect(page).to have_link("新建沟通工单")
    end

    it "显示标签页" do
      expect(page).to have_content("基本信息")
      expect(page).to have_content("快递收单工单")
      expect(page).to have_content("审核工单")
      expect(page).to have_content("沟通工单")
      expect(page).to have_content("费用明细")
      expect(page).to have_content("操作历史")
    end
  end

  describe "导入功能" do
    it "显示导入表单" do
      visit new_import_admin_reimbursements_path
      expect(page).to have_content("导入报销单")
      expect(page).to have_button("导入")
    end

    it "处理导入请求" do
      # 这里需要模拟文件上传，可能需要使用 Rack::Test::UploadedFile
      # 或者使用 stub 来模拟 ReimbursementImportService
    end
  end
end