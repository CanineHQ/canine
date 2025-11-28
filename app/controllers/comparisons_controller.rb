class ComparisonsController < ApplicationController
  skip_before_action :authenticate_user!
  layout "homepage"

  def show
    comparisons = YAML.load_file(Rails.root.join("resources", "comparisons.yml"))
    @comparison = comparisons["comparisons"].find { |c| c["slug"] == params[:competitor] }

    if @comparison.nil?
      redirect_to root_path, alert: "Comparison not found"
    end
  end
end
