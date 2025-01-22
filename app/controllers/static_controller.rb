class StaticController < ApplicationController
  INSTALL_SCRIPT = "curl -sSL https://raw.githubusercontent.com/czhu12/canine/refs/heads/main/install/install.sh | bash"
  skip_before_action :authenticate_user!

  def index
  end
end
