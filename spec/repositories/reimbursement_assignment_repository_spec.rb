# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReimbursementAssignmentRepository, type: :repository do
  # Test data setup
  let!(:reimbursement1) { create(:reimbursement) }
  let!(:reimbursement2) { create(:reimbursement) }
  let!(:assignee1) { create(:admin_user, email: "assignee1-#{SecureRandom.hex(4)}@example.com") }
  let!(:assignee2) { create(:admin_user, email: "assignee2-#{SecureRandom.hex(4)}@example.com") }
  let!(:assigner1) { create(:admin_user, email: "assigner1-#{SecureRandom.hex(4)}@example.com") }
  let!(:assigner2) { create(:admin_user, email: "assigner2-#{SecureRandom.hex(4)}@example.com") }
  
  let!(:active_assignment1) do
    create(:reimbursement_assignment,
           reimbursement: reimbursement1,
           assignee: assignee1,
           assigner: assigner1,
           is_active: true,
           notes: "Active assignment notes",
           created_at: 1.day.ago)
  end
  
  let!(:inactive_assignment) do
    create(:reimbursement_assignment,
           reimbursement: reimbursement1,
           assignee: assignee2,
           assigner: assigner1,
           is_active: false,
           notes: "Inactive assignment notes",
           created_at: 2.days.ago)
  end
  
  let!(:active_assignment2) do
    create(:reimbursement_assignment,
           reimbursement: reimbursement2,
           assignee: assignee1,
           assigner: assigner2,
           is_active: true,
           notes: "Another active assignment",
           created_at: Time.current)
  end

  describe '.find' do
    it 'returns assignment when found' do
      result = described_class.find(active_assignment1.id)
      expect(result).to eq(active_assignment1)
    end

    it 'returns nil when not found' do
      result = described_class.find(99_999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_id' do
    it 'returns assignment when found' do
      result = described_class.find_by_id(active_assignment1.id)
      expect(result).to eq(active_assignment1)
    end

    it 'returns nil when not found' do
      result = described_class.find_by_id(99_999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_ids' do
    it 'returns assignments with given ids' do
      result = described_class.find_by_ids([active_assignment1.id, inactive_assignment.id])
      expect(result.pluck(:id)).to match_array([active_assignment1.id, inactive_assignment.id])
    end
  end

  describe '.active' do
    it 'returns only active assignments' do
      result = described_class.active
      expect(result.pluck(:id)).to match_array([active_assignment1.id, active_assignment2.id])
      expect(result.all?(&:is_active)).to be true
    end
  end

  describe '.inactive' do
    it 'returns only inactive assignments' do
      result = described_class.inactive
      expect(result.pluck(:id)).to include(inactive_assignment.id)
      expect(result.all? { |a| !a.is_active }).to be true
    end
  end

  describe '.by_assignee' do
    it 'returns assignments for specific assignee' do
      result = described_class.by_assignee(assignee1.id)
      expect(result.pluck(:id)).to match_array([active_assignment1.id, active_assignment2.id])
    end
  end

  describe '.by_assigner' do
    it 'returns assignments for specific assigner' do
      result = described_class.by_assigner(assigner1.id)
      expect(result.pluck(:id)).to match_array([active_assignment1.id, inactive_assignment.id])
    end
  end

  describe '.active_by_assignee' do
    it 'returns active assignments for specific assignee' do
      result = described_class.active_by_assignee(assignee1.id)
      expect(result.pluck(:id)).to match_array([active_assignment1.id, active_assignment2.id])
      expect(result.all?(&:is_active)).to be true
    end
  end

  describe '.active_by_assigner' do
    it 'returns active assignments for specific assigner' do
      result = described_class.active_by_assigner(assigner1.id)
      expect(result.pluck(:id)).to include(active_assignment1.id)
      expect(result.all?(&:is_active)).to be true
    end
  end

  describe '.inactive_by_assignee' do
    it 'returns inactive assignments for specific assignee' do
      result = described_class.inactive_by_assignee(assignee2.id)
      expect(result.pluck(:id)).to include(inactive_assignment.id)
      expect(result.all? { |a| !a.is_active }).to be true
    end
  end

  describe '.inactive_by_assigner' do
    it 'returns inactive assignments for specific assigner' do
      result = described_class.inactive_by_assigner(assigner1.id)
      expect(result.pluck(:id)).to include(inactive_assignment.id)
      expect(result.all? { |a| !a.is_active }).to be true
    end
  end

  describe '.for_reimbursement' do
    it 'returns all assignments for reimbursement' do
      result = described_class.for_reimbursement(reimbursement1.id)
      expect(result.pluck(:id)).to match_array([active_assignment1.id, inactive_assignment.id])
    end
  end

  describe '.active_for_reimbursement' do
    it 'returns active assignment for reimbursement' do
      result = described_class.active_for_reimbursement(reimbursement1.id)
      expect(result.pluck(:id)).to eq([active_assignment1.id])
    end
  end

  describe '.current_for_reimbursement' do
    it 'returns current active assignment for reimbursement' do
      result = described_class.current_for_reimbursement(reimbursement1.id)
      expect(result).to eq(active_assignment1)
    end

    it 'returns nil when no active assignment exists' do
      inactive_reimbursement = create(:reimbursement)
      result = described_class.current_for_reimbursement(inactive_reimbursement.id)
      expect(result).to be_nil
    end
  end

  describe '.recent_first' do
    it 'returns assignments ordered by creation date descending' do
      result = described_class.recent_first
      expect(result.first.id).to eq(active_assignment2.id)
      expect(result.pluck(:id)).to eq([active_assignment2.id, active_assignment1.id, inactive_assignment.id])
    end
  end

  describe '.active_recent_first' do
    it 'returns active assignments ordered by creation date descending' do
      result = described_class.active_recent_first
      expect(result.first.id).to eq(active_assignment2.id)
      expect(result.all?(&:is_active)).to be true
    end
  end

  describe '.by_assignee_recent' do
    it 'returns assignee assignments ordered by creation date' do
      result = described_class.by_assignee_recent(assignee1.id)
      expect(result.first.id).to eq(active_assignment2.id)
    end
  end

  describe '.active_by_assignee_recent' do
    it 'returns active assignee assignments ordered by creation date' do
      result = described_class.active_by_assignee_recent(assignee1.id)
      expect(result.first.id).to eq(active_assignment2.id)
      expect(result.all?(&:is_active)).to be true
    end
  end

  describe '.exists_active_for_reimbursement?' do
    it 'returns true when active assignment exists' do
      result = described_class.exists_active_for_reimbursement?(reimbursement1.id)
      expect(result).to be true
    end

    it 'returns false when no active assignment exists' do
      inactive_reimbursement = create(:reimbursement)
      result = described_class.exists_active_for_reimbursement?(inactive_reimbursement.id)
      expect(result).to be false
    end
  end

  describe '.active_assignment_for_reimbursement' do
    it 'returns active assignment for reimbursement' do
      result = described_class.active_assignment_for_reimbursement(reimbursement1.id)
      expect(result).to eq(active_assignment1)
    end
  end

  describe '.created_today' do
    it 'returns assignments created today' do
      result = described_class.created_today
      expect(result.pluck(:id)).to include(active_assignment2.id)
    end
  end

  describe '.created_this_week' do
    it 'returns assignments created this week' do
      result = described_class.created_this_week
      expect(result.count).to be >= 1
    end
  end

  describe '.created_this_month' do
    it 'returns assignments created this month' do
      result = described_class.created_this_month
      expect(result.count).to be >= 1
    end
  end

  describe '.active_created_today' do
    it 'returns active assignments created today' do
      result = described_class.active_created_today
      expect(result.pluck(:id)).to include(active_assignment2.id)
      expect(result.all?(&:is_active)).to be true
    end
  end

  describe '.total_count' do
    it 'returns total count of assignments' do
      result = described_class.total_count
      expect(result).to be >= 3
    end
  end

  describe '.active_count' do
    it 'returns count of active assignments' do
      result = described_class.active_count
      expect(result).to be >= 2
    end
  end

  describe '.inactive_count' do
    it 'returns count of inactive assignments' do
      result = described_class.inactive_count
      expect(result).to be >= 1
    end
  end

  describe '.count_by_assignee' do
    it 'returns count of assignments for assignee' do
      result = described_class.count_by_assignee(assignee1.id)
      expect(result).to eq(2)
    end
  end

  describe '.active_count_by_assignee' do
    it 'returns count of active assignments for assignee' do
      result = described_class.active_count_by_assignee(assignee1.id)
      expect(result).to eq(2)
    end
  end

  describe '.count_by_assigner' do
    it 'returns count of assignments for assigner' do
      result = described_class.count_by_assigner(assigner1.id)
      expect(result).to eq(2)
    end
  end

  describe '.active_count_by_assigner' do
    it 'returns count of active assignments for assigner' do
      result = described_class.active_count_by_assigner(assigner1.id)
      expect(result).to eq(1)
    end
  end

  describe '.search_by_notes' do
    it 'returns assignments matching notes pattern' do
      result = described_class.search_by_notes('Active assignment')
      expect(result.pluck(:id)).to include(active_assignment1.id)
    end

    it 'returns empty when query is blank' do
      result = described_class.search_by_notes('')
      expect(result).to be_empty
    end

    it 'returns empty when no notes match' do
      result = described_class.search_by_notes('NonexistentKeyword')
      expect(result).to be_empty
    end
  end

  describe '.active_search_by_notes' do
    it 'returns active assignments matching notes pattern' do
      result = described_class.active_search_by_notes('Active assignment')
      expect(result.pluck(:id)).to include(active_assignment1.id)
      expect(result.all?(&:is_active)).to be true
    end

    it 'returns active assignments when query is blank' do
      result = described_class.active_search_by_notes('')
      expect(result.all?(&:is_active)).to be true
    end
  end

  describe '.recent' do
    it 'returns recent assignments with default limit' do
      result = described_class.recent
      expect(result.count).to be <= 10
      expect(result.first.id).to eq(active_assignment2.id)
    end

    it 'returns recent assignments with custom limit' do
      result = described_class.recent(2)
      expect(result.count).to eq(2)
    end
  end

  describe '.active_recent' do
    it 'returns recent active assignments' do
      result = described_class.active_recent
      expect(result.all?(&:is_active)).to be true
      expect(result.first.id).to eq(active_assignment2.id)
    end
  end

  describe '.page' do
    it 'returns paginated assignments' do
      result = described_class.page(1, 2)
      expect(result.count).to be <= 2
    end
  end

  describe '.active_page' do
    it 'returns paginated active assignments' do
      result = described_class.active_page(1, 2)
      expect(result.count).to be <= 2
      expect(result.all?(&:is_active)).to be true
    end
  end

  describe '.exists?' do
    it 'returns true when assignment exists' do
      result = described_class.exists?(id: active_assignment1.id)
      expect(result).to be true
    end

    it 'returns false when assignment does not exist' do
      result = described_class.exists?(id: 99_999)
      expect(result).to be false
    end
  end

  describe '.exists_for_reimbursement?' do
    it 'returns true when assignment exists for reimbursement' do
      result = described_class.exists_for_reimbursement?(reimbursement1.id)
      expect(result).to be true
    end

    it 'returns false when no assignment exists for reimbursement' do
      new_reimbursement = create(:reimbursement)
      result = described_class.exists_for_reimbursement?(new_reimbursement.id)
      expect(result).to be false
    end
  end

  describe '.has_active_assignment?' do
    it 'returns true when active assignment exists' do
      result = described_class.has_active_assignment?(reimbursement1.id)
      expect(result).to be true
    end

    it 'returns false when no active assignment exists' do
      new_reimbursement = create(:reimbursement)
      result = described_class.has_active_assignment?(new_reimbursement.id)
      expect(result).to be false
    end
  end

  describe '.optimized_list' do
    it 'returns assignments with included associations' do
      result = described_class.optimized_list
      expect(result).to be_present
      expect(result.first).to respond_to(:reimbursement)
      expect(result.first).to respond_to(:assignee)
      expect(result.first).to respond_to(:assigner)
    end
  end

  describe '.active_optimized_list' do
    it 'returns active assignments with included associations' do
      result = described_class.active_optimized_list
      expect(result.all?(&:is_active)).to be true
      expect(result.first).to respond_to(:reimbursement)
    end
  end

  describe '.optimized_for_reimbursement' do
    it 'returns reimbursement assignments with included associations' do
      result = described_class.optimized_for_reimbursement(reimbursement1.id)
      expect(result).to be_present
      expect(result.first).to respond_to(:assignee)
      expect(result.first).to respond_to(:assigner)
    end
  end

  describe '.safe_find' do
    it 'returns assignment when found' do
      result = described_class.safe_find(active_assignment1.id)
      expect(result).to eq(active_assignment1)
    end

    it 'returns nil when not found' do
      result = described_class.safe_find(99_999)
      expect(result).to be_nil
    end

    it 'returns nil on error' do
      allow(described_class).to receive(:find).and_raise(StandardError.new('Test error'))
      result = described_class.safe_find(active_assignment1.id)
      expect(result).to be_nil
    end
  end

  describe '.safe_find_by_id' do
    it 'returns assignment when found' do
      result = described_class.safe_find_by_id(active_assignment1.id)
      expect(result).to eq(active_assignment1)
    end

    it 'returns nil when not found' do
      result = described_class.safe_find_by_id(99_999)
      expect(result).to be_nil
    end
  end

  describe '.safe_current_for_reimbursement' do
    it 'returns current assignment for reimbursement' do
      result = described_class.safe_current_for_reimbursement(reimbursement1.id)
      expect(result).to eq(active_assignment1)
    end

    it 'returns nil when not found' do
      new_reimbursement = create(:reimbursement)
      result = described_class.safe_current_for_reimbursement(new_reimbursement.id)
      expect(result).to be_nil
    end

    it 'returns nil on error' do
      allow(described_class).to receive(:current_for_reimbursement).and_raise(StandardError.new('Test error'))
      result = described_class.safe_current_for_reimbursement(reimbursement1.id)
      expect(result).to be_nil
    end
  end
end
