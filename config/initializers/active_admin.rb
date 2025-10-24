require 'inherited_resources'

ActiveAdmin.setup do |config|
  # == Site Title
  #
  # Set the title that is displayed on the main layout
  # for each of the active admin pages.
  #
  config.site_title = 'SCI2工单系统'

  # Set the link url for the title. For example, to take
  # users to your main site. Defaults to no link.
  #
  # config.site_title_link = "/"

  # Set an optional image to be displayed for the header
  # instead of a string (overrides :site_title)
  #
  # Note: Aim for an image that's 21px high so it fits in the header.
  #
  # config.site_title_image = "logo.png"

  # == Load Paths
  #
  # By default Active Admin files go inside app/admin/.
  # You can change this directory.
  #
  # eg:
  #   config.load_paths = [File.join(Rails.root, 'app', 'ui')]
  #
  # Or, you can also load more directories.
  # Useful when setting namespaces with users that are not your main AdminUser entity.
  #
  # eg:
  #   config.load_paths = [
  #     File.join(Rails.root, 'app', 'admin'),
  #     File.join(Rails.root, 'app', 'cashier')
  #   ]

  # == Default Namespace
  #
  # Set the default namespace each administration resource
  # will be added to.
  #
  config.default_namespace = :admin

  # == User Authentication
  #
  # Active Admin will automatically call an authentication
  # method in a before filter of all controller actions to
  # ensure that there is a currently logged in admin user.
  #
  # This setting changes the method which Active Admin calls
  # within the application controller.
  config.authentication_method = :authenticate_admin_user!

  # == User Authorization
  #
  # Active Admin will automatically call an authorization
  # method in a before filter of all controller actions to
  # ensure that there is a user with proper rights. You can use
  # CanCanAdapter or make your own. Please refer to documentation.
  config.authorization_adapter = ActiveAdmin::CanCanAdapter

  # In case you prefer Pundit over other solutions you can here pass
  # the name of default policy class. This policy will be used in every
  # case when Pundit is unable to find suitable policy.
  # config.pundit_default_policy = "MyDefaultPunditPolicy"

  # If you wish to maintain a separate set of Pundit policies for admin
  # resources, you may set a namespace here that Pundit will search
  # within when looking for a resource's policy.
  # config.pundit_policy_namespace = :admin

  # You can customize your CanCan Ability class name here.
  config.cancan_ability_class = 'Ability'

  # You can specify a method to be called on unauthorized access.
  # This is necessary in order to prevent a redirect loop which happens
  # because, by default, user gets redirected to Dashboard. If user
  # doesn't have access to Dashboard, he'll end up in a redirect loop.
  # Method provided here should be defined in application_controller.rb.
  config.on_unauthorized_access = :access_denied

  # == Current User
  #
  # Active Admin will associate actions with the current
  # user performing them.
  #
  # This setting changes the method which Active Admin calls
  # (within the application controller) to return the currently logged in user.
  config.current_user_method = :current_admin_user

  # == Logging Out
  #
  # Active Admin displays a logout link on each screen. These
  # settings configure the location and method used for the link.
  #
  # This setting changes the path where the link points to. If it's
  # a string, the strings is used as the path. If it's a Symbol, we
  # will call the method to return the path.
  #
  config.logout_link_path = :destroy_admin_user_session_path

  # This setting changes the http method used when rendering the
  # link. For example :get, :delete, :put, etc..
  #
  # Default:
  # config.logout_link_method = :get

  # == Root
  #
  # Set the action to call for the root path. You can set different
  # roots for each namespace.
  #
  config.root_to = 'dashboard#index'

  # == Admin Comments
  #
  # This allows your users to comment on any resource registered with Active Admin.
  #
  # You can completely disable comments:
  config.comments = false

  # You can change the name under which comments are registered:
  # config.comments_registration_name = 'AdminComment'

  # You can change the order for the comments and you can change the column
  # to be used for ordering:
  # config.comments_order = 'created_at ASC'

  # You can disable the menu item for the comments index page:
  # config.comments_menu = false

  # You can customize the comment menu:
  # config.comments_menu = { parent: 'Admin', priority: 1 }

  # == Batch Actions
  #
  # Enable and disable Batch Actions
  #
  config.batch_actions = true
  # Disable scope counts globally

  # == Controller Filters
  #
  # You can add before, after and around filters to all of your
  # Active Admin resources and pages from here.
  #
  # config.before_action :do_something_awesome

  # == Attribute Filters
  #
  # You can exclude possibly sensitive model attributes from being displayed,
  # added to forms, or exported by default by ActiveAdmin
  #
  config.filter_attributes = %i[encrypted_password password password_confirmation]

  # == Localize Date/Time Format
  #
  # Set the localize format to display dates and times.
  # To understand how to localize your app with I18n, read more at
  # https://guides.rubyonrails.org/i18n.html
  #
  # You can run `bin/rails runner 'puts I18n.t("date.formats")'` to see the
  # available formats in your application.
  #
  # config.localize_format = :long

  # == Setting a Favicon
  #
  # config.favicon = 'favicon.ico'

  # == Meta Tags
  #
  # Add additional meta tags to the head element of active admin pages.
  #
  # Add tags to all pages logged in users see:
  #   config.meta_tags = { author: 'My Company' }

  # By default, sign up/sign in/recover password pages are excluded
  # from showing up in search engine results by adding a robots meta
  # tag. You can reset the hash of meta tags included in logged out
  # pages:
  #   config.meta_tags_for_logged_out_pages = {}

  # == Removing Breadcrumbs
  #
  # Breadcrumbs are enabled by default. You can customize them for individual
  # resources or you can disable them globally from here.
  #
  # config.breadcrumb = false

  # == Create Another Checkbox
  #
  # Create another checkbox is disabled by default. You can customize it for individual
  # resources or you can enable them globally from here.
  #
  # config.create_another = true

  # == Register Stylesheets & Javascripts
  #
  # We recommend using the built in Active Admin layout and loading
  # up your own stylesheets / javascripts to customize the look
  # and feel.
  #
  # To load a stylesheet:
  #   config.register_stylesheet 'my_stylesheet.css'
  #
  # You can provide an options hash for more control, which is passed along to stylesheet_link_tag():
  #   config.register_stylesheet 'my_print_stylesheet.css', media: :print
  #
  # To load a javascript file:
  #   config.register_javascript 'my_javascript.js'

  # Register custom JavaScript files for work order forms
  config.register_javascript 'audit_work_order_form.js'
  config.register_javascript 'communication_work_order_form.js'
  # config.register_javascript 'chartkick'
  # config.register_javascript 'Chart.bundle'
  config.register_javascript 'active_admin_custom.js'

  # Register custom CSS files
  config.register_stylesheet 'active_admin_dashboard.css'
  config.register_stylesheet 'active_admin_custom'
  config.register_stylesheet 'custom_tooltip.css'
  config.register_stylesheet 'active_admin_permissions'

  # == CSV options
  #
  # Set the CSV builder separator
  # config.csv_options = { col_sep: ';' }
  #
  # Force the use of quotes
  config.csv_options = { col_sep: ',', force_quotes: true }

  # == Default Per Page
  #
  # Set the default number of items displayed per page.
  #
  config.default_per_page = 30

  # == Maximum Per Page
  #
  # Set the maximum number of items displayed per page.
  #
  # config.max_per_page = 10_000

  # == Menu System
  #
  # You can add a navigation menu to be used in your application, or configure a provided menu
  #
  # To change the default utility navigation to show a link to your website & a logout btn
  #
  #   config.namespace :admin do |admin|
  #     admin.build_menu :utility_navigation do |menu|
  #       menu.add label: "My Great Website", url: "http://www.mygreatwebsite.com", html_options: { target: :blank }
  #       admin.add_logout_button_to_menu menu
  #     end
  #   end
  #
  # If you wanted to add a static menu item to the default menu provided:
  #
  #   config.namespace :admin do |admin|
  #     admin.build_menu :default do |menu|
  #       menu.add label: "My Great Website", url: "http://www.mygreatwebsite.com", html_options: { target: "_blank" }
  #     end
  #   end

  # Configure namespace-based menu permissions
  config.namespace :admin do |admin|
    # Build the default menu with permission-based visibility
    admin.build_menu :default do |menu|
      # Menu items will be controlled at the resource level using `if` proc
      # This ensures menu items are hidden based on user permissions
    end

    # Configure download links with permission control
    admin.download_links = proc {
      # Only super admins can download, others can view but not download
      current_admin_user&.super_admin? || false
    }
  end

  # == Download Links
  #
  # You can disable download links on resource listing pages,
  # or customize the formats shown per namespace/globally
  #
  # To disable/customize for the :admin namespace:
  #
  #   config.namespace :admin do |admin|
  #
  #     # Disable the links entirely
  #     admin.download_links = false
  #
  #     # Only show XML & PDF options
  #     admin.download_links = [:xml, :pdf]
  #
  #     # Enable/disable the links based on block
  #     #   (for example, with cancan)
  #     admin.download_links = proc { can?(:view_download_links) }
  #
  #   end
end
