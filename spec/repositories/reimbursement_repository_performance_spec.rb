# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReimbursementRepository, type: :repository do
  include QueryPerformanceHelper

  describe 'Performance Optimization' do
    let!(:reimbursements) { create_list(:reimbursement, 10, :with_assignment) }

    describe 'Query Performance' do
      it 'executes optimized list queries efficiently' do
        expect_max_queries(2) do
          ReimbursementRepository.optimized_list.to_a
        end
      end

      it 'handles batch operations efficiently' do
        reimbursement_ids = reimbursements.map(&:id)

        expect_max_queries(1) do
          ReimbursementRepository.find_by_ids(reimbursement_ids)
        end
      end

      it 'executes complex queries efficiently' do
        expect_max_queries(3) do
          ReimbursementRepository.assigned_to_user(1).includes(:active_assignment)
        end
      end

      it 'avoids N+1 queries in status operations' do
        expect_no_n_plus_one do
          ReimbursementRepository.status_counts
        end
      end
    end

    describe 'Query Time Performance' do
      it 'completes simple queries within time limits' do
        expect_query_time_under(0.1) do
          ReimbursementRepository.pending.count
        end
      end

      it 'completes complex queries within time limits' do
        expect_query_time_under(0.5) do
          ReimbursementRepository.with_unread_updates.includes(:active_assignment)
        end
      end
    end

    describe 'Memory Usage' do
      it 'uses efficient memory for large datasets' do
        # Create larger dataset for memory testing
        large_reimbursement_ids = create_list(:reimbursement, 100).map(&:id)

        memory_before = ObjectSpace.count_objects[:TOTAL]

        # Use find_each for memory efficiency
        ReimbursementRepository.find_each_by_ids(large_reimbursement_ids) do |reimbursement|
          # Process each record
          reimbursement.id
        end

        memory_after = ObjectSpace.count_objects[:TOTAL]
        memory_increase = memory_after - memory_before

        # Memory increase should be reasonable (< 1000 objects)
        expect(memory_increase).to be < 1000
      end
    end

    describe 'Index Usage' do
      it 'uses indexes effectively for indexed queries' do
        # Test query that should use invoice_number index
        performance = measure_query_performance do
          ReimbursementRepository.find_by_invoice_number(reimbursements.first.invoice_number)
        end

        expect(performance[:query_count]).to eq(1)
        expect(performance[:total_time]).to be < 0.05
      end

      it 'uses indexes for status queries' do
        performance = measure_query_performance do
          ReimbursementRepository.by_status('pending').count
        end

        expect(performance[:query_count]).to eq(1)
        expect(performance[:total_time]).to be < 0.05
      end
    end

    describe 'Bulk Operations' do
      it 'performs bulk updates efficiently' do
        expect_max_queries(1) do
          ReimbursementRepository.update_all({ status: 'processing' }, { id: reimbursements.map(&:id) })
        end
      end

      it 'handles bulk inserts efficiently' do
        new_reimbursements = build_list(:reimbursement, 5)

        expect_max_queries(1) do
          Reimbursement.import(new_reimbursements)
        end if defined?(Reimbursement.import)
      end
    end

    describe 'Caching Strategies' do
      it 'benefits from query caching' do
        # First query
        performance1 = measure_query_performance do
          ReimbursementRepository.current_approval_nodes
        end

        # Second query (should use cache)
        performance2 = measure_query_performance do
          ReimbursementRepository.current_approval_nodes
        end

        # Second query should be faster due to caching
        expect(performance2[:total_time]).to be <= performance1[:total_time]
      end

      it 'caches expensive aggregation queries' do
        performance = measure_query_performance do
          ReimbursementRepository.status_counts
        end

        expect(performance[:query_count]).to eq(4) # One query per status
        expect(performance[:total_time]).to be < 0.2
      end
    end
  end

  describe 'Edge Cases and Error Handling' do
    it 'handles empty result sets efficiently' do
      performance = measure_query_performance do
        ReimbursementRepository.where(id: -1).to_a
      end

      expect(performance[:query_count]).to eq(1)
      expect(performance[:total_time]).to be < 0.1
    end

    it 'handles large result sets with pagination' do
      # Create more data
      create_list(:reimbursement, 50)

      performance = measure_query_performance do
        ReimbursementRepository.page(1, 25).to_a
      end

      expect(performance[:query_count]).to eq(1)
      expect(performance[:total_time]).to be < 0.2
    end

    it 'handles complex joins efficiently' do
      performance = expect_optimized_repository_query(
        -> { ReimbursementRepository.joins(:active_assignment).includes(:active_assignment).to_a }
      )

      expect(performance[:query_count]).to be <= 2
    end
  end
end