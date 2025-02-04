class AsyncRendererController < ApplicationController
  def async_render
    renderer = "Async::#{params[:view_model]}ViewModel".constantize
    view_model = renderer.new(current_user, params)
    html = view_model.async_render
  rescue => e
    puts e.message
    html = view_model.render_error
  ensure
    render inline: html.html_safe
  end
end
