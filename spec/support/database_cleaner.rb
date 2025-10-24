# spec/support/database_cleaner.rb
require 'database_cleaner/active_record'
RSpec.configure do |config|
  # 在整个测试套件开始前清理数据库
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  # 在每个测试用例前使用事务策略
  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  # 对于使用 JS 的系统测试，使用截断策略
  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end

  # 在每个测试用例前启动 DatabaseCleaner
  config.before(:each) do
    DatabaseCleaner.start
  end

  # 在每个测试用例后清理数据库
  config.after(:each) do
    DatabaseCleaner.clean
  end
end
