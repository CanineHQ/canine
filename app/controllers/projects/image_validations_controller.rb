class Projects::ImageValidationsController < ApplicationController
  def create
    result = ContainerRegistry::ImageChecker.check(params[:image_url])
    render json: { valid: result.valid, error: result.error }
  end
end
