# spec/services/service_registry_spec.rb
require 'rails_helper'

RSpec.describe ServiceRegistry do
  let(:admin_user) { create(:admin_user) }
  let(:file) { double('File') }
  let(:reimbursement) { create(:reimbursement) }
  let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }
  let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, audit_work_order: audit_work_order) }
  let(:express_receipt_work_order) { create(:express_receipt_work_order, reimbursement: reimbursement) }
  
  # 模拟服务实例
  let(:reimbursement_import_service) { double('ReimbursementImportService') }
  let(:express_receipt_import_service) { double('ExpressReceiptImportService') }
  let(:fee_detail_import_service) { double('FeeDetailImportService') }
  let(:operation_history_import_service) { double('OperationHistoryImportService') }
  let(:audit_work_order_service) { double('AuditWorkOrderService') }
  let(:communication_work_order_service) { double('CommunicationWorkOrderService') }
  let(:express_receipt_work_order_service) { double('ExpressReceiptWorkOrderService') }
  let(:fee_detail_verification_service) { double('FeeDetailVerificationService') }
  
  before do
    allow(Current).to receive(:admin_user).and_return(admin_user)
    
    # 模拟服务类和它们的初始化方法
    stub_const("ReimbursementImportService", Class.new do
      def initialize(file, admin_user); end
    end)
    
    stub_const("ExpressReceiptImportService", Class.new do
      def initialize(file, admin_user); end
    end)
    
    stub_const("FeeDetailImportService", Class.new do
      def initialize(file, admin_user); end
    end)
    
    stub_const("OperationHistoryImportService", Class.new do
      def initialize(file, admin_user); end
    end)
    
    stub_const("AuditWorkOrderService", Class.new do
      def initialize(work_order, admin_user); end
    end)
    
    stub_const("CommunicationWorkOrderService", Class.new do
      def initialize(work_order, admin_user); end
    end)
    
    stub_const("ExpressReceiptWorkOrderService", Class.new do
      def initialize(work_order, admin_user); end
    end)
    
    stub_const("FeeDetailVerificationService", Class.new do
      def initialize(admin_user); end
    end)
  end
  
  describe '.get_service' do
    it 'returns an instance of the specified service class' do
      service = described_class.get_service(ReimbursementImportService, file, admin_user)
      expect(service).to be_a(ReimbursementImportService)
    end
    
    it 'accepts a string as service class name' do
      service = described_class.get_service('ReimbursementImportService', file, admin_user)
      expect(service).to be_a(ReimbursementImportService)
    end
    
    it 'raises an error for unknown service class' do
      expect { described_class.get_service('UnknownService') }.to raise_error(ArgumentError, /未知的服务类/)
    end
  end
  
  describe '.get_service_by_name' do
    it 'returns an instance of the service with the specified name' do
      service = described_class.get_service_by_name('reimbursement_import', file, admin_user)
      expect(service).to be_a(ReimbursementImportService)
    end
    
    it 'adds "Service" suffix if not present' do
      service = described_class.get_service_by_name('fee_detail_verification', admin_user)
      expect(service).to be_a(FeeDetailVerificationService)
    end
  end
  
  describe '.get_work_order_service' do
    it 'returns AuditWorkOrderService for AuditWorkOrder' do
      service = described_class.get_work_order_service(audit_work_order, admin_user)
      expect(service).to be_a(AuditWorkOrderService)
    end
    
    it 'returns CommunicationWorkOrderService for CommunicationWorkOrder' do
      service = described_class.get_work_order_service(communication_work_order, admin_user)
      expect(service).to be_a(CommunicationWorkOrderService)
    end
    
    it 'returns ExpressReceiptWorkOrderService for ExpressReceiptWorkOrder' do
      service = described_class.get_work_order_service(express_receipt_work_order, admin_user)
      expect(service).to be_a(ExpressReceiptWorkOrderService)
    end
    
    it 'uses Current.admin_user if no user provided' do
      expect(AuditWorkOrderService).to receive(:new).with(audit_work_order, admin_user)
      described_class.get_work_order_service(audit_work_order)
    end
    
    it 'raises an error for unsupported work order type' do
      work_order = double('WorkOrder')
      allow(work_order).to receive(:class).and_return(WorkOrder)
      
      expect { described_class.get_work_order_service(work_order) }.to raise_error(ArgumentError, /不支持的工单类型/)
    end
  end
  
  describe 'convenience methods' do
    it 'returns ReimbursementImportService from reimbursement_import_service' do
      service = described_class.reimbursement_import_service(file, admin_user)
      expect(service).to be_a(ReimbursementImportService)
    end
    
    it 'returns ExpressReceiptImportService from express_receipt_import_service' do
      service = described_class.express_receipt_import_service(file, admin_user)
      expect(service).to be_a(ExpressReceiptImportService)
    end
    
    it 'returns FeeDetailImportService from fee_detail_import_service' do
      service = described_class.fee_detail_import_service(file, admin_user)
      expect(service).to be_a(FeeDetailImportService)
    end
    
    it 'returns OperationHistoryImportService from operation_history_import_service' do
      service = described_class.operation_history_import_service(file, admin_user)
      expect(service).to be_a(OperationHistoryImportService)
    end
    
    it 'returns AuditWorkOrderService from audit_work_order_service' do
      service = described_class.audit_work_order_service(audit_work_order, admin_user)
      expect(service).to be_a(AuditWorkOrderService)
    end
    
    it 'returns CommunicationWorkOrderService from communication_work_order_service' do
      service = described_class.communication_work_order_service(communication_work_order, admin_user)
      expect(service).to be_a(CommunicationWorkOrderService)
    end
    
    it 'returns FeeDetailVerificationService from fee_detail_verification_service' do
      service = described_class.fee_detail_verification_service(admin_user)
      expect(service).to be_a(FeeDetailVerificationService)
    end
    
    it 'uses Current.admin_user if no user provided' do
      expect(FeeDetailVerificationService).to receive(:new).with(admin_user)
      described_class.fee_detail_verification_service
    end
  end
end