source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.2'

# === CORE ===================================================================
gem 'activeadmin'
gem 'activeadmin_addons'
gem 'activerecord-session_store'
gem 'activerecord-transactionable'
gem 'bootsnap', require: false
gem 'cancancan'
gem 'devise'
gem 'devise-i18n'
gem 'image_processing', '~> 1.2'
gem 'jbuilder'
gem 'paper_trail'
gem 'pg', '~> 1.4'
gem 'puma', '~> 6.0'
gem 'rails', '~> 7.1.3'
gem 'ransack', '~> 4.1.1'
gem 'roo', '~> 2.10.0'
gem 'roo-xls'
gem 'ruby-ole', '~> 1.2', '>= 1.2.12'
gem 'spreadsheet'
gem 'sqlite3', '~> 1.4'
gem 'state_machines-activerecord'
gem 'stimulus-rails'
gem 'turbo-rails'
gem 'tzinfo-data', platforms: %i[mingw x64_mingw mswin]

# === DEVELOPMENT & TEST =========================================================
group :development, :test do
  gem 'dotenv-rails'
  gem 'bundler-audit'
  gem 'codecov', require: false
  gem 'database_cleaner-active_record'
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'memory_profiler'
  gem 'rspec-rails', '~> 6.0.0'
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
  gem 'simplecov-json', require: false
end

# === DEVELOPMENT ============================================================
group :development do
  gem 'annotate'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'web-console'

  # Capistrano deployment
  gem 'capistrano', '~> 3.20'
  gem 'capistrano-bundler', '~> 2.0'
  gem 'capistrano-rails', '~> 1.6'
  gem 'capistrano-rvm'
  gem 'ed25519', '>= 1.2', '< 2.0'
  gem 'bcrypt_pbkdf', '>= 1.0', '< 2.0'
end

# === TEST ===================================================================
group :test do
  gem 'capybara'
  gem 'rails-controller-testing'
  gem 'selenium-webdriver'
  gem 'webdrivers'
end
