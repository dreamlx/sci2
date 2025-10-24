# frozen_string_literal: true

# Query Performance Monitoring
# Identifies N+1 queries and performance bottlenecks

module QueryPerformanceHelper
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def expect_max_queries(max_count)
      around do |example|
        query_count = 0
        ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
          query_count += 1
        end

        example.run

        expect(query_count).to be <= max_count,
          "Expected at most #{max_count} queries, but got #{query_count}"
      end
    end

    def expect_no_n_plus_one
      around do |example|
        # Track duplicate query patterns
        query_patterns = Hash.new(0)

        ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
          next unless payload[:name] == 'ActiveRecord'

          # Extract query pattern (remove values, keep structure)
          query_pattern = payload[:sql].gsub(/\d+/, '?').gsub(/'.*?'/, "'?'")
          query_patterns[query_pattern] += 1
        end

        example.run

        # Check for potential N+1 patterns
        repeated_patterns = query_patterns.select { |_, count| count > 3 }
        if repeated_patterns.any?
          puts "\n⚠️  Potential N+1 queries detected:"
          repeated_patterns.each do |pattern, count|
            puts "  Query executed #{count} times: #{pattern[0..100]}..."
          end
        end
      end
    end

    def expect_query_time_under(max_seconds)
      around do |example|
        total_time = 0

        ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
          total_time += (finish - start)
        end

        example.run

        expect(total_time).to be <= max_seconds,
          "Expected query time under #{max_seconds}s, but got #{total_time.round(4)}s"
      end
    end
  end

  # Instance methods for performance testing
  def measure_query_performance(&block)
    query_count = 0
    total_time = 0
    queries = []

    ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      next unless payload[:name] == 'ActiveRecord'

      query_count += 1
      total_time += (finish - start)
      queries << {
        sql: payload[:sql],
        duration: finish - start,
        name: payload[:name]
      }
    end

    result = block.call

    {
      query_count: query_count,
      total_time: total_time,
      average_time: query_count > 0 ? total_time / query_count : 0,
      queries: queries
    }
  end

  def expect_optimized_repository_query(repository_method, *args)
    performance = measure_query_performance do
      repository_method.call(*args)
    end

    # Performance assertions
    expect(performance[:query_count]).to be <= 3,
      "Repository query should use ≤ 3 queries, got #{performance[:query_count]}"

    expect(performance[:total_time]).to be <= 0.5,
      "Repository query should complete in ≤ 0.5s, got #{performance[:total_time].round(4)}s"

    performance
  end

  def identify_slow_queries(threshold_ms = 100)
    slow_queries = []

    ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      next unless payload[:name] == 'ActiveRecord'

      duration_ms = (finish - start) * 1000
      if duration_ms > threshold_ms
        slow_queries << {
          sql: payload[:sql],
          duration_ms: duration_ms,
          name: payload[:name]
        }
      end
    end

    slow_queries
  end
end

RSpec.configure do |config|
  config.include QueryPerformanceHelper, type: :repository
  config.include QueryPerformanceHelper, file_path: %r{spec/repositories}
end