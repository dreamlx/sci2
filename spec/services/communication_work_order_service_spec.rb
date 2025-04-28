# spec/services/communication_work_order_service_spec.rb
require 'rails_helper'

RSpec.describe CommunicationWorkOrderService do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }
  let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, audit_work_order: audit_work_order) }
  let(:service) { described_class.new(communication_work_order, admin_user) }

  before do
    Current.admin_user = admin_user
  end

  after do
    Current.reset
  end

  describe '#initialize' do
    it 'raises error if not given a CommunicationWorkOrder' do
      expect { described_class.new("not a work order", admin_user) }.to raise_error(ArgumentError)
    end
    
    it 'sets Current.admin_user' do
      expect(Current).to receive(:admin_user=).with(admin_user)
      described_class.new(communication_work_order, admin_user)
    end
  end
  
  describe '#start_processing' do
    it 'calls start_processing! on the work order' do
      expect(communication_work_order).to receive(:start_processing!)
      service.start_processing
    end
    
    it 'returns true on success' do
      allow(communication_work_order).to receive(:start_processing!).and_return(true)
      expect(service.start_processing).to be true
    end
    
    it 'returns false on failure' do
      # Create a generic StateMachines::InvalidTransition exception
      invalid_transition = begin
        # Create a mock exception that mimics StateMachines::InvalidTransition
        exception = StandardError.new("Cannot transition from 'pending' to 'processing'")
        def exception.message
          "Cannot transition from 'pending' to 'processing'"
        end
        exception
      end
      
      allow(communication_work_order).to receive(:start_processing!).and_raise(invalid_transition)
      expect(service.start_processing).to be false
      expect(communication_work_order.errors[:base]).to include(a_string_matching(/无法开始处理/))
    end
    
    it 'assigns shared attributes' do
      params = { problem_type: '问题类型A', problem_description: '问题描述1', remark: '备注', processing_opinion: '处理意见X' }
      expect(communication_work_order).to receive(:assign_attributes).with(params)
      allow(communication_work_order).to receive(:start_processing!)
      service.start_processing(params)
    end
  end
  
  describe '#mark_needs_communication' do
    it 'calls mark_needs_communication! on the work order' do
      expect(communication_work_order).to receive(:mark_needs_communication!)
      service.mark_needs_communication
    end
    
    it 'returns true on success' do
      allow(communication_work_order).to receive(:mark_needs_communication!).and_return(true)
      expect(service.mark_needs_communication).to be true
    end
    
    it 'returns false on failure' do
      # Create a generic StateMachines::InvalidTransition exception
      invalid_transition = begin
        # Create a mock exception that mimics StateMachines::InvalidTransition
        exception = StandardError.new("Cannot transition from 'pending' to 'needs_communication'")
        def exception.message
          "Cannot transition from 'pending' to 'needs_communication'"
        end
        exception
      end
      
      allow(communication_work_order).to receive(:mark_needs_communication!).and_raise(invalid_transition)
      expect(service.mark_needs_communication).to be false
      expect(communication_work_order.errors[:base]).to include(a_string_matching(/无法标记为需要沟通/))
    end
    
    it 'assigns shared attributes' do
      params = { problem_type: '问题类型A', problem_description: '问题描述1' }
      expect(communication_work_order).to receive(:assign_attributes).with(params)
      allow(communication_work_order).to receive(:mark_needs_communication!)
      service.mark_needs_communication(params)
    end
  end
  
  describe '#approve' do
    before do
      allow(communication_work_order).to receive(:status).and_return('processing')
    end
    
    it 'calls approve! on the work order' do
      expect(communication_work_order).to receive(:approve!)
      service.approve
    end
    
    it 'sets resolution_summary if provided' do
      expect(communication_work_order).to receive(:resolution_summary=).with('测试解决方案')
      allow(communication_work_order).to receive(:approve!)
      service.approve(resolution_summary: '测试解决方案')
    end
    
    it 'returns true on success' do
      allow(communication_work_order).to receive(:approve!).and_return(true)
      expect(service.approve).to be true
    end
    
    it 'returns false on failure' do
      # Create a generic StateMachines::InvalidTransition exception
      invalid_transition = begin
        # Create a mock exception that mimics StateMachines::InvalidTransition
        exception = StandardError.new("Cannot transition from 'processing' to 'approved'")
        def exception.message
          "Cannot transition from 'processing' to 'approved'"
        end
        exception
      end
      
      allow(communication_work_order).to receive(:approve!).and_raise(invalid_transition)
      expect(service.approve).to be false
      expect(communication_work_order.errors[:base]).to include(a_string_matching(/无法批准/))
    end
    
    it 'assigns shared attributes' do
      params = { problem_type: '问题类型A', resolution_summary: '解决方案' }
      expect(communication_work_order).to receive(:assign_attributes).with(hash_including(problem_type: '问题类型A'))
      allow(communication_work_order).to receive(:approve!)
      service.approve(params)
    end
  end
  
  describe '#reject' do
    before do
      allow(communication_work_order).to receive(:status).and_return('processing')
    end
    
    it 'requires resolution_summary' do
      expect(service.reject).to be false
      expect(communication_work_order.errors[:resolution_summary]).to include(a_string_matching(/必须填写拒绝理由\/摘要/))
    end
    
    it 'calls reject! on the work order' do
      expect(communication_work_order).to receive(:reject!)
      service.reject(resolution_summary: '测试拒绝理由')
    end
    
    it 'sets resolution_summary' do
      expect(communication_work_order).to receive(:resolution_summary=).with('测试拒绝理由')
      allow(communication_work_order).to receive(:reject!)
      service.reject(resolution_summary: '测试拒绝理由')
    end
    
    it 'returns true on success' do
      allow(communication_work_order).to receive(:reject!).and_return(true)
      expect(service.reject(resolution_summary: '测试拒绝理由')).to be true
    end
    
    it 'returns false on failure' do
      # Create a generic StateMachines::InvalidTransition exception
      invalid_transition = begin
        # Create a mock exception that mimics StateMachines::InvalidTransition
        exception = StandardError.new("Cannot transition from 'processing' to 'rejected'")
        def exception.message
          "Cannot transition from 'processing' to 'rejected'"
        end
        exception
      end
      
      allow(communication_work_order).to receive(:reject!).and_raise(invalid_transition)
      expect(service.reject(resolution_summary: '测试拒绝理由')).to be false
      expect(communication_work_order.errors[:base]).to include(a_string_matching(/无法拒绝/))
    end
    
    it 'assigns shared attributes' do
      params = { problem_type: '问题类型A', resolution_summary: '拒绝理由' }
      expect(communication_work_order).to receive(:assign_attributes).with(hash_including(problem_type: '问题类型A'))
      allow(communication_work_order).to receive(:reject!)
      service.reject(params)
    end
  end
  
  describe '#add_communication_record' do
    let(:params) { { content: '测试沟通内容', communicator_role: '审核人' } }
    let(:communication_record) { build_stubbed(:communication_record) }
    
    it 'delegates to the work order' do
      expect(communication_work_order).to receive(:add_communication_record).and_return(communication_record)
      allow(communication_record).to receive(:persisted?).and_return(true)
      service.add_communication_record(params)
    end
    
    it 'adds current admin user email if communicator_name not provided' do
      expected_params = hash_including(
        content: '测试沟通内容',
        communicator_role: '审核人',
        communicator_name: admin_user.email
      )
      expect(communication_work_order).to receive(:add_communication_record).with(expected_params).and_return(communication_record)
      allow(communication_record).to receive(:persisted?).and_return(true)
      service.add_communication_record(params)
    end
    
    it 'adds recorded_at' do
      recorded_at = Time.current
      expect(communication_work_order).to receive(:add_communication_record).with(
        hash_including(
          content: '测试沟通内容',
          communicator_role: '审核人',
          communicator_name: admin_user.email,
          recorded_at: be_within(1.second).of(recorded_at)
        )
      ).and_return(communication_record)
      allow(communication_record).to receive(:persisted?).and_return(true)
      service.add_communication_record(params)
    end
    
    it 'adds error if record not persisted' do
      allow(communication_work_order).to receive(:add_communication_record).and_return(communication_record)
      allow(communication_record).to receive(:persisted?).and_return(false)
      allow(communication_record).to receive(:errors).and_return(double(full_messages: ['错误消息']))
      
      service.add_communication_record(params)
      expect(communication_work_order.errors[:base]).to include(a_string_matching(/添加沟通记录失败/))
    end
  end
  
  describe '#select_fee_details' do
    let(:fee_detail_ids) { [1, 2, 3] }
    
    it 'delegates to the work order' do
      expect(communication_work_order).to receive(:select_fee_details).with(fee_detail_ids)
      service.select_fee_details(fee_detail_ids)
    end
  end
  
  describe '#update_fee_detail_verification' do
    let(:fee_detail) { create(:fee_detail) }
    let(:verification_service) { instance_double(FeeDetailVerificationService) }
    
    before do
      allow(communication_work_order).to receive_message_chain(:fee_details, :find_by).and_return(fee_detail)
      allow(FeeDetailVerificationService).to receive(:new).and_return(verification_service)
    end
    
    it 'creates a FeeDetailVerificationService with the current admin user' do
      expect(FeeDetailVerificationService).to receive(:new).with(admin_user)
      allow(verification_service).to receive(:update_verification_status)
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
      allow(communication_work_order).to receive_message_chain(:fee_details, :find_by).and_return(nil)
      expect(service.update_fee_detail_verification(999, 'verified')).to be false
      expect(communication_work_order.errors[:base]).to include(a_string_matching(/未找到关联的费用明细/))
    end
  end
end