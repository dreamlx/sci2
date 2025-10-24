# frozen_string_literal: true

# Test Performance Configuration
# Optimizes test suite execution for better performance

RSpec.configure do |config|
  # Performance settings
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures = false

  # Database cleanup strategy for performance
  config.before(:suite) do
    # Use database cleaner for better performance
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Parallel testing configuration
  if ENV['PARALLEL_WORKERS']
    require 'parallel_tests'
    config.parallelize(workers: :number_of_processors)
  end

  # Factory caching for performance
  config.before(:suite) do
    # Pre-warm factories - temporarily disabled due to migration issues
    # FactoryBot.lint
  end

  # Optimize factory creation
  config.before(:all) do
    # Cache expensive factory operations
    @cached_factories ||= {}
  end

  # Performance profiling
  if ENV['PROFILE_TESTS']
    config.profile_examples = 20
    config.order = :random
    Kernel.srand config.seed
  end

  # Slow test identification
  config.around(:each) do |example|
    start_time = Time.current
    example.run
    execution_time = Time.current - start_time

    if execution_time > 5.seconds
      puts "\n⚠️  Slow test detected: #{example.full_description} (#{execution_time.round(2)}s)"
    end
  end

  # Memory usage monitoring
  config.after(:suite) do
    if ENV['MONITOR_MEMORY']
      GC.start
      puts "\n=== Memory Usage ==="
      puts "Ruby objects: #{ObjectSpace.count_objects[:TOTAL]}"
    end
  end

  # Test data optimization
  config.before(:each) do |example|
    # Use minimal data creation for fast tests
    if example.metadata[:fast_test]
      DatabaseCleaner.strategy = :transaction
    end
  end

  # Skip expensive tests in CI unless explicitly requested
  config.filter_run_excluding slow: true if ENV['CI'] && !ENV['INCLUDE_SLOW_TESTS']

  # Performance-focused tags
  config.filter_run_excluding performance_benchmark: true unless ENV['RUN_PERFORMANCE_TESTS']
end

# Custom performance helpers
module TestPerformanceHelpers
  def with_database_transaction
    ActiveRecord::Base.transaction do
      yield
      raise ActiveRecord::Rollback
    end
  end

  def create_cached_factory(factory_name, traits = {})
    @cached_factories[factory_name] ||= create(factory_name, traits)
  end

  def measure_performance(&block)
    start_time = Time.current
    result = block.call
    execution_time = Time.current - start_time
    puts "Execution time: #{execution_time.round(4)}s"
    result
  end
end

RSpec.configure do |config|
  config.include TestPerformanceHelpers
end