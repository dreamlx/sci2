require 'rails_helper'

RSpec.describe OperationHistoryImportService, type: :service do
  describe 'Automatic Reopening Removal' do
    let(:admin_user) { create(:admin_user) }
    let(:closed_reimbursement) { create(:reimbursement, status: 'closed', invoice_number: 'R001') }
    let(:csv_content) do
      <<~CSV
        单据编号,操作类型,操作日期,操作人,操作意见
        R001,审核,2025-01-01 10:00:00,张三,审核通过
      CSV
    end
    let(:csv_file) { Tempfile.new(['test', '.csv']) }
    
    before do
      csv_file.write(csv_content)
      csv_file.rewind
    end
    
    after do
      csv_file.close
      csv_file.unlink
    end
    
    it 'does not automatically reopen closed reimbursements' do
      expect(closed_reimbursement.status).to eq('closed')
      
      service = described_class.new(csv_file, admin_user)
      result = service.import
      
      # Verify the operation history was imported
      expect(result[:success]).to be_truthy
      expect(result[:imported]).to eq(1)
      
      # Verify the reimbursement status was NOT changed
      closed_reimbursement.reload
      expect(closed_reimbursement.status).to eq('closed')
      
      # Verify the operation history was still created
      operation_history = OperationHistory.find_by(document_number: 'R001')
      expect(operation_history).to be_present
      expect(operation_history.operation_type).to eq('审核')
    end
    
    it 'still imports operation history for closed reimbursements' do
      service = described_class.new(csv_file, admin_user)
      
      expect {
        service.import
      }.to change(OperationHistory, :count).by(1)
      
      operation_history = OperationHistory.last
      expect(operation_history.document_number).to eq('R001')
      expect(operation_history.operation_type).to eq('审核')
      expect(operation_history.operator).to eq('张三')
    end
    
    it 'does not increment updated_reimbursement_count for closed reimbursements' do
      service = described_class.new(csv_file, admin_user)
      result = service.import
      
      # The count should be 0 since we no longer automatically reopen
      expect(result[:updated_reimbursements]).to eq(0)
    end
    
    context 'with multiple reimbursements in different states' do
      let(:pending_reimbursement) { create(:reimbursement, status: 'pending', invoice_number: 'R002') }
      let(:processing_reimbursement) { create(:reimbursement, status: 'processing', invoice_number: 'R003') }
      let(:multi_csv_content) do
        <<~CSV
          单据编号,操作类型,操作日期,操作人,操作意见
          R001,审核,2025-01-01 10:00:00,张三,审核通过
          R002,提交,2025-01-02 11:00:00,李四,提交申请
          R003,处理,2025-01-03 12:00:00,王五,正在处理
        CSV
      end
      
      before do
        pending_reimbursement
        processing_reimbursement
        csv_file.rewind
        csv_file.truncate(0)
        csv_file.write(multi_csv_content)
        csv_file.rewind
      end
      
      it 'does not change status of any reimbursement regardless of current state' do
        original_statuses = {
          'R001' => closed_reimbursement.status,
          'R002' => pending_reimbursement.status,
          'R003' => processing_reimbursement.status
        }
        
        service = described_class.new(csv_file, admin_user)
        result = service.import
        
        expect(result[:success]).to be_truthy
        expect(result[:imported]).to eq(3)
        expect(result[:updated_reimbursements]).to eq(0)
        
        # Verify no status changes occurred
        [closed_reimbursement, pending_reimbursement, processing_reimbursement].each(&:reload)
        
        expect(closed_reimbursement.status).to eq(original_statuses['R001'])
        expect(pending_reimbursement.status).to eq(original_statuses['R002'])
        expect(processing_reimbursement.status).to eq(original_statuses['R003'])
      end
    end
  end
  
  describe 'Operation History Creation' do
    let(:admin_user) { create(:admin_user) }
    let(:reimbursement) { create(:reimbursement, invoice_number: 'R001') }
    let(:csv_content) do
      <<~CSV
        单据编号,操作类型,操作日期,操作人,操作意见,表单类型,操作节点
        R001,审核,2025-01-01 10:00:00,张三,审核通过,报销单,审核节点
      CSV
    end
    let(:csv_file) { Tempfile.new(['test', '.csv']) }
    
    before do
      csv_file.write(csv_content)
      csv_file.rewind
    end
    
    after do
      csv_file.close
      csv_file.unlink
    end
    
    it 'still creates operation history records correctly' do
      service = described_class.new(csv_file, admin_user)
      result = service.import
      
      expect(result[:success]).to be_truthy
      expect(result[:imported]).to eq(1)
      
      operation_history = OperationHistory.find_by(document_number: 'R001')
      expect(operation_history).to be_present
      expect(operation_history.operation_type).to eq('审核')
      expect(operation_history.operator).to eq('张三')
      expect(operation_history.notes).to eq('审核通过')
      expect(operation_history.form_type).to eq('报销单')
      expect(operation_history.operation_node).to eq('审核节点')
    end
  end
end