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

      expect do
        service.import
      end.to change(OperationHistory, :count).by(1)

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

    describe 'automatic auditor assignment from operation history' do
      let(:admin_user) { create(:admin_user) }
      let!(:auditor1) { create(:admin_user, name: '张三') }
      let!(:auditor2) { create(:admin_user, name: '李四') }

      context 'when reimbursement has no active assignment and operation type is "加签"' do
        let(:unassigned_reimbursement) { create(:reimbursement, invoice_number: 'R010') }
        let(:csv_content) do
          <<~CSV
            单据编号,操作类型,操作日期,操作人,操作意见
            R010,加签,2025-01-01 10:00:00,张三,添加审核人
          CSV
        end
        let(:csv_file) { Tempfile.new(['test', '.csv']) }

        before do
          unassigned_reimbursement
          csv_file.write(csv_content)
          csv_file.rewind
        end

        after do
          csv_file.close
          csv_file.unlink
        end

        it 'automatically assigns the reimbursement to the matching operator' do
          expect(unassigned_reimbursement.active_assignment).to be_nil

          service = described_class.new(csv_file, admin_user)
          result = service.import

          expect(result[:success]).to be_truthy
          expect(result[:imported]).to eq(1)

          unassigned_reimbursement.reload
          assignment = unassigned_reimbursement.active_assignment

          expect(assignment).to be_present
          expect(assignment.assignee).to eq(auditor1)
          expect(assignment.assigner).to eq(admin_user)
          expect(assignment.is_active).to be true
          expect(assignment.notes).to include('自动分配：操作历史中检测到加签操作和操作人匹配')
        end

        it 'handles operator name with extra content' do
          csv_content_modified = <<~CSV
            单据编号,操作类型,操作日期,操作人,操作意见
            R010,加签,2025-01-01 10:00:00,审核员张三,添加审核人
          CSV

          csv_file.rewind
          csv_file.truncate(0)
          csv_file.write(csv_content_modified)
          csv_file.rewind

          service = described_class.new(csv_file, admin_user)
          service.import

          unassigned_reimbursement.reload
          assignment = unassigned_reimbursement.active_assignment

          expect(assignment).to be_present
          expect(assignment.assignee).to eq(auditor1)
        end
      end

      context 'when reimbursement already has an active assignment' do
        let(:assigned_reimbursement) { create(:reimbursement, invoice_number: 'R011') }
        let!(:existing_assignment) do
          create(:reimbursement_assignment, reimbursement: assigned_reimbursement, assignee: auditor2, assigner: admin_user,
                                            is_active: true)
        end
        let(:csv_content) do
          <<~CSV
            单据编号,操作类型,操作日期,操作人,操作意见
            R011,加签,2025-01-01 10:00:00,张三,添加审核人
          CSV
        end
        let(:csv_file) { Tempfile.new(['test', '.csv']) }

        before do
          assigned_reimbursement
          existing_assignment
          csv_file.write(csv_content)
          csv_file.rewind
        end

        after do
          csv_file.close
          csv_file.unlink
        end

        it 'does not create a new assignment' do
          expect(assigned_reimbursement.active_assignment).to eq(existing_assignment)

          service = described_class.new(csv_file, admin_user)
          result = service.import

          expect(result[:success]).to be_truthy
          expect(result[:imported]).to eq(1)

          assigned_reimbursement.reload
          expect(assigned_reimbursement.active_assignment).to eq(existing_assignment)
          expect(ReimbursementAssignment.where(reimbursement: assigned_reimbursement).count).to eq(1)
        end
      end

      context 'when operation type is not "加签"' do
        let(:unassigned_reimbursement) { create(:reimbursement, invoice_number: 'R012') }
        let(:csv_content) do
          <<~CSV
            单据编号,操作类型,操作日期,操作人,操作意见
            R012,审核,2025-01-01 10:00:00,张三,审核通过
          CSV
        end
        let(:csv_file) { Tempfile.new(['test', '.csv']) }

        before do
          unassigned_reimbursement
          csv_file.write(csv_content)
          csv_file.rewind
        end

        after do
          csv_file.close
          csv_file.unlink
        end

        it 'does not assign the reimbursement' do
          expect(unassigned_reimbursement.active_assignment).to be_nil

          service = described_class.new(csv_file, admin_user)
          result = service.import

          expect(result[:success]).to be_truthy
          expect(result[:imported]).to eq(1)

          unassigned_reimbursement.reload
          expect(unassigned_reimbursement.active_assignment).to be_nil
        end
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
