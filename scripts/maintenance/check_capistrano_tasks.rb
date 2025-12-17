#!/usr/bin/env ruby

# Script to check what Capistrano tasks are being executed during deployment
puts '=== Capistrano Tasks Analysis ==='
puts "Time: #{Time.now}"
puts

# Check Capistrano Rails tasks
puts '1. Capistrano Rails Tasks Check:'
puts 'Looking for automatic database tasks...'
puts

# Read Capfile to see what's included
capfile_content = begin
  File.read('Capfile')
rescue StandardError
  'Capfile not found'
end
puts '2. Capfile includes:'
capfile_content.each_line.with_index(1) do |line, num|
  if line.include?('require') && (line.include?('rails') || line.include?('bundler'))
    puts "  Line #{num}: #{line.strip}"
  end
end
puts

# Check deploy.rb for custom tasks
deploy_content = begin
  File.read('config/deploy.rb')
rescue StandardError
  'deploy.rb not found'
end
puts '3. Custom deployment tasks in deploy.rb:'
deploy_content.each_line.with_index(1) do |line, num|
  if line.include?('namespace') || line.include?('task') || line.include?('before') || line.include?('after')
    puts "  Line #{num}: #{line.strip}"
  end
end
puts

# Check for Rails-specific hooks that might run db:seed
puts '4. Potential Rails hooks that could populate data:'
rails_hooks = [
  'deploy:migrate',
  'deploy:seed',
  'rails:db:seed',
  'rails:db:setup',
  'deploy:setup_db'
]

rails_hooks.each do |hook|
  if deploy_content.include?(hook) || capfile_content.include?(hook)
    puts "  FOUND: #{hook}"
  else
    puts "  Not found: #{hook}"
  end
end

puts
puts '=== End Capistrano Analysis ==='
