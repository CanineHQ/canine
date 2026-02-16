class AddOns::BaseController < ApplicationController
  before_action :set_add_on

  def set_service
    @service = K8::Helm::Service.create_from_add_on(active_connection)
  end

  def active_connection
    @_active_connection ||= K8::Connection.new(@add_on, current_user)
  end
  helper_method :active_connection

  private

  def set_add_on
    @add_on = current_account.add_ons.find(params[:add_on_id])
    set_service
  end
end
