# Load DSL and set up stages
require 'capistrano/setup'

# Include default deployment tasks
require 'capistrano/deploy'

# Use copy SCM instead of Git for firewall environments
require 'capistrano/scm/copy'
install_plugin Capistrano::SCM::Copy

# Include tasks from other gems included in your Gemfile
require 'capistrano/rails'
require 'capistrano/bundler'
require 'capistrano/rvm'
# require 'capistrano3/puma'

# Load custom tasks from `lib/capistrano/tasks` if you have any
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }