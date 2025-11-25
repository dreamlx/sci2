# spec/rails_helper.rb
# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
# Explicitly require Rails environment to ensure proper loading
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
require 'capybara/rspec' # Require Capybara RSpec integration
require 'selenium-webdriver' # For JavaScript-enabled tests
# Manually require state_machines-activerecord with error handling
begin
  require 'state_machines-activerecord'
rescue LoadError => e
  puts "Warning: state_machines-activerecord could not be loaded in test environment: #{e.message}"
end
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Load support files
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }
#
# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Include Rails controller testing helpers
  config.include Rails::Controller::Testing::TemplateAssertions, type: :request

  # Include Devise test helpers for request specs
  config.include Devise::Test::IntegrationHelpers, type: :request

  # Include Devise test helpers for controller specs
  config.include Devise::Test::ControllerHelpers, type: :controller

  # Include Warden test helpers for feature and system specs (Capybara)
  config.include Warden::Test::Helpers, type: :feature
  config.include Warden::Test::Helpers, type: :system
  
  # Include Devise test helpers for system specs
  config.include Devise::Test::IntegrationHelpers, type: :system
  
  # Configure Capybara for system tests
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    # Use optimized Chrome driver configuration for better stability
    driven_by :selenium_chrome_headless
  end

  # Additional setup for Chrome driver management
  config.before(:suite) do
    # Ensure webdrivers are properly cached
    Webdrivers.cache_time = 86_400 # 24 hours cache

    # Use system ChromeDriver if available to avoid download issues
    if system('which chromedriver > /dev/null 2>&1')
      Webdrivers::Chromedriver.required_version = :system
    end
  end

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = Rails.root.join('spec/fixtures')

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false # 设置为 false，让 DatabaseCleaner 接管事务管理

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/7-1/rspec-rails
  #
  # You can also this infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  # config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # Configure shoulda-matchers
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end

  # Configure FactoryBot
  config.include FactoryBot::Syntax::Methods

  # Performance optimization settings with improved test isolation
  config.before(:suite) do
    # Pre-warm factories for better performance
    FactoryBot.lint if ENV['LINT_FACTORIES']
  end

  # Additional cleanup for Repository tests - simplified approach
  # DatabaseCleaner should handle most cleanup, but we ensure specific isolation
  config.after(:each, type: :repository) do
    # Only clean up operations table to avoid foreign key issues
    WorkOrderOperation.delete_all if defined?(WorkOrderOperation)
  end

  # Disable parallel testing to avoid SQLite locking issues
  # Parallel testing with SQLite can cause database locking errors
  # config.parallelize(workers: :number_of_processors) if ENV['PARALLEL_WORKERS']

  # Performance monitoring
  config.around(:each) do |example|
    if ENV['PROFILE_TESTS']
      start_time = Time.current
      example.run
      execution_time = Time.current - start_time

      if execution_time > 3.seconds
        puts "\n🐌 Slow test: #{example.full_description} (#{execution_time.round(2)}s)"
      end
    else
      example.run
    end
  end

  # Memory optimization
  config.after(:suite) do
    if ENV['MONITOR_MEMORY']
      GC.start
      puts "\n📊 Memory Usage: #{ObjectSpace.count_objects[:TOTAL]} objects"
    end
  end

  # Skip slow tests in CI by default
  config.filter_run_excluding slow: true if ENV['CI'] && !ENV['INCLUDE_SLOW_TESTS']

  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
