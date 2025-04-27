ActiveAdmin.setup do |config|
  # Set site title
  config.site_title = "SCI2工单系统"

  # Set default namespace
  config.default_namespace = :admin

  # Set root path
  config.root_to = 'dashboard#index'

  # Enable batch actions
  config.batch_actions = true

  # Set records per page
  config.default_per_page = 30

  # Set CSV download options
  config.csv_options = { col_sep: ',', force_quotes: true }

  # Disable comments
  config.comments = false
end
