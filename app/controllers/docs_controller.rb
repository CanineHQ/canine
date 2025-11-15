class DocsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :swagger, :docs ]

  layout false

  def swagger
    render plain: File.read(Rails.root.join('swagger', 'v1', 'swagger.yaml'))
  end

  def index
  end
end
