# Load DSL and set up stages
require 'capistrano/setup'

# Include default deployment tasks
require 'capistrano/deploy'

# Include tasks from other gems included in your Gemfile
require 'capistrano/rails'
require 'capistrano/bundler'
require 'capistrano/rvm'
require 'capistrano/puma'
require 'capistrano3/puma'

# Load custom tasks from `lib/capistrano/tasks` if you have any
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }