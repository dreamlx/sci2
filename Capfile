# Load DSL and set up stages
require 'capistrano/setup'

# Include default deployment tasks
require 'capistrano/deploy'

# --- Plugin Loading Order ---
# The order of loading plugins is important.

# Load SCM plugin first.
require 'capistrano/scm/git'
install_plugin Capistrano::SCM::Git

# Load RVM integration.
require 'capistrano/rvm'

# Load Bundler integration.
require 'capistrano/bundler'

# Load Rails integration (includes assets, migrations).
require 'capistrano/rails'

# Load Puma integration.
require 'capistrano/puma'
install_plugin Capistrano::Puma

# --- Custom Tasks ---
# Load custom tasks from `lib/capistrano/tasks` if you have any.
Dir.glob('lib/capistrano/tasks/**/*.rake').each { |r| import r }