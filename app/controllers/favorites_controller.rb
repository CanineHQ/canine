# frozen_string_literal: true

class FavoritesController < ApplicationController
  include ActionView::RecordIdentifier
  def toggle
    @favoriteable = find_favoriteable

    result = Favorites::Toggle.execute(
      user: current_user,
      account: current_account,
      favoriteable: @favoriteable
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            dom_id(@favoriteable, :favorite),
            partial: "favorites/button",
            locals: { favoriteable: @favoriteable }
          ),
          turbo_stream.replace(
            "sidebar_favorites",
            partial: "layouts/sidebar_favorites"
          )
        ]
      end
      format.json do
        render json: {
          action: result.action_taken,
          favorited: result.action_taken == :added
        }
      end
    end
  end

  private

  def find_favoriteable
    unless %w[Project Cluster AddOn].include?(params[:favoriteable_type])
      raise ActionController::BadRequest, "Invalid favoriteable type"
    end

    klass = params[:favoriteable_type].constantize
    klass.find(params[:favoriteable_id])
  end
end
