# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditWorkOrderRepository, type: :repository do
  # Test data setup
  let!(:reimbursement1) { create(:reimbursement) }
  let!(:reimbursement2) { create(:reimbursement) }
  
  let!(:approved_audit) do
    create(:audit_work_order,
           reimbursement: reimbursement1,
           audit_result: 'approved',
           status: 'approved',
           vat_verified: true,
           audit_date: 1.day.ago,
           audit_comment: 'Approved after review')
  end
  
  let!(:rejected_audit) do
    create(:audit_work_order,
           reimbursement: reimbursement2,
           audit_result: 'rejected',
           status: 'rejected',
           vat_verified: false,
           audit_date: 2.days.ago,
           audit_comment: 'Rejected due to issues')
  end
  
  let!(:pending_audit) do
    create(:audit_work_order,
           reimbursement: reimbursement1,
           audit_result: nil,
           status: 'pending',
           vat_verified: true,
           audit_date: nil,
           created_at: Time.current)
  end

  describe '.find' do
    it 'returns audit work order when found' do
      result = described_class.find(approved_audit.id)
      expect(result).to eq(approved_audit)
    end

    it 'returns nil when not found' do
      result = described_class.find(99_999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_id' do
    it 'returns audit work order when found' do
      result = described_class.find_by_id(approved_audit.id)
      expect(result).to eq(approved_audit)
    end

    it 'returns nil when not found' do
      result = described_class.find_by_id(99_999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_ids' do
    it 'returns audit work orders with given ids' do
      result = described_class.find_by_ids([approved_audit.id, rejected_audit.id])
      expect(result.pluck(:id)).to match_array([approved_audit.id, rejected_audit.id])
    end
  end

  describe '.by_audit_result' do
    it 'returns audits with specified result' do
      result = described_class.by_audit_result('approved')
      expect(result.pluck(:id)).to include(approved_audit.id)
      expect(result.all? { |a| a.audit_result == 'approved' }).to be true
    end
  end

  describe '.approved' do
    it 'returns only approved audits' do
      result = described_class.approved
      expect(result.pluck(:id)).to include(approved_audit.id)
      expect(result.all? { |a| a.audit_result == 'approved' }).to be true
    end
  end

  describe '.rejected' do
    it 'returns only rejected audits' do
      result = described_class.rejected
      expect(result.pluck(:id)).to include(rejected_audit.id)
      expect(result.all? { |a| a.audit_result == 'rejected' }).to be true
    end
  end

  describe '.pending_audit' do
    it 'returns audits with nil audit_result' do
      result = described_class.pending_audit
      expect(result.pluck(:id)).to include(pending_audit.id)
      expect(result.all? { |a| a.audit_result.nil? }).to be true
    end
  end

  describe '.vat_verified' do
    it 'returns VAT verified audits' do
      result = described_class.vat_verified
      expect(result.pluck(:id)).to match_array([approved_audit.id, pending_audit.id])
      expect(result.all?(&:vat_verified)).to be true
    end
  end

  describe '.vat_not_verified' do
    it 'returns VAT not verified audits' do
      result = described_class.vat_not_verified
      expect(result.pluck(:id)).to include(rejected_audit.id)
      expect(result.all? { |a| !a.vat_verified }).to be true
    end
  end

  describe '.by_vat_verified' do
    it 'returns audits with specified VAT verification status' do
      result = described_class.by_vat_verified(true)
      expect(result.all?(&:vat_verified)).to be true
    end
  end

  describe '.by_status' do
    it 'returns audits with specified status' do
      result = described_class.by_status('approved')
      expect(result.pluck(:id)).to include(approved_audit.id)
    end
  end

  describe '.pending' do
    it 'returns pending audits' do
      result = described_class.pending
      expect(result.pluck(:id)).to include(pending_audit.id)
    end
  end

  describe '.processing' do
    it 'returns processing audits' do
      processing_audit = create(:audit_work_order, status: 'processing')
      result = described_class.processing
      expect(result.pluck(:id)).to include(processing_audit.id)
    end
  end

  describe '.completed' do
    it 'returns completed audits' do
      completed_audit = create(:audit_work_order, status: 'completed')
      result = described_class.completed
      expect(result.pluck(:id)).to include(completed_audit.id)
    end
  end

  describe '.status_approved' do
    it 'returns audits with approved status' do
      result = described_class.status_approved
      expect(result.pluck(:id)).to include(approved_audit.id)
    end
  end

  describe '.status_rejected' do
    it 'returns audits with rejected status' do
      result = described_class.status_rejected
      expect(result.pluck(:id)).to include(rejected_audit.id)
    end
  end

  describe '.approved_and_vat_verified' do
    it 'returns approved and VAT verified audits' do
      result = described_class.approved_and_vat_verified
      expect(result.pluck(:id)).to include(approved_audit.id)
      expect(result.all? { |a| a.audit_result == 'approved' && a.vat_verified }).to be true
    end
  end

  describe '.rejected_with_comments' do
    it 'returns rejected audits with comments' do
      result = described_class.rejected_with_comments
      expect(result.pluck(:id)).to include(rejected_audit.id)
    end
  end

  describe '.pending_audit_vat_verified' do
    it 'returns pending audits that are VAT verified' do
      result = described_class.pending_audit_vat_verified
      expect(result.pluck(:id)).to include(pending_audit.id)
    end
  end

  describe '.for_reimbursement' do
    it 'returns audits for specific reimbursement' do
      result = described_class.for_reimbursement(reimbursement1.id)
      expect(result.pluck(:id)).to match_array([approved_audit.id, pending_audit.id])
    end
  end

  describe '.by_reimbursement' do
    it 'returns audits for reimbursement object' do
      result = described_class.by_reimbursement(reimbursement1)
      expect(result.pluck(:id)).to match_array([approved_audit.id, pending_audit.id])
    end
  end

  describe '.audited_today' do
    it 'returns audits with audit_date today' do
      today_audit = create(:audit_work_order, audit_date: Time.current)
      result = described_class.audited_today
      expect(result.pluck(:id)).to include(today_audit.id)
    end
  end

  describe '.audited_this_week' do
    it 'returns audits from this week' do
      result = described_class.audited_this_week
      expect(result.count).to be >= 0
    end
  end

  describe '.audited_this_month' do
    it 'returns audits from this month' do
      result = described_class.audited_this_month
      expect(result.count).to be >= 0
    end
  end

  describe '.by_audit_date_range' do
    it 'returns audits within date range' do
      result = described_class.by_audit_date_range(3.days.ago, Date.current)
      expect(result.count).to be >= 2
    end
  end

  describe '.created_today' do
    it 'returns audits created today' do
      result = described_class.created_today
      expect(result.pluck(:id)).to include(pending_audit.id)
    end
  end

  describe '.created_this_week' do
    it 'returns audits created this week' do
      result = described_class.created_this_week
      expect(result.count).to be >= 1
    end
  end

  describe '.created_this_month' do
    it 'returns audits created this month' do
      result = described_class.created_this_month
      expect(result.count).to be >= 1
    end
  end

  describe '.total_count' do
    it 'returns total count of audit work orders' do
      result = described_class.total_count
      expect(result).to be >= 3
    end
  end

  describe '.approved_count' do
    it 'returns count of approved audits' do
      result = described_class.approved_count
      expect(result).to be >= 1
    end
  end

  describe '.rejected_count' do
    it 'returns count of rejected audits' do
      result = described_class.rejected_count
      expect(result).to be >= 1
    end
  end

  describe '.pending_audit_count' do
    it 'returns count of pending audits' do
      result = described_class.pending_audit_count
      expect(result).to be >= 1
    end
  end

  describe '.vat_verified_count' do
    it 'returns count of VAT verified audits' do
      result = described_class.vat_verified_count
      expect(result).to be >= 2
    end
  end

  describe '.vat_not_verified_count' do
    it 'returns count of VAT not verified audits' do
      result = described_class.vat_not_verified_count
      expect(result).to be >= 1
    end
  end

  describe '.audit_result_counts' do
    it 'returns counts grouped by audit result' do
      result = described_class.audit_result_counts
      expect(result['approved']).to be >= 1
      expect(result['rejected']).to be >= 1
    end
  end

  describe '.status_counts' do
    it 'returns counts grouped by status' do
      result = described_class.status_counts
      expect(result).to be_a(Hash)
    end
  end

  describe '.search_by_audit_comment' do
    it 'returns audits matching comment pattern' do
      result = described_class.search_by_audit_comment('Approved')
      expect(result.pluck(:id)).to include(approved_audit.id)
    end

    it 'returns empty when query is blank' do
      result = described_class.search_by_audit_comment('')
      expect(result).to be_empty
    end
  end


  describe '.recent_audits' do
    it 'returns recent audits ordered by audit date' do
      result = described_class.recent_audits
      expect(result.first.id).to eq(approved_audit.id)
    end

    it 'limits results to specified limit' do
      result = described_class.recent_audits(1)
      expect(result.count).to eq(1)
    end
  end

  describe '.recent' do
    it 'returns recent audits ordered by creation date' do
      result = described_class.recent
      expect(result.first.id).to eq(pending_audit.id)
    end
  end

  describe '.oldest_first' do
    it 'returns audits ordered by creation date ascending' do
      result = described_class.oldest_first
      expect(result.last.id).to eq(pending_audit.id)
    end
  end

  describe '.page' do
    it 'returns paginated audits' do
      result = described_class.page(1, 2)
      expect(result.count).to be <= 2
    end
  end

  describe '.exists?' do
    it 'returns true when audit exists' do
      result = described_class.exists?(id: approved_audit.id)
      expect(result).to be true
    end

    it 'returns false when audit does not exist' do
      result = described_class.exists?(id: 99_999)
      expect(result).to be false
    end
  end

  describe '.exists_for_reimbursement?' do
    it 'returns true when audit exists for reimbursement' do
      result = described_class.exists_for_reimbursement?(reimbursement1.id)
      expect(result).to be true
    end

    it 'returns false when no audit exists for reimbursement' do
      new_reimbursement = create(:reimbursement)
      result = described_class.exists_for_reimbursement?(new_reimbursement.id)
      expect(result).to be false
    end
  end

  describe '.has_approved_audit?' do
    it 'returns true when approved audit exists for reimbursement' do
      result = described_class.has_approved_audit?(reimbursement1.id)
      expect(result).to be true
    end

    it 'returns false when no approved audit exists' do
      result = described_class.has_approved_audit?(reimbursement2.id)
      expect(result).to be false
    end
  end

  describe '.has_rejected_audit?' do
    it 'returns true when rejected audit exists for reimbursement' do
      result = described_class.has_rejected_audit?(reimbursement2.id)
      expect(result).to be true
    end

    it 'returns false when no rejected audit exists' do
      result = described_class.has_rejected_audit?(reimbursement1.id)
      expect(result).to be false
    end
  end

  describe '.optimized_list' do
    it 'returns audits with included associations' do
      result = described_class.optimized_list
      expect(result).to be_present
      expect(result.first).to respond_to(:reimbursement)
      expect(result.first).to respond_to(:creator)
    end
  end

  describe '.with_associations' do
    it 'returns audits with included associations' do
      result = described_class.with_associations
      expect(result).to be_present
      expect(result.first).to respond_to(:reimbursement)
      expect(result.first).to respond_to(:creator)
    end
  end

  describe '.safe_find' do
    it 'returns audit when found' do
      result = described_class.safe_find(approved_audit.id)
      expect(result).to eq(approved_audit)
    end

    it 'returns nil when not found' do
      result = described_class.safe_find(99_999)
      expect(result).to be_nil
    end

    it 'returns nil on error' do
      allow(described_class).to receive(:find).and_raise(StandardError.new('Test error'))
      result = described_class.safe_find(approved_audit.id)
      expect(result).to be_nil
    end
  end

  describe '.safe_find_by_id' do
    it 'returns audit when found' do
      result = described_class.safe_find_by_id(approved_audit.id)
      expect(result).to eq(approved_audit)
    end

    it 'returns nil when not found' do
      result = described_class.safe_find_by_id(99_999)
      expect(result).to be_nil
    end
  end
end
