class BuildPacksController < ApplicationController
  def search
    result = Buildpacks::Search.execute(query: params[:q])
    if result.success?
      render json: result.results
    else
      render json: { error: "Failed to search buildpacks" }, status: :unprocessable_entity
    end
  end

  def details
    result = Buildpacks::Details.execute(
      namespace: params[:namespace],
      name: params[:name]
    )
    if result.success?
      render json: result.result
    else
      render json: { error: "Failed to fetch buildpack details" }, status: :unprocessable_entity
    end
  end
end
