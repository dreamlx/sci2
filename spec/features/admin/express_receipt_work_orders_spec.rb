require 'rails_helper'

RSpec.describe "快递收单工单管理", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:express_receipt_work_order) { create(:express_receipt_work_order, reimbursement: reimbursement) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe "列表页" do
    it "显示所有快递收单工单" do
      visit admin_express_receipt_work_orders_path
      expect(page).to have_content("快递收单工单")
      expect(page).to have_content(reimbursement.invoice_number)
      expect(page).to have_content(express_receipt_work_order.tracking_number)
    end

    it "有导入按钮" do
      visit admin_express_receipt_work_orders_path
      expect(page).to have_link("导入快递收单")
    end
  end

  describe "详情页" do
    it "显示快递收单工单详细信息" do
      visit admin_express_receipt_work_order_path(express_receipt_work_order)
      expect(page).to have_content("快递收单工单 ##{express_receipt_work_order.id}")
      expect(page).to have_content(reimbursement.invoice_number)
      expect(page).to have_content(express_receipt_work_order.tracking_number)
      expect(page).to have_content(express_receipt_work_order.courier_name)
    end

    it "显示标签页" do
      visit admin_express_receipt_work_order_path(express_receipt_work_order)
      expect(page).to have_content("基本信息")
      expect(page).to have_content("关联审核工单")
      expect(page).to have_content("状态变更历史")
    end
  end

  describe "创建快递收单工单" do
    it "可以创建新快递收单工单" do
      visit new_admin_express_receipt_work_order_path

      select "#{reimbursement.invoice_number} - #{reimbursement.applicant}", from: "express_receipt_work_order[reimbursement_id]"
      fill_in "express_receipt_work_order[tracking_number]", with: "SF1234567890"
      fill_in "express_receipt_work_order[courier_name]", with: "顺丰速运"

      # 设置日期
      page.execute_script("$('#express_receipt_work_order_received_at').val('#{Date.today}')")

      click_button "创建快递收单工单"

      expect(page).to have_content("快递收单工单已成功创建")
      expect(page).to have_content("SF1234567890")
      expect(page).to have_content("顺丰速运")
    end
  end

  describe "导入功能" do
    it "显示导入表单" do
      visit new_import_admin_express_receipt_work_orders_path
      expect(page).to have_content("导入快递收单")
      expect(page).to have_button("导入")
    end

    it "处理导入请求", js: true do
      # 创建测试CSV文件
      require 'csv'
      csv_path = Rails.root.join('tmp', 'test_express_receipts.csv')
      CSV.open(csv_path, 'wb') do |csv|
        csv << ['报销单号', '快递单号', '快递公司', '收单日期']
        csv << [reimbursement.invoice_number, 'SF1234567890', '顺丰速运', Date.today.to_s]
      end

      visit new_import_admin_express_receipt_work_orders_path
      attach_file('file', csv_path)
      click_button "导入"

      expect(page).to have_content("导入成功")
      expect(ExpressReceiptWorkOrder.where(tracking_number: 'SF1234567890').count).to eq(1)

      # 清理测试文件
      File.delete(csv_path) if File.exist?(csv_path)
    end
  end
end