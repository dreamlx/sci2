# Gemfile
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.2'

# Rails core
gem 'rails', '~>7.1.5.1'
gem 'sqlite3', '~> 1.4'
gem 'puma', '~> 6.0'
# gem 'bootsnap', '>= 1.4.4', require: false

# Frontend
gem 'importmap-rails'
gem 'turbo-rails'
gem 'stimulus-rails'
gem 'jbuilder'

# ActiveAdmin
gem 'activeadmin'
gem 'devise'
gem 'sassc-rails'
gem 'kaminari'

# State machine
gem 'state_machines'
gem 'state_machines-activerecord'

# XLS/XLSX processing
gem 'roo'

# CSV processing
gem 'csv'

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rspec-rails'
  gem 'factory_bot_rails'
end

group :development do
  gem 'web-console', '>= 4.1.0'
  gem 'rack-mini-profiler', '~> 2.0'
  gem 'listen', '~> 3.3'
  gem 'spring'
end

group :test do
  gem 'shoulda-matchers', '~> 5.0'
  gem 'capybara', '>= 3.26'
  gem 'selenium-webdriver'
  gem 'webdrivers'
end
