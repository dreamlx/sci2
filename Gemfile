source 'https://rubygems.org'

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.1.5'
# Use sqlite3 as the database for Active Record
gem 'sqlite3', group: %i[development test]
# Use PostgreSQL as the database for Active Record
# gem 'pg', '~> 1.1'
# Use MySQL as the database for Active Record
# gem 'mysql2', '~> 0.5'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 6.1'
# Use JavaScript with a library like jQuery
gem 'jquery-rails'
# Use SCSS for stylesheets
gem 'sassc-rails'
# Transpile app-like JavaScript. Read more: https://github.com/rails/jsbundling-rails
gem 'jsbundling-rails'
# Hotwire's Stimulus reflex
# gem 'stimulus_reflex'
# Use Hotwire to deliver dynamic web applications over WebSockets and SSE
gem 'turbo-rails'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder'

# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

group :development do
  # Capistrano deployment
  gem 'capistrano', '~> 3.19'
  gem 'capistrano-rails', '~> 1.6'
  gem 'capistrano-bundler', '~> 2.1'
  gem 'capistrano-rvm', '~> 0.1'
  gem 'capistrano-puma', '~> 5.2'
  gem 'capistrano3-puma', '~> 5.2'
  gem 'sshkit', '~> 1.22'
end

group :development, :test do
  gem 'shoulda-matchers'
  gem 'factory_bot_rails'
  gem 'roo'
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rspec-rails'
  gem 'rails-controller-testing'
  gem 'capybara' # Add Capybara gem
  gem 'selenium-webdriver' # Add selenium-webdriver gem for Capybara
  gem 'database_cleaner-active_record' # Add database_cleaner for test database cleanup
end

# Use Devise for authentication
gem 'devise'
# Use ActiveAdmin for admin interface
gem 'activeadmin'
# Use state_machines for state management
gem 'state_machines'
gem 'state_machines-activerecord'
