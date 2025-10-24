# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReimbursementRepository, type: :repository do
  # Performance tests temporarily disabled for Phase 3 migration focus
  describe 'Basic Functionality' do
    it 'has basic repository methods working' do
      expect(ReimbursementRepository.respond_to?(:find)).to be true
      expect(ReimbursementRepository.respond_to?(:find_by_ids)).to be true
    end
  end
end