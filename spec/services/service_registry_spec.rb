require 'rails_helper'

RSpec.describe ServiceRegistry, type: :module do
  # 创建一个测试控制器类
  class TestController < ApplicationController
    def current_admin_user
      @current_admin_user ||= AdminUser.first
    end
  end

  let(:controller) { TestController.new }
  let(:admin_user) { create(:admin_user) }
  let(:file) { double('file') }
  let(:work_order) { double('work_order') }

  before do
    allow(controller).to receive(:current_admin_user).and_return(admin_user)
  end

  describe '#reimbursement_import_service' do
    it '返回 ReimbursementImportService 实例' do
      expect(ReimbursementImportService).to receive(:new).with(file, admin_user)
      controller.reimbursement_import_service(file)
    end
  end

  describe '#express_receipt_import_service' do
    it '返回 ExpressReceiptImportService 实例' do
      expect(ExpressReceiptImportService).to receive(:new).with(file, admin_user)
      controller.express_receipt_import_service(file)
    end
  end

  describe '#fee_detail_import_service' do
    it '返回 FeeDetailImportService 实例' do
      expect(FeeDetailImportService).to receive(:new).with(file, admin_user)
      controller.fee_detail_import_service(file)
    end
  end

  describe '#operation_history_import_service' do
    it '返回 OperationHistoryImportService 实例' do
      expect(OperationHistoryImportService).to receive(:new).with(file, admin_user)
      controller.operation_history_import_service(file)
    end
  end

  describe '#audit_work_order_service' do
    it '返回 AuditWorkOrderService 实例' do
      expect(AuditWorkOrderService).to receive(:new).with(work_order, admin_user)
      controller.audit_work_order_service(work_order)
    end
  end

  describe '#communication_work_order_service' do
    it '返回 CommunicationWorkOrderService 实例' do
      expect(CommunicationWorkOrderService).to receive(:new).with(work_order, admin_user)
      controller.communication_work_order_service(work_order)
    end
  end

  describe '#express_receipt_work_order_service' do
    it '返回 ExpressReceiptWorkOrderService 实例' do
      expect(ExpressReceiptWorkOrderService).to receive(:new).with(work_order, admin_user)
      controller.express_receipt_work_order_service(work_order)
    end
  end

  describe '#fee_detail_verification_service' do
    it '返回 FeeDetailVerificationService 实例' do
      expect(FeeDetailVerificationService).to receive(:new).with(admin_user)
      controller.fee_detail_verification_service
    end
  end

  describe '#work_order_status_change_service' do
    it '返回 WorkOrderStatusChangeService 实例' do
      expect(WorkOrderStatusChangeService).to receive(:new).with(admin_user)
      controller.work_order_status_change_service
    end
  end
end