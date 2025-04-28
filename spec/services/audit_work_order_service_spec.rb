# spec/services/audit_work_order_service_spec.rb
require 'rails_helper'

RSpec.describe AuditWorkOrderService do
  # 使用 double 而不是实际创建记录，避免数据库操作
  let(:admin_user) { instance_double(AdminUser, id: 1) }
  let(:reimbursement) { instance_double(Reimbursement, id: 1, invoice_number: 'R202501001') }
  let(:audit_work_order) do
    instance_double(AuditWorkOrder,
      id: 1,
      reimbursement: reimbursement,
      errors: instance_double(ActiveModel::Errors, add: nil, '[]': [], empty?: true),
      assign_attributes: nil
    )
  end
  let(:service) { described_class.new(audit_work_order, admin_user) }

  before do
    # 允许 audit_work_order 接收 is_a? 方法调用
    allow(audit_work_order).to receive(:is_a?).with(AuditWorkOrder).and_return(true)
    # 允许 Current 接收 admin_user= 方法调用
    allow(Current).to receive(:admin_user=)
  end
  
  describe '#initialize' do
    it 'raises error if not given an AuditWorkOrder' do
      expect { described_class.new("not a work order", admin_user) }.to raise_error(ArgumentError)
    end
    
    it 'sets Current.admin_user' do
      expect(Current).to receive(:admin_user=).with(admin_user)
      described_class.new(audit_work_order, admin_user)
    end
  end
  
  describe '#start_processing' do
    before do
      allow(audit_work_order).to receive(:start_processing!)
    end
    
    it 'calls start_processing! on the work order' do
      expect(audit_work_order).to receive(:start_processing!)
      service.start_processing
    end
    
    it 'returns true on success' do
      expect(service.start_processing).to be true
    end
    
    it 'returns false on failure' do
      # 使用 StandardError 代替 StateMachines::InvalidTransition
      allow(audit_work_order).to receive(:start_processing!).and_raise(StandardError.new("Invalid transition"))
      allow(audit_work_order.errors).to receive(:add)
      expect(audit_work_order.errors).to receive(:add).with(:base, /无法开始处理/)
      
      expect(service.start_processing).to be false
    end
    
    it 'assigns shared attributes' do
      params = { problem_type: '问题类型A', problem_description: '问题描述1', remark: '备注', processing_opinion: '处理意见X' }
      expect(audit_work_order).to receive(:assign_attributes).with(params)
      service.start_processing(params)
    end
  end
  
  describe '#approve' do
    before do
      allow(audit_work_order).to receive(:approve!)
      allow(audit_work_order).to receive(:audit_comment=)
    end
    
    it 'calls approve! on the work order' do
      expect(audit_work_order).to receive(:approve!)
      service.approve
    end
    
    it 'sets audit_comment if provided' do
      expect(audit_work_order).to receive(:audit_comment=).with('测试审核意见')
      service.approve(audit_comment: '测试审核意见')
    end
    
    it 'returns true on success' do
      expect(service.approve).to be true
    end
    
    it 'returns false on failure' do
      # 使用 StandardError 代替 StateMachines::InvalidTransition
      allow(audit_work_order).to receive(:approve!).and_raise(StandardError.new("Invalid transition"))
      allow(audit_work_order.errors).to receive(:add)
      expect(audit_work_order.errors).to receive(:add).with(:base, /无法批准/)
      
      expect(service.approve).to be false
    end
    
    it 'assigns shared attributes' do
      params = { problem_type: '问题类型A', audit_comment: '审核意见' }
      expect(audit_work_order).to receive(:assign_attributes).with(hash_including(problem_type: '问题类型A'))
      service.approve(params)
    end
  end
  
  describe '#reject' do
    before do
      allow(audit_work_order).to receive(:reject!)
      allow(audit_work_order).to receive(:audit_comment=)
    end
    
    it 'requires audit_comment' do
      allow(audit_work_order.errors).to receive(:add)
      expect(audit_work_order.errors).to receive(:add).with(:audit_comment, /必须填写拒绝理由/)
      
      expect(service.reject).to be false
    end
    
    it 'calls reject! on the work order' do
      expect(audit_work_order).to receive(:reject!)
      service.reject(audit_comment: '测试拒绝理由')
    end
    
    it 'sets audit_comment' do
      expect(audit_work_order).to receive(:audit_comment=).with('测试拒绝理由')
      service.reject(audit_comment: '测试拒绝理由')
    end
    
    it 'returns true on success' do
      expect(service.reject(audit_comment: '测试拒绝理由')).to be true
    end
    
    it 'returns false on failure' do
      # 使用 StandardError 代替 StateMachines::InvalidTransition
      allow(audit_work_order).to receive(:reject!).and_raise(StandardError.new("Invalid transition"))
      allow(audit_work_order.errors).to receive(:add)
      expect(audit_work_order.errors).to receive(:add).with(:base, /无法拒绝/)
      
      expect(service.reject(audit_comment: '测试拒绝理由')).to be false
    end
    
    it 'assigns shared attributes' do
      params = { problem_type: '问题类型A', audit_comment: '拒绝理由' }
      expect(audit_work_order).to receive(:assign_attributes).with(hash_including(problem_type: '问题类型A'))
      service.reject(params)
    end
  end
  
  describe '#select_fee_details' do
    let(:fee_detail_ids) { [1, 2, 3] }
    
    it 'delegates to the work order' do
      expect(audit_work_order).to receive(:select_fee_details).with(fee_detail_ids)
      service.select_fee_details(fee_detail_ids)
    end
  end
  
  describe '#update_fee_detail_verification' do
    let(:fee_detail) { instance_double(FeeDetail, id: 1) }
    let(:verification_service) { instance_double(FeeDetailVerificationService) }
    let(:fee_details) { instance_double(ActiveRecord::Relation) }
    
    before do
      allow(audit_work_order).to receive(:fee_details).and_return(fee_details)
      allow(fee_details).to receive(:find_by).with(id: fee_detail.id).and_return(fee_detail)
      allow(fee_details).to receive(:find_by).with(id: 999).and_return(nil)
      allow(FeeDetailVerificationService).to receive(:new).and_return(verification_service)
      allow(verification_service).to receive(:update_verification_status)
    end
    
    it 'creates a FeeDetailVerificationService with the current admin user' do
      expect(FeeDetailVerificationService).to receive(:new).with(admin_user)
      service.update_fee_detail_verification(fee_detail.id, 'verified')
    end
    
    it 'calls update_verification_status on the verification service' do
      expect(verification_service).to receive(:update_verification_status).with(fee_detail, 'verified', nil)
      service.update_fee_detail_verification(fee_detail.id, 'verified')
    end
    
    it 'passes comment to the verification service if provided' do
      expect(verification_service).to receive(:update_verification_status).with(fee_detail, 'verified', '测试验证意见')
      service.update_fee_detail_verification(fee_detail.id, 'verified', '测试验证意见')
    end
    
    it 'returns false if fee detail not found' do
      allow(audit_work_order.errors).to receive(:add)
      expect(audit_work_order.errors).to receive(:add).with(:base, /未找到关联的费用明细/)
      
      expect(service.update_fee_detail_verification(999, 'verified')).to be false
    end
  end
end