class AddOns::BaseController < ApplicationController
  before_action :set_add_on

  private

  def set_add_on
    @add_on = AddOn.find(params[:add_on_id])
  end
end
