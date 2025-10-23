# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReimbursementRepository, type: :repository do
  let(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement, status: 'pending', invoice_number: 'INV-001') }
  let!(:processing_reimbursement) { create(:reimbursement, status: 'processing', invoice_number: 'INV-002') }
  let!(:closed_reimbursement) { create(:reimbursement, status: 'closed', invoice_number: 'INV-003') }

  describe '.find' do
    it 'returns reimbursement when found' do
      result = described_class.find(reimbursement.id)
      expect(result).to eq(reimbursement)
    end

    it 'returns nil when not found' do
      result = described_class.find(99999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_id' do
    it 'returns reimbursement when found' do
      result = described_class.find_by_id(reimbursement.id)
      expect(result).to eq(reimbursement)
    end

    it 'returns nil when not found' do
      result = described_class.find_by_id(99999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_invoice_number' do
    it 'returns reimbursement when found' do
      result = described_class.find_by_invoice_number('INV-001')
      expect(result).to eq(reimbursement)
    end

    it 'returns nil when not found' do
      result = described_class.find_by_invoice_number('NON-EXISTENT')
      expect(result).to be_nil
    end
  end

  describe '.find_or_initialize_by_invoice_number' do
    it 'returns existing reimbursement when found' do
      result = described_class.find_or_initialize_by_invoice_number('INV-001')
      expect(result).to eq(reimbursement)
      expect(result.persisted?).to be true
    end

    it 'returns new reimbursement when not found' do
      result = described_class.find_or_initialize_by_invoice_number('NEW-INV')
      expect(result.invoice_number).to eq('NEW-INV')
      expect(result.persisted?).to be false
    end
  end

  describe '.find_by_ids' do
    it 'returns reimbursements for given ids' do
      ids = [reimbursement.id, processing_reimbursement.id]
      result = described_class.find_by_ids(ids)
      expect(result.count).to eq(2)
      expect(result).to include(reimbursement, processing_reimbursement)
    end

    it 'returns empty relation when no ids match' do
      result = described_class.find_by_ids([99999, 99998])
      expect(result.count).to eq(0)
    end
  end

  describe '.find_by_invoice_numbers' do
    it 'returns reimbursements for given invoice numbers' do
      invoice_numbers = ['INV-001', 'INV-002']
      result = described_class.find_by_invoice_numbers(invoice_numbers)
      expect(result.count).to eq(2)
      expect(result.pluck(:invoice_number)).to contain_exactly('INV-001', 'INV-002')
    end
  end

  describe '.index_by_invoice_numbers' do
    it 'returns indexed hash by invoice numbers' do
      invoice_numbers = ['INV-001', 'INV-002']
      result = described_class.index_by_invoice_numbers(invoice_numbers)
      expect(result['INV-001']).to eq(reimbursement)
      expect(result['INV-002']).to eq(processing_reimbursement)
    end
  end

  describe '.by_status' do
    it 'returns reimbursements with specified status' do
      result = described_class.by_status('pending')
      expect(result.count).to eq(1)
      expect(result.first).to eq(reimbursement)
    end
  end

  describe '.by_statuses' do
    it 'returns reimbursements with specified statuses' do
      statuses = ['pending', 'processing']
      result = described_class.by_statuses(statuses)
      expect(result.count).to eq(2)
      expect(result.pluck(:status)).to contain_exactly('pending', 'processing')
    end
  end

  describe '.pending' do
    it 'returns only pending reimbursements' do
      result = described_class.pending
      expect(result.count).to eq(1)
      expect(result.first.status).to eq('pending')
    end
  end

  describe '.processing' do
    it 'returns only processing reimbursements' do
      result = described_class.processing
      expect(result.count).to eq(1)
      expect(result.first.status).to eq('processing')
    end
  end

  describe '.closed' do
    it 'returns only closed reimbursements' do
      result = described_class.closed
      expect(result.count).to eq(1)
      expect(result.first.status).to eq('closed')
    end
  end

  # Electronic/Non-electronic scopes
  describe '.electronic' do
    let!(:electronic_reimb) { create(:reimbursement, is_electronic: true) }
    let!(:non_electronic_reimb) { create(:reimbursement, is_electronic: false) }

    it 'returns only electronic reimbursements' do
      result = described_class.electronic
      expect(result).to include(electronic_reimb)
      expect(result).not_to include(non_electronic_reimb)
    end
  end

  describe '.non_electronic' do
    let!(:electronic_reimb) { create(:reimbursement, is_electronic: true) }
    let!(:non_electronic_reimb) { create(:reimbursement, is_electronic: false) }

    it 'returns only non-electronic reimbursements' do
      result = described_class.non_electronic
      expect(result).to include(non_electronic_reimb)
      expect(result).not_to include(electronic_reimb)
    end
  end

  # Assignment scopes
  describe '.unassigned' do
    let!(:assigned_reimbursement) { create(:reimbursement) }
    let!(:assignment) { create(:reimbursement_assignment, reimbursement: assigned_reimbursement, is_active: true) }

    it 'returns reimbursements without active assignments' do
      result = described_class.unassigned
      expect(result).to include(reimbursement, processing_reimbursement, closed_reimbursement)
      expect(result).not_to include(assigned_reimbursement)
    end
  end

  describe '.assigned_to_user' do
    let!(:assigned_reimbursement) { create(:reimbursement) }
    let!(:assignment) { create(:reimbursement_assignment, reimbursement: assigned_reimbursement, assignee: admin_user, is_active: true) }

    it 'returns reimbursements assigned to specific user' do
      result = described_class.assigned_to_user(admin_user.id)
      expect(result).to contain_exactly(assigned_reimbursement)
    end
  end

  describe '.my_assignments' do
    let!(:assigned_reimbursement) { create(:reimbursement) }
    let!(:assignment) { create(:reimbursement_assignment, reimbursement: assigned_reimbursement, assignee: admin_user, is_active: true) }

    it 'returns the same as assigned_to_user' do
      result = described_class.my_assignments(admin_user.id)
      expect(result).to eq(described_class.assigned_to_user(admin_user.id))
    end
  end

  # Update and notification scopes
  describe '.with_unread_updates' do
    let!(:unread_reimbursement) { create(:reimbursement, has_updates: true, last_update_at: 1.day.ago) }
    let!(:read_reimbursement) { create(:reimbursement, has_updates: true, last_update_at: 1.day.ago, last_viewed_at: 2.hours.ago) }

    it 'returns reimbursements with unread updates' do
      result = described_class.with_unread_updates
      expect(result).to include(unread_reimbursement)
      expect(result).not_to include(read_reimbursement)
    end
  end

  describe '.with_unviewed_operation_histories' do
    let!(:reimbursement_with_hist) { create(:reimbursement) }
    let!(:recent_history) { create(:operation_history, document_number: reimbursement_with_hist.invoice_number, created_at: 1.hour.ago) }
    let!(:viewed_reimbursement) { create(:reimbursement, last_viewed_operation_histories_at: 2.hours.ago) }
    let!(:old_history) { create(:operation_history, document_number: viewed_reimbursement.invoice_number, created_at: 3.hours.ago) }

    it 'returns reimbursements with unviewed operation histories' do
      result = described_class.with_unviewed_operation_histories
      expect(result).to include(reimbursement_with_hist)
      expect(result).not_to include(viewed_reimbursement)
    end
  end

  describe '.with_unviewed_express_receipts' do
    let!(:reimbursement_with_express) { create(:reimbursement) }
    let!(:recent_express) { create(:express_receipt_work_order, reimbursement: reimbursement_with_express, created_at: 1.hour.ago) }
    let!(:viewed_reimbursement) { create(:reimbursement, last_viewed_express_receipts_at: 2.hours.ago) }
    let!(:old_express) { create(:express_receipt_work_order, reimbursement: viewed_reimbursement, created_at: 3.hours.ago) }

    it 'returns reimbursements with unviewed express receipts' do
      result = described_class.with_unviewed_express_receipts
      expect(result).to include(reimbursement_with_express)
      expect(result).not_to include(viewed_reimbursement)
    end
  end

  describe '.with_unviewed_records' do
    let!(:reimbursement_with_hist) { create(:reimbursement) }
    let!(:recent_history) { create(:operation_history, document_number: reimbursement_with_hist.invoice_number, created_at: 1.hour.ago) }
    let!(:reimbursement_with_express) { create(:reimbursement) }
    let!(:recent_express) { create(:express_receipt_work_order, reimbursement: reimbursement_with_express, created_at: 1.hour.ago) }

    it 'returns union of unviewed operation histories and express receipts' do
      result = described_class.with_unviewed_records
      expect(result).to include(reimbursement_with_hist, reimbursement_with_express)
    end
  end

  describe '.assigned_with_unread_updates' do
    let!(:assigned_unread) { create(:reimbursement, has_updates: true, last_update_at: Time.current) }
    let!(:assignment) { create(:reimbursement_assignment, reimbursement: assigned_unread, assignee: admin_user, is_active: true) }

    it 'returns assigned reimbursements with unread updates' do
      result = described_class.assigned_with_unread_updates(admin_user.id)
      expect(result).to contain_exactly(assigned_unread)
    end
  end

  describe '.ordered_by_notification_status' do
    let!(:old_no_updates) { create(:reimbursement, has_updates: false, last_update_at: 2.days.ago) }
    let!(:recent_updates) { create(:reimbursement, has_updates: true, last_update_at: 1.hour.ago) }
    let!(:older_updates) { create(:reimbursement, has_updates: true, last_update_at: 1.day.ago) }

    it 'orders by notification status correctly' do
      result = described_class.ordered_by_notification_status
      expect(result.first).to eq(recent_updates)
      expect(result.second).to eq(older_updates)
      expect(result.third).to eq(old_no_updates)
    end
  end

  describe '.status_counts' do
    it 'returns counts for each status' do
      result = described_class.status_counts
      expect(result[:pending]).to eq(1)
      expect(result[:processing]).to eq(1)
      expect(result[:closed]).to eq(1)
      expect(result[:waiting_completion]).to eq(0)
    end
  end

  describe '.created_today' do
    it 'returns reimbursements created today' do
      # Create a reimbursement with today's date
      today_reimbursement = create(:reimbursement, created_at: Time.current)
      result = described_class.created_today
      expect(result).to include(today_reimbursement)
    end
  end

  describe '.created_between' do
    it 'returns reimbursements created within date range' do
      start_date = 1.day.ago
      end_date = Time.current
      result = described_class.created_between(start_date, end_date)
      expect(result.count).to eq(3) # All test reimbursements were created recently
    end
  end

  describe '.search_by_invoice_number' do
    it 'returns reimbursements matching invoice pattern' do
      result = described_class.search_by_invoice_number('INV')
      expect(result.count).to eq(3)
    end

    it 'returns empty when no match' do
      result = described_class.search_by_invoice_number('XYZ')
      expect(result.count).to eq(0)
    end
  end

  describe '.page' do
    it 'returns paginated results' do
      # Create more reimbursements for pagination testing
      create_list(:reimbursement, 5)

      result = described_class.page(1, 2)
      expect(result.count).to eq(2)
    end
  end

  describe '.exists?' do
    it 'returns true when reimbursement exists' do
      result = described_class.exists?(id: reimbursement.id)
      expect(result).to be true
    end

    it 'returns false when reimbursement does not exist' do
      result = described_class.exists?(id: 99999)
      expect(result).to be false
    end
  end

  describe '.exists_by_invoice_number?' do
    it 'returns true when invoice number exists' do
      result = described_class.exists_by_invoice_number?('INV-001')
      expect(result).to be true
    end

    it 'returns false when invoice number does not exist' do
      result = described_class.exists_by_invoice_number?('NON-EXISTENT')
      expect(result).to be false
    end
  end

  describe '.select_fields' do
    it 'returns only selected fields' do
      result = described_class.select_fields([:id, :invoice_number])
      expect(result.first).to have_attributes(id: reimbursement.id, invoice_number: 'INV-001')
      expect { result.first.status }.to raise_error(ActiveModel::MissingAttributeError)
    end
  end

  describe '.safe_find' do
    it 'returns reimbursement when found' do
      result = described_class.safe_find(reimbursement.id)
      expect(result).to eq(reimbursement)
    end

    it 'returns nil when not found without logging error' do
      expect(Rails.logger).not_to receive(:error)
      result = described_class.safe_find(99999)
      expect(result).to be_nil
    end

    it 'returns nil when exception occurs' do
      allow(Reimbursement).to receive(:find).and_raise(StandardError, 'Database connection failed')
      result = described_class.safe_find(99999)
      expect(result).to be_nil
    end
  end

  describe '.safe_find_by_invoice_number' do
    it 'returns reimbursement when found' do
      result = described_class.safe_find_by_invoice_number('INV-001')
      expect(result).to eq(reimbursement)
    end

    it 'returns nil when not found without logging error' do
      expect(Rails.logger).not_to receive(:error)
      result = described_class.safe_find_by_invoice_number('NON-EXISTENT')
      expect(result).to be_nil
    end

    it 'returns nil when exception occurs' do
      allow(Reimbursement).to receive(:find_by_invoice_number).and_raise(StandardError, 'Database connection failed')
      result = described_class.safe_find_by_invoice_number('NON-EXISTENT')
      expect(result).to be_nil
    end
  end

  describe 'method chaining' do
    it 'allows method chaining for complex queries' do
      result = described_class
        .by_status('pending')
        .where('created_at >= ?', 1.day.ago)
        .order(:created_at)
        .limit(1)

      expect(result.count).to eq(1)
      expect(result.first).to eq(reimbursement)
    end
  end

  describe 'performance optimizations' do
    it 'uses optimized list for dashboard queries' do
      result = described_class.optimized_list
      expect(result).to respond_to(:each)
    end
  end
end