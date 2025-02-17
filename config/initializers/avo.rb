# For more information regarding these settings check out our docs https://docs.avohq.io
# The values disaplayed here are the default ones. Uncomment and change them to fit your needs.
Avo.configure do |config|
  ## == Routing ==
  config.root_path = '/admin'
  # used only when you have custom `map` configuration in your config.ru
  # config.prefix_path = "/internal"

  # Sometimes you might want to mount Avo's engines yourself.
  # https://docs.avohq.io/3.0/routing.html
  # config.mount_avo_engines = true

  # Where should the user be redirected when visiting the `/avo` url
  # config.home_path = nil

  ## == Licensing ==
  # config.license_key = ENV['AVO_LICENSE_KEY']

  ## == Set the context ==
  config.set_context do
    # Return a context object that gets evaluated within Avo::ApplicationController
  end

  ## == Authentication ==
  config.current_user_method = :current_user
  # config.authenticate_with do
  #   current_user.present? && current_user.admin?
  # end

  ## == Authorization ==
  # config.is_admin_method = :is_admin
  # config.is_developer_method = :is_developer
  # config.authorization_methods = {
  #   index: 'index?',
  #   show: 'show?',
  #   edit: 'edit?',
  #   new: 'new?',
  #   update: 'update?',
  #   create: 'create?',
  #   destroy: 'destroy?',
  #   search: 'search?',
  # }
  # config.raise_error_on_missing_policy = false
  config.authorization_client = nil
  config.explicit_authorization = true

  ## == Localization ==
  # config.locale = 'en-US'

  ## == Resource options ==
  # config.resource_row_controls_config = {
  #   placement: :right,
  #   float: false,
  #   show_on_hover: false
  # }.freeze
  # config.model_resource_mapping = {}
  # config.default_view_type = :table
  # config.per_page = 24
  # config.per_page_steps = [12, 24, 48, 72]
  # config.via_per_page = 8
  # config.id_links_to_resource = false
  # config.pagination = -> do
  #   {
  #     type: :default,
  #     size: 9, # `[1, 2, 2, 1]` for pagy < 9.0
  #   }
  # end

  ## == Response messages dismiss time ==
  # config.alert_dismiss_time = 5000


  ## == Number of search results to display ==
  # config.search_results_count = 8

  ## == Associations lookup list limit ==
  # config.associations_lookup_list_limit = 1000

  ## == Cache options ==
  ## Provide a lambda to customize the cache store used by Avo.
  ## We compute the cache store by default, this is NOT the default, just an example.
  # config.cache_store = -> {
  #   ActiveSupport::Cache.lookup_store(:solid_cache_store)
  # }
  # config.cache_resources_on_index_view = true

  ## == Turbo options ==
  # config.turbo = -> do
  #   {
  #     instant_click: true
  #   }
  # end

  ## == Logger ==
  # config.logger = -> {
  #   file_logger = ActiveSupport::Logger.new(Rails.root.join("log", "avo.log"))
  #
  #   file_logger.datetime_format = "%Y-%m-%d %H:%M:%S"
  #   file_logger.formatter = proc do |severity, time, progname, msg|
  #     "[Avo] #{time}: #{msg}\n".tap do |i|
  #       puts i
  #     end
  #   end
  #
  #   file_logger
  # }

  ## == Customization ==
  config.click_row_to_view_record = true
  # config.app_name = 'Avocadelicious'
  # config.timezone = 'UTC'
  # config.currency = 'USD'
  # config.hide_layout_when_printing = false
  # config.full_width_container = false
  # config.full_width_index_view = false
  # config.search_debounce = 300
  # config.view_component_path = "app/components"
  # config.display_license_request_timeout_error = true
  # config.disabled_features = []
  # config.buttons_on_form_footers = true
  # config.field_wrapper_layout = true
  # config.resource_parent_controller = "Avo::ResourcesController"
  # config.first_sorting_option = :desc # :desc or :asc
  # config.exclude_from_status = []

  ## == Branding ==
  # config.branding = {
  #   colors: {
  #     background: "248 246 242",
  #     100 => "#CEE7F8",
  #     400 => "#399EE5",
  #     500 => "#0886DE",
  #     600 => "#066BB2",
  #   },
  #   chart_colors: ["#0B8AE2", "#34C683", "#2AB1EE", "#34C6A8"],
  #   logo: "/avo-assets/logo.png",
  #   logomark: "/avo-assets/logomark.png",
  #   placeholder: "/avo-assets/placeholder.svg",
  #   favicon: "/avo-assets/favicon.ico"
  # }

  ## == Breadcrumbs ==
  # config.display_breadcrumbs = true
  # config.set_initial_breadcrumbs do
  #   add_breadcrumb "Home", '/avo'
  # end

  ## == Menus ==
  # config.main_menu = -> {
  #   section "Dashboards", icon: "avo/dashboards" do
  #     all_dashboards
  #   end

  #   section "Resources", icon: "avo/resources" do
  #     all_resources
  #   end

  #   section "Tools", icon: "avo/tools" do
  #     all_tools
  #   end
  # }
  # config.profile_menu = -> {
  #   link "Profile", path: "/avo/profile", icon: "heroicons/outline/user-circle"
  # }
end
