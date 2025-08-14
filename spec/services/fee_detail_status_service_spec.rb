require 'rails_helper'

RSpec.describe FeeDetailStatusService, type: :service do
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  
  describe '#update_status' do
    context '当费用明细没有关联工单时' do
      it '状态应该为 pending' do
        service = FeeDetailStatusService.new([fee_detail.id])
        service.update_status
        
        expect(fee_detail.reload.verification_status).to eq('pending')
      end
    end
    
    context '当费用明细只关联审核工单时' do
      let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'approved') }
      
      before do
        create(:work_order_fee_detail, fee_detail: fee_detail, work_order: audit_work_order)
      end
      
      it '应该根据审核工单状态更新' do
        service = FeeDetailStatusService.new([fee_detail.id])
        service.update_status
        
        expect(fee_detail.reload.verification_status).to eq('verified')
      end
    end
    
    context '当费用明细只关联沟通工单时' do
      let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, status: 'completed') }
      
      before do
        create(:work_order_fee_detail, fee_detail: fee_detail, work_order: communication_work_order)
      end
      
      it '状态应该保持为 pending（沟通工单不影响状态）' do
        service = FeeDetailStatusService.new([fee_detail.id])
        service.update_status
        
        expect(fee_detail.reload.verification_status).to eq('pending')
      end
    end
    
    context '当费用明细同时关联审核工单和沟通工单时' do
      let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'approved') }
      let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, status: 'completed') }
      
      before do
        create(:work_order_fee_detail, fee_detail: fee_detail, work_order: audit_work_order)
        create(:work_order_fee_detail, fee_detail: fee_detail, work_order: communication_work_order)
      end
      
      it '应该只根据审核工单状态更新，忽略沟通工单' do
        service = FeeDetailStatusService.new([fee_detail.id])
        service.update_status
        
        expect(fee_detail.reload.verification_status).to eq('verified')
      end
    end
    
    context '当有多个审核工单和沟通工单时' do
      let(:old_audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'rejected', created_at: 1.day.ago) }
      let(:new_audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'approved', created_at: 1.hour.ago) }
      let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, status: 'completed', created_at: 30.minutes.ago) }
      
      before do
        create(:work_order_fee_detail, fee_detail: fee_detail, work_order: old_audit_work_order)
        create(:work_order_fee_detail, fee_detail: fee_detail, work_order: new_audit_work_order)
        create(:work_order_fee_detail, fee_detail: fee_detail, work_order: communication_work_order)
      end
      
      it '应该根据最新的审核工单状态更新' do
        service = FeeDetailStatusService.new([fee_detail.id])
        service.update_status
        
        expect(fee_detail.reload.verification_status).to eq('verified')
      end
    end
  end
  
  describe '#get_latest_work_order' do
    let(:service) { FeeDetailStatusService.new([fee_detail.id]) }
    
    context '当有审核工单和沟通工单时' do
      let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, created_at: 1.hour.ago) }
      let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, created_at: 30.minutes.ago) }
      
      before do
        create(:work_order_fee_detail, fee_detail: fee_detail, work_order: audit_work_order)
        create(:work_order_fee_detail, fee_detail: fee_detail, work_order: communication_work_order)
      end
      
      it '应该返回最新的审核工单，排除沟通工单' do
        latest_work_order = service.send(:get_latest_work_order, fee_detail)
        expect(latest_work_order).to eq(audit_work_order)
        expect(latest_work_order).not_to eq(communication_work_order)
      end
    end
    
    context '当只有沟通工单时' do
      let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement) }
      
      before do
        create(:work_order_fee_detail, fee_detail: fee_detail, work_order: communication_work_order)
      end
      
      it '应该返回 nil' do
        latest_work_order = service.send(:get_latest_work_order, fee_detail)
        expect(latest_work_order).to be_nil
      end
    end
  end
  
  describe '#determine_status_from_work_order' do
    let(:service) { FeeDetailStatusService.new([fee_detail.id]) }
    
    context '当工单是沟通工单时' do
      let(:communication_work_order) { create(:communication_work_order, status: 'completed') }
      
      it '应该返回 pending' do
        status = service.send(:determine_status_from_work_order, communication_work_order)
        expect(status).to eq('pending')
      end
    end
    
    context '当工单是审核工单时' do
      it '已批准的审核工单应该返回 verified' do
        audit_work_order = create(:audit_work_order, status: 'approved')
        status = service.send(:determine_status_from_work_order, audit_work_order)
        expect(status).to eq('verified')
      end
      
      it '已拒绝的审核工单应该返回 problematic' do
        audit_work_order = create(:audit_work_order, status: 'rejected')
        status = service.send(:determine_status_from_work_order, audit_work_order)
        expect(status).to eq('problematic')
      end
      
      it '待处理的审核工单应该返回 pending' do
        audit_work_order = create(:audit_work_order, status: 'pending')
        status = service.send(:determine_status_from_work_order, audit_work_order)
        expect(status).to eq('pending')
      end
    end
  end
end