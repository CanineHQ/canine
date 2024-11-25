class AddOns::BaseController < ApplicationController
  before_action :set_add_on

  def set_service
    if @add_on.chart_type == "redis"
      @service = K8::Helm::Redis.new(@add_on)
    elsif @add_on.chart_type == "postgresql"
      @service = K8::Helm::Postgresql.new(@add_on)
    else
      @service = K8::Helm::Service.new(@add_on)
    end
  end

  private

  def set_add_on
    @add_on = current_account.add_ons.find(params[:add_on_id])
    set_service
  end
end
