require 'rails_helper'

RSpec.describe Reimbursement, type: :model do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }

  describe 'Constants' do
    it 'defines the correct status constants' do
      expect(described_class::STATUS_PENDING).to eq('pending')
      expect(described_class::STATUS_PROCESSING).to eq('processing')
      expect(described_class::STATUS_CLOSED).to eq('closed')
      expect(described_class::STATUS_CLOSE_ALIAS).to eq('close')
      expect(described_class::STATUSES).to contain_exactly('pending', 'processing', 'closed', 'close')
    end
  end

  describe 'Associations' do
    it { should have_many(:fee_details).with_foreign_key('document_number').with_primary_key('invoice_number').dependent(:destroy) }
    it { should have_many(:work_orders).dependent(:destroy) }
    it { should have_many(:audit_work_orders).class_name('AuditWorkOrder') }
    it { should have_many(:communication_work_orders).class_name('CommunicationWorkOrder') }
    it { should have_many(:express_receipt_work_orders).class_name('ExpressReceiptWorkOrder') }
    it { should have_many(:operation_histories).with_foreign_key('document_number').with_primary_key('invoice_number').dependent(:destroy) }
    it { should have_many(:assignments).class_name('ReimbursementAssignment').dependent(:destroy) }
    it { should have_many(:assignees).through(:assignments).source(:assignee) }
    it { should have_one(:active_assignment).class_name('ReimbursementAssignment') }
    it { should have_one(:current_assignee).through(:active_assignment).source(:assignee) }

    it 'filters work orders by type correctly' do
      audit_wo = create(:work_order, reimbursement: reimbursement, type: 'AuditWorkOrder')
      comm_wo = create(:work_order, reimbursement: reimbursement, type: 'CommunicationWorkOrder')
      express_wo = create(:work_order, reimbursement: reimbursement, type: 'ExpressReceiptWorkOrder')

      expect(reimbursement.audit_work_orders).to contain_exactly(audit_wo)
      expect(reimbursement.communication_work_orders).to contain_exactly(comm_wo)
      expect(reimbursement.express_receipt_work_orders).to contain_exactly(express_wo)
    end
  end

  describe 'Validations' do
    subject { create(:reimbursement) }

    it { should validate_presence_of(:invoice_number) }
    it { should validate_uniqueness_of(:invoice_number) }
    it { should validate_inclusion_of(:status).in_array(described_class::STATUSES) }
    it { should allow_value(true).for(:is_electronic) }
    it { should allow_value(false).for(:is_electronic) }
    it { should_not allow_value(nil).for(:is_electronic) }
  end

  describe 'State Machine' do
    it 'starts in the pending state' do
      expect(reimbursement).to be_pending
    end

    context 'with event :start_processing' do
      it 'transitions from pending to processing' do
        reimbursement.start_processing
        expect(reimbursement).to be_processing
      end
    end

    context 'with event :close_processing' do
      let(:processing_reimbursement) { create(:reimbursement, status: 'processing') }
      it 'transitions from processing to closed' do
        processing_reimbursement.close_processing
        expect(processing_reimbursement).to be_closed
      end
    end

    context 'with event :reopen_to_processing' do
      let(:closed_reimbursement) { create(:reimbursement, status: 'closed') }
      it 'transitions from closed to processing' do
        closed_reimbursement.reopen_to_processing
        expect(closed_reimbursement).to be_processing
      end
    end
  end

  describe 'Scopes' do
    let!(:pending_reimbursement) { create(:reimbursement, status: 'pending', is_electronic: true) }
    let!(:processing_reimbursement) { create(:reimbursement, status: 'processing', is_electronic: false) }
    let!(:closed_reimbursement) { create(:reimbursement, status: 'closed', is_electronic: true) }
    let!(:unassigned_reimbursement) { create(:reimbursement) }
    let!(:assigned_reimbursement) { create(:reimbursement) }
    let!(:assignment) { create(:reimbursement_assignment, reimbursement: assigned_reimbursement, assignee: admin_user, is_active: true) }


    it '.pending returns reimbursements with pending status' do
      expect(described_class.pending).to contain_exactly(pending_reimbursement)
    end

    it '.processing returns reimbursements with processing status' do
      expect(described_class.processing).to contain_exactly(processing_reimbursement)
    end

    it '.closed returns reimbursements with closed status' do
      expect(described_class.closed).to contain_exactly(closed_reimbursement)
    end

    it '.electronic returns electronic reimbursements' do
      expect(described_class.electronic).to contain_exactly(pending_reimbursement, closed_reimbursement)
    end

    it '.non_electronic returns non-electronic reimbursements' do
      expect(described_class.non_electronic).to contain_exactly(processing_reimbursement)
    end

    it '.unassigned returns reimbursements without an active assignment' do
      expect(described_class.unassigned).to include(unassigned_reimbursement, pending_reimbursement, processing_reimbursement, closed_reimbursement)
      expect(described_class.unassigned).not_to include(assigned_reimbursement)
    end

    it '.assigned_to_user returns reimbursements assigned to a specific user' do
      expect(described_class.assigned_to_user(admin_user.id)).to contain_exactly(assigned_reimbursement)
    end

    it '.my_assignments returns the same as assigned_to_user' do
      expect(described_class.my_assignments(admin_user.id)).to eq(described_class.assigned_to_user(admin_user.id))
    end

    context 'with unread/unviewed scopes' do
      let!(:r1) { create(:reimbursement, last_viewed_at: nil, last_update_at: 1.day.ago, has_updates: true) }
      let!(:r2) { create(:reimbursement, last_viewed_at: 2.days.ago, last_update_at: 1.day.ago, has_updates: true) }
      let!(:r3) { create(:reimbursement, last_viewed_at: 1.day.ago, last_update_at: 2.days.ago, has_updates: true) }
      let!(:r4) { create(:reimbursement, has_updates: false) }

      let!(:op_hist_r) { create(:reimbursement) }
      let!(:op_hist) { create(:operation_history, document_number: op_hist_r.invoice_number, created_at: Time.current) }
      let!(:viewed_op_hist_r) { create(:reimbursement, last_viewed_operation_histories_at: 2.days.ago) }
      let!(:viewed_op_hist) { create(:operation_history, document_number: viewed_op_hist_r.invoice_number, created_at: 3.days.ago) }


      let!(:exp_rec_r) { create(:reimbursement) }
      let!(:exp_rec) { create(:work_order, reimbursement: exp_rec_r, type: 'ExpressReceiptWorkOrder', created_at: Time.current) }

      it '.with_unread_updates returns reimbursements with unread updates' do
        expect(described_class.with_unread_updates).to contain_exactly(r1, r2)
      end

      it '.with_unviewed_operation_histories returns correct records' do
        expect(described_class.with_unviewed_operation_histories).to include(op_hist_r)
        expect(described_class.with_unviewed_operation_histories).not_to include(viewed_op_hist_r)
      end

      it '.with_unviewed_express_receipts returns correct records' do
        expect(described_class.with_unviewed_express_receipts).to include(exp_rec_r)
      end

      it '.with_unviewed_records returns a union of both unviewed scopes' do
          expect(described_class.with_unviewed_records).to include(op_hist_r, exp_rec_r)
      end
    end

    it '.assigned_with_unread_updates returns assigned reimbursements with unread updates' do
       assigned_unread = create(:reimbursement, has_updates: true, last_update_at: Time.current)
       create(:reimbursement_assignment, reimbursement: assigned_unread, assignee: admin_user, is_active: true)

       expect(described_class.assigned_with_unread_updates(admin_user.id)).to contain_exactly(assigned_unread)
    end

    it '.ordered_by_notification_status sorts correctly' do
      r1 = create(:reimbursement, has_updates: true, last_update_at: 1.day.ago)
      r2 = create(:reimbursement, has_updates: false, last_update_at: 2.days.ago)
      r3 = create(:reimbursement, has_updates: true, last_update_at: Time.current)

      expect(described_class.ordered_by_notification_status).to eq([r3, r1, r2])
    end
  end

  describe 'Instance Methods' do
    describe 'status checkers' do
      it '#pending? returns true for pending status' do
        reimbursement.status = 'pending'
        expect(reimbursement).to be_pending
      end

      it '#processing? returns true for processing status' do
        reimbursement.status = 'processing'
        expect(reimbursement).to be_processing
      end

      it '#closed? returns true for closed status' do
        reimbursement.status = 'closed'
        expect(reimbursement).to be_closed
      end

      it '#electronic? returns the value of is_electronic' do
        reimbursement.is_electronic = true
        expect(reimbursement).to be_electronic
        reimbursement.is_electronic = false
        expect(reimbursement).not_to be_electronic
      end
    end

    describe 'fee detail checkers' do
      let!(:reimbursement_with_fees) { create(:reimbursement) }

      it '#all_fee_details_verified? returns true when all are verified' do
        create_list(:fee_detail, 2, document_number: reimbursement_with_fees.invoice_number, verification_status: 'verified')
        expect(reimbursement_with_fees.all_fee_details_verified?).to be true
      end

      it '#all_fee_details_verified? returns false if not all are verified' do
        create(:fee_detail, document_number: reimbursement_with_fees.invoice_number, verification_status: 'verified')
        create(:fee_detail, document_number: reimbursement_with_fees.invoice_number, verification_status: 'pending')
        expect(reimbursement_with_fees.all_fee_details_verified?).to be false
      end

      it '#all_fee_details_verified? returns false if no fee details exist' do
        expect(reimbursement_with_fees.all_fee_details_verified?).to be false
      end

      it '#any_fee_details_problematic? returns true if any are problematic' do
        create(:fee_detail, document_number: reimbursement_with_fees.invoice_number, verification_status: 'problematic')
        expect(reimbursement_with_fees.any_fee_details_problematic?).to be true
      end

      it '#any_fee_details_problematic? returns false if none are problematic' do
        create(:fee_detail, document_number: reimbursement_with_fees.invoice_number, verification_status: 'verified')
        expect(reimbursement_with_fees.any_fee_details_problematic?).to be false
      end
    end

    describe '#can_be_closed?' do
      it 'returns true if processing and all fee details are verified' do
        reimbursement.update(status: 'processing')
        allow(reimbursement).to receive(:all_fee_details_verified?).and_return(true)
        expect(reimbursement.can_be_closed?).to be true
      end

      it 'returns false if not processing' do
        reimbursement.update(status: 'pending')
        allow(reimbursement).to receive(:all_fee_details_verified?).and_return(true)
        expect(reimbursement.can_be_closed?).to be false
      end

      it 'returns false if fee details are not verified' do
        reimbursement.update(status: 'processing')
        allow(reimbursement).to receive(:all_fee_details_verified?).and_return(false)
        expect(reimbursement.can_be_closed?).to be false
      end
    end

    describe '#close!' do
       it 'updates status to closed if it can be closed' do
        reimbursement.update(status: "processing")
         allow(reimbursement).to receive(:can_be_closed?).and_return(true)
         reimbursement.close!
         expect(reimbursement.reload).to be_closed
       end

       it 'does not update status if it cannot be closed' do
         allow(reimbursement).to receive(:can_be_closed?).and_return(false)
         reimbursement.update(status: 'processing')
         reimbursement.close!
         expect(reimbursement.reload).to be_processing
       end
    end

    describe '#update_status_based_on_fee_details!' do
        let(:processing_reimbursement) { create(:reimbursement, status: 'processing') }
        let(:closed_reimbursement) { create(:reimbursement, status: 'closed') }

        it 'closes a processing reimbursement if all fee details are verified' do
            allow(processing_reimbursement).to receive(:all_fee_details_verified?).and_return(true)
            processing_reimbursement.update_status_based_on_fee_details!
            expect(processing_reimbursement.reload).to be_closed
        end

        it 'reopens a closed reimbursement if any fee details are problematic' do
            allow(closed_reimbursement).to receive(:any_fee_details_problematic?).and_return(true)
            closed_reimbursement.update_status_based_on_fee_details!
            expect(closed_reimbursement.reload).to be_processing
        end
    end

    describe '#reopen_to_processing!' do
      it 'reopens a closed reimbursement' do
        reimbursement.update(status: 'closed')
        reimbursement.reopen_to_processing!
        expect(reimbursement.reload).to be_processing
      end

      it 'does not reopen if not closed' do
        reimbursement.update(status: 'pending')
        reimbursement.reopen_to_processing!
        expect(reimbursement.reload).to be_pending
      end
    end

    describe '#manual_status_change!' do
      it 'updates status and sets override flags' do
        reimbursement.manual_status_change!('closed', admin_user)
        reimbursement.reload
        expect(reimbursement.status).to eq('closed')
        expect(reimbursement.manual_override).to be true
        expect(reimbursement.manual_override_at).to be_present
      end
    end

    describe '#reset_manual_override!' do
      it 'resets override flags' do
        reimbursement.update(manual_override: true, manual_override_at: Time.current)
        reimbursement.reset_manual_override!
        reimbursement.reload
        expect(reimbursement.manual_override).to be false
        expect(reimbursement.manual_override_at).to be_nil
      end
    end

    describe '#should_close_based_on_external_status?' do
      it 'returns true for "已付款"' do
        reimbursement.external_status = '已付款'
        expect(reimbursement.should_close_based_on_external_status?).to be true
      end

      it 'returns true for "待付款"' do
        reimbursement.external_status = '待付款'
        expect(reimbursement.should_close_based_on_external_status?).to be true
      end

      it 'returns false for other statuses' do
        reimbursement.external_status = '审批中'
        expect(reimbursement.should_close_based_on_external_status?).to be false
      end
    end

    describe '#has_active_work_orders?' do
      it 'returns true if audit work orders exist' do
        create(:work_order, reimbursement: reimbursement, type: 'AuditWorkOrder')
        expect(reimbursement.has_active_work_orders?).to be true
      end

      it 'returns true if communication work orders exist' do
        create(:work_order, reimbursement: reimbursement, type: 'CommunicationWorkOrder')
        expect(reimbursement.has_active_work_orders?).to be true
      end

      it 'returns false if only express receipt work orders exist' do
        create(:work_order, reimbursement: reimbursement, type: 'ExpressReceiptWorkOrder')
        expect(reimbursement.has_active_work_orders?).to be false
      end
    end

    describe '#determine_internal_status_from_external' do
        it 'returns current status if manual override is active' do
          reimbursement.update(status: 'pending', manual_override: true)
          expect(reimbursement.determine_internal_status_from_external('已付款')).to eq('pending')
        end

        it 'returns closed for "已付款"' do
          expect(reimbursement.determine_internal_status_from_external('已付款')).to eq('closed')
        end

        it 'returns processing if active work orders exist' do
          create(:work_order, reimbursement: reimbursement, type: 'AuditWorkOrder')
          expect(reimbursement.determine_internal_status_from_external('审批中')).to eq('processing')
        end

        it 'returns pending as a default' do
          expect(reimbursement.determine_internal_status_from_external('审批中')).to eq('pending')
        end
    end

    describe '#can_create_work_orders?' do
        it 'returns true if not closed' do
          reimbursement.update(status: 'processing')
          expect(reimbursement.can_create_work_orders?).to be true
        end

        it 'returns false if closed' do
          reimbursement.update(status: 'closed')
          expect(reimbursement.can_create_work_orders?).to be false
        end
    end

    describe '#mark_as_received' do
      it 'updates receipt status and date' do
        reimbursement.mark_as_received
        reimbursement.reload
        expect(reimbursement.receipt_status).to eq('received')
        expect(reimbursement.receipt_date).to be_present
      end
    end

    describe '#meeting_type_context' do
      it 'returns "个人" for personal-sounding names' do
        reimbursement.document_name = "个人交通费"
        expect(reimbursement.meeting_type_context).to eq("个人")
      end

      it 'returns "学术论坛" for academic-sounding names' do
        reimbursement.document_name = "参加学术会议"
        expect(reimbursement.meeting_type_context).to eq("学术论坛")
      end

      it 'defaults to "个人"' do
        reimbursement.document_name = "其他费用"
        expect(reimbursement.meeting_type_context).to eq("个人")
      end
    end

  end

  describe 'Notification-related methods' do
    let(:r_with_history) { create(:reimbursement) }
    let(:r_with_receipts) { create(:reimbursement) }

    before do
        create(:operation_history, document_number: r_with_history.invoice_number, created_at: 1.day.ago)
        create(:work_order, reimbursement: r_with_receipts, type: 'ExpressReceiptWorkOrder', created_at: 1.day.ago)
    end

    describe '#has_unviewed_operation_histories?' do
        it 'is true if never viewed' do
            r_with_history.update!(last_viewed_operation_histories_at: nil)
            expect(r_with_history.has_unviewed_operation_histories?).to be true
        end

        it 'is true if new histories exist since last view' do
            r_with_history.update!(last_viewed_operation_histories_at: 2.days.ago)
            expect(r_with_history.has_unviewed_operation_histories?).to be true
        end

        it 'is false if no new histories exist' do
            r_with_history.update!(last_viewed_operation_histories_at: Time.current)
            expect(r_with_history.has_unviewed_operation_histories?).to be false
        end
    end

    describe '#has_unviewed_express_receipts?' do
        it 'is true if never viewed' do
            r_with_receipts.update!(last_viewed_express_receipts_at: nil)
            expect(r_with_receipts.has_unviewed_express_receipts?).to be true
        end
    end

    describe '#mark_operation_histories_as_viewed!' do
      it 'updates the timestamp' do
        reimbursement.mark_operation_histories_as_viewed!
        expect(reimbursement.last_viewed_operation_histories_at).to be_present
      end
    end

    describe '#mark_express_receipts_as_viewed!' do
      it 'updates the timestamp' do
        reimbursement.mark_express_receipts_as_viewed!
        expect(reimbursement.last_viewed_express_receipts_at).to be_present
      end
    end

    describe '#mark_all_as_viewed!' do
      it 'updates both timestamps' do
        reimbursement.mark_all_as_viewed!
        expect(reimbursement.last_viewed_operation_histories_at).to be_present
        expect(reimbursement.last_viewed_express_receipts_at).to be_present
      end
    end

    describe 'Unified Notification Methods' do
        before do
            # Ensure records exist for calculations
            create(:operation_history, document_number: reimbursement.invoice_number, created_at: 1.day.ago)
            create(:work_order, reimbursement: reimbursement, type: 'ExpressReceiptWorkOrder', created_at: 2.days.ago)
            reimbursement.reload
        end

        it '#has_updates? is true if operation histories exist' do
            expect(reimbursement.has_updates?).to be true
        end

        it '#has_unread_updates? is true if never viewed' do
            reimbursement.update(last_viewed_at: nil)
            expect(reimbursement.has_unread_updates?).to be true
        end

        it '#calculate_last_update_time returns the latest timestamp' do
            latest_time = reimbursement.operation_histories.maximum(:created_at)
            expect(reimbursement.calculate_last_update_time).to be_within(1.second).of(latest_time)
        end

        it '#update_notification_status! updates columns correctly' do
            last_update = 1.day.ago
            allow(reimbursement).to receive(:calculate_last_update_time).and_return(last_update)
            reimbursement.update(last_viewed_at: 2.days.ago)
            reimbursement.update_notification_status!

            reimbursement.reload
            expect(reimbursement.last_update_at).to be_within(1.second).of(last_update)
            expect(reimbursement.has_updates).to be true
        end

        it '#mark_as_viewed! updates unified and legacy timestamps' do
            reimbursement.mark_as_viewed!
            reimbursement.reload
            expect(reimbursement.last_viewed_at).to be_present
            expect(reimbursement.has_updates).to be false
            expect(reimbursement.last_viewed_operation_histories_at).to be_present
            expect(reimbursement.last_viewed_express_receipts_at).to be_present
        end
    end
  end

  describe 'Callbacks' do
    it 'calls update_notification_status! after updating last_viewed timestamps' do
      expect(reimbursement).to receive(:update_notification_status!)
      reimbursement.update(last_viewed_at: Time.current)
    end
  end
end
