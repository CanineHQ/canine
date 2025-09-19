class Users::SessionsController < Devise::SessionsController
  layout 'homepage', only: [ :new, :create, :account_login, :account_create, :account_select ]
  before_action :require_no_authentication, only: [ :account_login, :account_select ]
  before_action :load_account_from_slug, only: [ :account_login, :account_create ]

  before_action :check_if_default_sign_in_allowed, only: [ :new ]
  before_action :check_if_account_select_allowed, only: [ :account_select ]

  def new
    super
  end

  def create
    super
  end

  def account_select
    @accounts = Account.all.includes(:stack_manager)
  end

  def account_login
    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    if @account.stack_manager&.portainer?
      render "devise/sessions/portainer"
    else
      render :new
    end
  end

  def account_create
    # If account has a stack manager, use Portainer authentication
    if @account.stack_manager.present?
      result = Portainer::Login.execute(
        username: params[:user][:username],
        password: params[:user][:password],
        account: @account,
      )

      if result.success?
        sign_in(result.user)

        # Auto-associate user with account if they sign in through account URL
        session[:account_id] = result.account.id

        redirect_to after_sign_in_path_for(result.user), notice: "Logged in successfully"
      else
        flash.now[:alert] = result.message
        self.resource = result.user || resource_class.new(sign_in_params)
        clean_up_passwords(resource)
        render 'devise/sessions/portainer'
      end
    else
      redirect_to new_user_session_path
    end
  end

  private

  def check_if_default_sign_in_allowed
    if Rails.application.config.account_sign_in_only
      redirect_to accounts_select_url
    end
  end

  def check_if_account_select_allowed
    unless Rails.application.config.account_sign_in_only
      redirect_to new_user_session_path
    end
  end

  def load_account_from_slug
    @account = Account.friendly.find(params[:slug])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Account not found"
    redirect_to new_user_session_path
  end
end
