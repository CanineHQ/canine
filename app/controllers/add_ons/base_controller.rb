class AddOns::BaseController < ApplicationController
  before_action :set_add_on

  def set_service
    if @add_on.chart_type == "redis"
      @service = K8::Helm::Redis.new(active_connection)
    elsif @add_on.chart_type == "postgresql"
      @service = K8::Helm::Postgresql.new(active_connection)
    else
      @service = K8::Helm::Service.new(active_connection)
    end
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
