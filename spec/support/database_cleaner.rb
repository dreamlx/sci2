# spec/support/database_cleaner.rb
require 'database_cleaner/active_record'

# PostgreSQL优化配置 - 简化连接管理避免超时
RSpec.configure do |config|
  # DatabaseCleaner configuration for better connection management
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do |example|
    # 简化策略，减少切换开销
    if example.metadata[:type] == :feature || example.metadata[:js] || example.metadata[:type] == :system
      DatabaseCleaner.strategy = :truncation
    else
      DatabaseCleaner.strategy = :transaction
    end
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.after(:suite) do
    # 简化清理，避免连接问题
    if defined?(ActiveRecord::Base)
      ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
    end
  end
end