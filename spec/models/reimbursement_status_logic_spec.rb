require 'rails_helper'

RSpec.describe Reimbursement, type: :model do
  describe 'New Status Logic with Manual Override' do
    let(:reimbursement) { create(:reimbursement, status: 'pending', external_status: '审批中') }
    
    describe '#manual_status_change!' do
      it 'allows manual status change to any valid status' do
        expect(reimbursement.status).to eq('pending')
        expect(reimbursement.manual_override).to be_falsey
        
        reimbursement.manual_status_change!('closed')
        
        expect(reimbursement.status).to eq('closed')
        expect(reimbursement.manual_override).to be_truthy
        expect(reimbursement.manual_override_at).to be_present
      end
      
      it 'updates manual_override_at timestamp' do
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)
        
        reimbursement.manual_status_change!('processing')
        
        expect(reimbursement.manual_override_at).to eq(freeze_time)
      end
      
      it 'allows changing from any status to any other status' do
        # Test all possible transitions
        ['pending', 'processing', 'closed'].each do |from_status|
          ['pending', 'processing', 'closed'].each do |to_status|
            next if from_status == to_status
            
            reimbursement.update!(status: from_status, manual_override: false)
            
            expect {
              reimbursement.manual_status_change!(to_status)
            }.not_to raise_error
            
            expect(reimbursement.status).to eq(to_status)
            expect(reimbursement.manual_override).to be_truthy
          end
        end
      end
    end
    
    describe '#reset_manual_override!' do
      before do
        reimbursement.manual_status_change!('closed')
      end
      
      it 'resets manual override flags' do
        expect(reimbursement.manual_override).to be_truthy
        expect(reimbursement.manual_override_at).to be_present
        
        reimbursement.reset_manual_override!
        
        expect(reimbursement.manual_override).to be_falsey
        expect(reimbursement.manual_override_at).to be_nil
      end
      
      it 'recalculates status based on system logic' do
        # Set up a scenario where external status should drive internal status
        reimbursement.update!(external_status: '已付款')
        reimbursement.reset_manual_override!
        
        # Should determine status based on external status priority
        expect(reimbursement.status).to eq('closed')
      end
    end
    
    describe '#should_close_based_on_external_status?' do
      it 'returns true for "已付款" external status' do
        reimbursement.external_status = '已付款'
        expect(reimbursement.should_close_based_on_external_status?).to be_truthy
      end
      
      it 'returns true for "待付款" external status' do
        reimbursement.external_status = '待付款'
        expect(reimbursement.should_close_based_on_external_status?).to be_truthy
      end
      
      it 'returns false for other external statuses' do
        ['审批中', '待审核'].each do |status|
          reimbursement.external_status = status
          expect(reimbursement.should_close_based_on_external_status?).to be_falsey
        end
      end
    end
    
    describe '#determine_internal_status_from_external' do
      context 'when manual override is active' do
        before do
          reimbursement.manual_status_change!('processing')
        end
        
        it 'returns current status without change' do
          reimbursement.external_status = '已付款'
          expect(reimbursement.determine_internal_status_from_external('审批中')).to eq('processing')
        end
      end
      
      context 'when no manual override' do
        it 'returns "closed" for closing external statuses' do
          ['已付款', '待付款'].each do |ext_status|
            expect(reimbursement.determine_internal_status_from_external(ext_status)).to eq('closed')
          end
        end
        
        it 'returns "processing" when there are active work orders' do
          # Mock the has_active_work_orders? method to return true
          allow(reimbursement).to receive(:has_active_work_orders?).and_return(true)
          
          expect(reimbursement.determine_internal_status_from_external('审批中')).to eq('processing')
        end
        
        it 'returns "pending" when no active work orders and non-closing external status' do
          expect(reimbursement.determine_internal_status_from_external('审批中')).to eq('pending')
        end
      end
    end
    
    describe 'External Status Priority Logic' do
      it 'prioritizes external status over work order status when appropriate' do
        # Mock active work orders
        allow(reimbursement).to receive(:has_active_work_orders?).and_return(true)
        
        # External status should override work order logic
        expect(reimbursement.determine_internal_status_from_external('已付款')).to eq('closed')
      end
      
      it 'uses work order logic when external status does not require closing' do
        allow(reimbursement).to receive(:has_active_work_orders?).and_return(true)
        
        expect(reimbursement.determine_internal_status_from_external('审批中')).to eq('processing')
      end
    end
    
    describe 'Manual Override Protection' do
      before do
        reimbursement.manual_status_change!('closed')
      end
      
      it 'protects manual status from automatic changes' do
        original_status = reimbursement.status
        
        # Try to change external status - should not affect internal status
        result = reimbursement.determine_internal_status_from_external('审批中')
        
        expect(result).to eq(original_status)
      end
      
      it 'allows manual changes even when override is active' do
        reimbursement.manual_status_change!('pending')
        expect(reimbursement.status).to eq('pending')
      end
    end
  end
end