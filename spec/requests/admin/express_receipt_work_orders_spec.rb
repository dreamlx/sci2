require 'rails_helper'

RSpec.describe "Admin::ExpressReceiptWorkOrders", type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:express_receipt_work_order) { create(:express_receipt_work_order, reimbursement: reimbursement) }

  before do
    sign_in admin_user
  end

  describe "GET /admin/express_receipt_work_orders" do
    it "返回成功响应" do
      get admin_express_receipt_work_orders_path
      expect(response).to be_successful
    end
  end

  describe "GET /admin/express_receipt_work_orders/:id" do
    it "返回成功响应" do
      get admin_express_receipt_work_order_path(express_receipt_work_order)
      expect(response).to be_successful
    end
  end

  describe "GET /admin/express_receipt_work_orders/new" do
    it "返回成功响应" do
      get new_admin_express_receipt_work_order_path
      expect(response).to be_successful
    end
  end

  describe "POST /admin/express_receipt_work_orders" do
    it "创建新的快递收单工单" do
      express_receipt_work_order_params = attributes_for(:express_receipt_work_order, reimbursement_id: reimbursement.id)
      expect {
        post admin_express_receipt_work_orders_path, params: { express_receipt_work_order: express_receipt_work_order_params }
      }.to change(ExpressReceiptWorkOrder, :count).by(1)
      expect(response).to redirect_to(admin_express_receipt_work_order_path(ExpressReceiptWorkOrder.last))
    end
  end

  describe "GET /admin/express_receipt_work_orders/new_import" do
    it "返回成功响应" do
      get new_import_admin_express_receipt_work_orders_path
      expect(response).to be_successful
    end
  end

  describe "POST /admin/express_receipt_work_orders/import" do
    it "处理没有文件的情况" do
      post import_admin_express_receipt_work_orders_path
      expect(response).to redirect_to(new_import_admin_express_receipt_work_orders_path)
      follow_redirect!
      expect(response.body).to include("请选择要导入的文件")
    end

    it "处理有效的CSV文件" do
      # 创建测试CSV文件
      require 'csv'
      csv_path = Rails.root.join('tmp', 'test_express_receipts.csv')
      CSV.open(csv_path, 'wb') do |csv|
        csv << ['报销单号', '快递单号', '快递公司', '收单日期']
        csv << [reimbursement.invoice_number, 'SF1234567890', '顺丰速运', Date.today.to_s]
      end

      file = fixture_file_upload(csv_path, 'text/csv')

      # 模拟导入服务成功
      service_double = instance_double(ExpressReceiptImportService, import: { success: true, created: 1, skipped: 0, unmatched: 0, errors: 0 })
      expect(ExpressReceiptImportService).to receive(:new).with(file, admin_user).and_return(service_double)

      post import_admin_express_receipt_work_orders_path, params: { file: file }

      expect(response).to redirect_to(admin_express_receipt_work_orders_path)
      follow_redirect!
      expect(response.body).to include("导入成功")

      # 清理测试文件
      File.delete(csv_path) if File.exist?(csv_path)
    end

    it "处理导入服务失败" do
      # 创建测试CSV文件
      require 'csv'
      csv_path = Rails.root.join('tmp', 'test_express_receipts.csv')
      CSV.open(csv_path, 'wb') do |csv|
        csv << ['报销单号', '快递单号', '快递公司', '收单日期']
        csv << [reimbursement.invoice_number, 'SF1234567890', '顺丰速运', Date.today.to_s]
      end

      file = fixture_file_upload(csv_path, 'text/csv')

      # 模拟导入服务失败
      service_double = instance_double(ExpressReceiptImportService, import: { success: false, errors: ["导入错误"] })
      allow(ExpressReceiptImportService).to receive(:new).with(file, admin_user).and_return(service_double)

      post import_admin_express_receipt_work_orders_path, params: { file: file }
      expect(response).to redirect_to(new_import_admin_express_receipt_work_orders_path)
      follow_redirect!
      expect(response.body).to include("导入失败: 导入错误")

      # 清理测试文件
      File.delete(csv_path) if File.exist?(csv_path)
    end
  end
end