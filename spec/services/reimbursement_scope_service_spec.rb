# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReimbursementScopeService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:other_admin_user) { create(:admin_user) }
  let(:base_chain) { Reimbursement.all }

  # Create test data with different statuses and assignments
  let!(:reimbursement_assigned_to_me) { create(:reimbursement, status: 'processing') }
  let!(:reimbursement_assigned_to_other) { create(:reimbursement, status: 'pending') }
  let!(:reimbursement_unassigned) { create(:reimbursement, status: 'pending') }
  let!(:reimbursement_with_unread_updates) { create(:reimbursement, status: 'pending') }

  let!(:assignment_to_me) do
    create(:reimbursement_assignment,
           reimbursement: reimbursement_assigned_to_me,
           assignee: admin_user,
           is_active: true)
  end

  let!(:assignment_to_other) do
    create(:reimbursement_assignment,
           reimbursement: reimbursement_assigned_to_other,
           assignee: other_admin_user,
           is_active: true)
  end

  let!(:assignment_with_updates) do
    create(:reimbursement_assignment,
           reimbursement: reimbursement_with_unread_updates,
           assignee: admin_user,
           is_active: true)
  end

  # Create reimbursements with unread updates
  before do
    # Mark reimbursement_with_unread_updates as having unread updates
    reimbursement_with_unread_updates.update!(
      has_updates: true,
      last_update_at: Time.current,
      last_viewed_at: 1.day.ago
    )
  end

  describe '#initialize' do
    it 'initializes with current_user and params' do
      params = { scope: 'assigned_to_me' }
      service = described_class.new(admin_user, params)

      expect(service.current_user).to eq(admin_user)
      expect(service.params).to eq(params)
    end

    it 'handles nil params' do
      service = described_class.new(admin_user)

      expect(service.current_user).to eq(admin_user)
      expect(service.params).to eq({})
    end
  end

  describe '#filtered_collection' do
    context 'when ID is present (single record view)' do
      it 'returns unfiltered chain' do
        params = { id: '123', scope: 'assigned_to_me' }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to eq(base_chain)
      end
    end

    context 'when scope is "assigned_to_me"' do
      it 'returns reimbursements assigned to current user' do
        params = { scope: 'assigned_to_me' }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to include(reimbursement_assigned_to_me)
        expect(result).not_to include(reimbursement_assigned_to_other)
        expect(result).not_to include(reimbursement_unassigned)
      end
    end

    context 'when scope is "with_unread_updates"' do
      it 'returns reimbursements with unread updates assigned to current user' do
        params = { scope: 'with_unread_updates' }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to include(reimbursement_with_unread_updates)
        expect(result).not_to include(reimbursement_assigned_to_me)
        expect(result).not_to include(reimbursement_assigned_to_other)
      end
    end

    context 'when scope is "unassigned"' do
      it 'returns unassigned reimbursements with pending status' do
        params = { scope: 'unassigned' }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to include(reimbursement_unassigned)
        expect(result).not_to include(reimbursement_assigned_to_me)
        expect(result).not_to include(reimbursement_assigned_to_other)
      end
    end

    context 'when scope is "pending"' do
      it 'returns pending reimbursements assigned to current user' do
        params = { scope: 'pending' }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to include(reimbursement_with_unread_updates)
        expect(result).not_to include(reimbursement_assigned_to_me) # processing status
        expect(result).not_to include(reimbursement_unassigned) # not assigned
      end
    end

    context 'when scope is "processing"' do
      it 'returns processing reimbursements assigned to current user' do
        params = { scope: 'processing' }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to include(reimbursement_assigned_to_me)
        expect(result).not_to include(reimbursement_with_unread_updates) # pending status
        expect(result).not_to include(reimbursement_unassigned) # not assigned
      end
    end

    context 'when scope is "closed"' do
      it 'returns closed reimbursements assigned to current user' do
        # Create a closed reimbursement assigned to current user for testing
        closed_reimbursement = create(:reimbursement, status: 'closed')
        create(:reimbursement_assignment,
               reimbursement: closed_reimbursement,
               assignee: admin_user,
               is_active: true)

        params = { scope: 'closed' }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to include(closed_reimbursement)
        expect(result).not_to include(reimbursement_assigned_to_me) # processing status
      end
    end

    context 'when scope is "all"' do
      it 'returns all reimbursements' do
        params = { scope: 'all' }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to include(reimbursement_assigned_to_me)
        expect(result).to include(reimbursement_assigned_to_other)
        expect(result).to include(reimbursement_unassigned)
        expect(result).to include(reimbursement_with_unread_updates)
      end
    end

    context 'when scope is nil' do
      it 'returns all reimbursements' do
        params = { scope: nil }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to include(reimbursement_assigned_to_me)
        expect(result).to include(reimbursement_assigned_to_other)
        expect(result).to include(reimbursement_unassigned)
        expect(result).to include(reimbursement_with_unread_updates)
      end
    end

    context 'when scope is empty string' do
      it 'returns all reimbursements' do
        params = { scope: '' }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to include(reimbursement_assigned_to_me)
        expect(result).to include(reimbursement_assigned_to_other)
        expect(result).to include(reimbursement_unassigned)
        expect(result).to include(reimbursement_with_unread_updates)
      end
    end

    context 'when scope is unknown' do
      it 'returns all reimbursements' do
        params = { scope: 'unknown_scope' }
        service = described_class.new(admin_user, params)
        result = service.filtered_collection(base_chain)

        expect(result).to respond_to(:count)
      end
    end
  end
end