# config/boot.rb
# Set up gems listed in the Gemfile.
require 'bundler/setup'

# Conditionally require bootsnap/setup if bootsnap is available
begin
  require 'bootsnap/setup'
rescue LoadError
  # Bootsnap is not available, do nothing
end
