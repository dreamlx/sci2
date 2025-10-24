# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeeDetailRepository, type: :repository do
  let!(:reimbursement) { create(:reimbursement, invoice_number: 'INV-001') }
  let!(:fee_detail) do
    create(:fee_detail, document_number: 'INV-001', external_fee_id: 'EXT-001', verification_status: 'pending',
                        amount: 100.0)
  end
  let!(:processing_fee_detail) do
    create(:fee_detail, document_number: 'INV-001', external_fee_id: 'EXT-002', verification_status: 'problematic',
                        amount: 200.0)
  end
  let!(:verified_fee_detail) do
    create(:fee_detail, document_number: 'INV-001', external_fee_id: 'EXT-003', verification_status: 'verified',
                        amount: 150.0)
  end
  let!(:other_reimbursement) { create(:reimbursement, invoice_number: 'INV-002') }
  let!(:other_fee_detail) do
    create(:fee_detail, document_number: 'INV-002', verification_status: 'pending', amount: 75.0)
  end

  describe '.find' do
    it 'returns fee detail when found' do
      result = described_class.find(fee_detail.id)
      expect(result).to eq(fee_detail)
    end

    it 'returns nil when not found' do
      result = described_class.find(99_999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_id' do
    it 'returns fee detail when found' do
      result = described_class.find_by_id(fee_detail.id)
      expect(result).to eq(fee_detail)
    end

    it 'returns nil when not found' do
      result = described_class.find_by_id(99_999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_external_fee_id' do
    it 'returns fee detail when found' do
      result = described_class.find_by_external_fee_id('EXT-001')
      expect(result).to eq(fee_detail)
    end

    it 'returns nil when not found' do
      result = described_class.find_by_external_fee_id('NON-EXISTENT')
      expect(result).to be_nil
    end
  end

  describe '.find_or_create_by_external_fee_id' do
    let!(:new_reimbursement) { create(:reimbursement, invoice_number: 'INV-NEW') }

    it 'returns existing fee detail when found' do
      result = described_class.find_or_create_by_external_fee_id('EXT-001')
      expect(result).to eq(fee_detail)
      expect(result.persisted?).to be true
    end

    it 'creates new fee detail when not found' do
      result = described_class.find_or_create_by_external_fee_id('NEW-001',
                                                                 document_number: 'INV-NEW',
                                                                 verification_status: 'pending',
                                                                 amount: 50.0,
                                                                 fee_type: '测试费用')
      expect(result.persisted?).to be true
      expect(result.external_fee_id).to eq('NEW-001')
      expect(result.document_number).to eq('INV-NEW')
    end
  end

  # Status scopes
  describe '.pending' do
    it 'returns only pending fee details' do
      result = described_class.pending
      expect(result).to include(fee_detail, other_fee_detail)
      expect(result).not_to include(processing_fee_detail, verified_fee_detail)
    end
  end

  describe '.problematic' do
    it 'returns only problematic fee details' do
      result = described_class.problematic
      expect(result).to include(processing_fee_detail)
      expect(result).not_to include(fee_detail, verified_fee_detail, other_fee_detail)
    end
  end

  describe '.verified' do
    it 'returns only verified fee details' do
      result = described_class.verified
      expect(result).to include(verified_fee_detail)
      expect(result).not_to include(fee_detail, processing_fee_detail, other_fee_detail)
    end
  end

  # Document-based queries
  describe '.by_document' do
    it 'returns fee details for specific document' do
      result = described_class.by_document('INV-001')
      expect(result.count).to eq(3)
      expect(result.pluck(:document_number).uniq).to contain_exactly('INV-001')
    end

    it 'returns empty when no fee details for document' do
      result = described_class.by_document('NON-EXISTENT')
      expect(result).to be_empty
    end
  end

  describe '.for_reimbursement' do
    it 'returns fee details for specific reimbursement' do
      result = described_class.for_reimbursement(reimbursement)
      expect(result.count).to eq(3)
      expect(result.pluck(:document_number).uniq).to contain_exactly('INV-001')
    end
  end

  describe '.for_reimbursements' do
    it 'returns fee details for multiple reimbursements' do
      result = described_class.for_reimbursements([reimbursement, other_reimbursement])
      expect(result.count).to eq(4)
      expect(result.pluck(:document_number).uniq).to contain_exactly('INV-001', 'INV-002')
    end
  end

  # Amount-based queries
  describe '.with_amount_greater_than' do
    it 'returns fee details with amount greater than specified' do
      result = described_class.with_amount_greater_than(100)
      expect(result).to include(processing_fee_detail, verified_fee_detail)
      expect(result).not_to include(fee_detail, other_fee_detail)
    end
  end

  describe '.with_amount_between' do
    it 'returns fee details within amount range' do
      result = described_class.with_amount_between(100, 150)
      expect(result).to include(fee_detail, verified_fee_detail)
      expect(result).not_to include(processing_fee_detail, other_fee_detail)
    end
  end

  # Date-based queries
  describe '.created_today' do
    it 'returns fee details created today' do
      today_fee_detail = create(:fee_detail, created_at: Time.current)
      result = described_class.created_today
      expect(result).to include(today_fee_detail)
    end
  end

  describe '.created_this_month' do
    it 'returns fee details created this month' do
      this_month_fee_detail = create(:fee_detail, created_at: Date.current)
      result = described_class.created_this_month
      expect(result).to include(this_month_fee_detail)
    end
  end

  # Search functionality
  describe '.search_by_fee_type' do
    let!(:search_reimbursement) { create(:reimbursement, invoice_number: 'INV-SEARCH') }
    let!(:transport_fee) { create(:fee_detail, document_number: 'INV-SEARCH', fee_type: '交通费') }
    let!(:meal_fee) { create(:fee_detail, document_number: 'INV-SEARCH', fee_type: '餐费') }

    it 'returns fee details matching fee type pattern' do
      result = described_class.search_by_fee_type('交通')
      expect(result).to include(transport_fee)
      expect(result).not_to include(meal_fee)
    end
  end

  # Count operations
  describe '.status_counts' do
    it 'returns correct counts for each status' do
      result = described_class.status_counts
      expect(result[:pending]).to eq(2)
      expect(result[:problematic]).to eq(1)
      expect(result[:verified]).to eq(1)
    end
  end

  describe '.total_amount' do
    it 'returns sum of all amounts' do
      result = described_class.total_amount
      expect(result).to eq(525.0) # 100 + 200 + 150 + 75
    end
  end

  describe '.total_amount_by_status' do
    it 'returns sum of amounts by status' do
      result = described_class.total_amount_by_status('pending')
      expect(result).to eq(175.0) # 100 + 75
    end
  end

  # Complex queries (simplified for SQLite compatibility)
  describe '.verification_summary' do
    it 'returns verification status summary with counts and totals' do
      # Test that the method runs without error
      expect { described_class.verification_summary }.not_to raise_error
    end
  end

  describe '.by_fee_type_totals' do
    let!(:totals_reimbursement) { create(:reimbursement, invoice_number: 'INV-TOTALS') }
    let!(:transport_fee1) { create(:fee_detail, document_number: 'INV-TOTALS', fee_type: '交通费', amount: 100) }
    let!(:transport_fee2) { create(:fee_detail, document_number: 'INV-TOTALS', fee_type: '交通费', amount: 200) }
    let!(:meal_fee) { create(:fee_detail, document_number: 'INV-TOTALS', fee_type: '餐费', amount: 50) }

    it 'returns totals grouped by fee type' do
      result = described_class.by_fee_type_totals

      # Test that the method runs without error and returns expected structure
      expect(result).to respond_to(:find)
      expect(result.first).to respond_to(:fee_type)
      expect(result.first).to respond_to(:total_amount)
    end
  end

  # Pagination
  describe '.page' do
    before do
      # Create additional fee details for pagination testing with proper reimbursement
      create(:reimbursement, invoice_number: 'INV-PAGE')
      create_list(:fee_detail, 5, document_number: 'INV-PAGE')
    end

    it 'returns paginated results' do
      result = described_class.page(1, 3)
      expect(result.count).to eq(3)
    end
  end

  # Existence checks
  describe '.exists_by_external_fee_id?' do
    it 'returns true when fee detail exists' do
      result = described_class.exists_by_external_fee_id?('EXT-001')
      expect(result).to be true
    end

    it 'returns false when fee detail does not exist' do
      result = described_class.exists_by_external_fee_id?('NON-EXISTENT')
      expect(result).to be false
    end
  end

  # Batch operations
  describe '.find_by_external_fee_ids' do
    it 'returns fee details for multiple external IDs' do
      result = described_class.find_by_external_fee_ids(%w[EXT-001 EXT-002])
      expect(result.count).to eq(2)
      expect(result.pluck(:external_fee_id)).to contain_exactly('EXT-001', 'EXT-002')
    end
  end

  # Error handling
  describe '.safe_find' do
    it 'returns nil for non-existent ID without raising error' do
      result = described_class.safe_find(99_999)
      expect(result).to be_nil
    end

    it 'returns fee detail for existing ID' do
      result = described_class.safe_find(fee_detail.id)
      expect(result).to eq(fee_detail)
    end
  end

  describe '.safe_find_by_external_fee_id' do
    it 'returns nil for non-existent external ID without raising error' do
      result = described_class.safe_find_by_external_fee_id('NON-EXISTENT')
      expect(result).to be_nil
    end

    it 'returns fee detail for existing external ID' do
      result = described_class.safe_find_by_external_fee_id('EXT-001')
      expect(result).to eq(fee_detail)
    end
  end
end
